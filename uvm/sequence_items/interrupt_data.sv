// A holding class to hold interrupt data to be transferred in the testbench

class interrupt_data extends uvm_sequence_item;
    logic [8:0] rf_interrupt;     // interrupt list for register file
    logic [15:0] ep_interrupt;    // interrupt for which endpoint has an interrupt

    `uvm_object_utils_begin(interrupt_data)
    `uvm_object_utils_end

    function new(string name = "interrupt_data");
        super.new(name);
    endfunction

endclass : interrupt_data