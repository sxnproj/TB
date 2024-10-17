class interrupt_data_sub #(type T = interrupt_data) extends uvm_subscriber #(T);
    `uvm_component_utils(interrupt_data_sub)

    interrupt_data int_data;

    function new(string name = "interrupt_data_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(T t);
        int_data = t;
    endfunction
endclass : interrupt_data_sub