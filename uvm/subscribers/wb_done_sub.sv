class wb_done_sub #(type T = int) extends uvm_subscriber #(T);
    `uvm_component_utils(wb_done_sub)

    logic wb_done;          // 0 = wb not done, 1 = wb done

    function new(string name = "wb_done_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.wb_done = 0;           // initialize to 0
    endfunction

    virtual function void write(T t);
        this.wb_done = 1;               // set to 1 when wb calls this function
    endfunction

    virtual function void clear();
        this.wb_done = 0;               // subscribers call this to reset
    endfunction
endclass : wb_done_sub