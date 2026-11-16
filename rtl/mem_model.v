// Behavioral memory: request accepted at edge N, ready at edge N+LATENCY.
// Supported byte addresses: 0x00000000..0x0000ffff. Low four bits ignored.
// Requests while busy/acknowledging are ignored. Drop strobes after acceptance.
// If both strobes are asserted, write takes priority.
`timescale 1ns/1ps

module mem_model #(parameter LATENCY = 6) (
    input wire clk,
    input wire rst_n,
    input wire [31:0] mem_addr,
    input wire mem_re,
    input wire mem_we,
    input wire [127:0] mem_wdata,
    output reg [127:0] mem_rdata,
    output reg mem_ready
);
    reg [127:0] backing [0:4095];
    reg busy, pending_write;
    reg [27:0] block_addr;
    reg [127:0] write_data;
    integer remaining;
    integer i;
    initial begin
        if (LATENCY < 1) $fatal(1, "LATENCY must be positive");
        for (i = 0; i < 4096; i = i + 1)
            backing[i] = {4{16'hA5A5, i[15:0]}};
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            mem_ready <= 0;
            mem_rdata <= 0;
            remaining <= 0;
            pending_write <= 0;
            block_addr <= 0;
            write_data <= 0;
        end else begin
            mem_ready <= 0;
            if (busy) begin
                if (remaining == 1) begin
                    if (pending_write) backing[block_addr] <= write_data;
                    else mem_rdata <= backing[block_addr];
                    mem_ready <= 1;
                    busy <= 0;
                    remaining <= 0;
                end else remaining <= remaining - 1;
            end else if (!mem_ready && (mem_re || mem_we)) begin
                if (mem_addr[31:4] > 4095)
                    $fatal(1, "Memory address outside 4096-block backing store");
                block_addr <= mem_addr[31:4];
                pending_write <= mem_we;
                write_data <= mem_wdata;
                remaining <= LATENCY;
                busy <= 1;
            end
        end
    end
endmodule
