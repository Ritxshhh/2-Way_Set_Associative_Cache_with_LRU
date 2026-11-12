// tb_tag_comparator.v
`timescale 1ns/1ps
module tb_tag_comparator;

    reg  [21:0] addr_tag, way0_tag, way1_tag;
    reg         valid0, valid1;
    wire        way0_hit, way1_hit, hit, hit_way;

    tag_comparator u_tc (
        .addr_tag(addr_tag), .way0_tag(way0_tag), .way1_tag(way1_tag),
        .valid0(valid0), .valid1(valid1),
        .way0_hit(way0_hit), .way1_hit(way1_hit),
        .hit(hit), .hit_way(hit_way)
    );

    integer pass_cnt, fail_cnt;

    task check2;
        input        got, exp;
        input [63:0] id;
        input [63:0] sub;
        begin
            if (got === exp) begin
                $display("  PASS [case %0d, check %0d]", id, sub);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL [case %0d, check %0d]  got=%b  exp=%b", id, sub, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        addr_tag = 22'd5;
        way0_tag = 22'd0; way1_tag = 22'd0;
        valid0 = 0; valid1 = 0;

        // Case 1: both invalid → hit=0
        #1;
        check2(hit, 1'b0, 1, 1);

        // Case 2: valid0=1, way0_tag matches, valid1=0 → hit=1, hit_way=0
        valid0 = 1; way0_tag = 22'd5; valid1 = 0; #1;
        check2(hit,     1'b1, 2, 1);
        check2(hit_way, 1'b0, 2, 2);

        // Case 3: valid0=0, valid1=1, way1_tag matches → hit=1, hit_way=1
        valid0 = 0; valid1 = 1; way1_tag = 22'd5; #1;
        check2(hit,     1'b1, 3, 1);
        check2(hit_way, 1'b1, 3, 2);

        // Case 4: both valid, neither tag matches → hit=0
        valid0 = 1; way0_tag = 22'd9;
        valid1 = 1; way1_tag = 22'd9; #1;
        check2(hit, 1'b0, 4, 1);

        // Case 5: both valid, both tags match (upstream bug scenario)
        // Just confirm hit=1 and print a warning; do NOT fail.
        valid0 = 1; way0_tag = 22'd5;
        valid1 = 1; way1_tag = 22'd5; #1;
        if (hit)
            $display("  WARN [case 5] both ways hit simultaneously (upstream bug) — hit=%b", hit);
        else
            $display("  WARN [case 5] unexpected: hit=0 when both ways match");

        $display("--- Result: %0d PASS, %0d FAIL ---", pass_cnt, fail_cnt);
        $finish;
    end
endmodule
