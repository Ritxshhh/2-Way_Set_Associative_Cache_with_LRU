// ============================================================================
// Testbench: tb_direct_mapped_smoke
// File:      tb/tb_direct_mapped_smoke.v
//
// Smoke test for direct_mapped_cache.  Runs 5 accesses and asserts the
// hit/miss pattern is exactly: MISS, HIT, HIT, MISS, MISS.
//
// Includes an inline memory model that responds after a 4-cycle latency
// and returns an address-derived data pattern for reads.
// ============================================================================

`timescale 1ns / 1ps

module tb_direct_mapped_smoke;

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    reg          clk, rst_n;
    reg  [31:0]  cpu_addr, cpu_wdata;
    reg          cpu_we, cpu_re;
    wire [31:0]  cpu_rdata;
    wire         cpu_ready;

    wire [31:0]  mem_addr;
    wire         mem_re_w, mem_we_w;
    wire [127:0] mem_wdata_w;
    reg  [127:0] mem_rdata_r;
    reg          mem_ready_r;

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    direct_mapped_cache dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (cpu_addr),
        .cpu_wdata (cpu_wdata),
        .cpu_we    (cpu_we),
        .cpu_re    (cpu_re),
        .cpu_rdata (cpu_rdata),
        .cpu_ready (cpu_ready),
        .mem_addr  (mem_addr),
        .mem_re    (mem_re_w),
        .mem_we    (mem_we_w),
        .mem_wdata (mem_wdata_w),
        .mem_rdata (mem_rdata_r),
        .mem_ready (mem_ready_r)
    );

    // ----------------------------------------------------------------
    // Clock generation – 10 ns period (100 MHz)
    // ----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Inline Memory Model  (4-count latency, address-based read data)
    //
    // Protocol:  cache holds mem_re/mem_we high until mem_ready pulses.
    //            Memory starts a 4-tick counter on the rising request,
    //            then asserts mem_ready for exactly one cycle.
    //            For reads, mem_rdata = {addr+12, addr+8, addr+4, addr}.
    // ----------------------------------------------------------------
    reg [2:0] mem_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_cnt     <= 3'd0;
            mem_ready_r <= 1'b0;
            mem_rdata_r <= 128'd0;
        end else begin
            mem_ready_r <= 1'b0;                       // default: deassert
            if (mem_cnt != 3'd0) begin
                if (mem_cnt == 3'd4) begin              // count reached → respond
                    mem_ready_r <= 1'b1;
                    mem_cnt     <= 3'd0;
                    if (mem_re_w)                       // provide read data
                        mem_rdata_r <= {mem_addr + 32'd12,
                                        mem_addr + 32'd8,
                                        mem_addr + 32'd4,
                                        mem_addr};
                end else begin
                    mem_cnt <= mem_cnt + 3'd1;
                end
            end else if ((mem_re_w || mem_we_w) && !mem_ready_r) begin
                mem_cnt <= 3'd1;                       // start counting
            end
        end
    end

    // ----------------------------------------------------------------
    // Test infrastructure
    // ----------------------------------------------------------------
    integer pass_count;

    // ---- Task: issue a CPU READ and report HIT / MISS ----
    task do_read;
        input  [31:0] addr;
        output        is_miss;
        reg           miss_flag;
        begin
            miss_flag = 0;
            cpu_addr  = addr;
            cpu_wdata = 32'd0;
            cpu_re    = 1;
            cpu_we    = 0;
            @(posedge clk);              // cache latches request → TAG_CHECK
            cpu_re = 0;
            while (!cpu_ready) begin
                @(posedge clk);
                if (dut.state == 3'd4 || dut.state == 3'd3)  // FETCH_BLOCK or WRITE_BACK
                    miss_flag = 1;
            end
            is_miss = miss_flag;
        end
    endtask

    // ---- Task: issue a CPU WRITE and report HIT / MISS ----
    task do_write;
        input  [31:0] addr;
        input  [31:0] data;
        output        is_miss;
        reg           miss_flag;
        begin
            miss_flag = 0;
            cpu_addr  = addr;
            cpu_wdata = data;
            cpu_we    = 1;
            cpu_re    = 0;
            @(posedge clk);              // cache latches request → TAG_CHECK
            cpu_we = 0;
            while (!cpu_ready) begin
                @(posedge clk);
                if (dut.state == 3'd4 || dut.state == 3'd3)
                    miss_flag = 1;
            end
            is_miss = miss_flag;
        end
    endtask

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    reg is_miss;

    initial begin
        $dumpfile("tb_direct_mapped_smoke.vcd");
        $dumpvars(0, tb_direct_mapped_smoke);

        // ---- Initialise ----
        cpu_addr  = 32'd0;
        cpu_wdata = 32'd0;
        cpu_we    = 0;
        cpu_re    = 0;
        pass_count = 0;

        // ---- Reset ----
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("");
        $display("=========================================");
        $display("  Direct-Mapped Cache – Smoke Test");
        $display("=========================================");

        // ============================================================
        // Step 1: Read addr=0x0000_0000  →  expect MISS  (cold miss)
        // ============================================================
        do_read(32'h0000_0000, is_miss);
        $display("Step 1: Read  0x00000000 -> %s", is_miss ? "MISS" : "HIT");
        if (is_miss) pass_count = pass_count + 1;
        else         $display("  FAIL: expected MISS");
        @(posedge clk);  // gap – let cache return to IDLE

        // ============================================================
        // Step 2: Read addr=0x0000_0000  →  expect HIT
        // ============================================================
        do_read(32'h0000_0000, is_miss);
        $display("Step 2: Read  0x00000000 -> %s", is_miss ? "MISS" : "HIT");
        if (!is_miss) pass_count = pass_count + 1;
        else          $display("  FAIL: expected HIT");
        @(posedge clk);

        // ============================================================
        // Step 3: Write addr=0x0000_0000, data=0xDEADBEEF → expect HIT
        //         dirty_mem[0] must become 1
        // ============================================================
        do_write(32'h0000_0000, 32'hDEAD_BEEF, is_miss);
        $display("Step 3: Write 0x00000000, data=0xDEADBEEF -> %s  dirty_mem[0]=%0b",
                 is_miss ? "MISS" : "HIT", dut.dirty_mem[0]);
        if (!is_miss && dut.dirty_mem[0] == 1'b1)
            pass_count = pass_count + 1;
        else
            $display("  FAIL: expected HIT with dirty_mem[0]=1");
        @(posedge clk);

        // ============================================================
        // Step 4: Read addr=0x0000_0800  →  expect MISS
        //         Same index=0, different tag → evicts dirty line
        //         → WRITE_BACK first, then FETCH_BLOCK
        // ============================================================
        do_read(32'h0000_0800, is_miss);
        $display("Step 4: Read  0x00000800 -> %s", is_miss ? "MISS" : "HIT");
        if (is_miss) pass_count = pass_count + 1;
        else         $display("  FAIL: expected MISS (with WRITE_BACK)");
        @(posedge clk);

        // ============================================================
        // Step 5: Read addr=0x0000_0000  →  expect MISS
        //         Line 0 now holds 0x0800's data — direct-mapped
        //         cache cannot hold both simultaneously.
        // ============================================================
        do_read(32'h0000_0000, is_miss);
        $display("Step 5: Read  0x00000000 -> %s", is_miss ? "MISS" : "HIT");
        if (is_miss) pass_count = pass_count + 1;
        else         $display("  FAIL: expected MISS");

        // ============================================================
        // Summary
        // ============================================================
        $display("");
        $display("=========================================");
        $display("  Expected pattern: MISS, HIT, HIT, MISS, MISS");
        if (pass_count == 5)
            $display("  RESULT: ALL 5 CHECKS PASSED");
        else
            $display("  RESULT: FAILED — %0d / 5 checks passed", pass_count);
        $display("=========================================");
        $display("");

        #100;
        $finish;
    end

    // ----------------------------------------------------------------
    // Watchdog – kill simulation if it hangs
    // ----------------------------------------------------------------
    initial begin
        #100_000;
        $display("TIMEOUT: simulation exceeded 100 us — aborting.");
        $finish;
    end

endmodule

