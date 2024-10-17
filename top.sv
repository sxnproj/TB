`include "uvm_macros.svh"
`include "uvm/if_utmi.sv"
`include "uvm/if_wb.sv"
`include "uvm/if_sram.sv"
`include "uvm/if_dft.sv"

`include "uvm/usbf_top_pkg.sv"

typedef virtual if_sram sram_interface;

module test;

    import uvm_pkg::*;
    import usbf_top_pkg::*;

    logic phy_clk_pad_i;
    logic clk;

    initial begin
        phy_clk_pad_i = 0;
        clk = 0;
    end

    // 100 MHz clock
    always begin
        #5 clk = ~clk ;
    end

    // 60 MHz clock (16.6667/2) 16/2 is 62.5
    always begin
        #8 phy_clk_pad_i = ~phy_clk_pad_i;
    end

    if_utmi utmi_if(phy_clk_pad_i);
    if_wb wb_if(clk);
    if_sram sram_if(clk);
    if_dft dft_if();

    sram memory(                // these signals were named from the perspective of the USB device
        .sram_data_i(sram_if.sram_data_o),
        .sram_data_o(sram_if.sram_data_i),
        .sram_adr_i(sram_if.sram_adr_o),  
        .sram_we_i(sram_if.sram_we_o), 
        .sram_re_i(sram_if.sram_re_o), 
        .sram_clk(clk)
    );

    usbf_top top(
        .clk(clk),      // wishbone interface
        .reset(wb_if.reset),
        .wb_addr_i(wb_if.wb_addr_i),
        .wb_data_i(wb_if.wb_data_i),
        .wb_data_o(wb_if.wb_data_o),
        .wb_ack_o(wb_if.wb_ack_o),
        .wb_we_i(wb_if.wb_we_i),
        .wb_stb_i(wb_if.wb_stb_i),
        .wb_cyc_i(wb_if.wb_cyc_i),
        .inta_o(wb_if.inta_o),
        .intb_o(wb_if.intb_o),
        .dma_req_o(wb_if.dma_req_o),
        .dma_ack_i(wb_if.dma_ack_i),
        .susp_o(wb_if.susp_o),
        .resume_req_i(wb_if.resume_req_i),

        .phy_clk_pad_i(phy_clk_pad_i),   // UTMI interface
        .phy_rst_pad_o(utmi_if.phy_rst_pad_o),
        .DataOut_pad_o(utmi_if.DataOut_pad_o),
        .TxValid_pad_o(utmi_if.TxValid_pad_o),
        .TxReady_pad_i(utmi_if.TxReady_pad_i),
        .RxValid_pad_i(utmi_if.RxValid_pad_i),
        .RxActive_pad_i(utmi_if.RxActive_pad_i),
        .RxError_pad_i(utmi_if.RxError_pad_i),
        .DataIn_pad_i(utmi_if.DataIn_pad_i),
        .XcvSelect_pad_o(utmi_if.XcvSelect_pad_o),
        .TermSel_pad_o(utmi_if.TermSel_pad_o),
        .SuspendM_pad_o(utmi_if.SuspendM_pad_o),
        .LineState_pad_i(utmi_if.LineState_pad_i),
        .OpMode_pad_o(utmi_if.OpMode_pad_o),
        .usb_vbus_pad_i(utmi_if.usb_vbus_pad_i),
        .VControl_Load_pad_o(utmi_if.VControl_Load_pad_o),
        .VControl_pad_o(utmi_if.VControl_pad_o),
        .VStatus_pad_i(utmi_if.VStatus_pad_i),

        .sram_adr_o(sram_if.sram_adr_o),      // Buffer Memory Interface
        .sram_data_i(sram_if.sram_data_i),
        .sram_data_o(sram_if.sram_data_o),
        .sram_re_o(sram_if.sram_re_o),
        .sram_we_o(sram_if.sram_we_o),

        .scan_en(dft_if.scan_en),         // DFT interface
        .test_mode(dft_if.test_mode),
        .scan_in0(dft_if.scan_in0),
        .scan_out0(dft_if.scan_out0)
    );

    initial begin
        $timeformat(-9,2,"ns", 16);
        // $set_coverage_db_name("results_conv");
        `ifdef SDFSCAN
            $sdf_annotate("sdf/usbf_top_tsmc18_scan.sdf", test.top);
        `endif
        uvm_resource_db#(utmi_interface)::set(.scope("ifs"), .name("if_utmi"), .val(utmi_if));
        uvm_resource_db#(wb_interface)::set(.scope("ifs"), .name("if_wb"), .val(wb_if));
        uvm_resource_db#(sram_interface)::set(.scope("ifs"), .name("if_sram"), .val(sram_if));

        run_test("usbf_top_test");
    end

endmodule