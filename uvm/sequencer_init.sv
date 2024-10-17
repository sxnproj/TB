class sequencer_init extends uvm_sequencer #(packet_init);
    `uvm_component_utils(sequencer_init)

    function new(string name = "sequencer_init", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : sequencer_init