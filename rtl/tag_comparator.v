// tag_comparator.v
// Combinational tag match and hit-way select.
`timescale 1ns/1ps

module tag_comparator (
    input  wire [21:0] addr_tag,
    input  wire [21:0] way0_tag,
    input  wire [21:0] way1_tag,
    input  wire        valid0,
    input  wire        valid1,
    output wire        way0_hit,
    output wire        way1_hit,
    output wire        hit,
    output wire        hit_way
);
    assign way0_hit = valid0 && (way0_tag == addr_tag);
    assign way1_hit = valid1 && (way1_tag == addr_tag);
    assign hit      = way0_hit || way1_hit;
    assign hit_way  = way1_hit ? 1'b1 : 1'b0;
endmodule
