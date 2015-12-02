
## Copyright (c) 2015 Connectal Project

## Permission is hereby granted, free of charge, to any person
## obtaining a copy of this software and associated documentation
## files (the "Software"), to deal in the Software without
## restriction, including without limitation the rights to use, copy,
## modify, merge, publish, distribute, sublicense, and/or sell copies
## of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:

## The above copyright notice and this permission notice shall be
## included in all copies or substantial portions of the Software.

## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
## EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
## MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
## NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
## BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
## ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
## CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.

if [info exists env(DEBUG_NETS)] {
    set debug_nets "$env(DEBUG_NETS)"
    set debug_port [dict create]
    set debug_core [dict create]
    set core_number 0

    foreach pattern $debug_nets {
	set nets [lsort -dictionary [get_nets $pattern]]
	set nets [get_nets $nets]
	set clocks ""
	set net [lindex $nets 0]
	set pins [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION==OUT}]
	puts "pins $pins"
	if [llength $pins] {
	    set fanin [all_fanin -startpoints_only $pins]
	    puts "fanin $fanin"
	    set clock [get_clocks -of_objects $fanin]
	    puts "clock $clock [dict exists $debug_core $clock]"
	    if {![dict exists $debug_core "$clock"]} {
		set core [create_debug_core u_ila_$core_number ila]
		incr core_number
		puts "created core $core"
		set_property C_DATA_DEPTH 1024 $core
		set_property C_TRIGIN_EN false $core
		set_property C_TRIGOUT_EN false $core
		set_property C_ADV_TRIGGER false $core
		set_property C_INPUT_PIPE_STAGES 0 $core
		set_property C_EN_STRG_QUAL false $core
		set_property ALL_PROBE_SAME_MU true $core
		set_property ALL_PROBE_SAME_MU_CNT 1 $core
		dict set debug_core "$clock" "$core"
		set_property port_width 1 [get_debug_ports $core/clk]
		connect_debug_port $core/clk [get_nets -of_objects $clock]

		set_property port_width [llength $nets] [get_debug_ports $core/probe0]
		connect_debug_port $core/probe0 $nets
	    } else {
		set core [dict get $debug_core $clock]
		puts "found core $core"
		set probe [create_debug_port $core probe]
		set_property port_width [llength $nets] [get_debug_ports $probe]
		connect_debug_port $probe $nets
	    }
	}
    }
    write_debug_probes -force debug_probes.ltx
}

## load vc707g2/Impl/TopDown/top-post-link.dcp
## mark signals to debug
## push the "Set up debug" to launch the wizard to instantiate the ILA (integrated logic analyzer)
##
## Synthesis often mangles internal signals. If you use BSV mkProbe,
## those signals will be annotated (* mark_debug = "true" *) in the
## verilog and more of them will survive synthesis. Chips that cross
## netlist boundaries will also be easier to find post synthesis.
##
## If it complains that some of the signals are partially defined or
## have unknown clocks, push the "more info" link and then try the
## "assign clocks" link.
## 
## when that is done, source this file
##    source scripts/chipscope.tcl

## This script writes two files. The first is the bitstream and the second describes the signals that the ILA captures.
##   debug.bit
##   debug.ltx
## Program the board via Vivado, giving it the two file names.
## Add, configure, and click the run button to have it wait for triggers
## Then run
##   pciescanportal
##   NOPROGRAM=1 vc707g2/bin/ubuntu.exe
## Hopefully something triggered
opt_design
place_design
phys_opt_design
route_design
write_bitstream -force debug.bit
write_debug_probes -force debug.ltx
report_timing_summary -file debug_timing_summary.txt
