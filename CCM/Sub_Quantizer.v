/*
    Quantizer based on idea https://www.frontiersin.org/articles/10.3389/fnins.2015.00222/full
*/

module Quantizer(
    input [31:0] num_in,//32bit fixed point (1b S, 15b I, 16b F)
    output [15:0] num_out//16bit fixed point (1b S, 5b I, 10b F)
);

    wire sign;
    wire [4:0] newI;
    wire [9:0] newF;

    assign sign = num_in[31];
    assign newI = (num_in[30:21] == 10'd0)?num_in[20:16]:(sign)?5'b00_000:5'b11_111;//set to max value if overflow
    assign newF = num_in[15:6];//truncate low precision

    assign num_out = {sign, newI, newF};

endmodule
