// initialization to initialize the USB core into a certain state to test

class packet_init extends uvm_sequence_item;

    rand bit [6:0] function_address;            // address of the device

    rand bit [13:0] buffer_size;
    constraint buffer_list {buffer_size inside {32, 64, 128, 256, 512};}

    randc bit [1:0] ep_type;
    constraint ep_list {ep_type >= 1;
                        ep_type <= 2;}

    `uvm_object_utils_begin(packet_init)
        // `uvm_field_int(function_address, UVM_ALL_ON|UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "packet_init");
        super.new(name);
    endfunction

endclass : packet_init