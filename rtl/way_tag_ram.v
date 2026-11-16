// One way's tags; contents become meaningful when its valid bit is set.
`timescale 1ns/1ps

module way_tag_ram #(
    parameter SETS = 64,
    parameter INDEX_W = 6,
    parameter TAG_W = 22
) (
    input wire clk,
    input wire we,
    input wire [INDEX_W-1:0] set_idx,
    input wire [TAG_W-1:0] wtag,
    output wire [TAG_W-1:0] rtag
);
    reg [TAG_W-1:0] mem [0:SETS-1];
    assign rtag = mem[set_idx];
    always @(posedge clk)
        if (we) mem[set_idx] <= wtag;
endmodule
