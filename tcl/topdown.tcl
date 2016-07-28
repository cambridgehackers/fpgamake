
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
if {"$env(PRTOP)" != ""} {
    set dcp_name $env(PRTOP)
}
log_command "read_checkpoint $dcp_name" "$outputDir/[file tail $dcp_name].log"

foreach dcp $env(MODULE_NETLISTS) {
    log_command "read_checkpoint $dcp" "$outputDir/[file tail $dcp].log"
}

log_command "link_design" "$outputDir/link_design.log"

foreach xdc $env(XDC) {
    log_command "read_xdc $xdc" "$outputDir/[file tail $xdc].log"
}

if {"$env(RECONFIG_INSTANCES)" != ""} {
    set cellname ""
    set pblockname ""
    foreach name $env(RECONFIG_INSTANCES) {
	if {"$env(PRTOP)" != ""} {
	    set cell [get_cells -hier $name]
	    set pblock [get_pblocks -of_objects $cell]
	    set pblock [get_pblocks pblock_$name]
	    set cellmodule [get_property REF_NAME $cell]
	    update_design -cells top/$name -black_box
	    lock_design -level routing
	    set dcp "./Synth/$cellmodule/$cellmodule-synth.dcp"
	    log_command "read_checkpoint -cell $cell $dcp" "$outputDir/[file tail $dcp].log"
	} else {
	    set cell [get_cells -hier $name]
	    set_property HD.RECONFIGURABLE 1 $cell
	    set_property RESET_AFTER_RECONFIG 1 [get_pblocks pblock_$name]
	}
    }
}

## DEBUG_NETS="host_ep7_cfg_function_number host_ep7_cfg_device_number host_ep7_cfg_bus_number"
if [info exists env(DEBUG_NETS)] {
    set debug_nets "$env(DEBUG_NETS)"
    set debug_port 0
    foreach debug_net $debug_nets {
	set nets [get_nets "$debug_net[*]"]
	puts "debug_port $debug_port nets $nets"
	if {$debug_port < 1} {
	    create_debug_core u_ila_0 ila
	    set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
	    set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
	    set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
	    set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
	    set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
	    set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
	    set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
	    set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]

	    set pins [get_pins -leaf -of_objects $nets -filter {DIRECTION==OUT}]
	    puts "pins $pins"
	    set cell [get_cells -of_objects [lindex $pins 0]]
	    puts "cell $cell"

	    set clock [get_clocks -of_objects [get_pins "$cell/C"]]
	    puts "clock $clock"
	    set_property port_width 1 [get_debug_ports u_ila_0/clk]
	    connect_debug_port u_ila_0/clk [get_nets -of_objects $clock]

	    set_property port_width [llength $nets] [get_debug_ports u_ila_0/probe0]
	    connect_debug_port u_ila_0/probe0 $nets
	} else { 
	    create_debug_port u_ila_0 probe
	    set_property port_width [llength $nets] [get_debug_ports u_ila_0/probe$debug_port]
	    connect_debug_port u_ila_0/probe$debug_port $nets
	}
	incr debug_port
    }
    write_debug_probes -force $outputDir/debug_nets.ltx
}

if [info exists CFGBVS] {
    set_property CFGBVS $CFGBVS [current_design]
}
if [info exists CONFIG_VOLTAGE] {
    set_property CONFIG_VOLTAGE $CONFIG_VOLTAGE [current_design]
}

log_command "write_checkpoint -force $outputDir/$instance-post-link.dcp" $outputDir/temp.log
report_timing_summary -file $outputDir/$instance-post-link-timing-summary.txt > $outputDir/temp.log
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/$instance-post-link-timing.txt > $outputDir/temp.log
if {[version -short] >= "2014.3"} {
    report_cdc -details -verbose -file $outputDir/$instance-post-link-cdc.txt > $outputDir/temp.log
}
if {"$env(REPORT_NWORST_TIMING_PATHS)" != ""} {
    report_timing -nworst $env(REPORT_NWORST_TIMING_PATHS) -sort_by slack -path_type summary -slack_lesser_than 0.2 -unique_pins
    puts "****************************************"
    puts "If timing report says 'No timing paths found.' then the design met the timing constraints."
    puts "If it reported negative slack, then the design did not meet the timing constraints."
    puts "****************************************"
}

report_utilization -hierarchical -file $outputDir/$instance-post-link-util.txt

