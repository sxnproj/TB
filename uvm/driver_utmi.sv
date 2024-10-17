typedef virtual if_utmi utmi_interface;

typedef bit [7:0] byte_type;
typedef byte_type crc16_type [1:0];

// typedef enum {OUT, IN, SOF, SETUP} packet_type;
typedef enum {OUT, IN, SETUP} packet_type;
typedef enum {DATA0, DATA1} data_type;

class driver_utmi extends uvm_driver #(packet_transaction);
    `uvm_component_utils(driver_utmi)

    utmi_interface utmi_vif;

    packet_data pack_data;

    uvm_analysis_port #(packet_transaction) packet_transaction_port;    // analysis port to send transaction data to subscribers
    uvm_analysis_port #(packet_data) packet_data_port;                  // analysis port to send packet data to subscribers
    uvm_analysis_port #(int) utmi_done_port;                            // analysis port to tell subscribers utmi is done
    uvm_analysis_port #(int) data_buffer_port;                          // analysis port to control what data buffer each endpoint is on
    uvm_analysis_port #(utmi_read_data) utmi_read_data_port;            // analysis port to send IN packet reads to subscribers

    endpoint_data_sub sub_endpoint_data;        // subscriber to get endpoint data
    func_address_sub sub_func_address;          // subscriber to get function address
    buffer_size_sub sub_buffer_size;            // subscriber to get buffer size
    wb_done_sub sub_wb_done;                    // subscriber to determine if wb is done
    data_buffer_sub sub_data_buffer;            // subscriber to hold the data buffer each endpoint is on

    int control;

    function new(string name = "driver_utmi", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(utmi_interface)::read_by_name(.scope("ifs"), .name("if_utmi"), .val(utmi_vif)));

        // create subscribers
        this.sub_endpoint_data = endpoint_data_sub#(endpoint_data)::type_id::create("sub_endpoint_data", this);
        this.sub_func_address = func_address_sub#(func_address)::type_id::create("sub_func_address", this);
        this.sub_buffer_size = buffer_size_sub#(buffer_size)::type_id::create("sub_buffer_size", this);
        this.sub_wb_done = wb_done_sub#(int)::type_id::create("sub_wb_done", this);
        this.sub_data_buffer = data_buffer_sub#(int)::type_id::create("sub_data_buffer", this);

        // create analysis ports
        this.packet_transaction_port = new("packet_transaction_port", this);
        this.packet_data_port = new("packet_data_port", this);
        this.utmi_done_port = new("utmi_done_port", this);
        this.data_buffer_port = new("data_buffer_port", this);
        this.utmi_read_data_port = new("utmi_read_data_port", this);

        this.control = 0;
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        this.data_buffer_port.connect(this.sub_data_buffer.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        phase.raise_objection(this);

        init_signals();
        enter_fs_mode();
        // enter_hs_mode();

        repeat(50)
        process_transaction();

        repeat(100)
        @(negedge utmi_vif.phy_clk_pad_i);

        phase.drop_objection(this);
    endtask

    task process_transaction();
        int endpoint;
        int times;
        buffer_size buffer_size;
        endpoint_data ep_data;
        int done = 0;

        this.sub_wb_done.clear();

        seq_item_port.get(req);                 // get random transaction data
        packet_transaction_port.write(req);     // send transaction data to subscribers

        endpoint = req.endpoint_address;                            // the endpoint we will communicate with
        ep_data = this.sub_endpoint_data.ep_array[endpoint];        // grab the endpoint data of specific endpoint
        buffer_size = this.sub_buffer_size.buffer_array[endpoint];  // grab the buffer size of the endpoint

        if (buffer_size.buff_size == 8) begin   // account for control transaction, 8 bytes of data
            times = 1;
        end
        else begin
            times = buffer_size.buff_size/32;             // calculate the number of transactions to fill up endpoint
        end

        // $display("times - %d", times);
        // $display("endpoint - %d", endpoint);
        $display("---------------------------------");

        if (ep_data.ep_type == 2'b00) begin    // control endpoint
            $display("control %d", endpoint);
            // $display("data - %d", req.data);
            // $display("packets - %d", buffer_size.buff_size);
            // for (int x = 0; x < times; x ++) begin
            //     if (this.control == 0) begin
            //         send_token_packet(8'b0010_1101, ep_data.ep_number);     // send setup token packet
            //         this.control = 1;

            //         if (x == times - 1) begin                               // alert subscribers if it is the last packet
            //             done = 1;
            //         end
            //         send_data(req, ep_data, buffer_size, done);          // send data packet
            //     end
            //     else begin
            //         // send_token_packet(8'b0110_1001, ep_data.ep_number);     // send in token packet
            //         send_token_packet(8'b1110_0001, ep_data.ep_number);     // send out token packet
            //         this.control = 0;

            //         send_data(req, ep_data, buffer_size, 1);          // send data packet

            //         // repeat(10)
            //         @(negedge utmi_vif.TxValid_pad_o);      // wait for ACK

            //         repeat(10)                              // give time after ACK
            //         @(negedge utmi_vif.phy_clk_pad_i);

            //         send_token_packet(8'b0110_1001, ep_data.ep_number);     // send IN token

            //         @(negedge utmi_vif.TxValid_pad_o);

            //         send_data_wb_in(ep_data, 1, 8);                            // send data to wb so it can keep going
                    
            //         if (this.control == 0) begin
            //             repeat(5)
            //             @(negedge utmi_vif.phy_clk_pad_i);
                        
            //             send_handshake(8'b1101_0010);       // send ACK
            //         end

            //         // this.utmi_done_port.write(1);                               // tell subscribers the utmi is done
            //         // $display("waiting on wb");
            //         // @(posedge this.sub_wb_done.wb_done);                        // wait until wb is done with its processing
            //         // $display("done waiting on wb");
            //         // this.sub_wb_done.clear();
            //         // break;
            //     end

            //     // if (x == times - 1) begin                               // alert subscribers if it is the last packet
            //     //     done = 1;
            //     // end
            //     // send_data(req, ep_data, buffer_size, done);          // send data packet
            // end
            // this.utmi_done_port.write(1);                               // tell subscribers the utmi is done
            // $display("waiting on wb");
            // @(posedge this.sub_wb_done.wb_done);                        // wait until wb is done with its processing
            // $display("done waiting on wb");
            // this.sub_wb_done.clear();
        end
        else if (ep_data.ep_type == 2'b01) begin    // IN endpoint
            handle_in(req, ep_data, buffer_size, times);
        end
        else if (ep_data.ep_type == 2'b10) begin    // OUT endpoint
            handle_out(req, ep_data, buffer_size, times);
        end

        repeat (10)
        @(negedge utmi_vif.phy_clk_pad_i);
    endtask

    task handle_in(input packet_transaction req, input endpoint_data ep_data, input buffer_size buffer_size, input int times);
        int done = 0;

        $display("in - endpoint %d", req.endpoint_address);
        $display("packets (bytes) - %d", buffer_size.buff_size);
        // $display("times - %d", times);

        for (int x = 0; x < times; x ++) begin          // send data until buffer is filled
            if (x == times - 1) begin
                done = 1;
            end
            // $display("send data - %d", done);
            send_data_wb_in(ep_data, done, 32);
        end

        @(posedge this.sub_wb_done.wb_done);        // wb is done filling the IN buffer
        this.sub_wb_done.clear();

        done = 0;

        for (int x = 0; x < times; x ++) begin                          // keep asking for data until all expected data is given
            if (x == times - 1) begin
                done = 1;                                               // determine if it is the last packet
            end
            send_token_packet(8'b0110_1001, ep_data.ep_number);         // send IN token packet

            collect_in_data(done);                                      // collect the response

            repeat(5)
            @(negedge utmi_vif.phy_clk_pad_i);

            send_handshake(8'b1101_0010);       // send ACK
        end

        this.utmi_done_port.write(1);                               // tell subscribers the utmi is done
        $display("waiting on wb - utmi");
        @(posedge this.sub_wb_done.wb_done);                        // wait until wb is done with its processing
        $display("done waiting - utmi");
        this.sub_wb_done.clear();
    endtask

    task handle_out(input packet_transaction req, input endpoint_data ep_data, input buffer_size buffer_size, input int times);
        int done = 0;
        int error;

        $display("out - endpoint %d", req.endpoint_address);
        $display("packets (bytes) - %d", buffer_size.buff_size);

        for (int x = 0; x < times; x ++) begin
            send_token_packet(8'b1110_0001, ep_data.ep_number);     // send out token packet
            if (x == times - 1) begin                               // alert subscribers if it is the last packet
                done = 1;
            end
            send_data(req, ep_data, buffer_size, done, error);          // send data packet
            if (error == 1) begin                                       // we need to send an extra packet
                $display("error packet");
                x = x - 1;
            end
        end
        $display("waiting on wb - utmi");
        this.utmi_done_port.write(1);                               // tell subscribers the utmi is done
        @(posedge this.sub_wb_done.wb_done);                        // wait until wb transaction handler done with its processing
        this.sub_wb_done.clear();
        $display("waiting on wb again - utmi");
        this.utmi_done_port.write(1);
        @(posedge this.sub_wb_done.wb_done);                        // wait until wb interrupt handler is done processing
        this.sub_wb_done.clear();
    endtask

    task collect_in_data(input int done);
        utmi_read_data read_data;
        int index = 0;

        read_data = utmi_read_data::type_id::create("read_data");
        read_data.done = done;                                      // set to 1 if it is the last packet

        @(posedge utmi_vif.TxValid_pad_o);
        utmi_vif.TxReady_pad_i = 1;

        while (utmi_vif.TxValid_pad_o == 1) begin       // wait until transfer is over
            @(negedge utmi_vif.phy_clk_pad_i);          // wait for next clock cycle
            case (index)
                0       :   read_data.token = utmi_vif.DataOut_pad_o;
                33      :   read_data.crc16[0] = utmi_vif.DataOut_pad_o;
                34      :   read_data.crc16[1] = utmi_vif.DataOut_pad_o;
                default :   read_data.data[index - 1] = utmi_vif.DataOut_pad_o;
            endcase
            index = index + 1;                          // increment index
        end
        utmi_vif.TxReady_pad_i = 0;

        this.utmi_read_data_port.write(read_data);
    endtask

    task send_handshake(input bit [7:0] pid);
        utmi_vif.RxActive_pad_i = 1;
        @(negedge utmi_vif.phy_clk_pad_i);
        utmi_vif.RxValid_pad_i = 1;
        utmi_vif.RxError_pad_i = 0;

        utmi_vif.DataIn_pad_i = pid;    // send PID
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.RxActive_pad_i = 0;
        utmi_vif.RxValid_pad_i = 0;
        utmi_vif.DataIn_pad_i = 8'b0000_0000;

        repeat(5)
        @(negedge utmi_vif.phy_clk_pad_i);

    endtask

    task send_data_wb_in(input endpoint_data ep_data, input int last, input int size);
        this.pack_data = packet_data::type_id::create("pack_data");
        assert(this.pack_data.randomize());
        this.pack_data.done = last;
        this.pack_data.error = 0;       // turn off errors for now

        this.pack_data.packet_size = size;

        this.packet_data_port.write(pack_data);

        repeat(10)
        @(negedge utmi_vif.phy_clk_pad_i);
    endtask

    // packages up the data in the transaction and does all the processing to prepare subscribers for the packet
    task send_data(input packet_transaction pak_trans, input endpoint_data ep_data, input buffer_size buffer_size, input int last, output int error);
        // $display("buffer size - %d", buffer_size.buff_size);

        this.pack_data = packet_data::type_id::create("pack_data");
        assert(this.pack_data.randomize());                 // randomize the data
        this.pack_data.done = last;                         // if 1 then flip done flag in subscriber

        if (this.pack_data.error == 1) begin                // set error if there is an error
            error = 1;
        end
        else begin
            error = 0;
        end

        if (ep_data.ep_type == 2'b00) begin                 // set packet size to 8 if control otherwise 32
            this.pack_data.packet_size = 8;
        end
        else begin
            this.pack_data.packet_size = 32;
        end
        $display("data sent - utmi");
        this.packet_data_port.write(pack_data);                 // send randomized data and information to subscribers

        send_data_packet(this.pack_data, ep_data, pak_trans);

    endtask

    // sends a single packet of data within a transaction
    task send_data_packet(input packet_data pak_data, input endpoint_data ep_data, input packet_transaction trans);
        bit [7:0] pid;
        bit [7:0] data [31:0];
        int loops;
        bit [7:0] crc16_out [1:0];

        // set the PID for the data packet
        if (this.sub_data_buffer.ep_data_buffer[trans.endpoint_address] == 0) begin         // go with DATA0
            pid = 8'b1100_0011;
        end
        else if (this.sub_data_buffer.ep_data_buffer[trans.endpoint_address] == 1) begin    // go with DATA1
            pid = 8'b0100_1011;
        end

        if (pak_data.error != 1) begin  // only swap buffer if no error
            this.data_buffer_port.write(trans.endpoint_address);        // write the endpoint number to toggle the data buffer
        end

        data = pak_data.data;                       // set the data to send in the data packet
        loops = pak_data.packet_size;               // set the times to loop based on packet size

        if (loops == 8) begin                       // calculate the crc with the two packet size options
            crc16_out = crc16_cal(data[7:0], 8);
        end
        else if (loops == 32) begin
            crc16_out = crc16_cal(data[31:0], 32);
        end

        if (pak_data.error == 1) begin          // generate error
            if (pak_data.crc_data == 0) begin   // generate the error in crc
                crc16_out[pak_data.index_crc] = crc16_out[pak_data.index_crc] + pak_data.data_corrupt;
            end
            else begin                          // generate the error in data
                data[pak_data.index_data] = data[pak_data.index_data] + pak_data.data_corrupt;
            end
        end

        utmi_vif.RxActive_pad_i = 1;
        @(negedge utmi_vif.phy_clk_pad_i);
        utmi_vif.RxValid_pad_i = 1;
        utmi_vif.DataIn_pad_i = pid;                     // send pid byte
        @(negedge utmi_vif.phy_clk_pad_i);

        for (int x = 0; x < loops; x++) begin           // start at byte 0 and send however many we need
            utmi_vif.DataIn_pad_i = data[x];
            @(negedge utmi_vif.phy_clk_pad_i);
        end

        utmi_vif.DataIn_pad_i = crc16_out[1];           // send crc
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.DataIn_pad_i = crc16_out[0];
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.RxActive_pad_i = 0;                // end the transaction
        utmi_vif.RxValid_pad_i = 0;
        utmi_vif.DataIn_pad_i = 8'b0000_0000;
        @(negedge utmi_vif.phy_clk_pad_i);

        repeat(5)
        @(negedge utmi_vif.phy_clk_pad_i);
    endtask

    // sends the token packet
    task send_token_packet(input bit [7:0] pid, input bit [3:0] endpoint_number);
        bit [10:0] crc_input;
        bit [10:0] crc_input_rev;
        bit [4:0] crc_output;

        crc_input[6:0] = this.sub_func_address.function_address.function_address;   // combine function address with endpoint number
        crc_input[10:7] = endpoint_number;
        crc_input_rev = {<< {crc_input}};       // reverse the data to put into the crc calculator

        crc_output = crc5_cal(crc_input_rev);

        utmi_vif.RxActive_pad_i = 1;
        @(negedge utmi_vif.phy_clk_pad_i);
        utmi_vif.RxValid_pad_i = 1;
        utmi_vif.RxError_pad_i = 0;

        utmi_vif.DataIn_pad_i = pid;    // send PID
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.DataIn_pad_i = crc_input[7:0];    // send address and endpoint
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.DataIn_pad_i = {crc_output, crc_input[10:8]};    // CRC and remaining endpoint
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.RxActive_pad_i = 0;
        utmi_vif.RxValid_pad_i = 0;
        utmi_vif.DataIn_pad_i = 8'b0000_0000;

        @(negedge utmi_vif.phy_clk_pad_i);
    endtask

    task init_signals();
        utmi_vif.TxReady_pad_i = 0;
        utmi_vif.RxValid_pad_i = 0;
        utmi_vif.RxActive_pad_i = 0;
        utmi_vif.RxError_pad_i = 0;
        utmi_vif.DataIn_pad_i = 0;
        utmi_vif.LineState_pad_i = 0;
        utmi_vif.usb_vbus_pad_i = 0;
        utmi_vif.VStatus_pad_i = 0;
    endtask

    task enter_fs_mode();
        utmi_vif.LineState_pad_i = 0;
        repeat(6_001_000)
        @(negedge utmi_vif.phy_clk_pad_i);      // this wait enters normal mode

        utmi_vif.LineState_pad_i = 1;
        repeat(500)
        @(negedge utmi_vif.phy_clk_pad_i);      // this wait enters reset

        utmi_vif.LineState_pad_i = 0;
        repeat(100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 0;           // do not chirp so it enters FS mode
        repeat(100_000)
        @(negedge utmi_vif.phy_clk_pad_i);
    endtask

    task enter_hs_mode();
        utmi_vif.LineState_pad_i = 0;
        repeat(6_001_000)
        @(negedge utmi_vif.phy_clk_pad_i);      // this wait enters normal mode

        utmi_vif.LineState_pad_i = 1;
        repeat(500)
        @(negedge utmi_vif.phy_clk_pad_i);      // this wait enters reset

        utmi_vif.LineState_pad_i = 0;
        repeat(100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 2;           // start chirping to go into HS mode
        repeat (200_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 1;
        repeat (100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 2;
        repeat (100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 1;
        repeat (100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 2;
        repeat (100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 1;
        repeat (100_000)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 0;
        repeat (500)
        @(negedge utmi_vif.phy_clk_pad_i);

        utmi_vif.LineState_pad_i = 1;        // idle for HS mode
        repeat (1_000)
        @(negedge utmi_vif.phy_clk_pad_i);
    endtask

    function crc16_type crc16_cal(input bit [7:0] data_in [], input int size);//, output bit crc16 [15:0]);
        bit Gn [$] = '{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 , 0, 1, 0, 1};
        bit hold [$] = '{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
        bit res [$];
        bit [7:0] data_rev [];
        bit data [];
        reg [7:0] crc16_out [1:0];
        bit crc16 [15:0];

        data_rev = new [size];

        foreach (data_in[i]) begin
            data_rev[i] = {>> {data_in[i]}};
        end

        data = {>> {data_rev}};
        data = {<< {data}};

        foreach (data[i]) begin
            if (data[i] == hold.pop_front()) begin
                hold.push_back(1'b0);
            end
            else begin
                hold.push_back(1'b0);
                xor16(hold, Gn, res);
                hold = res;
            end
        end

        for (int x = 0; x < 16; x ++) begin
            if (hold.pop_front() == 1'b0) begin
                crc16[x] = 1'b1;
            end
            else begin
                crc16[x] = 1'b0;
            end
        end

        crc16_out = {<<{crc16}};
        foreach (crc16_out[i]) begin
            crc16_out[i] = {<<{crc16_out[i]}};
        end

        return crc16_out;
    endfunction

    function bit [4:0] crc5_cal(input bit [10:0] data_in);//, output bit crc5 [4:0]);
        bit Gn [$] = '{0, 0, 1, 0, 1};
        bit hold [$] = '{1, 1, 1, 1, 1};
        bit res [$];
        bit data [];
        bit crc5 [4:0];
        reg [4:0] crc5_out;

        data = {>> 1 {data_in}};

        foreach (data[i]) begin
            if (data[i] == hold.pop_front()) begin
                hold.push_back(1'b0);
            end
            else begin
                hold.push_back(1'b0);
                xor5(hold, Gn, res);
                hold = res;
            end
        end

        for (int x = 0; x < 5; x ++) begin
            if (hold.pop_front() == 1'b0) begin
                crc5[x] = 1'b1;
            end
            else begin
                crc5[x] = 1'b0;
            end
        end

        crc5_out = {<< {crc5}};
        crc5_out = {<< {crc5_out}};

        return crc5_out;
    endfunction

    function void xor5(input bit hold [$], input bit Gn [$], output bit res [$]);
        bit x [$];
        bit y [$];
        res = {};
        x = hold;
        y = Gn;
        for (int i = 0; i < 5; i ++) begin
            if (x.pop_front() == y.pop_front()) begin
                res.push_back(1'b0);
            end
            else begin
                res.push_back(1'b1);
            end
        end
    endfunction

    function void xor16(input bit hold [$], input bit Gn [$], output bit res [$]);
        bit x [$];
        bit y [$];
        res = {};
        x = hold;
        y = Gn;
        for (int i = 0; i < 16; i ++) begin
            if (x.pop_front() == y.pop_front()) begin
                res.push_back(1'b0);
            end
            else begin
                res.push_back(1'b1);
            end
        end
    endfunction

endclass : driver_utmi