// ============================================================================
// Testbench: tb_compare
// File:      tb/tb_compare.v
//
// Trace-driven comparison testbench:
//   Instantiates both direct_mapped_cache and cache_2way_top in parallel,
//   executes an external access trace specified via +trace=<filename>,
//   and computes comparative statistics (Hits, Misses, Hit Rate %).
// ============================================================================

`timescale 1ns/1ps

module tb_compare;

    // ------------------------------------------------------------------
    // Clocks and Reset
    // ------------------------------------------------------------------
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;

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

    mem_model #(.LATENCY(3)) u_dm_mem (
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

    mem_model #(.LATENCY(3)) u_sa_mem (
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
    // Trace Parsing & Execution
    // ------------------------------------------------------------------
    reg [1023:0] trace_filename;
    integer fd;
    reg [31:0]   trace_addr;
    reg [31:0]   trace_wdata;
    reg [8*8-1:0] op_str;

    integer total_accesses = 0;
    integer dm_hits        = 0;
    integer dm_misses      = 0;
    integer sa_hits        = 0;
    integer sa_misses      = 0;

    reg dm_saw_miss, sa_saw_miss;
    reg dm_done, sa_done;

    task run_access;
        input is_write;
        input [31:0] addr;
        input [31:0] data;
        integer timeout;
        begin
            total_accesses = total_accesses + 1;
            dm_saw_miss = 1'b0;
            sa_saw_miss = 1'b0;
            dm_done     = 1'b0;
            sa_done     = 1'b0;

            @(negedge clk);
            // Drive DM
            dm_addr  = addr;
            dm_wdata = data;
            dm_we    = is_write;
            dm_re    = !is_write;

            // Drive 2-Way
            sa_addr  = addr;
            sa_wdata = data;
            sa_we    = is_write;
            sa_re    = !is_write;

            @(negedge clk);
            dm_we = 1'b0; dm_re = 1'b0;
            sa_we = 1'b0; sa_re = 1'b0;

            timeout = 0;
            while ((!dm_done || !sa_done) && timeout < 1000) begin
                @(posedge clk);
                #1;
                if (dm_ready) dm_done = 1'b1;
                if (sa_ready) sa_done = 1'b1;
                if (dm_mem_re || dm_mem_we) dm_saw_miss = 1'b1;
                if (sa_mem_re || sa_mem_we) sa_saw_miss = 1'b1;
                timeout = timeout + 1;
            end

            if (timeout >= 1000) begin
                $display("ERROR: Timeout executing access %0d to 0x%08h (dm_done=%b, sa_done=%b)",
                         total_accesses, addr, dm_done, sa_done);
                $finish;
            end

            // Account hits/misses
            if (dm_saw_miss) dm_misses = dm_misses + 1;
            else             dm_hits   = dm_hits + 1;

            if (sa_saw_miss) sa_misses = sa_misses + 1;
            else             sa_hits   = sa_hits + 1;

            repeat (2) @(posedge clk); // settle back to IDLE
        end
    endtask

    real dm_rate;
    real sa_rate;

    initial begin
        if (!$value$plusargs("trace=%s", trace_filename)) begin
            trace_filename = "sim/traces/conflict.trc";
        end

        fd = $fopen(trace_filename, "r");
        if (fd == 0) begin
            $display("ERROR: Could not open trace file '%0s'", trace_filename);
            $finish;
        end

        $display("");
        $display("===============================================================================");
        $display("  TRACE-DRIVEN CACHE COMPARISON BENCHMARK");
        $display("  Trace file: %0s", trace_filename);
        $display("===============================================================================");

        // Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // Read and process operations
        while ($fscanf(fd, "%s %h %h\n", op_str, trace_addr, trace_wdata) == 3) begin
            if (op_str[7:0] == "R") begin
                run_access(1'b0, trace_addr, 32'd0);
            end else if (op_str[7:0] == "W") begin
                run_access(1'b1, trace_addr, trace_wdata);
            end
        end

        $fclose(fd);

        dm_rate = (total_accesses > 0) ? (dm_hits * 100.0 / total_accesses) : 0.0;
        sa_rate = (total_accesses > 0) ? (sa_hits * 100.0 / total_accesses) : 0.0;

        $display("");
        $display("-------------------------------------------------------------------------------");
        $display("  METRIC                     DIRECT-MAPPED            2-WAY SET-ASSOCIATIVE");
        $display("-------------------------------------------------------------------------------");
        $display("  Total Accesses:            %10d               %10d", total_accesses, total_accesses);
        $display("  Cache Hits:                %10d               %10d", dm_hits, sa_hits);
        $display("  Cache Misses:              %10d               %10d", dm_misses, sa_misses);
        $display("  Hit Rate (%%):              %10.2f%%              %10.2f%%", dm_rate, sa_rate);
        $display("-------------------------------------------------------------------------------");
        $display("  Hit Rate Delta:            %+10.2f%%", (sa_rate - dm_rate));
        $display("===============================================================================");
        $display("");

        #50;
        $finish;
    end

endmodule
