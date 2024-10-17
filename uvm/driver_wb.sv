typedef virtual if_wb wb_interface;
// typedef virtual if_utmi utmi_interface;

// typedef enum {DATA0, DATA1} data_type;

class driver_wb extends uvm_driver #(packet_init);
    `uvm_component_utils(driver_wb)

    wb_interface wb_vif;
    utmi_interface utmi_vif;

    semaphore wb_bus_sem;       // semaphore to allow only one task to use wb bus at a time

    endpoint_data ep_array[4];
    int buffer_size_array[4];

    uvm_analysis_port #(endpoint_data) endpoint_data_port;      // send endpoint data out
    uvm_analysis_port #(interrupt_data) interrupt_data_port;    // send interrupt data out
    uvm_analysis_port #(func_address) function_address_port;    // send function address out
    uvm_analysis_port #(buffer_size) buffer_size_port;          // send buffer size out
    uvm_analysis_port #(int) wb_done_port;                      // used to alert subscribers that the wb is done
    uvm_analysis_port #(wb_read_data) wb_data_port;               // send data read from wb to subscribers

    packet_transaction_sub sub_packet_transaction;      // subscriber that holds the transaction information
    packet_data_sub sub_packet_data;                    // subscriber that holds the packet data
    utmi_done_sub sub_utmi_done;                        // subscriber that determines if utmi is done

    bit start;

    function new(string name = "driver_wb", uvm_component parent = null);
        super.new(name, parent);
        // create analysis ports
        this.endpoint_data_port = new("endpoint_data_port", this);
        this.interrupt_data_port = new("interrupt_data_port", this);
        this.function_address_port = new("function_address_port", this);
        this.buffer_size_port = new("buffer_size_port", this);
        this.wb_done_port = new("wb_done_port", this);
        this.wb_data_port = new("wb_data_port", this);

        // this.init_data = packet_init::type_id::create("init_data", this);
        // create subscribers
        this.sub_packet_transaction = packet_transaction_sub#(packet_transaction)::type_id::create("sub_packet_transaction", this);
        this.sub_packet_data = packet_data_sub#(packet_data)::type_id::create("sub_packet_data", this);
        this.sub_utmi_done = utmi_done_sub#(int)::type_id::create("sub_utmi_done", this);

        // initialize semaphores
        this.wb_bus_sem = new(1);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(wb_interface)::read_by_name(.scope("ifs"), .name("if_wb"), .val(wb_vif)));
        void'(uvm_resource_db#(utmi_interface)::read_by_name(.scope("ifs"), .name("if_utmi"), .val(utmi_vif)));

        this.start = 0;
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        reset();
        init_ep_buf_size();
        init_ep_csr();
        init_ep_int_msk();
        init_rf_int_mask();
        init_func_address();

        fork
            handle_interrupts();
            handle_transactions();
        join
    endtask

    // task that handles all the interrupt processing when an interrupt happens
    task handle_interrupts();
        interrupt_data interrupt_out;
        while (1) begin
            @(posedge wb_vif.clk);
            if (wb_vif.inta_o == 1'b1) begin
                $display("handle interrupts");
                read_rf_interrupts(interrupt_out);                  // the interrupt data is now stored in interrupt_out variable
                if (interrupt_out.ep_interrupt != 0) begin         // there is an interrupt on an endpoint
                    if (interrupt_out.ep_interrupt & 16'b0000_0000_0000_0001) begin        // endpoint 0
                        read_ep_interrupts(0);
                    end
                    if (interrupt_out.ep_interrupt & 16'b0000_0000_0000_0010) begin        // endpoint 1
                        read_ep_interrupts(1);
                    end
                    if (interrupt_out.ep_interrupt & 16'b0000_0000_0000_0100) begin        // endpoint 2
                        read_ep_interrupts(2);
                    end
                    if (interrupt_out.ep_interrupt & 16'b0000_0000_0000_1000) begin        // endpoint 3
                        read_ep_interrupts(3);
                    end
                end
                if (interrupt_out.rf_interrupt & 9'b1_0000_0000) begin     // it is in reset, so wait for reset to be over
                    $display("reset here");
                    // $display("rf_interrupts %b", this.interrupt_out.rf_interrupt);
                    repeat(150_000)
                    @(negedge wb_vif.clk);
                end
            end
        end
    endtask

    // task that handles IN type packets by writing data into memory to be sent when requested
    task handle_transactions();
        endpoint_data ep_data;
        int ep_address;
        int buffer_size;

        while (1) begin
            $display("waiting for data - wb driver");
            @(posedge this.sub_packet_data.new_data);       // wait until new transaction is created
            this.sub_utmi_done.clear();

            $display("handle packets");

            ep_address = this.sub_packet_transaction.pak_transaction.endpoint_address;
            ep_data = ep_array[ep_address];     // get the endpoint data for this transaction
            buffer_size = this.buffer_size_array[ep_address];

            if (ep_data.ep_type == 2'b00) begin                     // control endpoint
                this.sub_packet_data.clear();                   // clear flag for to wait for new transaction
                $display("waiting on utmi");
                @(posedge this.sub_utmi_done.utmi_done);        // wait until utmi has finished driving
                this.sub_utmi_done.clear();                     // clear flag for transaction

                handle_dma(buffer_size, ep_address);
            end
            if (ep_data.ep_type == 2'b10) begin                     // OUT endpoint
                this.sub_packet_data.clear();                   // clear flag for to wait for new transaction
                this.sub_utmi_done.clear();
                $display("waiting on utmi");
                @(posedge this.sub_utmi_done.utmi_done);        // wait until utmi has finished driving
                this.sub_utmi_done.clear();                     // clear flag for transaction

                handle_dma(buffer_size, ep_address);
            end
            if (ep_data.ep_type == 2'b01) begin                     // IN endpoint

                in_write_to_mem(ep_address);                              // all the data should be here, write it to memory and tell utmi once done

                this.sub_packet_data.clear();                   // clear flag for to wait for new transaction
                this.wb_done_port.write(1);                 // tell utmi the IN buffer is filled
                $display("waiting on utmi - wb in");
                @(this.sub_utmi_done.utmi_done);
                $display("done waiting - wb in");
                this.sub_utmi_done.clear();                     // clear flag for transaction
            end
            this.wb_done_port.write(1);         // tell subscribers that wb transaction handler
        end
    endtask

    task out_read_from_mem(input int address, output bit [31:0] wb_out);
        bit [17:0] addr;
        bit [14:0] sram_addr;
        bit [31:0] data_out;

        sram_addr = address;
        addr = {1'b1, sram_addr, 2'b00};        // generate the memory address to read from

        wb_read(addr, 0, data_out);

        wb_out = data_out;
    endtask

    // used by IN endpoints to write data to memory for sending to the utmi
    task in_write_to_mem(input int ep_address);
        bit [17:0] addr;
        bit [31:0] data;
        int max_idx;
        bit [14:0] sram_addr = 15'b000_0000_0000_0000;
        bit [15:0] dma_ack = 16'b0000_0000_0000_0001;

        max_idx = this.sub_packet_data.current_index;   // get the bytes of data
        dma_ack = dma_ack << ep_address;

        $display("bytes - %d", max_idx);

        for (int x = 0; x < max_idx; x = x + 4) begin
            data[7:0] = this.sub_packet_data.data_packet[x];
            data[15:8] = this.sub_packet_data.data_packet[x + 1];
            data[23:16] = this.sub_packet_data.data_packet[x + 2];
            data[31:24] = this.sub_packet_data.data_packet[x + 3];

            this.wb_bus_sem.get(1);

            addr = {1'b1, sram_addr, 2'b00};
            sram_addr = sram_addr + 1;
            wb_write(addr, data);                           // write the 4 bytes of data to memory

            this.wb_bus_sem.put(1);

            wb_vif.dma_ack_i = dma_ack;                     // give dma ack to tell endpoint there is data in the buffer
            @(posedge utmi_vif.phy_clk_pad_i);
            wb_vif.dma_ack_i = 16'b0000_0000_0000_0000;
        end

    endtask

    task handle_dma(input int buffer_size, input int ep_address);
        int size;
        bit [15:0] dma_ack = 16'b0000_0000_0000_0001;
        
        dma_ack = dma_ack << ep_address;    // select the right location to signal dma ack

        $display("dma doing");

        repeat(20)
        @(negedge wb_vif.clk);

        if (((wb_vif.dma_req_o >> ep_address) & 16'b0000_0000_0000_0001) == 1) begin
            wb_vif.dma_ack_i = dma_ack;
            while (1) begin
                @(negedge wb_vif.clk);
                if (((wb_vif.dma_req_o >> ep_address) & 16'b0000_0000_0000_0001) == 0) begin     // wait until dma req is no longer asserted
                    break;
                end
            end
        end

        wb_vif.dma_ack_i = 16'b0000_0000_0000_0000;
    endtask

    // handles reading endpoint interrupts and if the endpoint is filled, it handles reading the data from the memory
    task read_ep_interrupts(input int endpoint_number);
    bit [17:0] addr;
    bit [31:0] data = 32'h00000000;
    bit [4:0] location = 5'b00100;
    bit [31:0] out_data;
    int buffer_size;
    int reads;
    wb_read_data data_out;

    this.wb_bus_sem.get(1);

    location = location + endpoint_number;      // should be 0 for ep 0, and 1 for ep 1 and so on
    addr = {9'b000000000, location, 2'b01, 2'b00};
    
    wb_read(addr, data, out_data);
    // $display("ep_interrupts %b", out_data);

    if (((out_data & 31'b0000_0000_0000_0000_0000_0000_0001_0000) >> 4 == 1) && this.ep_array[endpoint_number].ep_type != 2'b01) begin       // the endpoint is filled (OUT and CONTROL endpoints)
        buffer_size = this.buffer_size_array[endpoint_number];
        reads = buffer_size / 4;                                    // calculate the number of times w need to read
        
        for (int x = 0; x < reads; x ++) begin
            data_out = wb_read_data::type_id::create("data_out", this);
            if (x == reads - 1) begin       // last read signal
                data_out.done = 1;
            end

            out_read_from_mem(x, out_data);     // reads 4 bytes "32 bits" from the memory from selected address
            data_out.data = out_data;

            this.wb_data_port.write(data_out);  // sends the read data to subscribers
        end

        this.wb_done_port.write(1);         // tell subscribers that wb is done reading from memory
    end

    this.wb_bus_sem.put(1);
    endtask

    task init_func_address();
        bit [6:0] function_address;
        bit [17:0] addr = 18'b00_0000_0000_0000_0100;
        bit [31:0] data;
        func_address function_addr;

        seq_item_port.get(req);
        function_address = req.function_address;
        data = {25'b0000000000000000000000000, function_address};

        
        function_addr = func_address::type_id::create("function_addr", this);
        function_addr.function_address = function_address;
        this.function_address_port.write(function_addr);        // send function address to subscribers

        this.wb_bus_sem.get(1);
        wb_write(addr, data);
        this.wb_bus_sem.put(1);
    endtask

    task read_rf_interrupts(output interrupt_data interrupt_out);
        bit [17:0] addr = 18'b00_0000_0000_0000_1100;
        bit [31:0] data = 32'h00000000;
        bit [31:0] out_data;

        this.wb_bus_sem.get(1);
        wb_rf_read(addr, data, out_data);
        this.wb_bus_sem.put(1);

        interrupt_out = interrupt_data::type_id::create("interrupt_out", this);
        interrupt_out.rf_interrupt = out_data[28:20];       // interrupt list for register file
        interrupt_out.ep_interrupt = out_data[15:0];        // interrupt for which endpoint has an interrupt
        interrupt_data_port.write(interrupt_out);      // send interrupt data to subscribers
        // $display("rf_interrupts %b", out_data);
    endtask

    // initializes the endpoint buffer sizes
    task init_ep_buf_size();
        bit [17:0] addr0;
        bit [17:0] addr1;
        bit [31:0] data;
        bit [4:0] location = 5'b00100;

        buffer_size buff_size;

        // configure ep 0 - 3
        for (int x = 0; x <= 3; x++) begin
            buff_size = buffer_size::type_id::create("buff_size", this);
            buff_size.ep_number = x;
            addr0 = {9'b000000000, location, 2'b10, 2'b00};   // location determines the endpoint targeted and the "10" is the buf0 size write
            addr1 = {9'b000000000, location, 2'b11, 2'b00};  // same endpoint but the "11" selects buf1 instead of buf0
            if (location == 5'b00100) begin
                data = {1'b0, 14'b00000000001000, 17'b00000000000000000};      // hardcode ep 0 to store 8 bytes for setup transaction
                buff_size.buff_size = 8;
                this.buffer_size_array[x] = 8;
            end
            else begin
                seq_item_port.get(req);
                data = {1'b0, req.buffer_size, 17'b00000000000000000};     // rest of the ep gets random buffer size
                buff_size.buff_size = req.buffer_size;
                this.buffer_size_array[x] = req.buffer_size;
            end
            this.buffer_size_port.write(buff_size);     // send buffer size to subscribers
            this.wb_bus_sem.get(1);
            wb_write(addr0, data);
            wb_write(addr1, data);
            this.wb_bus_sem.put(1);
            location = location + 1;
        end
    endtask

    // initializes the csr register of all endpoints
    task init_ep_csr();
        bit [1:0] ep_type;
        bit [1:0] tr_type = 2'b00;
        bit [1:0] ep_dis = 2'b00;
        bit [3:0] ep_number;
        bit lrg_ok = 1'b1;
        bit sml_ok = 1'b1;
        bit dma_en = 1'b1;
        bit ots_stop = 1'b0;
        bit [1:0] tr_fr = 2'b11;
        bit [10:0] max_pl_sz = 11'b00000100000;

        bit [31:0] data;
        bit [17:0] addr;
        bit [4:0] location = 5'b00100;

        endpoint_data ep_model;

        for (int x = 0; x <= 3; x++) begin
            addr = {9'b000000000, location, 2'b00, 2'b00};   // location determines the ep and the "00" next to it commands a csr write
            if (location == 5'b00100) begin
                ep_type = 2'b00;                // control endpoint type
                ep_number = 3'b0000;            // set ep number to 0
                max_pl_sz = 11'b00000001000;    // set packet size to 8
                dma_en = 1'b0;                  // turn dma off
                data = {4'b0000, ep_type, tr_type, ep_dis, ep_number, lrg_ok, sml_ok, dma_en, 1'b0, ots_stop, tr_fr, max_pl_sz};
            end
            else if (ep_type == 2'b00) begin
                seq_item_port.get(req);
                ep_type = req.ep_type;      // randomize the endpoint type
                ep_number = ep_number + 1;  // increment the endpoint number
                max_pl_sz = 11'b00000100000;    // set packet size to 32
                dma_en = 1'b1;                  // turn dma on
                data = {4'b0000, ep_type, tr_type, ep_dis, ep_number, lrg_ok, sml_ok, dma_en, 1'b0, ots_stop, tr_fr, max_pl_sz};
            end
            else begin  // randc is being weird, so use this else to ensure all ep types are created
                if (ep_type == 2'b01) begin
                    ep_type = 2'b10;
                end
                else begin
                    ep_type = 2'b01;
                end
                ep_number = ep_number + 1;  // increment the endpoint number
                max_pl_sz = 11'b00000100000;    // set packet size to 32
                dma_en = 1'b1;                  // turn dma on
                data = {4'b0000, ep_type, tr_type, ep_dis, ep_number, lrg_ok, sml_ok, dma_en, 1'b0, ots_stop, tr_fr, max_pl_sz};
            end
            this.wb_bus_sem.get(1);
            wb_write(addr, data);
            this.wb_bus_sem.put(1);
            location = location + 1;

            ep_model = endpoint_data::type_id::create("ep_model", this);        // store all the ep data to send to utmi side
            ep_model.ep_type = ep_type;
            ep_model.tr_type = tr_type;
            ep_model.ep_dis = ep_dis;
            ep_model.ep_number = ep_number;
            ep_model.lrg_ok = lrg_ok;
            ep_model.sml_ok = sml_ok;
            ep_model.dma_en = dma_en;
            ep_model.ots_stop = ots_stop;
            ep_model.tr_fr = tr_fr;
            ep_model.max_pl_sz = max_pl_sz;
            this.endpoint_data_port.write(ep_model);        // send endpoint data to subscribers
            this.ep_array[x] = ep_model;
            // $display("sending ep - %b", ep_model.ep_type);
        end
    endtask

    // initializes interrupt masks for endpoints
    task init_ep_int_msk();
        bit [17:0] addr;
        bit [31:0] data = 32'b0011_1111_0011_1111_0000_0000_0000_0000;  // hardcode all the ep to have all interrupts on

        bit [4:0] location = 5'b00100;

        this.wb_bus_sem.get(1);
        for (int x = 0; x <= 3; x++) begin
            addr = {9'b000000000, location, 2'b01, 2'b00};  // location selects the ep to and the "01" writes to the int_mask
            wb_write(addr, data);
            location = location + 1;
        end
        this.wb_bus_sem.put(1);
    endtask

    // initializes interrupt mask for register file
    task init_rf_int_mask();
        // sets all the interrupts in the register file to enabled
        bit [17:0] addr = 18'b00_0000_0000_0000_1000;               // if [8:2] == 2 it is a write to int_mask for register file
        bit [31:0] data = 32'b0000_0001_1111_1111_0000_0001_1111_1111;  // [26:16] and [8:0] writes to int_mask

        this.wb_bus_sem.get(1);
        wb_write(addr, data);
        this.wb_bus_sem.put(1);
    endtask

    // writes something through the wb
    task wb_write(input bit [17:0] address, input bit [31:0] data);
        wb_vif.wb_stb_i = 1;
        wb_vif.wb_cyc_i = 1;
        wb_vif.wb_we_i = 1;
        wb_vif.wb_addr_i = address;
        wb_vif.wb_data_i = data;

        @(posedge wb_vif.wb_ack_o);

        wb_vif.wb_stb_i = 0;
        wb_vif.wb_cyc_i = 0;
        wb_vif.wb_we_i = 0;
        wb_vif.wb_addr_i = 18'b000000000000000000;
        wb_vif.wb_data_i = 32'b00000000000000000000000000000000;

        repeat(5)
        @(negedge wb_vif.clk);
    endtask

    // reads from the rf registers
    task wb_rf_read(input bit [17:0] address, input bit [31:0] data, output bit [31:0] out_data);
        wb_vif.wb_stb_i = 1;
        wb_vif.wb_cyc_i = 1;
        wb_vif.wb_we_i = 1;
        wb_vif.wb_addr_i = address;
        wb_vif.wb_data_i = data;

        @(posedge wb_vif.wb_ack_o);

        wb_vif.wb_stb_i = 0;
        wb_vif.wb_cyc_i = 0;
        wb_vif.wb_we_i = 0;
        wb_vif.wb_addr_i = 18'b000000000000000000;
        wb_vif.wb_data_i = 32'b00000000000000000000000000000000;

        out_data = wb_vif.wb_data_o;                        // read the data
        // $display("interrupts - %b", wb_vif.wb_data_o);

        @(negedge wb_vif.clk);          // now clear the register by doing a read

        wb_vif.wb_stb_i = 1;
        wb_vif.wb_cyc_i = 1;
        wb_vif.wb_we_i = 0;
        wb_vif.wb_addr_i = address;
        wb_vif.wb_data_i = data;

        @(posedge wb_vif.wb_ack_o);

        wb_vif.wb_stb_i = 0;
        wb_vif.wb_cyc_i = 0;
        wb_vif.wb_we_i = 0;
        wb_vif.wb_addr_i = 18'b000000000000000000;
        wb_vif.wb_data_i = 32'b00000000000000000000000000000000;

        repeat(5)
        @(negedge wb_vif.clk);

    endtask

    // reads from the wb
    task wb_read(input bit [17:0] address, input bit [31:0] data, output bit [31:0] out_data);
        wb_vif.wb_stb_i = 1;
        wb_vif.wb_cyc_i = 1;
        wb_vif.wb_we_i = 0;
        wb_vif.wb_addr_i = address;
        wb_vif.wb_data_i = data;

        @(posedge wb_vif.wb_ack_o);

        wb_vif.wb_stb_i = 0;
        wb_vif.wb_cyc_i = 0;
        wb_vif.wb_we_i = 0;
        wb_vif.wb_addr_i = 18'b000000000000000000;
        wb_vif.wb_data_i = 32'b00000000000000000000000000000000;

        out_data = wb_vif.wb_data_o;                        // read the data
        // $display("interrupts - %b", wb_vif.wb_data_o);

        repeat(5)
        @(negedge wb_vif.clk);

    endtask

    // resets the device
    task reset();
        wb_vif.reset = 1'b0;
        wb_vif.wb_addr_i = 0;
        wb_vif.wb_data_i = 32'h00000000;
        wb_vif.wb_we_i = 1'b0;
        wb_vif.wb_stb_i = 1'b0;
        wb_vif.wb_cyc_i = 1'b0;
        wb_vif.dma_ack_i = 16'h0000;
        wb_vif.resume_req_i = 1'b0;
        @(negedge wb_vif.clk);
        @(negedge wb_vif.clk);
        wb_vif.reset = 1'b1;
        @(negedge wb_vif.clk);
        @(negedge wb_vif.clk);
        wb_vif.reset = 1'b0;
        @(negedge wb_vif.clk);
        @(negedge wb_vif.clk);
    endtask

endclass : driver_wb