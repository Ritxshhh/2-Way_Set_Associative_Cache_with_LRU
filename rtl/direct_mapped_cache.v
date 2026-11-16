// ============================================================================
// Module:  direct_mapped_cache
// File:    rtl/direct_mapped_cache.v
//
// Direct-mapped, write-back cache with 128 lines, each holding a 128-bit
// (4-word) block.  Uses a 6-state FSM:  IDLE → TAG_CHECK → HIT  (hit path)
// or  TAG_CHECK → [WRITE_BACK →] FETCH_BLOCK → FILL_LINE → TAG_CHECK  (miss).
//
// Address breakdown (32-bit word-aligned):
//   tag       = addr[31:11]   (21 bits)
//   index     = addr[10:4]    ( 7 bits, selects 1 of 128 lines)
//   word_sel  = addr[ 3:2]    ( 2 bits, selects 1 of 4 words in the line)
//   addr[1:0] = 00            (word-aligned)
// ============================================================================

`timescale 1ns/1ps

module direct_mapped_cache #(
    parameter ADDR_W    = 32,
    parameter NUM_LINES = 128,
    parameter INDEX_W   = 7,
    parameter TAG_W     = 21,
    parameter OFFSET_W  = 4
)(
    input                clk,
    input                rst_n,

    // ---- CPU-side interface ----
    input  [31:0]        cpu_addr,
    input  [31:0]        cpu_wdata,
    input                cpu_we,
    input                cpu_re,
    output reg [31:0]    cpu_rdata,
    output reg           cpu_ready,

    // ---- Memory-side interface ----
    output reg [31:0]    mem_addr,
    output reg           mem_re,
    output reg           mem_we,
    output reg [127:0]   mem_wdata,
    input  [127:0]       mem_rdata,
    input                mem_ready
);

    // ----------------------------------------------------------------
    // FSM state encodings (3-bit)
    // ----------------------------------------------------------------
    localparam IDLE        = 3'd0;
    localparam TAG_CHECK   = 3'd1;
    localparam HIT         = 3'd2;
    localparam WRITE_BACK  = 3'd3;
    localparam FETCH_BLOCK = 3'd4;
    localparam FILL_LINE   = 3'd5;

    reg [2:0] state;

    // ----------------------------------------------------------------
    // Internal storage arrays  (128 entries, indexed by `index`)
    // ----------------------------------------------------------------
    reg [127:0] data_mem  [0:127];
    reg [20:0]  tag_mem   [0:127];
    reg         valid_mem [0:127];
    reg         dirty_mem [0:127];

    // ----------------------------------------------------------------
    // Latched request signals
    // ----------------------------------------------------------------
    reg [31:0]  addr_reg;       // latched cpu_addr
    reg         we_reg;         // latched cpu_we
    reg [31:0]  wdata_reg;      // latched cpu_wdata
    reg [127:0] mem_rdata_reg;  // latched block from memory

    // ----------------------------------------------------------------
    // Address field extraction (from latched address)
    // ----------------------------------------------------------------
    wire [TAG_W-1:0]   tag      = addr_reg[ADDR_W-1 : ADDR_W-TAG_W];  // [31:11]
    wire [INDEX_W-1:0] index    = addr_reg[ADDR_W-TAG_W-1 : OFFSET_W]; // [10:4]
    wire [1:0]         word_sel = addr_reg[3:2];

    // ----------------------------------------------------------------
    // Hit detection
    // ----------------------------------------------------------------
    wire hit = valid_mem[index] && (tag_mem[index] == tag);

    // ----------------------------------------------------------------
    // Main sequential logic
    // ----------------------------------------------------------------
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            cpu_rdata     <= 32'd0;
            cpu_ready     <= 1'b0;
            mem_addr      <= 32'd0;
            mem_re        <= 1'b0;
            mem_we        <= 1'b0;
            mem_wdata     <= 128'd0;
            addr_reg      <= 32'd0;
            we_reg        <= 1'b0;
            wdata_reg     <= 32'd0;
            mem_rdata_reg <= 128'd0;
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                data_mem[i]  <= 128'd0;
                tag_mem[i]   <= 21'd0;
                valid_mem[i] <= 1'b0;
                dirty_mem[i] <= 1'b0;
            end
        end else begin
            case (state)
                // --------------------------------------------------
                // IDLE – wait for a CPU request
                // --------------------------------------------------
                IDLE: begin
                    cpu_ready <= 1'b0;
                    if (cpu_re || cpu_we) begin
                        addr_reg  <= cpu_addr;
                        we_reg    <= cpu_we;
                        wdata_reg <= cpu_wdata;
                        state     <= TAG_CHECK;
                    end
                end

                // --------------------------------------------------
                // TAG_CHECK – compare stored tag with requested tag
                // --------------------------------------------------
                TAG_CHECK: begin
                    if (hit)
                        state <= HIT;
                    else if (valid_mem[index] && dirty_mem[index])
                        state <= WRITE_BACK;
                    else
                        state <= FETCH_BLOCK;
                end

                // --------------------------------------------------
                // HIT – serve the request from the cache
                // --------------------------------------------------
                HIT: begin
                    if (we_reg) begin
                        // Write: update only the selected 32-bit word
                        case (word_sel)
                            2'd0: data_mem[index][31:0]   <= wdata_reg;
                            2'd1: data_mem[index][63:32]  <= wdata_reg;
                            2'd2: data_mem[index][95:64]  <= wdata_reg;
                            2'd3: data_mem[index][127:96] <= wdata_reg;
                        endcase
                        dirty_mem[index] <= 1'b1;
                    end else begin
                        // Read: return the selected word
                        case (word_sel)
                            2'd0: cpu_rdata <= data_mem[index][31:0];
                            2'd1: cpu_rdata <= data_mem[index][63:32];
                            2'd2: cpu_rdata <= data_mem[index][95:64];
                            2'd3: cpu_rdata <= data_mem[index][127:96];
                        endcase
                    end
                    cpu_ready <= 1'b1;
                    state     <= IDLE;
                end

                // --------------------------------------------------
                // WRITE_BACK – flush dirty line to memory
                // --------------------------------------------------
                WRITE_BACK: begin
                    mem_addr  <= {tag_mem[index], index, 4'b0000};
                    mem_wdata <= data_mem[index];
                    mem_we    <= 1'b1;
                    if (mem_ready) begin
                        mem_we <= 1'b0;
                        state  <= FETCH_BLOCK;
                    end
                end

                // --------------------------------------------------
                // FETCH_BLOCK – read the required block from memory
                // --------------------------------------------------
                FETCH_BLOCK: begin
                    mem_addr <= {tag, index, 4'b0000};
                    mem_re   <= 1'b1;
                    if (mem_ready) begin
                        mem_rdata_reg <= mem_rdata;
                        mem_re        <= 1'b0;
                        state         <= FILL_LINE;
                    end
                end

                // --------------------------------------------------
                // FILL_LINE – install fetched block, then retry
                // --------------------------------------------------
                FILL_LINE: begin
                    data_mem[index]  <= mem_rdata_reg;
                    tag_mem[index]   <= tag;
                    valid_mem[index] <= 1'b1;
                    dirty_mem[index] <= 1'b0;
                    state            <= TAG_CHECK;   // retry → will now hit
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

