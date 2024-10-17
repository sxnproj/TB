class packet_init_sub #(type T = packet_init) extends uvm_subscriber #(T);
    `uvm_component_utils(packet_init_sub)

    packet_init pak_init;

    function new(string name = "packet_init_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(T t);
        this.pak_init = t;
    endfunction
endclass : packet_init_sub