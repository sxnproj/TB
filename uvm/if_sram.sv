parameter SSRAM_HADR = 14;

interface if_sram(input clk);

    var logic [31:0] sram_data_i;
    var logic [31:0] sram_data_o;
    var logic [SSRAM_HADR:0] sram_adr_o;
    var logic sram_we_o;
    var logic sram_re_o;

endinterface : if_sram