## now clear the MARK_DEBUG so that it does not interfere with meeting timing
set debug_nets [get_nets -hier -filter { MARK_DEBUG==TRUE }]
if {[llength $debug_nets] > 0} {
    set_property MARK_DEBUG false $debug_nets
    set_property DONT_TOUCH false $debug_nets
}

log_command opt_design $outputDir/opt_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-opt.dcp" $outputDir/temp.log
if {"$env(REPORT_NWORST_TIMING_PATHS)" != ""} {
    report_timing -nworst $env(REPORT_NWORST_TIMING_PATHS) -sort_by slack -path_type summary -slack_lesser_than 0.2 -unique_pins
    puts "****************************************"
    puts "If timing report says 'No timing paths found.' then the design met the timing constraints."
    puts "If it reported negative slack, then the design did not meet the timing constraints."
    puts "****************************************"
}
report_timing_summary -file $outputDir/$instance-post-opt-timing-summary.txt > $outputDir/temp.log
report_utilization -hierarchical -file $outputDir/$instance-post-link-util.txt
foreach pblock [get_pblocks] {
    report_utilization -pblocks $pblock -file $outputDir/$pblock-post-link-util.txt > $outputDir/temp.log
}
report_drc -file $outputDir/pre_place_drc.txt
log_command place_design    $outputDir/place_design.log
log_command "write_checkpoint -force $outputDir/$instance-post-place.dcp" $outputDir/temp.log
if {"$env(REPORT_NWORST_TIMING_PATHS)" != ""} {
    report_timing -nworst $env(REPORT_NWORST_TIMING_PATHS) -sort_by slack -path_type summary -slack_lesser_than 0.2 -unique_pins
    puts "****************************************"
    puts "If timing report says 'No timing paths found.' then the design met the timing constraints."
    puts "If it reported negative slack, then the design did not meet the timing constraints."
    puts "****************************************"
}
report_utilization -hierarchical -file $outputDir/$instance-post-place-util.txt
report_timing_summary -file $outputDir/$instance-post-place-timing-summary.txt
report_io -file $outputDir/$instance-post-place-io.txt > $outputDir/temp.log

# just do top down build
log_command "phys_opt_design" $outputDir/phys-opt-design.log
log_command "write_checkpoint -force $outputDir/$instance-post-phys-opt.dcp" $outputDir/temp.log
log_command "route_design" $outputDir/route-design.log
log_command "write_checkpoint -force $outputDir/$instance-post-route.dcp" $outputDir/temp.log
if {"$env(REPORT_NWORST_TIMING_PATHS)" != ""} {
	report_timing -nworst $env(REPORT_NWORST_TIMING_PATHS) -sort_by slack -path_type summary -slack_lesser_than 0.2 -unique_pins
	puts "****************************************"
	puts "If timing report says 'No timing paths found.' then the design met the timing constraints."
	puts "If it reported negative slack, then the design did not meet the timing constraints."
	puts "****************************************"
}
report_utilization -hierarchical -file $outputDir/$instance-post-route-util.txt
report_timing_summary -file $outputDir/$instance-post-route-timing-summary.txt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/$instance-post-route-timing.txt > $outputDir/temp.log
report_io -file $outputDir/$instance-post-route-io.txt > $outputDir/temp.log
report_datasheet -file $outputDir/$instance-post-route_datasheet.txt > $outputDir/temp.log
set_property "BITSTREAM.STARTUP.MATCH_CYCLE" NoWait [current_design]

if {[info exists env(BITFILE)] && $env(BITFILE) != ""} {
	## commented out -logic_location_file for now because the files are huge -Jamey
	#log_command "write_xdc -no_fixed_only -force $outputDir/$instance-post-route.xdc" $outputDir/write_bitstream.log
	#log_command "write_edif -force $outputDir/$instance-post-route.edif" $outputDir/write_bitstream.log
        if {"$env(PRTOP)" == ""} {
	    log_command "write_bitstream -bin_file -force $env(BITFILE)" $outputDir/write_bitstream.log
        } else {
	    log_command "write_bitstream -bin_file -force $env(BITFILE)" $outputDir/write_bitstream.log
	    set write_cell_bitstream_works 0
	    if $write_cell_bitstream_works {
		foreach name $env(RECONFIG_NETLISTS) {
		    set cellname top/$name
		    log_command "write_bitstream -bin_file -force -cell [get_cells $cellname] $env(BITFILE)" $outputDir/write_bitstream.log
		}
	    }
        }
}
set impl_end_time [clock seconds]
puts "topdown.tcl elapsed time [expr $impl_end_time - $impl_start_time] seconds"
