// ============================================================================
// Testbench: tb_dm_vs_2way
// File:      tb/tb_dm_vs_2way.v
//
// Head-to-head comparison: runs the SAME access sequence through both
// direct_mapped_cache and cache_2way_top, then prints a side-by-side
// HIT/MISS scorecard.
//
// The sequence is specifically chosen so that the 2-way set-associative
// cache keeps both conflicting lines resident while the direct-mapped
// cache thrashes (conflict misses on every access after the first fill).
//
// Addresses used (all map to the same set/index):
//   DM  index 0:  0x0000_0000 (tag 0), 0x0000_0800 (tag 1)
//   2W  set   0:  0x0000_0000 (tag 0), 0x0000_0400 (tag 1)
//
// Access pattern:   R A, R B, R A, R B, R A     (5 reads)
// Expected DM:      M    M    M    M    M        (all conflict misses after step 1-2)
// Expected 2-way:   M    M    H    H    H        (both lines co-resident from step 3)
// ============================================================================

`timescale 1ns / 1ps

module tb_dm_vs_2way;

    // ================================================================
    //  Clock & reset
    // ================================================================
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;

    // ================================================================
    //  Direct-Mapped Cache instance  (128 lines, index = addr[10:4])
    // ================================================================
    reg  [31:0]  dm_cpu_addr, dm_cpu_wdata;
    reg          dm_cpu_we, dm_cpu_re;
    wire [31:0]  dm_cpu_rdata;
    wire         dm_cpu_ready;
    wire [31:0]  dm_mem_addr;
    wire         dm_mem_re, dm_mem_we;
    wire [127:0] dm_mem_wdata;
    wire [127:0] dm_mem_rdata;
    wire         dm_mem_ready;

    direct_mapped_cache u_dm (
        .clk       (clk),       .rst_n     (rst_n),
        .cpu_addr  (dm_cpu_addr),  .cpu_wdata (dm_cpu_wdata),
        .cpu_we    (dm_cpu_we),    .cpu_re    (dm_cpu_re),
        .cpu_rdata (dm_cpu_rdata), .cpu_ready (dm_cpu_ready),
        .mem_addr  (dm_mem_addr),  .mem_re    (dm_mem_re),
        .mem_we    (dm_mem_we),    .mem_wdata (dm_mem_wdata),
        .mem_rdata (dm_mem_rdata), .mem_ready (dm_mem_ready)
    );

    mem_model #(.LATENCY(3)) u_dm_mem (
        .clk      (clk),       .rst_n    (rst_n),
        .mem_addr (dm_mem_addr),
        .mem_re   (dm_mem_re), .mem_we   (dm_mem_we),
        .mem_wdata(dm_mem_wdata),
        .mem_rdata(dm_mem_rdata), .mem_ready(dm_mem_ready)
    );

    // ================================================================
    //  2-Way Set-Associative Cache instance  (64 sets, index = addr[9:4])
    // ================================================================
    reg  [31:0]  sa_cpu_addr, sa_cpu_wdata;
    reg          sa_cpu_we, sa_cpu_re;
    wire [31:0]  sa_cpu_rdata;
    wire         sa_cpu_ready;
    wire [31:0]  sa_mem_addr;
    wire         sa_mem_re, sa_mem_we;
    wire [127:0] sa_mem_wdata;
    wire [127:0] sa_mem_rdata;
    wire         sa_mem_ready;

    cache_2way_top u_sa (
        .clk       (clk),       .rst_n     (rst_n),
        .cpu_addr  (sa_cpu_addr),  .cpu_wdata (sa_cpu_wdata),
        .cpu_we    (sa_cpu_we),    .cpu_re    (sa_cpu_re),
        .cpu_rdata (sa_cpu_rdata), .cpu_ready (sa_cpu_ready),
        .mem_addr  (sa_mem_addr),  .mem_re    (sa_mem_re),
        .mem_we    (sa_mem_we),    .mem_wdata (sa_mem_wdata),
        .mem_rdata (sa_mem_rdata), .mem_ready (sa_mem_ready)
    );

    mem_model #(.LATENCY(3)) u_sa_mem (
        .clk      (clk),       .rst_n    (rst_n),
        .mem_addr (sa_mem_addr),
        .mem_re   (sa_mem_re), .mem_we   (sa_mem_we),
        .mem_wdata(sa_mem_wdata),
        .mem_rdata(sa_mem_rdata), .mem_ready(sa_mem_ready)
    );

    // ================================================================
    //  Access tasks
    // ================================================================

    // --- Direct-Mapped read ---
    task dm_read;
        input  [31:0] addr;
        output        is_miss;
        reg           miss_flag;
        begin
            miss_flag    = 0;
            dm_cpu_addr  = addr;
            dm_cpu_re    = 1;
            dm_cpu_we    = 0;
            dm_cpu_wdata = 32'd0;
            @(posedge clk);
            dm_cpu_re = 0;
            while (!dm_cpu_ready) begin
                @(posedge clk);
                if (u_dm.state == 3'd4 || u_dm.state == 3'd3) miss_flag = 1;
            end
            is_miss = miss_flag;
        end
    endtask

    // --- 2-Way SA read ---
    task sa_read;
        input  [31:0] addr;
        output        is_miss;
        reg           saw_fetch;
        begin
            saw_fetch    = 0;
            sa_cpu_addr  = addr;
            sa_cpu_re    = 1;
            sa_cpu_we    = 0;
            sa_cpu_wdata = 32'd0;
            @(posedge clk);
            sa_cpu_re = 0;
            while (!sa_cpu_ready) begin
                @(posedge clk);
                if (sa_mem_re) saw_fetch = 1;
            end
            is_miss = saw_fetch;
        end
    endtask

    // ================================================================
    //  Test sequence
    // ================================================================
    // Addresses that conflict on the SAME index / set:
    //   DM:  A = 0x0000_0000   B = 0x0000_0800   (both index 0)
    //   2W:  A = 0x0000_0000   B = 0x0000_0400   (both set   0)
    localparam [31:0] DM_A = 32'h0000_0000,  DM_B = 32'h0000_0800;
    localparam [31:0] SA_A = 32'h0000_0000,  SA_B = 32'h0000_0400;

    reg dm_miss, sa_miss;
    reg [4:0] dm_results;   // bit per step: 1=miss
    reg [4:0] sa_results;
    integer   dm_misses, sa_misses;
    integer   step;

    initial begin
        $dumpfile("tb_dm_vs_2way.vcd");
        $dumpvars(0, tb_dm_vs_2way);

        // init
        dm_cpu_addr = 0; dm_cpu_wdata = 0; dm_cpu_we = 0; dm_cpu_re = 0;
        sa_cpu_addr = 0; sa_cpu_wdata = 0; sa_cpu_we = 0; sa_cpu_re = 0;
        dm_misses   = 0; sa_misses    = 0;

        // reset
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("");
        $display("==========================================================");
        $display("  Direct-Mapped  vs  2-Way Set-Associative  — Conflict Test");
        $display("==========================================================");
        $display("  Step  Addr(DM)   DM      Addr(2W)   2-Way");
        $display("  ----  ---------  ------  ---------  ------");

        // ----- Run 5 alternating-address reads -----
        // The pattern is:  A  B  A  B  A
        for (step = 0; step < 5; step = step + 1) begin
            // --- Direct-Mapped ---
            if (step[0] == 0) dm_read(DM_A, dm_miss);
            else              dm_read(DM_B, dm_miss);
            dm_results[step] = dm_miss;
            if (dm_miss) dm_misses = dm_misses + 1;
            @(posedge clk);

            // --- 2-Way SA ---
            if (step[0] == 0) sa_read(SA_A, sa_miss);
            else              sa_read(SA_B, sa_miss);
            sa_results[step] = sa_miss;
            if (sa_miss) sa_misses = sa_misses + 1;
            @(posedge clk);

            $display("  %0d     0x%08h  %s    0x%08h  %s",
                     step + 1,
                     step[0] == 0 ? DM_A : DM_B,
                     dm_miss ? "MISS" : " HIT",
                     step[0] == 0 ? SA_A : SA_B,
                     sa_miss ? "MISS" : " HIT");
        end

        // ----- Verdict -----
        $display("");
        $display("  Total misses:  DM = %0d / 5    2-Way = %0d / 5", dm_misses, sa_misses);
        $display("");

        if (dm_results == 5'b11111 && sa_results == 5'b00011) begin
            $display("  PASS: DM thrashes on every access (5 misses);");
            $display("        2-way holds both lines after initial fills (2 misses).");
        end else begin
            $display("  FAIL: unexpected hit/miss pattern");
            $display("        DM  = %b (expected 11111)", dm_results);
            $display("        2W  = %b (expected 00011)", sa_results);
        end

        $display("==========================================================");
        $display("");
        #100;
        $finish;
    end

    // Watchdog
    initial begin
        #500_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule

