`timescale 1ns/1ps
module tb_way_ram;
    reg clk=0;
    always #5 clk=~clk;
    reg we=0, tag_we=0;
    reg [3:0] word_we=0;
    reg [5:0] set_idx=0;
    reg [127:0] wdata=0;
    reg [21:0] wtag=0;
    wire [127:0] rdata;
    wire [21:0] rtag;
    localparam [127:0] LINE0=128'hCAFE_0000_0000_0000_0000_0000_0000_0000;
    localparam [127:0] LINE5=128'h11112222_33334444_55556666_77778888;
    way_data_ram data_ram(clk,we,word_we,set_idx,wdata,rdata);
    way_tag_ram tag_ram(clk,tag_we,set_idx,wtag,rtag);
    task check;
        input [127:0] data;
        input [21:0] tag;
        input [511:0] label;
        begin
            #1;
            if (rdata !== data || rtag !== tag)
                $fatal(1,"FAIL %0s: data=%h tag=%h",label,rdata,rtag);
            $display("PASS %0s",label);
        end
    endtask
    initial begin
        @(negedge clk); we=1; tag_we=1; word_we=4'b1111;
        wdata=LINE0; wtag=22'h123456;
        @(negedge clk); we=0; tag_we=0;
        check(LINE0,22'h123456,"set 0 full-line write and tag");
        set_idx=5; we=1; tag_we=1; wdata=LINE5; wtag=22'h234567;
        @(negedge clk); we=0; tag_we=0;
        check(LINE5,22'h234567,"set 5 full-line write and tag");
        set_idx=0;
        check(LINE0,22'h123456,"set 0 unaffected by set 5 write, asynchronous read");
        set_idx=5;
        check(LINE5,22'h234567,"set 5 asynchronous reread");
        we=1; word_we=4'b0001; wdata={96'hDEAD_DEAD_DEAD_DEAD_DEAD_DEAD,32'hDEADBEEF};
        @(negedge clk); we=0;
        check({LINE5[127:32],32'hDEADBEEF},22'h234567,"partial write changes only word 0");
        word_we=4'b1111; wdata=0; wtag=0;
        @(negedge clk);
        check({LINE5[127:32],32'hDEADBEEF},22'h234567,"disabled write preserves data and tag");
        we=1; word_we=0;
        @(negedge clk); we=0;
        check({LINE5[127:32],32'hDEADBEEF},22'h234567,"zero word mask preserves line");
        set_idx=0;
        check(LINE0,22'h123456,"set 0 unaffected by partial write");
        $display("PASS tb_way_ram: all checks"); $finish;
    end
    initial begin #1000; $fatal(1,"timeout"); end
endmodule
