// tb_valid_lru.v
`timescale 1ns/1ps
module tb_valid_lru;

    // ── clock & reset ──────────────────────────────────────────────
    reg clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // ── lru_state DUT ──────────────────────────────────────────────
    reg [5:0] lru_set;
    reg       touch, touch_way;
    wire      lru_way;

    lru_state u_lru (
        .clk(clk), .rst_n(rst_n),
        .set_idx(lru_set), .touch(touch), .touch_way(touch_way),
        .lru_way(lru_way)
    );

    // ── valid_bits DUT ─────────────────────────────────────────────
    reg [5:0] vb_set;
    reg       set_way0, set_way1, clear_way0, clear_way1;
    wire      valid0, valid1;

    valid_bits u_vb (
        .clk(clk), .rst_n(rst_n),
        .set_idx(vb_set),
        .set_way0(set_way0), .set_way1(set_way1),
        .clear_way0(clear_way0), .clear_way1(clear_way1),
        .valid0(valid0), .valid1(valid1)
    );

    // ── helper task ────────────────────────────────────────────────
    integer pass_cnt, fail_cnt;

    task check;
        input        got, exp;
        input [63:0] id;
        begin
            if (got === exp) begin
                $display("  PASS [%0d]", id);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL [%0d]  got=%b  exp=%b", id, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ── stimulus ───────────────────────────────────────────────────
    initial begin
        pass_cnt = 0; fail_cnt = 0;
        {touch, touch_way, set_way0, set_way1, clear_way0, clear_way1} = 6'd0;
        lru_set = 6'd3; vb_set = 6'd3;

        // reset
        rst_n = 0; @(posedge clk); #1; rst_n = 1;

        // ── LRU tests ──────────────────────────────────────────────
        $display("--- LRU tests ---");

        // touch Way-0 → lru_way should become 1
        touch = 1; touch_way = 0; @(posedge clk); #1; touch = 0;
        check(lru_way, 1'b1, 1);   // lru_way == 1 (Way-1 is LRU)

        // touch Way-0 again → lru_way stays 1
        touch = 1; touch_way = 0; @(posedge clk); #1; touch = 0;
        check(lru_way, 1'b1, 2);

        // touch Way-1 → lru_way becomes 0
        touch = 1; touch_way = 1; @(posedge clk); #1; touch = 0;
        check(lru_way, 1'b0, 3);   // lru_way == 0 (Way-0 is LRU)

        // ── valid_bits tests ───────────────────────────────────────
        $display("--- valid_bits tests ---");

        // set Way-0 for set 3 → valid0=1, valid1=0
        set_way0 = 1; @(posedge clk); #1; set_way0 = 0;
        check(valid0, 1'b1, 4);
        check(valid1, 1'b0, 5);

        // set Way-1 for set 3 → valid1=1, valid0 still 1
        set_way1 = 1; @(posedge clk); #1; set_way1 = 0;
        check(valid1, 1'b1, 6);
        check(valid0, 1'b1, 7);

        // ── summary ────────────────────────────────────────────────
        $display("--- Result: %0d PASS, %0d FAIL ---", pass_cnt, fail_cnt);
        $finish;
    end
endmodule
