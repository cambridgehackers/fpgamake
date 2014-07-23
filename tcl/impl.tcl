
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

set outputDir ./Impl/$instance
file mkdir $outputDir

set scriptsdir [file dirname $argv0]
source $scriptsdir/log.tcl

set scriptsdir [file dirname $argv0]
source $scriptsdir/log.tcl

### logs
set commandlog "Impl/$instance/command"
set errorlog "Impl/$instance/critical"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

set impl_start_time [clock seconds]

set dcp_name "./Synth/$module/$module-synth.dcp"
log_command "read_checkpoint $dcp_name" "$outputDir/[file tail $dcp_name].log"
if {$instance == "top"} {
    set mode {default}
} else {
    set mode {out_of_context}
}

log_command "link_design -mode $mode -top $module" $outputDir/link_design.log
foreach dcp $env(MODULE_NETLISTS) {
    set instname [file tail [file dirname $dcp]]
    puts "$instname\n\t $dcp"
    log_command "read_checkpoint -cell $instname $dcp -strict" "$outputDir/[file tail $dcp]-read.log"
    log_command "lock_design -level Routing [get_cells $instname]" "$outputDir/[file tail $dcp]-lock.log"
}

foreach xdc $env(XDC) {
    log_command "read_xdc $xdc" "$outputDir/[file tail $xdc].log"
}

log_command "write_checkpoint -force $outputDir/$instance-post-link.dcp" $outputDir/temp.log
log_command "report_timing_summary -file $outputDir/$instance-post-link-timing-summary.rpt" $outputDir/temp.log

log_command opt_design $outputDir/opt_design.log
log_command "report_timing_summary -file $outputDir/$instance-post-opt-timing-summary.rpt" $outputDir/temp.log
log_command place_design  $outputDir/place_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-place.dcp" $outputDir/temp.log
log_command "report_timing_summary -file $outputDir/$instance-post-place-timing-summary.rpt" $outputDir/temp.log
log_command phys_opt_design $outputDir/phys_opt_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-phys-opt.dcp" $outputDir/temp.log
log_command "report_timing_summary -file $outputDir/$instance-post-phys-opt-timing-summary.rpt" $outputDir/temp.log

log_command route_design $outputDir/route_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-route.dcp" $outputDir/temp.log
log_command "report_timing_summary -file $outputDir/$instance-post-route-timing-summary.rpt" $outputDir/temp.log

if {[info exists env(BITFILE)] && $env(BITFILE) != ""} {
    log_command "write_bitstream -bin_file -force $env(BITFILE)" $outputDir/write_bitstream.log
}
set impl_end_time [clock seconds]
puts "impl.tcl elapsed time [expr $impl_end_time - $impl_start_time] seconds"
