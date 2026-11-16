# ==============================================================================
# synth_cache_2way.tcl
# Vivado synthesis script for 2-Way Set-Associative Cache with LRU
# Target: Xilinx Artix-7 xc7a35tcsg324-1
# ==============================================================================

set_param general.maxThreads 4
create_project -in_memory -part xc7a35tcsg324-1

# Read all RTL sources for modular 2-way cache
read_verilog -sv {
    ../rtl/way_data_ram.v
    ../rtl/way_tag_ram.v
    ../rtl/valid_bits.v
    ../rtl/lru_state.v
    ../rtl/tag_comparator.v
    ../rtl/cache_fsm.v
    ../rtl/cache_2way_top.v
}

# Synthesize design out-of-context
synth_design -top cache_2way_top -part xc7a35tcsg324-1 -mode out_of_context

# Define synthesis clock constraint (100 MHz target, 10.0 ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# Generate detailed reports
report_utilization -file cache_2way_utilization.rpt -pb cache_2way_utilization.pb
report_timing_summary -file cache_2way_timing.rpt -max_paths 10

puts "Synthesis for cache_2way_top completed successfully."
