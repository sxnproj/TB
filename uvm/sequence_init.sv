class sequence_init extends uvm_sequence #(packet_init);
    `uvm_object_utils(sequence_init)

    function new(string name = "sequence_init");
        super.new(name);
    endfunction

    task body;
        packet_init packet;

        forever begin
            packet = packet_init::type_id::create("packet");
            start_item(packet);
            assert(packet.randomize());
            finish_item(packet);
        end
    endtask

endclass : sequence_init