class usbf_top_test extends uvm_test;
    `uvm_component_utils(usbf_top_test)

    env environment;
    sequence_virtual seq_v;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        environment = env::type_id::create("environment", this);
        seq_v = sequence_virtual::type_id::create("seq_v", this);
    endfunction

    task run_phase(uvm_phase phase);
        seq_v.start(environment.seqr_virtual);
    endtask: run_phase

endclass