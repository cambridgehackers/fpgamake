
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
} elseif [info exists env(FPGAMAKE_PARTNAME)] {
    set partname $env(FPGAMAKE_PARTNAME)
    if [info exists env(FPGAMAKE_BOARDNAME)] {
	set boardname $env(FPGAMAKE_BOARDNAME)
    }
} else {
    set boardname vc707
    set partname {xc7vx485tffg1761-2}
}

set module $env(MODULE)
set outputDir ./Synth/$module
file mkdir $outputDir
if {$module == "top" || $module == {mkZynqTop} || $module == {mkPcieTop} || $module == $env(FPGAMAKE_TOPMODULE)} {
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

set include_dirs [dict create]
#
# STEP#1: setup design sources and constraints
#
foreach headerfile $env(HEADERFILES) {
#    log_command "read_verilog $headerfile" $outputDir/temp.log
    dict set include_dirs [file dirname $headerfile] "True"
}

foreach vfile "$env(VFILES)" {
    dict set include_dirs [file dirname $vfile] "True"
}
set_property include_dirs [dict keys $include_dirs] [current_fileset]

if {[string length $env(VFILES)] > 0} {
    log_command "add_files -scan_for_includes $env(VFILES)" $outputDir/verilog.log
}
if { [info exists ::env(VHDL_LIBRARIES) ] } {
foreach vhdlib $env(VHDL_LIBRARIES) {
    set library [file tail $vhdlib]
    set library_files [glob "$vhdlib/*.vhdl"]
    log_command "add_files $library_files" $outputDir/$library.log
    foreach file "$library_files" {
	set_property LIBRARY "$library" [get_files $file]
    }
}
}

if {[string length $env(VHDFILES)] > 0} {
    log_command "add_files $env(VHDFILES)" $outputDir/vhd.log
}

if {[info exists env(MODULE_NETLISTS)]} {
    foreach dcp $env(MODULE_NETLISTS) {
	log_command "read_checkpoint $dcp" "$outputDir/[file tail $dcp].log"
    }
}
foreach ip $env(IP) {
    log_command "read_ip $ip" $outputDir/temp.log
}

set verilog_defines ""
if {[info exists env(VERILOG_DEFINES)]} {
    foreach d $env(VERILOG_DEFINES) {
	set verilog_defines "$verilog_defines -verilog_define $d"
    }
}

foreach xdc $env(XDC) {
    log_command "read_xdc $xdc" "$outputDir/[file tail $xdc].log"
}

# STEP#2: run synthesis, report utilization and timing estimates, write checkpoint design
#
log_command "synth_design $verilog_defines -name $module -top $module -part $partname -flatten rebuilt -include_dirs \"[dict keys $include_dirs]\" -mode $mode" "$outputDir/synth_design.log"

# Remove unused clocks that bluespec compiler exports
set clock_patterns {CLK_GATE_hdmi_clock_if CLK_*deleteme_unused_clock* CLK_GATE_*deleteme_unused_clock* RST_N_*deleteme_unused_reset*}
set clock_gate_pattern {CLK_GATE_*}
if [info exists env(PRESERVE_CLOCK_GATES)] {
    if {$env(PRESERVE_CLOCK_GATES) == 1} {
	set clock_gate_pattern {}
    }
}

foreach {pat} "$clock_patterns $clock_gate_pattern" {
    foreach {port} [get_ports $pat] {
	set net [get_nets -of_objects $port]
	puts "disconnecting net $net from port $port"
	disconnect_net -net [get_nets -of_objects $port] -objects $port
    }
}
if {[info exists env(USER_TCL_SCRIPT)]} {
    foreach item $env(USER_TCL_SCRIPT) {
	source $item
    }
}

set dcp_name "$outputDir/$module-synth.dcp"
log_command "write_checkpoint -force $dcp_name" $outputDir/temp.log
