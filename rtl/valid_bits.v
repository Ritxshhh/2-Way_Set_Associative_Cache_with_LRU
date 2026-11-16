// valid_bits.v
// Two valid bits per set (Way-0, Way-1), 64 sets.
`timescale 1ns/1ps

module valid_bits (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [5:0]  set_idx,
    input  wire        set_way0,
    input  wire        set_way1,
    input  wire        clear_way0,
    input  wire        clear_way1,
    output wire        valid0,
    output wire        valid1
);
    reg [63:0] way0_valid, way1_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            way0_valid <= 64'd0;
            way1_valid <= 64'd0;
        end else begin
            if (set_way0)   way0_valid[set_idx] <= 1'b1;
            if (clear_way0) way0_valid[set_idx] <= 1'b0;
            if (set_way1)   way1_valid[set_idx] <= 1'b1;
            if (clear_way1) way1_valid[set_idx] <= 1'b0;
        end
    end

    assign valid0 = way0_valid[set_idx];
    assign valid1 = way1_valid[set_idx];
endmodule
