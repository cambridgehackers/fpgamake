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

package require ::quartus::project
package require ::quartus::flow

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
set module_netlists [regexp -all -inline {\S+} $env(MODULE_NETLISTS)]
set partitions [regexp -all -inline {\S+} $env(PARTITIONS)]
set subinsts [regexp -all -inline {\S+} $env(SUBINST)]

set outputDir ./Impl/$module

set scriptdir [file dirname $argv0]
source $scriptdir/log.tcl

set sdc_files [regexp -all -inline {\S+} $env(SDC)]

if {![is_project_open]} {
    if {[project_exists $module]} {
	project_open -revision $module $module
    } else {
	project_new -revision $module $module
    }
}

#
# STEP#1: setup design sources and constraints
#
set include_dirs [dict create]
foreach headerfile $env(HEADERFILES) {
    #log_command "read_verilog $headerfile" $outputDir/temp.log
    dict set include_dirs [file dirname $headerfile] "True"
}

puts "vfiles"
puts $env(VFILES)
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

# Set SDC
foreach sdc_file $sdc_files {
    set_global_assignment -name SDC_FILE $sdc_file
}

# source tcl script
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
set_global_assignment -name INCREMENTAL_COMPILATION FULL_INCREMENTAL_COMPILATION
set_global_assignment -name SMART_RECOMPILE ON

# quartus_map --read_settings_files=on --write_settings_files=off $MODULE
set quartus_map_args [dict create]
dict set quartus_map_args read_settings_files on
dict set quartus_map_args write_settings_files off
set component_parameters [to_parameter_string $quartus_map_args]
if {[catch {execute_module -tool map -args "$component_parameters --analyze_project"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Analysis & Synthesis failed. See the report file.\n"
    project_close
    exit 1
}

puts partitions
puts $partitions
puts $module_netlists
foreach partition $partitions netlist $module_netlists subinst $subinsts {
    puts $partition
    puts $netlist
    set_global_assignment -name PARTITION_NETLIST_TYPE IMPORTED -section_id $partition
    set_global_assignment -name PARTITION_IMPORT_FILE $netlist -section_id $partition
    set_global_assignment -name PARTITION_IMPORT_EXISTING_LOGICLOCK_REGIONS REPLACE_CONFLICTING -section_id $partition
    set_instance_assignment -name PARTITION_HIERARCHY $subinst -to $partition -section_id $partition
}

export_assignments

# quartus_cdb --incremental_compilation_import $MODULE
if {[llength $partitions] != 0} {
set quartus_cdb_args [dict create]
dict set quartus_cdb_args incremental_compilation_import on
set component_parameters [to_parameter_string $quartus_cdb_args]
if {[catch {execute_module -tool cdb -args "$component_parameters"} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Import QXP failed. See the report file.\n"
    project_close
    exit 1
}
}

# quartus_map --read_settings_files=on --write_settings_files=off $MODULE
set quartus_map_args [dict create]
dict set quartus_map_args read_settings_files on
dict set quartus_map_args write_settings_files off
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

if {[catch {execute_module -tool asm} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Bitstream Generation failed. See the report file.\n"
    project_close
    exit 1
} else {
    puts "\nINFO: Assembler was successful.\n"
}

# quartus_sta $MODULE
if {[catch {execute_module -tool sta} result]} {
    puts "\nResult: $result\n"
    puts "ERROR: Timing Analysis failed. See the report file.\n"
    project_close
    exit 1
}

project_close
