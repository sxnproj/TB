class packet_transaction_sub #(type T = packet_transaction) extends uvm_subscriber #(T);
    `uvm_component_utils(packet_transaction_sub)

    packet_transaction pak_transaction;
    logic new_transaction;

    function new(string name = "packet_transaction_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.new_transaction = 0;
    endfunction

    virtual function void write(T t);
        this.pak_transaction = t;
        this.new_transaction = 1;
    endfunction

    virtual function void clear();
        this.new_transaction = 0;
    endfunction
endclass : packet_transaction_sub