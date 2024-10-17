// takes data sent to an endpoint and read from the wb side
// it reconstructs the data for comparision with the monitor
class utmi_data_sub #(type T = utmi_read_data) extends uvm_subscriber #(T);
    `uvm_component_utils(utmi_data_sub)

    bit [7:0] data_packet [511:0];      // potential 512 bytes of data
    utmi_read_data utmi_data;
    logic new_data;
    int current_index;

    function new(string name = "utmi_data_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.new_data = 0;
        this.current_index = 0;
    endfunction

    virtual function void write(T t);
        this.utmi_data = t;
        update();
    endfunction

    // updates data_packet variable with new packet data
    function void update();

        this.data_packet[this.current_index+:32] = this.utmi_data.data[0+:32];

        this.current_index = this.current_index + 32;

        if (this.utmi_data.done == 1) begin
            this.new_data = 1;
        end
    endfunction

    // reset the new_data variable to wait for another transaction to come in
    function void clear();
        this.new_data = 0;
        this.current_index = 0;
    endfunction
endclass : utmi_data_sub