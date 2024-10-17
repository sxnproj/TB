class env extends uvm_env;
    `uvm_component_utils(env)
    
    agent_utmi agt_utmi;
    agent_wb agt_wb;

    sequencer_virtual seqr_virtual;

    function new(string name = "env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr_virtual = sequencer_virtual::type_id::create("seqr_virtual", this);
        agt_utmi = agent_utmi::type_id::create("agt_utmi", this);
        agt_wb = agent_wb::type_id::create("agt_wb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        seqr_virtual.seqr_transaction = agt_utmi.seqr_transaction;
        seqr_virtual.seqr_init = agt_wb.seqr_init;

        // send the endpoint data from the wb driver to everyone who needs it
        agt_wb.drv_wb.endpoint_data_port.connect(agt_utmi.drv_utmi.sub_endpoint_data.analysis_export);  // send to utmi driver
        agt_wb.drv_wb.endpoint_data_port.connect(agt_utmi.mon_utmi.sub_endpoint_data.analysis_export);  // send to utmi monitor

        // send the transaction data from the utmi driver to everyone who needs it
        agt_utmi.drv_utmi.packet_transaction_port.connect(agt_wb.drv_wb.sub_packet_transaction.analysis_export);    // send to wb driver
        agt_utmi.drv_utmi.packet_transaction_port.connect(agt_wb.mon_wb.sub_packet_transaction.analysis_export);    // send to wb monitor

        // send function address from wb driver to everyone who needs it
        agt_wb.drv_wb.function_address_port.connect(agt_utmi.drv_utmi.sub_func_address.analysis_export);    // send to utmi driver
        agt_wb.drv_wb.function_address_port.connect(agt_utmi.mon_utmi.sub_func_address.analysis_export);    // send to utmi monitor

        // send buffer size from wb driver to everyone who needs it
        agt_wb.drv_wb.buffer_size_port.connect(agt_utmi.drv_utmi.sub_buffer_size.analysis_export);      // send to utmi driver
        agt_wb.drv_wb.buffer_size_port.connect(agt_utmi.mon_utmi.sub_buffer_size.analysis_export);      // send to utmi monitor

        // send packet data from utmi driver to everyone who needs it
        agt_utmi.drv_utmi.packet_data_port.connect(agt_wb.drv_wb.sub_packet_data.analysis_export);      // send to wb driver
        agt_utmi.drv_utmi.packet_data_port.connect(agt_wb.mon_wb.sub_packet_data.analysis_export);      // send to wb monitor

        // send the wb done signal from wb driver to everyone who needs it
        agt_wb.drv_wb.wb_done_port.connect(agt_utmi.drv_utmi.sub_wb_done.analysis_export);      // send to utmi driver

        // send the utmi done signal from utmi driver to everyone who needs it
        agt_utmi.drv_utmi.utmi_done_port.connect(agt_wb.drv_wb.sub_utmi_done.analysis_export);      // send to wb driver
    endfunction

endclass : env