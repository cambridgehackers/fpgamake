
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
set commandlog "Impl/TopDown/command"
set errorlog "Impl/TopDown/critical"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

set impl_start_time [clock seconds]

set dcp_name "./Synth/$module/$module-synth.dcp"
log_command "read_checkpoint $dcp_name" "$outputDir/[file tail $dcp_name].log"
foreach dcp $env(MODULE_NETLISTS) {
    log_command "read_checkpoint $dcp" "$outputDir/[file tail $dcp].log"
}
foreach xdc $env(XDC) {
    log_command "read_xdc $xdc" "$outputDir/[file tail $xdc].log"
}
foreach xdc $env(FLOORPLAN) {
    log_command "read_xdc $xdc" "$outputDir/[file tail $xdc].log"
}

log_command "link_design -top $module" $outputDir/link_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-link.dcp" $outputDir/temp.log
report_utilization -file $outputDir/$instance-post-link-util.rpt

log_command opt_design $outputDir/opt_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-opt.dcp" $outputDir/temp.log
report_utilization -file $outputDir/$instance-post-link-util.rpt
log_command place_design    $outputDir/place_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-place.dcp" $outputDir/temp.log
report_utilization -file $outputDir/$instance-post-place-util.rpt
report_timing_summary -file $outputDir/$instance-post-place-timing-summary.rpt
report_io -file $outputDir/$instance-post-place-io.rpt > hw/temp.log

if {"$env(FLOORPLAN)" == ""} {
    # just do top down build
    log_command "phys_opt_design" $outputDir/phys-opt-design.log
    log_command "write_checkpoint -force $outputDir/$instance-post-phys-opt.dcp" $outputDir/temp.log
    log_command "route_design" $outputDir/route-design.log
    log_command "write_checkpoint -force $outputDir/$instance-post-route.dcp" $outputDir/temp.log
    report_utilization -file $outputDir/$instance-post-route-util.rpt
    report_timing_summary -file $outputDir/$instance-post-route-timing-summary.rpt
    report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/$instance-post-route-timing.rpt > hw/temp.log
    report_io -file $outputDir/$instance-post-route-io.rpt > hw/temp.log
    report_datasheet -file $outputDir/$instance-post-route_datasheet.rpt > hw/temp.log
    if {[info exists env(BITFILE)] && $env(BITFILE) != ""} {
	log_command "write_bitstream -bin_file -force $env(BITFILE)" $outputDir/write_bitstream.log
    }
}
set impl_end_time [clock seconds]
puts "topdown.tcl elapsed time [expr $impl_end_time - $impl_start_time] seconds"
