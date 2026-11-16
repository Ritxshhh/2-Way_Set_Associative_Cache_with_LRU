// lru_state.v
// One LRU bit per set, 64 sets.
// lru_bit[set]==0 → Way-0 is LRU (evict next); ==1 → Way-1 is LRU.
`timescale 1ns/1ps

module lru_state (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [5:0]  set_idx,
    input  wire        touch,
    input  wire        touch_way,
    output wire        lru_way
);
    reg [63:0] lru_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     lru_bit <= 64'd0;
        else if (touch) lru_bit[set_idx] <= ~touch_way;
    end

    assign lru_way = lru_bit[set_idx];
endmodule
