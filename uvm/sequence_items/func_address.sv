class func_address extends uvm_sequence_item;
    logic [6:0] function_address;

    `uvm_object_utils_begin(func_address)
    `uvm_object_utils_end

    function new(string name = "func_address");
        super.new(name);
    endfunction

endclass : func_address