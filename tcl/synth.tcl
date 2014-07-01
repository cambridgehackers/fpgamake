
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

#
# STEP#0: define output directory area.
#
if [file exists {board.tcl}] {
    source {board.tcl}
} else {
    set boardname vc707
    set partname {xc7vx485tffg1761-2}
}

set module $env(MODULE)
set outputDir ./Synth/$module
file mkdir $outputDir
if {[llength $env(MODULE_NETLISTS)] > 0} {
    set mode default
} else {
    set mode out_of_context
}

set scriptsdir [file dirname $argv0]
source $scriptsdir/log.tcl

### logs
set commandlog "Synth/$module/command"
set errorlog "Synth/$module/critical"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

create_project $module -in_memory -part $partname

#
# STEP#1: setup design sources and constraints
#
log_command "read_verilog ./verilog/$module.v" $outputDir/temp.log
foreach vfile $env(VFILES) {
    log_command "read_verilog $vfile" $outputDir/temp.log
}
foreach dcp $env(MODULE_NETLISTS) {
    log_command "read_checkpoint $dcp" $outputDir/temp.log
}
foreach ip $env(IP) {
    log_command "read_ip $ip" $outputDir/temp.log
}

# STEP#2: run synthesis, report utilization and timing estimates, write checkpoint design
#
log_command "synth_design -name $module -top $module -part $partname -flatten rebuilt -mode $mode" "$outputDir/synth_design.log"

set dcp_name "$outputDir/$module"
append dcp_name "_synth.dcp"
log_command "write_checkpoint -force $dcp_name" $outputDir/temp.log
