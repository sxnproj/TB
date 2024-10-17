// class mainly used by the UTMI to send IN output data to subscribers
class utmi_read_data extends uvm_sequence_item;
    logic [7:0] data [31:0];            // DATA from the IN packet
    logic [7:0] token;                  // TOKEN from the IN packet
    logic [7:0] crc16 [1:0];            // CRC from the IN packet
    logic done;                         // signal that this is the last packet

    `uvm_object_utils_begin(utmi_read_data)
    `uvm_object_utils_end

    function new(string name = "utmi_read_data");
        super.new(name);
    endfunction

endclass : utmi_read_data