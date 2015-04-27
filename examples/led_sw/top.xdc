## gpio_sw_left
set_property LOC "N15" [get_ports "sw"]
set_property IOSTANDARD "LVCMOS33" [get_ports "sw"]
set_property PIO_DIRECTION "INPUT" [get_ports "sw"]

## led 0
set_property LOC "T22" [get_ports "led"]
set_property IOSTANDARD "LVCMOS25" [get_ports "led"]
set_property PIO_DIRECTION "OUTPUT" [get_ports "led"]
