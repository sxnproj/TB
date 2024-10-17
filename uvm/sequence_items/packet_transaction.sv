// A class to generate random transactions for either the host or device

class packet_transaction extends uvm_sequence_item;

    // rand bit [7:0] payload [31:0];
    // rand bit [7:0] payload [1022:0];       // Full speed 1023 bytes
    // rand bit [7:0] data [1023:0];       // High speed 1024 bytes

    // typedef enum {OUT, IN, SOF, SETUP} packet_type;
    typedef enum {OUT, IN, SETUP} packet_type;
    rand packet_type token;

    // typedef enum {DATA0, DATA1, DATA2, MDATA} data_type;
    typedef enum {DATA0, DATA1} data_type;
    rand data_type data;

    typedef enum {ACK, NAK, STALL, NYET} handshake_type;
    rand handshake_type handshake;

    typedef enum {PREAMBLE, ERR, SPLIT, PING} special_type;
    rand special_type special;

    rand bit [3:0] endpoint_address;
    constraint ep_address {endpoint_address inside {0,1,2,3};}  // constrain the endpoint to the first 4 available

    `uvm_object_utils_begin(packet_transaction)
    `uvm_object_utils_end

    function new(string name = "packet_transaction");
        super.new(name);
    endfunction

endclass : packet_transaction