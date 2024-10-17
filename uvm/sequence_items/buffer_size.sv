class buffer_size extends uvm_sequence_item;
    logic [3:0] ep_number;
    logic [13:0] buff_size;

    `uvm_object_utils_begin(buffer_size)
    `uvm_object_utils_end

    function new(string name = "buffer_size");
        super.new(name);
    endfunction

endclass : buffer_size