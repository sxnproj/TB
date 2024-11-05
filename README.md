This is a USB testbench that was made using the UVM framework. Currently drives a USB core into Full Speed mode and drives both IN and OUT type transactions. 

The initialization of the device is constrained to allow for better control of key parameters

The transactions are randomized and checked with monitors on both the host and device side interfaces for correct functionality.

UVM               - contains all the UVM files of the testbench

usbf_top_test.sv  - is the uvm_test file that instantiates the testbench

top.sv            - contains the device instantiations and starts the test
