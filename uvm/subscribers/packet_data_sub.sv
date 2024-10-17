class packet_data_sub #(type T = packet_data) extends uvm_subscriber #(T);
    `uvm_component_utils(packet_data_sub)

    bit [7:0] data_packet [511:0];      // potential 512 bytes of data
    packet_data data;
    logic new_data;
    logic updated;
    int current_index;

    function new(string name = "packet_data_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.new_data = 0;
        this.current_index = 0;
        this.updated = 0;
    endfunction

    virtual function void write(T t);
        this.data = t;
        update();
        this.updated = 1;
    endfunction

    // updates data_packet variable with new packet data
    function void update();
        int size;
        int lower_bound;

        // $display("sub error %d", this.data.error);

        if (this.data.error != 1) begin                         // only update if there is no error
            size = this.data.packet_size;
            lower_bound = this.current_index;

            if (size == 8) begin
                this.data_packet[lower_bound+:8] = this.data.data[0+:8];
            end
            else if (size == 32) begin
                this.data_packet[lower_bound+:32] = this.data.data[0+:32];
            end

            this.current_index = this.current_index + size;

            if (this.data.done == 1) begin       // if the done flag is set then the full data stream is over
                this.new_data = 1;
            end
        end
    endfunction

    // reset the new_data variable to wait for another transaction to come in
    function void clear();
        this.new_data = 0;
        this.current_index = 0;
    endfunction

    function void read();
        this.updated = 0;
    endfunction
endclass : packet_data_sub