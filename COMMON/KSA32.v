module KSA32(
	input [31:0] A,
	input [31:0] B,
	input Cin,
	output [31:0] Y,
	output Cout
);


	/*
		32-bit Kogge-stone adder
		
		Note) For n-bit adder, KSA needs log2(n) level of tree.
		32bit needs 5 level
	*/
	
/*

	//First level of KSA
	wire [31:0] P_1;
	wire [31:0] G_1;
	assign P_1 = A ^ B;
	assign G_1 = A & B;
	
	//Second level of KSA
	wire [31:0] P_2;
	wire [31:0] G_2;
	assign P_2 = {P_1 };
	assign G_2 = {};
	
	
	//Third level of KSA
	
	//Fourth level of KSA
	
	//Fifth level of KSA
	
*/
	
	//temp implementation
	wire [32:0] result;
	assign result = A + B;
	
	assign Y = result[31:0];
	assign Cout = result[32];
	
endmodule
