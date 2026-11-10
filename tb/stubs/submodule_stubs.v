// submodule_stubs.v
// TEMPORARY placeholder models of the submodules cache_2way_top instantiates,
// written only so cache_fsm / cache_2way_top can be simulated before the owning
// members push their RTL. They define the port interface cache_2way_top expects.
//
// Delete (or stop compiling) this file once the real rtl/way_data_ram.v,
// rtl/way_tag_ram.v, rtl/valid_bits.v, rtl/lru_state.v and rtl/tag_comparator.v
// exist -- compiling both will give duplicate-module errors.

// One way's data storage: SETS lines x 128 bits, async read, per-word write enable.
module way_data_ram #(
    parameter SETS    = 64,
    parameter INDEX_W = 6
) (
    input  wire               clk,
    input  wire [INDEX_W-1:0] index,
    input  wire [3:0]         word_we,
    input  wire [127:0]       wdata,
    output wire [127:0]       rdata
);
    reg [127:0] mem [0:SETS-1];
    integer i;
    initial for (i = 0; i < SETS; i = i + 1) mem[i] = 128'd0;

    always @(posedge clk) begin
        if (word_we[0]) mem[index][ 31: 0] <= wdata[ 31: 0];
        if (word_we[1]) mem[index][ 63:32] <= wdata[ 63:32];
        if (word_we[2]) mem[index][ 95:64] <= wdata[ 95:64];
        if (word_we[3]) mem[index][127:96] <= wdata[127:96];
    end

    assign rdata = mem[index];
endmodule

// One way's tag storage: SETS x TAG_W, async read.
module way_tag_ram #(
    parameter SETS    = 64,
    parameter INDEX_W = 6,
    parameter TAG_W   = 22
) (
    input  wire               clk,
    input  wire [INDEX_W-1:0] index,
    input  wire               we,
    input  wire [TAG_W-1:0]   wtag,
    output wire [TAG_W-1:0]   rtag
);
    reg [TAG_W-1:0] mem [0:SETS-1];
    integer i;
    initial for (i = 0; i < SETS; i = i + 1) mem[i] = {TAG_W{1'b0}};

    always @(posedge clk)
        if (we) mem[index] <= wtag;

    assign rtag = mem[index];
endmodule

// Two valid bits per set, cleared on reset.
module valid_bits #(
    parameter SETS    = 64,
    parameter INDEX_W = 6
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire [INDEX_W-1:0] index,
    input  wire               set_valid,
    input  wire               set_way,
    output wire               valid0,
    output wire               valid1
);
    reg [SETS-1:0] v0, v1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v0 <= {SETS{1'b0}};
            v1 <= {SETS{1'b0}};
        end else if (set_valid) begin
            if (set_way) v1[index] <= 1'b1;
            else         v0[index] <= 1'b1;
        end
    end

    assign valid0 = v0[index];
    assign valid1 = v1[index];
endmodule

// One LRU bit per set; lru_way names the least-recently-used way.
// Touching way w makes it MRU, so the LRU bit becomes ~w. Resets to 0 (Way-0 LRU).
module lru_state #(
    parameter SETS    = 64,
    parameter INDEX_W = 6
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire [INDEX_W-1:0] index,
    input  wire               touch,
    input  wire               touch_way,
    output wire               lru_way
);
    reg [SETS-1:0] lru;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     lru <= {SETS{1'b0}};
        else if (touch) lru[index] <= ~touch_way;
    end

    assign lru_way = lru[index];
endmodule

// Compares the request tag against both ways; Way-0 wins if both match.
module tag_comparator #(
    parameter TAG_W = 22
) (
    input  wire [TAG_W-1:0] tag,
    input  wire [TAG_W-1:0] way0_tag,
    input  wire [TAG_W-1:0] way1_tag,
    input  wire             valid0,
    input  wire             valid1,
    output wire             hit,
    output wire             hit_way
);
    wire hit0 = valid0 && (way0_tag == tag);
    wire hit1 = valid1 && (way1_tag == tag);

    assign hit     = hit0 | hit1;
    assign hit_way = ~hit0 & hit1;
endmodule
