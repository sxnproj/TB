class endpoint_data_sub #(type T = endpoint_data) extends uvm_subscriber #(T);
    `uvm_component_utils(endpoint_data_sub)

    endpoint_data ep_array[4] = '{null, null, null, null};

    function new(string name = "endpoint_data_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(T t);
        // $display("sub %d", t.ep_number);
        this.ep_array[t.ep_number] = t;     // store the endpoint into the array
    endfunction
endclass : endpoint_data_sub