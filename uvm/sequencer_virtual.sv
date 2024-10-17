class sequencer_virtual extends uvm_sequencer;
    `uvm_component_utils(sequencer_virtual)

    sequencer_transaction seqr_transaction;
    sequencer_init seqr_init;

    function new(string name = "sequencer_virtual", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : sequencer_virtual