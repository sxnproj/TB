// A initialization class to initialize the endpoints

class endpoint_data extends uvm_sequence_item;
    logic [1:0] ep_type;
    logic [1:0] tr_type;
    logic [1:0] ep_dis;
    logic [3:0] ep_number;
    logic lrg_ok;
    logic sml_ok;
    logic dma_en;
    logic ots_stop;
    logic [1:0] tr_fr;
    logic [10:0] max_pl_sz;

    // logic done;     // set to 0 when not done, 1 when finished sending

    `uvm_object_utils_begin(endpoint_data)
    `uvm_object_utils_end

    function new(string name = "endpoint_data");
        super.new(name);
    endfunction

endclass : endpoint_data