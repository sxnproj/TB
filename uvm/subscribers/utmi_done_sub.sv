class utmi_done_sub #(type T = int) extends uvm_subscriber #(T);
    `uvm_component_utils(utmi_done_sub)

    logic utmi_done;          // 0 = utmi not done, 1 = utmi done

    function new(string name = "utmi_done_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.utmi_done = 0;           // initialize to 0
    endfunction

    virtual function void write(T t);
        this.utmi_done = 1;               // set to 1 when utmi calls this function
    endfunction

    virtual function void clear();
        this.utmi_done = 0;               // subscribers call this to reset
    endfunction
endclass : utmi_done_sub