`include "src/usbf_defines.v"

interface if_wb(input clk);

    var logic reset;
    var logic [`USBF_UFC_HADR:0] wb_addr_i;
    var logic [31:0] wb_data_i;
    var logic [31:0] wb_data_o;
    var logic wb_ack_o;
    var logic wb_we_i;
    var logic wb_stb_i;
    var logic wb_cyc_i;
    var logic inta_o;
    var logic intb_o;
    var logic [15:0] dma_req_o;
    var logic [15:0] dma_ack_i;
    var logic susp_o;
    var logic resume_req_i;

endinterface : if_wb