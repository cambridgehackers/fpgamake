
## Copyright (c) 2014 Quanta Research Cambridge, Inc.

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


# NOTE: typical usage would be "vivado -mode tcl -source impl.tcl" 
#
if [file exists {board.tcl}] {
    source {board.tcl}
} else {
    set boardname vc707
    set partname {xc7vx485tffg1761-2}
}
set module $env(MODULE)
set instance $env(INST)

set outputDir ./Impl/TopDown
file mkdir $outputDir

set scriptsdir [file dirname $argv0]
source $scriptsdir/log.tcl

### logs
set commandlog "Impl/TopDown/command.write-ooc-xdc"
set errorlog "Impl/TopDown/critical.write-ooc-xdc"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

set dcp_name "$outputDir/top-post-place.dcp"
log_command "read_checkpoint $dcp_name" $outputDir/temp.log
log_command "link_design" $outputDir/temp.log

set subinsts $env(SUBINST)

foreach subinst $subinsts {
    set subinstCell [get_cells -hier $subinst]
    set module [get_property REF_NAME $subinstCell]
    file mkdir "./Impl/$subinst"
    set xdcHandle [open "./Impl/$subinst/$subinst-ooc-clocks.xdc" w]

    puts "$subinst $module ============================================================"
    report_property $subinstCell
    set pblock [get_pblocks -of [get_cells -hier $subinst]]
    puts "pblock $pblock"
    report_property $pblock

    set pins [get_pins -of [get_cells -hier $subinst] -filter DIRECTION==IN]
    foreach pin $pins {
	set port [get_property REF_PIN_NAME $pin]
	set clock [get_clocks -quiet -of $pin]
	if {[llength $clock] > 0} {
	    set period [get_property PERIOD $clock]
	    set clock_name "$subinst-$port"
	    puts $xdcHandle "# clock pin $pin"
	    puts $xdcHandle "# clock $clock"
	    puts $xdcHandle "create_clock -period $period -name $clock_name \[get_ports \{$port\}\]"

	    set clock_nets [get_nets -of_objects $clock]
	    puts $xdcHandle "# clock_nets $clock_nets"
	    set clock_src_pin [get_pins -of_objects $clock_nets -filter {DIRECTION==OUT}]
	    puts $xdcHandle "# clock_src_pin $clock_src_pin"
	    set clock_src_cell [get_cells -of_objects $clock_src_pin]
	    puts $xdcHandle "# clock_src_cell $clock_src_cell"
	    set clock_src_loc [get_property LOC $clock_src_cell]
	    puts $xdcHandle "# clock_src_loc $clock_src_loc"
	    report_property $clock_src_cell
	    puts $xdcHandle "set_property HD.CLK_SRC $clock_src_loc \[get_ports \{$port\}\]"
	}
    }
    close $xdcHandle
    
    set_property HD.LOC_FIXED 1 [get_pins $subinstCell/*]
    write_xdc -force -cell $subinstCell "./Impl/$subinst/$subinst-ooc.xdc"

    ::debug::gen_hd_timing_constraints -percent 25 -of_objects [get_cells $subinstCell] -file ./Impl/$subinst/$subinst-ooc-budget.xdc
}

