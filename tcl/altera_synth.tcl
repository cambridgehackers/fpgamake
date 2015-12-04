## Copyright (C) Cornell University, Inc.

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

#  TCL FILE INFORMATION
#
#  This Tcl file will perform the following:
#  1)  Create the lower-level project if needed.
#  --> If a project with the lower-level entity name does not exist in this directory,
#      the script will create it. If the project does exist, it will simply open the 
#      existing project.
#
#  2)  Set the appropriate user assignments.
#  --> When the script was generated, you chose which assignments you'd like to export to 
#      the lower-level module.  These assignments will be set, after which the project is 
#      ready to be compiled.

#
# STEP#0: define output directory area.
#
package require ::quartus::project
package require ::quartus::flow
package require ::quartus::misc

proc to_parameter_string {input_dict} {
  dict with input_dict {
    set component_parameters {}
    foreach item [dict keys $input_dict] {
        set val [dict get $input_dict $item]
        lappend component_parameters --$item=$val
    }
  }
  return $component_parameters
}

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
set inst $env(INST)
set outputDir ./Synth/$module

#  Create the project if it does not exist 
if {[is_project_open]} {
    project_close
}

if {![is_project_open]} {
    if {[project_exists Synth/$module/$module]} {
        project_open -revision $module Synth/$module/$module
    } else {
        project_new -revision $module Synth/$module/$module
    }
}

#
# STEP#1: setup design sources and constraints
#
set include_dirs [dict create]
foreach headerfile $env(HEADERFILES) {
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

#  Delete all logiclock regions in the lower-project 
package require ::quartus::logiclock
initialize_logiclock
set regions [get_logiclock]
foreach region $regions {
	logiclock_delete -region $region
}
uninitialize_logiclock

set_global_assignment -name FAMILY $env(FPGAMAKE_FAMILY)
set_global_assignment -name DEVICE $partname
set_global_assignment -name TOP_LEVEL_ENTITY $module
set_global_assignment -name INCREMENTAL_COMPILATION FULL_INCREMENTAL_COMPILATION
set_global_assignment -name SMART_RECOMPILE ON
set_global_assignment -name DEVICE_FILTER_SPEED_GRADE FASTEST
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 1

foreach floorplan $env(FLOORPLAN) {
    if {[file exists $floorplan]} {
        set fd [open $floorplan "r"]
        while {[gets $fd line] != -1} {
            if [regexp -all -- $module $line] {
                eval $line
            }
        }
        close $fd
    } else {
        post_message -type critical_warning "FLOORPLAN: $floorplan not found\n"
    }
}

set_global_assignment -name QIC_EXPORT_FILE $module.qxp
set_global_assignment -name QIC_EXPORT_NETLIST_TYPE POST_FIT
set_global_assignment -name QIC_EXPORT_ROUTING OFF
#set_instance_assignment -name VIRTUAL_PIN ON -to accel
#set_instance_assignment -name VIRTUAL_PIN ON -to at_altera
#set_instance_assignment -name VIRTUAL_PIN ON -to clk
#set_instance_assignment -name VIRTUAL_PIN ON -to dir
#set_instance_assignment -name VIRTUAL_PIN ON -to dir[0]
#set_instance_assignment -name VIRTUAL_PIN ON -to dir[1]
#set_instance_assignment -name VIRTUAL_PIN ON -to get_ticket
#set_instance_assignment -name VIRTUAL_PIN ON -to reset
#set_instance_assignment -name VIRTUAL_PIN ON -to speed_too_fast

export_assignments

# quartus_map --read_settings_files=on --write_settings_files=off $MODULE
set quartus_map_args [dict create]
dict set quartus_map_args read_settings_files on
dict set quartus_map_args write_settings_files on
set component_parameters [to_parameter_string $quartus_map_args]
if {[catch {execute_module -tool map -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Analysis & Synthesis failed. See the report file.\n"
    project_close
    exit 1
}

# quartus_cdb --merge=on $MODULE
set quartus_cdb_args [dict create]
dict set quartus_cdb_args merge on
set component_parameters [to_parameter_string $quartus_cdb_args]
if {[catch {execute_module -tool cdb -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: CDB failed. See the report file.\n"
    project_close
    exit 1
}

# quartus_fit --read_settings_files=on --write_settings_files=off $MODULE
set quartus_fit_args [dict create]
dict set quartus_fit_args read_settings_files on
dict set quartus_fit_args write_settings_files on
set component_parameters [to_parameter_string $quartus_fit_args]
if {[catch {execute_module -tool fit -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Fitting failed. See the report file.\n"
    project_close
    exit 1
}

# quartus_cdb --incremental_compilation_import $MODULE
set quartus_cdb_args [dict create]
dict set quartus_cdb_args incremental_compilation_export "$module-synth.qxp"
set component_parameters [to_parameter_string $quartus_cdb_args]
if {[catch {execute_module -tool cdb -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Exporting Netlist failed. See the report file.\n"
    project_close
    exit 1
}

project_close
