interface if_utmi(input phy_clk_pad_i);

    var logic phy_rst_pad_o;
    var logic [7:0] DataOut_pad_o;
    var logic TxValid_pad_o;
    var logic TxReady_pad_i;
    var logic RxValid_pad_i;
    var logic RxActive_pad_i;
    var logic RxError_pad_i;
    var logic [7:0] DataIn_pad_i;
    var logic XcvSelect_pad_o;
    var logic TermSel_pad_o;
    var logic SuspendM_pad_o;
    var logic [1:0] LineState_pad_i;
    var logic [1:0] OpMode_pad_o;
    var logic usb_vbus_pad_i;
    var logic VControl_Load_pad_o;
    var logic [3:0] VControl_pad_o;
    var logic [7:0] VStatus_pad_i;

endinterface : if_utmi