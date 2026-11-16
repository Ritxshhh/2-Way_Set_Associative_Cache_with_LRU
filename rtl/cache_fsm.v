// cache_fsm.v
// Controller FSM for the 2-way set-associative cache (64 sets x 2 ways, 16 B lines).
//
// Address breakdown (ADDR_W = 32):
//   tag      = addr[31:10]  (22 bits)
//   index    = addr[9:4]    (6 bits)
//   word_sel = addr[3:2]    (word within the 4-word line)
//
// The FSM owns the per-way dirty bits (way0_dirty / way1_dirty, one bit per set);
// every other piece of per-set state lives in the submodules it drives.
// All outputs except the registered internal state are Moore outputs decoded
// from the current state, so each state takes effect on one clock edge.

`timescale 1ns/1ps

module cache_fsm #(
    parameter ADDR_W   = 32,
    parameter SETS     = 64,
    parameter INDEX_W  = 6,
    parameter TAG_W    = 22,
    parameter OFFSET_W = 4
) (
    input  wire               clk,
    input  wire               rst_n,

    // CPU side
    input  wire [ADDR_W-1:0]  cpu_addr,
    input  wire [31:0]        cpu_wdata,
    input  wire               cpu_we,
    input  wire               cpu_re,
    output reg  [31:0]        cpu_rdata,
    output reg                cpu_ready,

    // Main-memory side
    output reg  [ADDR_W-1:0]  mem_addr,
    output reg                mem_re,
    output reg                mem_we,
    output reg  [127:0]       mem_wdata,
    input  wire [127:0]       mem_rdata,
    input  wire               mem_ready,

    // Shared index for every per-set structure
    output wire [INDEX_W-1:0] index,

    // Way-0 / Way-1 data RAMs
    input  wire [127:0]       way0_rdata,
    input  wire [127:0]       way1_rdata,
    output reg  [3:0]         way0_word_we,
    output reg  [3:0]         way1_word_we,
    output reg  [127:0]       data_wdata,

    // Way-0 / Way-1 tag RAMs
    input  wire [TAG_W-1:0]   way0_tag,
    input  wire [TAG_W-1:0]   way1_tag,
    output reg                way0_tag_we,
    output reg                way1_tag_we,
    output wire [TAG_W-1:0]   wtag,

    // Valid bits
    input  wire               valid0,
    input  wire               valid1,
    output reg                set_valid,
    output reg                set_valid_way,

    // LRU state
    input  wire               lru_way,
    output reg                touch,
    output reg                touch_way,

    // Tag comparator
    output wire [TAG_W-1:0]   cmp_tag,
    input  wire               hit,
    input  wire               hit_way
);

    localparam [4:0] IDLE          = 5'd0,
                     TAG_CHECK     = 5'd1,
                     HIT           = 5'd2,
                     SELECT_VICTIM = 5'd3,
                     WRITE_BACK    = 5'd4,
                     FETCH_BLOCK   = 5'd5,
                     FILL_WAY      = 5'd6;

    reg [4:0]        state;
    reg [ADDR_W-1:0] addr_q;       // latched request address
    reg [31:0]       wdata_q;      // latched store data
    reg              is_write;     // latched request type
    reg              hit_way_q;
    reg              victim_way;
    reg [127:0]      fill_line;    // block latched from mem_rdata
    reg [SETS-1:0]   way0_dirty;
    reg [SETS-1:0]   way1_dirty;

    wire [TAG_W-1:0] tag      = addr_q[ADDR_W-1 -: TAG_W];
    wire [1:0]       word_sel = addr_q[3:2];

    assign index   = addr_q[OFFSET_W +: INDEX_W];
    assign wtag    = tag;
    assign cmp_tag = tag;

    wire [127:0]     hit_line    = hit_way_q  ? way1_rdata : way0_rdata;
    wire [127:0]     victim_line = victim_way ? way1_rdata : way0_rdata;
    wire [TAG_W-1:0] victim_tag  = victim_way ? way1_tag   : way0_tag;
    wire             lru_valid   = lru_way    ? valid1     : valid0;
    wire             lru_dirty   = lru_way    ? way1_dirty[index] : way0_dirty[index];

    // ------------------------------------------------------------------
    // State register and internal registers
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            addr_q     <= {ADDR_W{1'b0}};
            wdata_q    <= 32'd0;
            is_write   <= 1'b0;
            hit_way_q  <= 1'b0;
            victim_way <= 1'b0;
            fill_line  <= 128'd0;
            way0_dirty <= {SETS{1'b0}};
            way1_dirty <= {SETS{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_re || cpu_we) begin
                        addr_q   <= cpu_addr;
                        wdata_q  <= cpu_wdata;
                        is_write <= cpu_we;
                        state    <= TAG_CHECK;
                    end
                end

                TAG_CHECK: begin
                    if (hit) begin
                        hit_way_q <= hit_way;
                        state     <= HIT;
                    end else begin
                        state     <= SELECT_VICTIM;
                    end
                end

                HIT: begin
                    if (is_write) begin
                        if (hit_way_q) way1_dirty[index] <= 1'b1;
                        else           way0_dirty[index] <= 1'b1;
                    end
                    state <= IDLE;
                end

                SELECT_VICTIM: begin
                    victim_way <= lru_way;
                    if (!lru_valid)
                        state <= FETCH_BLOCK;
                    else if (lru_dirty)
                        state <= WRITE_BACK;
                    else
                        state <= FETCH_BLOCK;
                end

                WRITE_BACK: begin
                    if (mem_ready) begin
                        if (victim_way) way1_dirty[index] <= 1'b0;
                        else            way0_dirty[index] <= 1'b0;
                        state <= FETCH_BLOCK;
                    end
                end

                FETCH_BLOCK: begin
                    if (mem_ready) begin
                        fill_line <= mem_rdata;
                        state     <= FILL_WAY;
                    end
                end

                FILL_WAY: begin
                    // Clean on fill-from-read, dirty on fill-from-write.
                    if (victim_way) way1_dirty[index] <= is_write;
                    else            way0_dirty[index] <= is_write;
                    state <= TAG_CHECK;     // retry; this will now hit
                end

                default: state <= IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Moore outputs
    // ------------------------------------------------------------------
    always @(*) begin
        cpu_rdata     = 32'd0;
        cpu_ready     = 1'b0;
        mem_addr      = {ADDR_W{1'b0}};
        mem_re        = 1'b0;
        mem_we        = 1'b0;
        mem_wdata     = 128'd0;
        way0_word_we  = 4'b0000;
        way1_word_we  = 4'b0000;
        data_wdata    = 128'd0;
        way0_tag_we   = 1'b0;
        way1_tag_we   = 1'b0;
        set_valid     = 1'b0;
        set_valid_way = 1'b0;
        touch         = 1'b0;
        touch_way     = 1'b0;

        case (state)
            HIT: begin
                if (is_write) begin
                    data_wdata = {4{wdata_q}};
                    if (hit_way_q) way1_word_we = 4'b0001 << word_sel;
                    else           way0_word_we = 4'b0001 << word_sel;
                end else begin
                    cpu_rdata = hit_line[word_sel*32 +: 32];
                end
                touch     = 1'b1;
                touch_way = hit_way_q;
                cpu_ready = 1'b1;
            end

            WRITE_BACK: begin
                mem_addr  = {victim_tag, index, {OFFSET_W{1'b0}}};
                mem_wdata = victim_line;
                mem_we    = 1'b1;
            end

            FETCH_BLOCK: begin
                mem_addr = {tag, index, {OFFSET_W{1'b0}}};
                mem_re   = 1'b1;
            end

            FILL_WAY: begin
                data_wdata = fill_line;
                if (victim_way) begin
                    way1_word_we = 4'b1111;
                    way1_tag_we  = 1'b1;
                end else begin
                    way0_word_we = 4'b1111;
                    way0_tag_we  = 1'b1;
                end
                set_valid     = 1'b1;
                set_valid_way = victim_way;
                touch         = 1'b1;
                touch_way     = victim_way;   // just-filled way becomes MRU
            end

            default: ;
        endcase
    end

endmodule
