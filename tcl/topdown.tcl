
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
set commandlog "Synth/$module/command"
set errorlog "Synth/$module/critical"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

set dcp_name "./Synth/$module/$module-synth.dcp"
read_checkpoint $dcp_name
foreach xdc $env(XDC) {
    read_xdc $xdc
}

log_command link_design $outputDir/temp.log
log_command "write_checkpoint -force $outputDir/$instance-post-link.dcp" $outputDir/temp.log

log_command opt_design $outputDir/opt_design.log
log_command place_design    $outputDir/place_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-place.dcp" $outputDir/temp.log

set subinsts $env(SUBINST)

foreach subinst $subinsts {
    set subinstCell [get_cells $subinst]
    set module [get_property REF_NAME $subinstCell]
    file mkdir "./Impl/$subinst"
    set xdcHandle [open "./Impl/$subinst/$subinst-ooc-clocks.xdc" w]

    puts "$subinst $module ============================================================"
    report_property $subinstCell
    set pblock [get_pblocks -of [get_cells $subinst]]
    puts "pblock $pblock"
    report_property $pblock

    set pins [get_pins -of [get_cells $subinst] -filter DIRECTION==IN]
    puts "pins $pins"
    foreach pin $pins {
	set foo [split $pin "/"]
	puts $foo
	set port [lindex $foo 1]
	set clock [get_clocks -of $pin]
	if {[llength $clock] > 0} {
	    set period [get_property PERIOD $clock]
	    puts $xdcHandle "create_clock -period $period -name $clock \[get_ports \{$port\}\]"
	}
    }
    close $xdcHandle
    
    set_property HD.LOC_FIXED 1 [get_pins $subinstCell/*]
    write_xdc -force -cell $subinstCell "./Impl/$subinst/$subinst-ooc.xdc"
}

