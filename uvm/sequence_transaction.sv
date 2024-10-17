class sequence_transaction extends uvm_sequence #(packet_transaction);
    `uvm_object_utils(sequence_transaction)

    function new(string name = "sequence_transaction");
        super.new(name);
    endfunction

    task body;
        packet_transaction packet;

        forever begin
            packet = packet_transaction::type_id::create("packet");
            start_item(packet);
            assert(packet.randomize());
            finish_item(packet);
        end
    endtask

endclass : sequence_transaction