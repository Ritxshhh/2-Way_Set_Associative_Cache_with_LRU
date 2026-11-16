// ============================================================================
// Testbench: tb_compare
// File:      tb/tb_compare.v
//
// Trace-driven comparison testbench:
//   Instantiates both direct_mapped_cache (Member 1) and cache_2way_top (Member 4),
//   each wired to its own mem_model instance (Member 2) with identical LATENCY
//   and identical initial backing-memory contents.
//
//   Parameters / plusargs supported:
//     +trace=<path>       Path to input trace file (default: sim/traces/random.trc)
//     +log_direct=<path>  Output log for direct-mapped (default: sim/results_direct.log)
//     +log_2way=<path>    Output log for 2-way SA (default: sim/results_2way.log)
//
//   Functional verification:
//     Maintains a golden reference memory model tracking expected word contents
//     after every write, and verifies that both caches return correct data on every read.
//
//   Per-access logging:
//     Writes "<address> <HIT/MISS> <cycle_count>" to both log files.
// ============================================================================

`timescale 1ns/1ps

module tb_compare;

    // ------------------------------------------------------------------
    // Clocks and Reset
    // ------------------------------------------------------------------
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;

    localparam MEM_LATENCY = 3;

    // ------------------------------------------------------------------
    // Direct-Mapped Cache instance & memory
    // ------------------------------------------------------------------
    reg  [31:0]  dm_addr = 32'd0;
    reg  [31:0]  dm_wdata = 32'd0;
    reg          dm_we = 1'b0;
    reg          dm_re = 1'b0;
    wire [31:0]  dm_rdata;
    wire         dm_ready;

    wire [31:0]  dm_mem_addr;
    wire         dm_mem_re, dm_mem_we;
    wire [127:0] dm_mem_wdata;
    wire [127:0] dm_mem_rdata;
    wire         dm_mem_ready;

    direct_mapped_cache u_dm_cache (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (dm_addr),
        .cpu_wdata (dm_wdata),
        .cpu_we    (dm_we),
        .cpu_re    (dm_re),
        .cpu_rdata (dm_rdata),
        .cpu_ready (dm_ready),
        .mem_addr  (dm_mem_addr),
        .mem_re    (dm_mem_re),
        .mem_we    (dm_mem_we),
        .mem_wdata (dm_mem_wdata),
        .mem_rdata (dm_mem_rdata),
        .mem_ready (dm_mem_ready)
    );

    mem_model #(.LATENCY(MEM_LATENCY)) u_dm_mem (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_addr  (dm_mem_addr),
        .mem_re    (dm_mem_re),
        .mem_we    (dm_mem_we),
        .mem_wdata (dm_mem_wdata),
        .mem_rdata (dm_mem_rdata),
        .mem_ready (dm_mem_ready)
    );

    // ------------------------------------------------------------------
    // 2-Way Set-Associative Cache instance & memory
    // ------------------------------------------------------------------
    reg  [31:0]  sa_addr = 32'd0;
    reg  [31:0]  sa_wdata = 32'd0;
    reg          sa_we = 1'b0;
    reg          sa_re = 1'b0;
    wire [31:0]  sa_rdata;
    wire         sa_ready;

    wire [31:0]  sa_mem_addr;
    wire         sa_mem_re, sa_mem_we;
    wire [127:0] sa_mem_wdata;
    wire [127:0] sa_mem_rdata;
    wire         sa_mem_ready;

    cache_2way_top u_sa_cache (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (sa_addr),
        .cpu_wdata (sa_wdata),
        .cpu_we    (sa_we),
        .cpu_re    (sa_re),
        .cpu_rdata (sa_rdata),
        .cpu_ready (sa_ready),
        .mem_addr  (sa_mem_addr),
        .mem_re    (sa_mem_re),
        .mem_we    (sa_mem_we),
        .mem_wdata (sa_mem_wdata),
        .mem_rdata (sa_mem_rdata),
        .mem_ready (sa_mem_ready)
    );

    mem_model #(.LATENCY(MEM_LATENCY)) u_sa_mem (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_addr  (sa_mem_addr),
        .mem_re    (sa_mem_re),
        .mem_we    (sa_mem_we),
        .mem_wdata (sa_mem_wdata),
        .mem_rdata (sa_mem_rdata),
        .mem_ready (sa_mem_ready)
    );

    // ------------------------------------------------------------------
    // Golden Reference Model (64 KB = 16,384 words)
    // ------------------------------------------------------------------
    reg [31:0] golden_mem [0:16383];
    integer dm_mismatches = 0;
    integer sa_mismatches = 0;

    // ------------------------------------------------------------------
    // Statistics & Counters
    // ------------------------------------------------------------------
    integer total_accesses = 0;
    integer total_reads    = 0;
    integer total_writes   = 0;
    integer dm_hits        = 0;
    integer dm_misses      = 0;
    integer sa_hits        = 0;
    integer sa_misses      = 0;
    integer dm_total_cycles = 0;
    integer sa_total_cycles = 0;

    // File descriptors
    integer fd_trace = 0;
    integer fd_direct = 0;
    integer fd_2way = 0;

    reg [1023:0] trace_filename;
    reg [1023:0] log_direct_path;
    reg [1023:0] log_2way_path;

    // ------------------------------------------------------------------
    // Access Execution Task
    // ------------------------------------------------------------------
    task run_access;
        input        is_write;
        input [31:0] addr;
        input [31:0] wdata;
        integer      dm_cycles, sa_cycles;
        reg          dm_miss, sa_miss;
        reg          dm_done, sa_done;
        integer      timeout;
        reg [31:0]   expected_data;
        begin
            total_accesses = total_accesses + 1;
            if (is_write) total_writes = total_writes + 1;
            else          total_reads  = total_reads + 1;

            dm_cycles = 0;
            sa_cycles = 0;
            dm_miss   = 1'b0;
            sa_miss   = 1'b0;
            dm_done   = 1'b0;
            sa_done   = 1'b0;

            expected_data = golden_mem[addr[15:2]];

            // Drive request on negedge clk
            @(negedge clk);
            dm_addr  = addr;
            dm_wdata = wdata;
            dm_we    = is_write;
            dm_re    = !is_write;

            sa_addr  = addr;
            sa_wdata = wdata;
            sa_we    = is_write;
            sa_re    = !is_write;

            // Wait for rising edge where request is sampled by DUTs
            @(posedge clk);
            @(negedge clk);
            dm_we = 1'b0; dm_re = 1'b0;
            sa_we = 1'b0; sa_re = 1'b0;

            timeout = 0;
            while ((!dm_done || !sa_done) && timeout < 2000) begin
                @(posedge clk);
                #1; // Sample immediately after rising edge

                if (!dm_done) begin
                    dm_cycles = dm_cycles + 1;
                    if (dm_mem_re || dm_mem_we) dm_miss = 1'b1;
                    if (dm_ready) begin
                        dm_done = 1'b1;
                        if (!is_write && (dm_rdata !== expected_data)) begin
                            $display("ERROR [Access %0d] DM Mismatch at 0x%08h: got 0x%08h, expected 0x%08h",
                                     total_accesses, addr, dm_rdata, expected_data);
                            dm_mismatches = dm_mismatches + 1;
                        end
                    end
                end

                if (!sa_done) begin
                    sa_cycles = sa_cycles + 1;
                    if (sa_mem_re || sa_mem_we) sa_miss = 1'b1;
                    if (sa_ready) begin
                        sa_done = 1'b1;
                        if (!is_write && (sa_rdata !== expected_data)) begin
                            $display("ERROR [Access %0d] 2W Mismatch at 0x%08h: got 0x%08h, expected 0x%08h",
                                     total_accesses, addr, sa_rdata, expected_data);
                            sa_mismatches = sa_mismatches + 1;
                        end
                    end
                end

                timeout = timeout + 1;
            end

            if (timeout >= 2000) begin
                $display("FATAL: Timeout executing access %0d to 0x%08h (dm_done=%b, sa_done=%b)",
                         total_accesses, addr, dm_done, sa_done);
                $finish;
            end

            // Update golden model for writes
            if (is_write) begin
                golden_mem[addr[15:2]] = wdata;
            end

            // Hit/Miss accounting
            if (dm_miss) dm_misses = dm_misses + 1;
            else         dm_hits   = dm_hits + 1;

            if (sa_miss) sa_misses = sa_misses + 1;
            else         sa_hits   = sa_hits + 1;

            dm_total_cycles = dm_total_cycles + dm_cycles;
            sa_total_cycles = sa_total_cycles + sa_cycles;

            // Log access: <address> <HIT/MISS> <cycle_count>
            if (fd_direct != 0) begin
                $fdisplay(fd_direct, "0x%08X %s %0d", addr, dm_miss ? "MISS" : "HIT", dm_cycles);
            end
            if (fd_2way != 0) begin
                $fdisplay(fd_2way, "0x%08X %s %0d", addr, sa_miss ? "MISS" : "HIT", sa_cycles);
            end

            // Allow caches to return to clean IDLE state
            repeat (2) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------
    // Main Simulation Process
    // ------------------------------------------------------------------
    real dm_rate, sa_rate;
    real dm_avg_cycles, sa_avg_cycles;
    integer b, w;
    reg [8*8-1:0] op_str;
    reg [31:0]    trace_addr;
    reg [31:0]    trace_wdata;

    initial begin
        // Process plusargs
        if (!$value$plusargs("trace=%s", trace_filename)) begin
            trace_filename = "sim/traces/random.trc";
        end
        if (!$value$plusargs("log_direct=%s", log_direct_path)) begin
            log_direct_path = "sim/results_direct.log";
        end
        if (!$value$plusargs("log_2way=%s", log_2way_path)) begin
            log_2way_path = "sim/results_2way.log";
        end

        // Initialize golden memory matching mem_model initial state
        for (b = 0; b < 4096; b = b + 1) begin
            for (w = 0; w < 4; w = w + 1) begin
                golden_mem[(b << 2) + w] = {16'hA5A5, b[15:0]};
            end
        end

        // Open trace and log files
        fd_trace = $fopen(trace_filename, "r");
        if (fd_trace == 0) begin
            $display("ERROR: Could not open trace file '%0s'", trace_filename);
            $finish;
        end

        fd_direct = $fopen(log_direct_path, "w");
        if (fd_direct == 0) begin
            $display("ERROR: Could not create direct log file '%0s'", log_direct_path);
            $finish;
        end

        fd_2way = $fopen(log_2way_path, "w");
        if (fd_2way == 0) begin
            $display("ERROR: Could not create 2-way log file '%0s'", log_2way_path);
            $finish;
        end

        $display("");
        $display("===============================================================================");
        $display("  TRACE-DRIVEN CACHE COMPARISON BENCHMARK");
        $display("  Trace file: %0s", trace_filename);
        $display("  Direct-mapped log: %0s", log_direct_path);
        $display("  2-Way SA log:      %0s", log_2way_path);
        $display("===============================================================================");

        // Apply Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // Read and process operations from trace
        while ($fscanf(fd_trace, "%s %h\n", op_str, trace_addr) == 2) begin
            if (op_str[7:0] == "R") begin
                run_access(1'b0, trace_addr, 32'd0);
            end else if (op_str[7:0] == "W") begin
                trace_wdata = 32'hD0000000 | (total_accesses & 32'h0000FFFF);
                run_access(1'b1, trace_addr, trace_wdata);
            end
        end

        $fclose(fd_trace);
        $fclose(fd_direct);
        $fclose(fd_2way);

        // Compute summary metrics
        dm_rate = (total_accesses > 0) ? (dm_hits * 100.0 / total_accesses) : 0.0;
        sa_rate = (total_accesses > 0) ? (sa_hits * 100.0 / total_accesses) : 0.0;
        dm_avg_cycles = (total_accesses > 0) ? (dm_total_cycles * 1.0 / total_accesses) : 0.0;
        sa_avg_cycles = (total_accesses > 0) ? (sa_total_cycles * 1.0 / total_accesses) : 0.0;

        $display("");
        $display("-------------------------------------------------------------------------------");
        $display("  METRIC                     DIRECT-MAPPED            2-WAY SET-ASSOCIATIVE");
        $display("-------------------------------------------------------------------------------");
        $display("  Total Accesses:            %10d               %10d", total_accesses, total_accesses);
        $display("    Reads / Writes:          %5d / %-5d         %5d / %-5d",
                 total_reads, total_writes, total_reads, total_writes);
        $display("  Cache Hits:                %10d               %10d", dm_hits, sa_hits);
        $display("  Cache Misses:              %10d               %10d", dm_misses, sa_misses);
        $display("  Hit Rate (%%):              %10.2f%%              %10.2f%%", dm_rate, sa_rate);
        $display("  Hit Rate Delta:            %+10.2f%%", (sa_rate - dm_rate));
        $display("  Total Cycles:              %10d               %10d", dm_total_cycles, sa_total_cycles);
        $display("  Avg Cycles / Access:       %10.2f                %10.2f", dm_avg_cycles, sa_avg_cycles);
        $display("-------------------------------------------------------------------------------");
        $display("  FUNCTIONAL VERIFICATION (Golden Model Comparison):");
        $display("    Direct-Mapped Mismatches: %0d", dm_mismatches);
        $display("    2-Way SA Mismatches:      %0d", sa_mismatches);
        if (dm_mismatches == 0 && sa_mismatches == 0) begin
            $display("    Status:                   PASSED (100%% Data Integrity Verified)");
        end else begin
            $display("    Status:                   FAILED (Data Mismatch Detected!)");
        end
        $display("===============================================================================");
        $display("");

        #50;
        $finish;
    end

endmodule
