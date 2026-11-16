// One way; defaults implement 64 sets of four 32-bit words.
`timescale 1ns/1ps

module way_data_ram #(
    parameter SETS = 64,
    parameter INDEX_W = 6
) (
    input wire clk,
    input wire we,
    input wire [3:0] word_we,
    input wire [INDEX_W-1:0] set_idx,
    input wire [127:0] wdata,
    output wire [127:0] rdata
);
    reg [127:0] mem [0:SETS-1];
    assign rdata = mem[set_idx];
    always @(posedge clk) begin
        if (we) begin
            if (word_we[0]) mem[set_idx][31:0] <= wdata[31:0];
            if (word_we[1]) mem[set_idx][63:32] <= wdata[63:32];
            if (word_we[2]) mem[set_idx][95:64] <= wdata[95:64];
            if (word_we[3]) mem[set_idx][127:96] <= wdata[127:96];
        end
    end
endmodule
