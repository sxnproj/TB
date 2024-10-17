class wb_read_data extends uvm_sequence_item;
    logic [31:0] data;
    logic done;

    `uvm_object_utils_begin(wb_read_data)
    `uvm_object_utils_end

    function new(string name = "wb_read_data");
        super.new(name);
    endfunction

endclass : wb_read_data