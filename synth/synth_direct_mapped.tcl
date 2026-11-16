# ==============================================================================
# synth_direct_mapped.tcl
# Vivado synthesis script for Direct-Mapped Cache Baseline
# Target: Xilinx Artix-7 xc7a35tcsg324-1
# ==============================================================================

set_param general.maxThreads 4
create_project -in_memory -part xc7a35tcsg324-1

# Read RTL design files
read_verilog -sv {
    ../rtl/direct_mapped_cache.v
}

# Synthesize design out-of-context
synth_design -top direct_mapped_cache -part xc7a35tcsg324-1 -mode out_of_context

# Define synthesis clock constraint (100 MHz target, 10.0 ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# Generate detailed reports
report_utilization -file direct_mapped_utilization.rpt -pb direct_mapped_utilization.pb
report_timing_summary -file direct_mapped_timing.rpt -max_paths 10

puts "Synthesis for direct_mapped_cache completed successfully."
