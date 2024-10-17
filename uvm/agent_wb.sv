class agent_wb extends uvm_agent;
    `uvm_component_utils(agent_wb)

    sequencer_init seqr_init;
    driver_wb drv_wb;
    monitor_wb mon_wb;

    function new(string name = "agent_wb", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr_init = sequencer_init::type_id::create("seqr_init", this);
        drv_wb = driver_wb::type_id::create("drv_wb", this);
        mon_wb = monitor_wb::type_id::create("mon_wb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv_wb.seq_item_port.connect(seqr_init.seq_item_export);
        drv_wb.interrupt_data_port.connect(mon_wb.sub_interrupt_data.analysis_export);  // send interrupt data from driver to monitor
        drv_wb.endpoint_data_port.connect(mon_wb.sub_endpoint_data.analysis_export);    // send endpoint data from driver to monitor
        drv_wb.function_address_port.connect(mon_wb.sub_func_address.analysis_export);  // send function address from driver to monitor
        drv_wb.buffer_size_port.connect(mon_wb.sub_buffer_size.analysis_export);        // send buffer size from driver to monitor
        drv_wb.wb_data_port.connect(mon_wb.sub_wb_data.analysis_export);                // send data read from memory to monitor
    endfunction

endclass : agent_wb