/*
	16x16 Multiplier using wallace tree
*/

/*
module CSA(
	input A,
	input B,
	input C,
	output X,
	output Y
	);
	
	assign X = A ^ B ^ C;//sum of three input
	assign Y = A&B + A&C + B&C;//carry out
	
endmodule	
*/

module MUL16(
	input clk,
	input rst_n,
	input op_start,
	output reg mul_finish,
	
	input [15:0] A,
	input [15:0] B,
	output [31:0] Y
	);
	
	/*
	//Create partial products
	genvar i, j;
	generate
		for(i = 0; i < 16; i = i + 1) begin : PP
			for(j = 0; j < 16; j = j + 1) begin : SUB
				wire P;
				assign P = A[0] & B[i];
			end
		end
	endgenerate
	
	
	//Level 1
	
	
	//Level 2
	
	
	//Level 3
	*/
	
	//temp implementation (assume 2 cycle delay)
	reg [31:0] lv1, lv2;
	wire [31:0] res;

	reg [3:0] state, next_state;
	
	assign Y = A * B;
	
	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) begin
			state <= 4'd0;
		end
		else begin
			state <= next_state;
		end
	end
	
	always @(*) begin
		case(state)
			2'd0: begin
				mul_finish <= 1;
				if(op_start) next_state <= 2'd1;
				else next_state <= 2'd0;
			end
			2'd1: begin
				mul_finish <= 0;
				next_state <= 2'd2;
			end
			2'd2: begin
				mul_finish <= 0;
				next_state <= 2'd3;
			end
			2'd3: begin
				mul_finish <= 0;
				next_state <= 2'd4;
			end
			2'd4: begin
				mul_finish <= 0;
				next_state <= 2'd5;
			end
			2'd5: begin
				mul_finish <= 0;
				next_state <= 2'd6;
			end
			2'd6: begin
				mul_finish <= 0;
				next_state <= 2'd7;
			end
			2'd7: begin
				mul_finish <= 0;
				next_state <= 2'd0;
			end
			default: begin
				mul_finish = 1'dx;
				next_state <= 2'dx;
			end
		endcase
	end
	
endmodule
