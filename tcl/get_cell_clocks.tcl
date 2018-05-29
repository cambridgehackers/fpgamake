proc get_pin_clocks {cell} {
    foreach pin [get_pins $cell/*] {
	set dir [get_property DIRECTION $pin]
	puts "----------------------------------------"
	puts "$dir    $pin";
	
	set nets [get_nets -quiet -of_objects $pin];
	puts "    nets $nets"
	set clks [get_clocks -quiet -of_objects $pin];
	puts "    clocks from pin $clks"
	foreach net $nets {
	    set driver_pin [get_pins -quiet -filter {DIRECTION == "OUT" && IS_LEAF == TRUE } -of_objects [ get_nets -segments $net ]]
	    set driver_cell [get_cells -of_objects $driver_pin]
	    puts "    driver_cell $driver_cell"
	    if { [get_property IS_SEQUENTIAL $driver_cell] == 1 } { 
		set timing_arc [get_timing_arcs -quiet -to $driver_pin]
		puts "    timing_arc $timing_arc"
		if {[llength $timing_arc] == 0} {
		    set driver_clock [get_clocks -quiet -of_objects $driver_pin]
		    puts "    driver_clock $driver_clock"
		    continue
		}
		set cell_clock_pin [get_pins -quiet -filter {IS_CLOCK} [get_property FROM_PIN $timing_arc]]
		if { [llength $cell_clock_pin] > 1 } { 
		    continue 
		}
	    } else { 
		# our driver cell is a LUT or LUTMEM in combinatorial mode, we need to trace further.
		set paths [get_timing_paths -quiet -through $driver_pin ]
		if { [llength $paths] > 0 } {
		    # note that here we arbitrarily select the start point of the FIRST timing path... there might be multiple clocks with timing paths for this net.
		    # use MARK_DEBUG_CLOCK to specify another clock in this case.
		    set cell_clock_pin [get_pins -quiet [get_property STARTPOINT_PIN [lindex $paths 0]]]  
		} else { 
		    # Can't find any timing path, so skip the net
		    continue
		}
	    }   
	    # clk_net will usually be a list of net segments, which needs filtering to determine the net connected to the driver pin
	    set clk_net [get_nets -of_objects $cell_clock_pin]
	    puts "    clk_net       $clk_net"
	    set clk_net_clock [get_clocks -quiet -of_objects $clk_net]
	    puts "    clk_net_clock $clk_net_clock"
	}
    }
}
