
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

####Report and DCP controls - values: 0-required min; 1-few extra; 2-all
set verbose      2
set dcpLevel     1

### logs
set runLog "Impl/$instance/run"
set commandLog "Impl/$instance/command"
set criticalLog "Impl/$instance/critical"

set logs [list $runLog $commandLog $criticalLog]
set rfh [open "$runLog.log" w]
set cfh [open "$commandLog.log" w]
set wfh [open "$criticalLog.log" w]

set dcp_name "./Synth/$module/$module-synth.dcp"
log_command "read_checkpoint $dcp_name" $outputDir/temp.log
foreach dcp $env(MODULE_NETLISTS) {
    log_command "read_checkpoint $dcp" $outputDir/temp.log
}
foreach xdc $env(XDC) {
    log_command "read_xdc $xdc" $outputDir/temp.log
}

log_command link_design $outputDir/temp.log
log_command "write_checkpoint -force $outputDir/$instance-post-link.dcp" $outputDir/temp.log

log_command opt_design $outputDir/opt_design.log
log_command place_design    $outputDir/place_design.log
log_command phys_opt_design $outputDir/phys_opt_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-place.dcp" $outputDir/temp.log

log_command route_design $outputDir/route_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-route.dcp" $outputDir/temp.log

