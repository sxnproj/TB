class agent_utmi extends uvm_agent;
    `uvm_component_utils(agent_utmi)

    sequencer_transaction seqr_transaction;
    driver_utmi drv_utmi;
    monitor_utmi mon_utmi;

    function new(string name = "agent_utmi", uvm_component parent = null);
        super.new(name, parent);

    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr_transaction = sequencer_transaction::type_id::create("seqr_transaction", this);
        drv_utmi = driver_utmi::type_id::create("drv_utmi", this);
        mon_utmi = monitor_utmi::type_id::create("mon_utmi", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv_utmi.seq_item_port.connect(seqr_transaction.seq_item_export);
        drv_utmi.packet_transaction_port.connect(mon_utmi.sub_packet_transaction.analysis_export);  // send transaction data from driver to monitor
        drv_utmi.packet_data_port.connect(mon_utmi.sub_packet_data.analysis_export);                // send packet data from driver to monitor
        drv_utmi.utmi_done_port.connect(mon_utmi.sub_utmi_done.analysis_export);                    // send utmi done signal to monitor
        drv_utmi.utmi_read_data_port.connect(mon_utmi.sub_utmi_data.analysis_export);               // send IN read data to the monitor
    endfunction

endclass : agent_utmi