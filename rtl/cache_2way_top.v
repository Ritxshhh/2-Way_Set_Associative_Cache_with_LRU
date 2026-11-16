// cache_2way_top.v
// Top-level 2-way set-associative cache with 1-bit-per-set LRU replacement.
// 64 sets x 2 ways x 16 B lines = 2 KB of data.
//
// Port list is identical in shape to direct_mapped_cache so both caches can be
// dropped into the same testbench.
//
// Structure:
//   way_data_ram  x2  (Way-0, Way-1)   128-bit lines, per-word write enables
//   way_tag_ram   x2  (Way-0, Way-1)   22-bit tags
//   valid_bits    x1                   2 valid bits per set
//   lru_state     x1                   1 LRU bit per set
//   tag_comparator x1                  hit / hit_way
//   cache_fsm     x1                   controller (also holds the dirty bits)

`timescale 1ns/1ps

module cache_2way_top #(
    parameter ADDR_W   = 32,
    parameter SETS     = 64,
    parameter INDEX_W  = 6,
    parameter TAG_W    = 22,
    parameter OFFSET_W = 4
) (
    input  wire               clk,
    input  wire               rst_n,

    input  wire [31:0]        cpu_addr,
    input  wire [31:0]        cpu_wdata,
    input  wire               cpu_we,
    input  wire               cpu_re,
    output reg  [31:0]        cpu_rdata,
    output reg                cpu_ready,

    output reg  [31:0]        mem_addr,
    output reg                mem_re,
    output reg                mem_we,
    output reg  [127:0]       mem_wdata,
    input  wire [127:0]       mem_rdata,
    input  wire               mem_ready
);

    wire [INDEX_W-1:0] index;

    wire [127:0]       way0_rdata, way1_rdata;
    wire [3:0]         way0_word_we, way1_word_we;
    wire [127:0]       data_wdata;

    wire [TAG_W-1:0]   way0_tag, way1_tag;
    wire               way0_tag_we, way1_tag_we;
    wire [TAG_W-1:0]   wtag;

    wire               valid0, valid1;
    wire               set_valid, set_valid_way;

    wire               lru_way;
    wire               touch, touch_way;

    wire [TAG_W-1:0]   cmp_tag;
    wire               hit, hit_way;

    wire [31:0]        fsm_cpu_rdata;
    wire               fsm_cpu_ready;
    wire [31:0]        fsm_mem_addr;
    wire               fsm_mem_re, fsm_mem_we;
    wire [127:0]       fsm_mem_wdata;

    // ------------------------------------------------------------------
    // Way-0 / Way-1 storage
    // ------------------------------------------------------------------
    way_data_ram #(.SETS(SETS), .INDEX_W(INDEX_W)) u_way0_data (
        .clk     (clk),
        .set_idx (index),
        .we      (|way0_word_we),
        .word_we (way0_word_we),
        .wdata   (data_wdata),
        .rdata   (way0_rdata)
    );

    way_data_ram #(.SETS(SETS), .INDEX_W(INDEX_W)) u_way1_data (
        .clk     (clk),
        .set_idx (index),
        .we      (|way1_word_we),
        .word_we (way1_word_we),
        .wdata   (data_wdata),
        .rdata   (way1_rdata)
    );

    way_tag_ram #(.SETS(SETS), .INDEX_W(INDEX_W), .TAG_W(TAG_W)) u_way0_tag (
        .clk   (clk),
        .set_idx (index),
        .we    (way0_tag_we),
        .wtag  (wtag),
        .rtag  (way0_tag)
    );

    way_tag_ram #(.SETS(SETS), .INDEX_W(INDEX_W), .TAG_W(TAG_W)) u_way1_tag (
        .clk   (clk),
        .set_idx (index),
        .we    (way1_tag_we),
        .wtag  (wtag),
        .rtag  (way1_tag)
    );

    // ------------------------------------------------------------------
    // Per-set bookkeeping
    // ------------------------------------------------------------------
    valid_bits u_valid (
        .clk       (clk),
        .rst_n     (rst_n),
        .set_idx   (index),
        .set_way0  (set_valid && !set_valid_way),
        .set_way1  (set_valid && set_valid_way),
        .clear_way0(1'b0),
        .clear_way1(1'b0),
        .valid0    (valid0),
        .valid1    (valid1)
    );

    lru_state u_lru (
        .clk       (clk),
        .rst_n     (rst_n),
        .set_idx   (index),
        .touch     (touch),
        .touch_way (touch_way),
        .lru_way   (lru_way)
    );

    tag_comparator u_cmp (
        .addr_tag (cmp_tag),
        .way0_tag (way0_tag),
        .way1_tag (way1_tag),
        .valid0   (valid0),
        .valid1   (valid1),
        .way0_hit (),           // per-way hits unused; FSM needs hit/hit_way only
        .way1_hit (),
        .hit      (hit),
        .hit_way  (hit_way)
    );

    // ------------------------------------------------------------------
    // Controller
    // ------------------------------------------------------------------
    cache_fsm #(
        .ADDR_W(ADDR_W), .SETS(SETS), .INDEX_W(INDEX_W),
        .TAG_W(TAG_W), .OFFSET_W(OFFSET_W)
    ) u_fsm (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_addr      (cpu_addr),
        .cpu_wdata     (cpu_wdata),
        .cpu_we        (cpu_we),
        .cpu_re        (cpu_re),
        .cpu_rdata     (fsm_cpu_rdata),
        .cpu_ready     (fsm_cpu_ready),
        .mem_addr      (fsm_mem_addr),
        .mem_re        (fsm_mem_re),
        .mem_we        (fsm_mem_we),
        .mem_wdata     (fsm_mem_wdata),
        .mem_rdata     (mem_rdata),
        .mem_ready     (mem_ready),
        .index         (index),
        .way0_rdata    (way0_rdata),
        .way1_rdata    (way1_rdata),
        .way0_word_we  (way0_word_we),
        .way1_word_we  (way1_word_we),
        .data_wdata    (data_wdata),
        .way0_tag      (way0_tag),
        .way1_tag      (way1_tag),
        .way0_tag_we   (way0_tag_we),
        .way1_tag_we   (way1_tag_we),
        .wtag          (wtag),
        .valid0        (valid0),
        .valid1        (valid1),
        .set_valid     (set_valid),
        .set_valid_way (set_valid_way),
        .lru_way       (lru_way),
        .touch         (touch),
        .touch_way     (touch_way),
        .cmp_tag       (cmp_tag),
        .hit           (hit),
        .hit_way       (hit_way)
    );

    // Drive the reg-typed top-level ports from the FSM's outputs.
    always @(*) begin
        cpu_rdata = fsm_cpu_rdata;
        cpu_ready = fsm_cpu_ready;
        mem_addr  = fsm_mem_addr;
        mem_re    = fsm_mem_re;
        mem_we    = fsm_mem_we;
        mem_wdata = fsm_mem_wdata;
    end

endmodule
