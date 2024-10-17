class monitor_utmi extends uvm_monitor;
    `uvm_component_utils(monitor_utmi)

    utmi_interface utmi_vif;

    packet_transaction_sub sub_packet_transaction;  // subscriber for getting transaction data
    endpoint_data_sub sub_endpoint_data;            // subscriber for getting endpoint data
    func_address_sub sub_func_address;          // subscriber to get function address
    buffer_size_sub sub_buffer_size;            // subscriber to get buffer size
    packet_data_sub sub_packet_data;            // subscriber to get packet data
    utmi_done_sub sub_utmi_done;            // subscriber to determine if UTMI is done generating data
    utmi_data_sub sub_utmi_data;            // subscriber to get read IN data from UTMI

    bit [7:0] read_data [511:0];        // max data size is 512 bytes

    function new(string name = "monitor_utmi", uvm_component parent = null);
        super.new(name, parent);
        // create subscribers
        this.sub_packet_transaction = packet_transaction_sub#(packet_transaction)::type_id::create("sub_packet_transaction", this);
        this.sub_endpoint_data = endpoint_data_sub#(endpoint_data)::type_id::create("sub_endpoint_data", this);
        this.sub_func_address = func_address_sub#(func_address)::type_id::create("sub_func_address", this);
        this.sub_buffer_size = buffer_size_sub#(buffer_size)::type_id::create("sub_buffer_size", this);
        this.sub_packet_data = packet_data_sub#(packet_data)::type_id::create("sub_packet_data", this);
        this.sub_utmi_done = utmi_done_sub#(int)::type_id::create("sub_utmi_done", this);
        this.sub_utmi_data = utmi_data_sub#(utmi_read_data)::type_id::create("sub_utmi_data", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(utmi_interface)::read_by_name(.scope("ifs"), .name("if_utmi"), .val(utmi_vif)));
    endfunction

    virtual task run_phase(uvm_phase phase);
        int keep_going = 1;
        super.run_phase(phase);

        while (keep_going) begin

            process_response(keep_going);

        end
    endtask

    task process_response(output int keep_going);
        int endpoint;
        endpoint_data ep_data;
        bit [7:0] response;
        int reads = 0;
        int transaction_times;
        int result;
        buffer_size buffer_size;

        @(posedge this.sub_packet_transaction.new_transaction);        // wait for utmi to finish with random transaction generation
        this.sub_packet_transaction.clear();

        endpoint = this.sub_packet_transaction.pak_transaction.endpoint_address;        // gather information about the transaction to verify
        ep_data = this.sub_endpoint_data.ep_array[endpoint];
        buffer_size = this.sub_buffer_size.buffer_array[endpoint];

        if (ep_data.ep_type == 2'b00) begin         // control endpoint
            response_control();
        end
        else if (ep_data.ep_type == 2'b01) begin    // IN endpoint
            response_in(result);

            if (result == 1) begin
                keep_going = 0;
                return;
            end
            $display("monitor utmi done");
        end
        else if (ep_data.ep_type == 2'b10) begin    // OUT endpoint
            transaction_times = buffer_size.buff_size / 32;   // calculate the expected times it takes to transfer data
            response_out(transaction_times, result);

            if (result == 1) begin                  // if there was an error discovered, exit
                keep_going = 0;
                return;
            end
            $display("monitor umti done");
        end

        this.sub_packet_data.clear();
        this.sub_utmi_data.clear();
        keep_going = 1;
        return;
    endtask

    task response_control();

    endtask

    task response_in(output int result);
        while (1) begin
            @(posedge utmi_vif.phy_clk_pad_i);
            if (this.sub_packet_data.new_data == 1 && this.sub_utmi_data.new_data == 1) begin       // wait for random data and received data to arrive
                if (this.sub_packet_data.current_index == this.sub_utmi_data.current_index) begin   // check the amount of data are the same

                    for (int x = 0; x < this.sub_packet_data.current_index; x ++) begin
                        if (this.sub_packet_data.data_packet[x] != this.sub_utmi_data.data_packet[x]) begin
                            $display("%b", this.sub_utmi_data.data_packet[0]);
                            $display("%b", this.sub_utmi_data.data_packet[1]);
                            $display("%b", this.sub_utmi_data.data_packet[2]);
                            $display("monitor utmi - byte number %d does not match, got %b and %b", x, this.sub_utmi_data.data_packet[x], this.sub_packet_data.data_packet[x]);
                            result = 1;
                            return;
                        end
                    end

                    $display("monitor utmi - IN transaction worked properly");
                    break;
                end
                else begin
                    $display("monitor utmi - The index stored does not match, got %d and %d", this.sub_utmi_data.current_index, this.sub_packet_data.current_index);
                    result = 1;
                    return;
                end
            end
        end
        this.sub_packet_data.clear();
        this.sub_utmi_data.clear();
        result = 0;
    endtask

    // out transactions sends data to the the device, so check for response and see if it is correct
    // a 1 in the result is an error, a 0 is pass
    task response_out(input int transaction_times, output int result);
        bit [7:0] response;
        logic prev_error = 0;
        int counter = 0;

        this.sub_packet_data.read();
        for (int x = 0; x < transaction_times; x ++) begin
            if (prev_error == 0) begin                          // only wait if there was no error in the previous packet
                while (1) begin
                    @(posedge utmi_vif.phy_clk_pad_i);
                    if (this.sub_packet_data.updated == 1) begin   // new packet generated
                        break;
                    end
                end
            end
            this.sub_packet_data.read();

            // $display("error %d", this.sub_packet_data.data.error);

            if (this.sub_packet_data.data.error == 1) begin         // an error expected, should ignore the packet
                counter = 0;
                while (1) begin
                    @(posedge utmi_vif.phy_clk_pad_i);

                    if (utmi_vif.TxValid_pad_o == 1) begin          // got a response, should not happen
                        $display("monitor utmi - Error in out transaction response, got a response during error %d", counter);
                        result = 1;
                        return;
                    end
                    if (this.sub_packet_data.updated == 1) begin    // utmi generated a new packet and no response was detected
                        prev_error = 1;
                        x = x - 1;          // decrement loop variable to account for extra packet
                        break;              // break from this error case while loop
                    end
                    counter = counter + 1;
                end
            end
            else begin                                              // no error expected, should get a response
                while (1) begin
                    @(posedge utmi_vif.phy_clk_pad_i);

                    if (utmi_vif.TxValid_pad_o == 1) begin          // got a response, check if it is a ACK

                        utmi_vif.TxReady_pad_i = 1;
                        response = utmi_vif.DataOut_pad_o;      // grab response
                        @(negedge utmi_vif.TxValid_pad_o);
                        utmi_vif.TxReady_pad_i = 0;

                        if (response != 8'b1101_0010) begin     // did not get an ACK, show error
                            $display("monitor utmi - Error in out transaction response, did not get a NAK, got %b instead", response);
                            result = 1;
                            return;
                        end
                        $display("monitor utmi - response good");
                        break;                      // response was good, break from the loop
                    end
                    if (this.sub_packet_data.updated == 1) begin    // no response was generated before utmi is sending new packet, error
                        $display("monitor utmi - Error in out transaction response, did not get a response");
                        result = 1;
                        return;
                    end
                end
                prev_error = 0;         // everything worked, set previous error to 0
            end
        end

        this.sub_packet_data.read();
        this.sub_packet_data.clear();
        result = 0;
        return;
    endtask

endclass : monitor_utmi