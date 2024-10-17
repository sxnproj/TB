class data_buffer_sub #(type T = int) extends uvm_subscriber #(T);
    `uvm_component_utils(data_buffer_sub)

    logic ep_data_buffer[4];          // 0 = DATA0, 1 = DATA1

    function new(string name = "data_buffer_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.ep_data_buffer[0] = 0;          // we initialize at DATA0
        this.ep_data_buffer[1] = 0;
        this.ep_data_buffer[2] = 0;
        this.ep_data_buffer[3] = 0;
    endfunction

    // toggle the data to swap between DATA0 and DATA1 depending on which endpoint is written to
    virtual function void write(T t);
        if (t == 0) begin
            this.ep_data_buffer[0] = ~this.ep_data_buffer[0];
        end
        else if (t == 1) begin
            this.ep_data_buffer[1] = ~this.ep_data_buffer[1];
        end
        else if (t == 2) begin
            this.ep_data_buffer[2] = ~this.ep_data_buffer[2];
        end
        else if (t == 3) begin
            this.ep_data_buffer[3] = ~this.ep_data_buffer[3];
        end
        else if (t == -1) begin
        this.ep_data_buffer[0] = 0;              // a reset case
        this.ep_data_buffer[1] = 0;
        this.ep_data_buffer[2] = 0;
        this.ep_data_buffer[3] = 0;
        end
    endfunction

    // used to reset back to DATA0 when resetting the device
    virtual function void reset();
        this.ep_data_buffer[0] = 0;
        this.ep_data_buffer[1] = 0;
        this.ep_data_buffer[2] = 0;
        this.ep_data_buffer[3] = 0;
    endfunction
endclass : data_buffer_sub