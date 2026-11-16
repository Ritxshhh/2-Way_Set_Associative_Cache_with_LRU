// ============================================================================
// Testbench: tb_cache_2way_writeback
// File:      tb/tb_cache_2way_writeback.v
//
// Verification of dirty-line writeback and memory consistency on eviction:
//   1. Write addr A (0x0000_0000) with 0xCAFEBABE -> fills Way-0, sets dirty0=1.
//   2. Write addr B (0x0000_0400) with 0xFEEDFACE -> fills Way-1, sets dirty1=1.
//      (Way-0 is now LRU).
//   3. Read addr C (0x0000_0800) -> miss in set 0.
//      - Asserts Way-0 is selected as victim.
//      - Asserts writeback to memory is executed with mem_we=1 and data=0xCAFEBABE.
//      - Fills Way-0 with addr C.
//   4. Read addr A (0x0000_0000) -> miss in set 0 (Way-1 holding B is now LRU).
//      - Asserts Way-1 is selected as victim and written back with 0xFEEDFACE.
//      - Fills Way-0 with addr A from mem_model.
//      - Verifies read data returned for A is 0xCAFEBABE (data integrity preserved!).
// ============================================================================

`timescale 1ns/1ps

module tb_cache_2way_writeback;

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
    wire [127:0] mem_rdata;
    wire         mem_ready;

    always #5 clk = ~clk;

    // Cache top instantiation
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

    // Reusable memory model
    mem_model #(.LATENCY(3)) u_mem (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_addr  (mem_addr),
        .mem_re    (mem_re),
        .mem_we    (mem_we),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );

    // Monitor writebacks
    reg        wb_observed;
    reg [31:0] wb_addr_captured;
    reg [31:0] wb_word0_captured;

    always @(posedge clk) begin
        if (mem_we && mem_ready) begin
            wb_observed        <= 1'b1;
            wb_addr_captured   <= mem_addr;
            wb_word0_captured  <= mem_wdata[31:0];
        end
    end

    // Test tasks
    integer errors = 0;

    task do_write;
        input [31:0] addr;
        input [31:0] data;
        integer timeout;
        begin
            wb_observed = 1'b0;
            @(negedge clk);
            cpu_addr  = addr;
            cpu_wdata = data;
            cpu_we    = 1'b1;
            cpu_re    = 1'b0;
            @(negedge clk);
            cpu_we    = 1'b0;
            timeout   = 0;
            while (!cpu_ready && timeout < 200) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cpu_ready) begin
                $display("ERROR: Timeout on write to 0x%08h", addr);
                errors = errors + 1;
            end
        end
    endtask

    task do_read;
        input  [31:0] addr;
        output [31:0] data;
        integer timeout;
        begin
            wb_observed = 1'b0;
            @(negedge clk);
            cpu_addr  = addr;
            cpu_we    = 1'b0;
            cpu_re    = 1'b1;
            @(negedge clk);
            cpu_re    = 1'b0;
            timeout   = 0;
            while (!cpu_ready && timeout < 200) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cpu_ready) begin
                $display("ERROR: Timeout on read from 0x%08h", addr);
                errors = errors + 1;
            end
            data = cpu_rdata;
        end
    endtask

    reg [31:0] rdata_val;

    initial begin
        $dumpfile("tb_cache_2way_writeback.vcd");
        $dumpvars(0, tb_cache_2way_writeback);

        $display("");
        $display("==========================================================");
        $display("  2-Way Cache Write-Back & Eviction Consistency Test");
        $display("==========================================================");

        // Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // 1. Write Addr A (0x0000_0000) = 0xCAFEBABE
        $display("Step 1: Write Addr A (0x0000_0000) = 0xCAFEBABE");
        do_write(32'h0000_0000, 32'hCAFE_BABE);
        if (wb_observed) begin
            $display("  FAIL: Unexpected writeback during cold miss write");
            errors = errors + 1;
        end else begin
            $display("  PASS: Allocated in Way-0 (clean fill, marked dirty)");
        end

        // 2. Write Addr B (0x0000_0400) = 0xFEEDFACE
        $display("Step 2: Write Addr B (0x0000_0400) = 0xFEEDFACE");
        do_write(32'h0000_0400, 32'hFEED_FACE);
        if (wb_observed) begin
            $display("  FAIL: Unexpected writeback during Way-1 allocate");
            errors = errors + 1;
        end else begin
            $display("  PASS: Allocated in Way-1 (clean fill, marked dirty)");
        end

        // 3. Read Addr C (0x0000_0800) -> Both ways dirty, Way-0 is LRU victim
        $display("Step 3: Read Addr C (0x0000_0800) -> triggers eviction of dirty Way-0");
        do_read(32'h0000_0800, rdata_val);
        if (!wb_observed) begin
            $display("  FAIL: Expected writeback of Way-0 not observed!");
            errors = errors + 1;
        end else if (wb_addr_captured !== 32'h0000_0000 || wb_word0_captured !== 32'hCAFE_BABE) begin
            $display("  FAIL: WB data mismatch: addr=0x%08h (exp 0x0), data=0x%08h (exp 0xCAFEBABE)",
                     wb_addr_captured, wb_word0_captured);
            errors = errors + 1;
        end else begin
            $display("  PASS: Writeback of Way-0 verified (addr=0x%08h, data=0x%08h)",
                     wb_addr_captured, wb_word0_captured);
        end

        // 4. Read Addr A (0x0000_0000) -> Now Way-1 (holding B) is LRU and dirty!
        $display("Step 4: Read Addr A (0x0000_0000) -> triggers eviction of dirty Way-1");
        do_read(32'h0000_0000, rdata_val);
        if (!wb_observed) begin
            $display("  FAIL: Expected writeback of Way-1 not observed!");
            errors = errors + 1;
        end else if (wb_addr_captured !== 32'h0000_0400 || wb_word0_captured !== 32'hFEED_FACE) begin
            $display("  FAIL: WB data mismatch: addr=0x%08h (exp 0x400), data=0x%08h (exp 0xFEEDFACE)",
                     wb_addr_captured, wb_word0_captured);
            errors = errors + 1;
        end else begin
            $display("  PASS: Writeback of Way-1 verified (addr=0x%08h, data=0x%08h)",
                     wb_addr_captured, wb_word0_captured);
        end

        // Check data read back for Addr A matches modified data written in Step 1
        if (rdata_val !== 32'hCAFE_BABE) begin
            $display("  FAIL: Data read for A mismatch: got=0x%08h, expected 0xCAFEBABE", rdata_val);
            errors = errors + 1;
        end else begin
            $display("  PASS: Addr A fetched from memory contains written data (0xCAFEBABE)");
        end

        // Summary
        $display("");
        $display("==========================================================");
        if (errors == 0) begin
            $display("  ALL WRITEBACK AND DATA INTEGRITY CHECKS PASSED!");
        end else begin
            $display("  FAILED WITH %0d ERROR(S)", errors);
        end
        $display("==========================================================");
        $display("");

        #50;
        $finish;
    end

    // Watchdog
    initial begin
        #500_000;
        $display("TIMEOUT: Simulation hung");
        $finish;
    end

endmodule
