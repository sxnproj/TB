class sequence_virtual extends uvm_sequence;
    `uvm_object_utils(sequence_virtual)
    `uvm_declare_p_sequencer(sequencer_virtual)

    sequence_transaction seq_transaction;
    sequence_init seq_init;

    function new(string name = "sequence_virtual");
        super.new(name);
    endfunction

    virtual task pre_body();
        seq_transaction = sequence_transaction::type_id::create("seq_transaction");
        seq_init = sequence_init::type_id::create("seq_init");
    endtask

    virtual task body();
        fork
            seq_init.start(p_sequencer.seqr_init);
            seq_transaction.start(p_sequencer.seqr_transaction);
        join
    endtask

endclass : sequence_virtual