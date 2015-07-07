
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
load_package flow
package require cmdline

#
# STEP#0: define output directory area.
#
if [file exists {board.tcl}] {
    source {board.tcl}
} elseif [info exists env(FPGAMAKE_PARTNAME)] {
    set partname $env(FPGAMAKE_PARTNAME)
    if [info exists env(FPGAMAKE_BOARDNAME)] {
	set boardname $env(FPGAMAKE_BOARDNAME)
    }
} else {
    set boardname de5
    set partname {5SGXEA7N2F45C2}
}

set module $env(MODULE)
set outputDir ./Synth/$module
file mkdir $outputDir

set scriptsdir [file dirname $argv0]
source $scriptsdir/log.tcl

### logs
set commandlog "Synth/$module/command"
set errorlog "Synth/$module/critical"

set commandfilehandle [open "$commandlog.log" w]
set errorfilehandle [open "$errorlog.log" w]

# Create the base project
if [project_exists $module] {
    project_open -revision $module $module
} else {
    project_new -revision $module $module
}

set include_dirs [dict create]

#
# STEP#1: setup design sources and constraints
#
foreach headerfile $env(HEADERFILES) {
#    log_command "read_verilog $headerfile" $outputDir/temp.log
    dict set include_dirs [file dirname $headerfile] "True"
}

foreach vfile $env(VFILES) {
    dict set include_dirs [file dirname $vfile] "True"
    puts $vfile
    set_global_assignment -name VERILOG_FILE $vfile
}

foreach qip $env(IP) {
    set_global_assignment -name QIP_FILE $qip
}

foreach stp $env(STP) {
    execute_module -tool stp -args "--stp_file $stp --enable"
}

if {[info exists env(USER_TCL_SCRIPT)]} {
    foreach item $env(USER_TCL_SCRIPT) {
        if [string match "*.sdc" $item] {
            set_global_assignment -name SDC_FILE $item
        } else {
            puts "Sourcing $item"
            source $item
        }
    }
}

set_global_assignment -name FAMILY $env(FPGAMAKE_FAMILY)
set_global_assignment -name DEVICE $partname
set_global_assignment -name TOP_LEVEL_ENTITY $module
set_global_assignment -name ORIGINAL_QUARTUS_VERSION 14
set_global_assignment -name DEVICE_FILTER_PACKAGE FBGA

export_assignments

# STEP#2:
set quartus_map_args [dict create]
dict set quartus_map_args rev      $module
dict set quartus_map_args family   "$env(FPGAMAKE_FAMILY)"
dict set quartus_map_args part     "$partname"

set component_parameters {}
foreach item [dict keys $quartus_map_args] {
    set val [dict get $quartus_map_args $item]
    lappend component_parameters --$item=$val
}

if {[catch {execute_module -tool map -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Analysis & Synthesis failed. See the report file.\n"
    project_close
    exit 1
} else {
    puts "\nINFO: Analysis & Synthesis was successful.\n"
}

project_close
