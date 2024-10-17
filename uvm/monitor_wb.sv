class monitor_wb extends uvm_monitor;
    `uvm_component_utils(monitor_wb)

    wb_interface wb_vif;

    packet_transaction_sub sub_packet_transaction;  // subscriber to get transaction data
    endpoint_data_sub sub_endpoint_data;            // subscriber to get endpoint data
    interrupt_data_sub sub_interrupt_data;          // subscriber to get interrupt data
    func_address_sub sub_func_address;          // subscriber to get function address
    buffer_size_sub sub_buffer_size;            // subscriber to get buffer size
    packet_data_sub sub_packet_data;            // subscriber to get packet data
    utmi_done_sub sub_utmi_done;                // subscriber to know if utmi is done processing
    wb_data_sub sub_wb_data;                    // subscriber to get ep data from wb side

    function new(string name = "monitor_wb", uvm_component parent = null);
        super.new(name, parent);
        // create subscribers
        this.sub_packet_transaction = packet_transaction_sub#(packet_transaction)::type_id::create("sub_packet_transaction", this);
        this.sub_endpoint_data = endpoint_data_sub#(endpoint_data)::type_id::create("sub_endpoint_data", this);
        this.sub_interrupt_data = interrupt_data_sub#(interrupt_data)::type_id::create("sub_interrupt_data", this);
        this.sub_func_address = func_address_sub#(func_address)::type_id::create("sub_func_address", this);
        this.sub_buffer_size = buffer_size_sub#(buffer_size)::type_id::create("sub_buffer_size", this);
        this.sub_packet_data = packet_data_sub#(packet_data)::type_id::create("sub_packet_data", this);
        this.sub_wb_data = wb_data_sub#(wb_read_data)::type_id::create("sub_wb_data", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(wb_interface)::read_by_name(.scope("ifs"), .name("if_wb"), .val(wb_vif)));
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        while (1) begin
            process_transaction();
        end
    endtask

    task process_transaction();
    int endpoint;
    endpoint_data ep_data;
    buffer_size buffer_size;
    int stop = 0;

    @(posedge this.sub_packet_transaction.new_transaction);         // utmi has generated a new transaction
    this.sub_packet_transaction.clear();

    endpoint = this.sub_packet_transaction.pak_transaction.endpoint_address;    // get information about the transaction
    ep_data = this.sub_endpoint_data.ep_array[endpoint];
    buffer_size = this.sub_buffer_size.buffer_array[endpoint];

    if (ep_data.ep_type == 2'b00) begin         // control endpoint

    end
    else if (ep_data.ep_type == 2'b01) begin    // IN endpoint
        // currently nothing to check for on the wb side for IN endpoints
        @(posedge this.sub_wb_data.new_data);
        this.sub_packet_data.clear();
    end
    else if (ep_data.ep_type == 2'b10) begin    // OUT endpoint
        check_out(stop);
    end
    endtask

    // task to check OUT endpoint transactions on the WB side
    task check_out(output int stop);
        while (1) begin
            @(posedge wb_vif.clk);
            if (this.sub_wb_data.new_data == 1 && this.sub_packet_data.new_data == 1) begin     // data from both drivers available to compare
                if (this.sub_wb_data.current_index == this.sub_packet_data.current_index) begin // check for the number of bytes stored

                    for (int x = 0; x < this.sub_wb_data.current_index; x ++) begin
                        if (this.sub_wb_data.data_packet[x] != this.sub_packet_data.data_packet[x]) begin   // make sure each byte stored matches
                            $display("monitor wb - byte number %d does not match, got %b and %b", x, this.sub_wb_data.data_packet[x], this.sub_packet_data.data_packet[x]);
                            stop = 1;
                            return;
                        end
                    end

                    $display("monitor wb - OUT transaction worked properly");
                    break;                                          // finished checking, so break out of while loop

                end
                else begin      // the stored data size is not the same
                    $display("monitor wb - The index stored does not match");
                    stop = 1;
                    return;
                end
            end
        end
        this.sub_wb_data.clear();       // clear both subscribers for next transaction
        this.sub_packet_data.clear();
        stop = 0;
    endtask

endclass : monitor_wb