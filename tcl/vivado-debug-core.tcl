#-----------------------------------------------------------
# Vivado v2014.1 (64-bit)
# SW Build 881834 on Fri Apr  4 13:56:21 MDT 2014
# IP Build 877625 on Fri Mar 28 16:29:15 MDT 2014
# Start of session at: Mon Jan  5 09:03:13 2015
# Process ID: 2017
# Log file: /scratch/jamey/connectal/tests/memread_manyclients128/vivado.log
# Journal file: /scratch/jamey/connectal/tests/memread_manyclients128/vivado.jou
#-----------------------------------------------------------
open_checkpoint kc705/Impl/TopDown/top-post-route.dcp
create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list n_301_host_ep7 ]]
set debug_nets [get_nets portalTop_memread_re_outfs_*/*EMPTY_N]
set_property port_width [llength $debug_nets] [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 $debug_nets
implement_debug_core
place_design
route_design
write_checkpoint -force debug.dcp
report_timing_summary -file debug_timing_summary.rpt
write_bitstream -bin_file -force -logic_location_file -mask_file -readback_file debug.bit
write_debug_probes -force debug debug.ltx
start_gui

