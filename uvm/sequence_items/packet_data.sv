class packet_data extends uvm_sequence_item;

    rand bit [7:0] data [31:0];

    rand bit [1:0] error;           // if this is 1 can call it an error, otherwise no error
    rand bit crc_data;              // if 0 then error in crc, 1 is error in data

    rand bit [4:0] index_data;
    constraint idx_d {index_data > 0;
                      index_data < 31;}

    rand bit index_crc;
    constraint idx_c {index_crc >= 0;
                      index_crc <= 1;}

    rand bit [7:0] data_corrupt;
    constraint data_c {data_corrupt > 0;
                       data_corrupt < 255;}


    int packet_size;
    int done;

    `uvm_object_utils_begin(packet_data)
    `uvm_object_utils_end

    function new(string name = "packet_data");
        super.new(name);
    endfunction

endclass : packet_data