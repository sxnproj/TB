class sequencer_transaction extends uvm_sequencer #(packet_transaction);
    `uvm_component_utils(sequencer_transaction)

    function new(string name = "sequencer_transaction", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : sequencer_transaction