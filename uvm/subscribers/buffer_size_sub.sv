class buffer_size_sub #(type T = buffer_size) extends uvm_subscriber #(T);
    `uvm_component_utils(buffer_size_sub)

    buffer_size buffer_array[4] = '{null, null, null, null};

    function new(string name = "buffer_size_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(T t);
        this.buffer_array[t.ep_number] = t;     // store the endpoint into the array
    endfunction
endclass : buffer_size_sub