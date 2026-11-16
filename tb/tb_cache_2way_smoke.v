// tb_cache_2way_smoke.v
// Smoke test for cache_2way_top. Uses the same addresses as the direct-mapped
// smoke test so the two results line up step for step.
//
//   1. R 0x000  -> MISS  (cold; fills Way-0 of set 0)
//   2. R 0x000  -> HIT
//   3. R 0x400  -> MISS  (tag 1, set 0; fills Way-1, Way-0 kept)
//   4. R 0x000  -> HIT   (both lines co-resident in set 0)
//   5. R 0x400  -> HIT
//   6. R 0x800  -> MISS  (tag 2, set 0; set full -> evict the LRU way)
//
// Expected LRU history for set 0 (lru_way = least-recently-used way, resets to 0):
//   step 1  victim = lru_way = 0 -> fill W0 (W0 now MRU, lru=1), retry hit W0 (lru=1)
//   step 2  hit W0                                                          (lru=1)
//   step 3  victim = lru_way = 1 (invalid) -> fill W1, retry hit W1         (lru=0)
//   step 4  hit W0                                                          (lru=1)
//   step 5  hit W1                                                          (lru=0)
//   step 6  victim = lru_way = 0 -> Way-0 (holding 0x000) is evicted; 0x400 stays.
//
// Hit/miss is judged externally: an access that issues a memory fetch (mem_re)
// is a miss.

`timescale 1ns/1ps

module tb_cache_2way_smoke;

    localparam MEM_LAT = 3;     // cycles from request to mem_ready

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg  [31:0]  cpu_addr = 32'd0;
    reg  [31:0]  cpu_wdata = 32'd0;
    reg          cpu_we = 1'b0;
    reg          cpu_re = 1'b0;
    wire [31:0]  cpu_rdata;
    wire         cpu_ready;
    wire [31:0]  mem_addr;
    wire         mem_re, mem_we;
    wire [127:0] mem_wdata;
    reg  [127:0] mem_rdata = 128'd0;
    reg          mem_ready = 1'b0;

    always #5 clk = ~clk;

    cache_2way_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (cpu_addr),
        .cpu_wdata (cpu_wdata),
        .cpu_we    (cpu_we),
        .cpu_re    (cpu_re),
        .cpu_rdata (cpu_rdata),
        .cpu_ready (cpu_ready),
        .mem_addr  (mem_addr),
        .mem_re    (mem_re),
        .mem_we    (mem_we),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );

    // ------------------------------------------------------------------
    // Behavioral main memory: every word holds a value derived from its
    // address, so read data can be checked without a backing array.
    // ------------------------------------------------------------------
    function [31:0] mem_word(input [31:0] byte_addr);
        mem_word = 32'hD000_0000 | {byte_addr[27:2], 2'b00};
    endfunction

    function [127:0] mem_line(input [31:0] base);
        mem_line = {mem_word(base + 12), mem_word(base + 8),
                    mem_word(base + 4),  mem_word(base)};
    endfunction

    integer mem_cnt = 0;
    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if ((mem_re || mem_we) && !mem_ready) begin
            if (mem_cnt == MEM_LAT) begin
                mem_cnt   <= 0;
                mem_ready <= 1'b1;
                if (mem_re) mem_rdata <= mem_line({mem_addr[31:4], 4'b0});
            end else begin
                mem_cnt <= mem_cnt + 1;
            end
        end else begin
            mem_cnt <= 0;
        end
    end

    // ------------------------------------------------------------------
    // Per-access observers
    // ------------------------------------------------------------------
    localparam [4:0] S_SELECT_VICTIM = 5'd3;

    reg     saw_fetch, saw_writeback, saw_victim;
    reg     victim_way;
    integer cycles;

    always @(posedge clk) begin
        if (mem_re) saw_fetch     <= 1'b1;
        if (mem_we) saw_writeback <= 1'b1;
        if (dut.u_fsm.state == S_SELECT_VICTIM) begin
            saw_victim <= 1'b1;
            victim_way <= dut.lru_way;
        end
        cycles <= cycles + 1;
    end

    // ------------------------------------------------------------------
    // Access task: one read, wait for cpu_ready, score HIT/MISS.
    // ------------------------------------------------------------------
    integer errors = 0;
    integer step   = 0;
    reg     was_hit;
    reg [31:0] got;

    task do_read(input [31:0] addr, input expect_hit);
        integer timeout;
        begin
            step = step + 1;
            @(negedge clk);
            saw_fetch = 1'b0; saw_writeback = 1'b0; saw_victim = 1'b0;
            cycles = 0;
            cpu_addr = addr;
            cpu_re   = 1'b1;
            @(negedge clk);
            cpu_re   = 1'b0;
            timeout  = 0;
            while (!cpu_ready && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cpu_ready) begin
                $display("  step %0d: TIMEOUT waiting for cpu_ready", step);
                errors = errors + 1;
            end
            got     = cpu_rdata;
            was_hit = !saw_fetch;

            $display("  step %0d: R 0x%08h  idx=%0d tag=%0d  -> %s  (rdata=0x%08h, %0d cycles)",
                     step, addr, addr[9:4], addr[31:10],
                     was_hit ? "HIT " : "MISS", got, cycles);

            if (was_hit != expect_hit) begin
                $display("           UNEXPECTED: expected %s", expect_hit ? "HIT" : "MISS");
                errors = errors + 1;
            end
            if (got !== mem_word(addr)) begin
                $display("           rdata mismatch: expected 0x%08h", mem_word(addr));
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache_2way_smoke);

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        $display("");
        $display("=== cache_2way_top smoke test ===");

        do_read(32'h0000_0000, 1'b0);   // 1  MISS (cold, fills Way-0)
        do_read(32'h0000_0000, 1'b1);   // 2  HIT
        do_read(32'h0000_0400, 1'b0);   // 3  MISS (fills Way-1)
        do_read(32'h0000_0000, 1'b1);   // 4  HIT  -- 0x000 still resident
        do_read(32'h0000_0400, 1'b1);   // 5  HIT
        do_read(32'h0000_0800, 1'b0);   // 6  MISS (evicts LRU way)

        // Step 6 victim check. Hand-derived LRU history says Way-0 is LRU.
        $display("");
        if (!saw_victim) begin
            $display("  step 6: FSM never reached SELECT_VICTIM");
            errors = errors + 1;
        end else begin
            $display("  step 6: victim way = Way-%0d (expected Way-0)", victim_way);
            if (victim_way !== 1'b0) errors = errors + 1;
        end
        if (saw_writeback) begin
            $display("  step 6: unexpected write-back (victim line was clean)");
            errors = errors + 1;
        end

        // Set 0 contents after step 6 (index is still 0): Way-0 = tag 2, Way-1 = tag 1.
        $display("  set 0 after step 6: Way-0 valid=%0d tag=%0d | Way-1 valid=%0d tag=%0d",
                 dut.valid0, dut.way0_tag, dut.valid1, dut.way1_tag);
        if (!(dut.valid0 && dut.way0_tag == 22'd2 && dut.valid1 && dut.way1_tag == 22'd1)) begin
            $display("  set 0 contents wrong: expected Way-0 tag 2, Way-1 tag 1");
            errors = errors + 1;
        end

        $display("");
        if (errors == 0)
            $display("PASS: pattern MISS,HIT,MISS,HIT,HIT,MISS and step-6 victim Way-0 confirmed");
        else
            $display("FAIL: %0d error(s)", errors);
        $display("");
        $finish;
    end

endmodule
