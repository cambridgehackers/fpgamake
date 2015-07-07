
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

package require ::quartus::project
package require ::quartus::flow

set boardname de5
set device "Stratix V"
set partname {5SGXEA7N2F45C2}

set module $env(MODULE)
set instance $env(INST)

set outputDir ./Impl/TopDown
file mkdir $outputDir

set scriptdir [file dirname $argv0]
source $scriptdir/log.tcl

### logs
set commandlog "Impl/TopDown/commmand"
set errorlog "Impl/TopDown/critical"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

if [project_exists $module] {
    project_open -revision $module $module
} else {
    project_new -revision $module $module
}

set fit_start_time [clock seconds]

if {[catch {execute_module -tool fit} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Fitting failed. See the report file.\n"
} else {
    puts "\nINFO: Fitting was successful.\n"
}

set sdcs [regexp -all -inline {\S+} $env(SDC)]
set component_parameters {}
foreach item $sdcs {
    lappend component_parameters --sdc=$item
}

if {[catch {execute_module -tool asm} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Timing Analysis failed. See the report file.\n"
    project_close
    exit 1
} else {
    puts "\nINFO: Assembler was successful.\n"
}

puts $component_parameters
if {[catch {execute_module -tool sta -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Timing Analysis failed. See the report file.\n"
    project_close
    exit 1
} else {
    puts "\nINFO: Timing Analysis was successful.\n"
}

set fit_end_time [clock seconds]

project_close
post_message -type info "fit.tcl elapsed time [expr $fit_end_time - $fit_start_time] seconds"
