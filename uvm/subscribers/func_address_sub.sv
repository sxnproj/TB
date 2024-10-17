class func_address_sub #(type T = func_address) extends uvm_subscriber #(T);
    `uvm_component_utils(func_address_sub)

    func_address function_address;

    function new(string name = "func_address_sub", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(T t);
        function_address = t;
    endfunction
endclass : func_address_sub