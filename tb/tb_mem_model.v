`timescale 1ns/1ps
module tb_mem_model;
    parameter LATENCY=6;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, mem_re=0, mem_we=0;
    reg [31:0] mem_addr=0;
    reg [127:0] mem_wdata=0;
    wire [127:0] mem_rdata;
    wire mem_ready;
    localparam [127:0] WRITTEN=128'h01234567_89ABCDEF_FEDCBA98_76543210;
    mem_model #(.LATENCY(LATENCY)) dut(clk,rst_n,mem_addr,mem_re,mem_we,mem_wdata,mem_rdata,mem_ready);
    task transaction;
        input writing;
        input [31:0] addr;
        input [127:0] data;
        input [127:0] expected;
        integer cycles;
        begin
            @(negedge clk); mem_addr=addr; mem_we=writing; mem_re=!writing; mem_wdata=data;
            @(posedge clk); #1;
            if (mem_ready !== 0) $fatal(1,"ready on acceptance edge");
            @(negedge clk); mem_re=0; mem_we=0; mem_addr=32'h90; mem_wdata=0;
            for (cycles=1; cycles<=LATENCY; cycles=cycles+1) begin
                @(posedge clk); #1;
                if (mem_ready !== (cycles==LATENCY))
                    $fatal(1,"FAIL latency: cycle %0d ready=%b",cycles,mem_ready);
            end
            $display("PASS %0s ready exactly %0d cycles after acceptance",writing ? "write" : "read",LATENCY);
            if (!writing) begin
                if (mem_rdata !== expected) $fatal(1,"FAIL read: got %h expected %h",mem_rdata,expected);
                $display("PASS read data %h (latched block address)",mem_rdata);
            end
            @(posedge clk); #1;
            if (mem_ready !== 0) $fatal(1,"FAIL ready pulse width");
            $display("PASS ready pulse lasts one cycle");
        end
    endtask
    initial begin
        repeat (2) @(negedge clk);
        if (mem_ready !== 0 || mem_rdata !== 0) $fatal(1,"reset outputs");
        rst_n=1;
        transaction(0,32'h12B,0,{4{32'hA5A50012}});
        transaction(1,32'h12F,WRITTEN,0);
        transaction(0,32'h120,0,WRITTEN);
        $display("PASS tb_mem_model: all checks LATENCY=%0d",LATENCY); $finish;
    end
    initial begin #10000; $fatal(1,"timeout"); end
endmodule
