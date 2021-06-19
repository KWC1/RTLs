/*
	Pooling function for NNAccelerator
	Author: SooHyun Kim (soohyunkim@kw.ac.kr)
*/

module Pooling(
	input clk,
	input rst_n,

	input [63:0] DIN,
	input DIN_VLD,
	output reg DIN_RDY,

	output [63:0] DOUT,
	output reg DOUT_VLD,
	input DOUT_RDY,

	input OP_START,
	input OP_CLEAR,

	input POOL_USE
	);
	
	localparam IDLE = 3'd0;
	localparam BYPASS_POOL = 3'd1;
	localparam USE_POOL = 3'd2;
	localparam CMP_1 = 3'd3;
	localparam CMP_2 = 3'd4;
	localparam WAIT_ENC = 3'd5;
	
	reg [2:0] state, next_state;
	reg [15:0] RESULT_CMP1, next_RESULT_CMP1;
	reg [15:0] RESULT_CMP2, next_RESULT_CMP2;
	reg [15:0] POOLED_RESULT, next_POOLED_RESULT;

	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) begin
			state <= 3'd0;
			RESULT_CMP1 <= 16'd0;
			RESULT_CMP2 <= 16'd0;
			POOLED_RESULT <= 16'd0;
		end
		else begin
			state <= next_state;
			RESULT_CMP1 <= next_RESULT_CMP1;
			RESULT_CMP2 <= next_RESULT_CMP2;
			POOLED_RESULT <= next_POOLED_RESULT;
		end
	end

	assign DOUT = (state == BYPASS_POOL)?DIN:{48'd0, POOLED_RESULT};

	always @(state, OP_START, OP_CLEAR, POOL_USE, DIN_VLD, DOUT_RDY) begin
		case(state)
			IDLE: begin
				if(~OP_START) next_state <= IDLE;
				else if(OP_START & POOL_USE) next_state <= USE_POOL;
				else next_state <= BYPASS_POOL;
			end
			BYPASS_POOL: begin
				if(OP_CLEAR) next_state <= IDLE;
				else next_state <= BYPASS_POOL;
			end
			USE_POOL: begin
				if(DIN_VLD) next_state <= CMP_1;
				else next_state <= USE_POOL;
			end
			CMP_1: begin
				next_state <= CMP_2;
			end
			CMP_2: begin
				next_state <= WAIT_ENC;
			end
			WAIT_ENC: begin
				if(DOUT_RDY) next_state <= USE_POOL;
				else next_state <= WAIT_ENC;
			end
			default: next_state <= 3'dx;
		endcase
	end

	always @(state) begin
		case(state)
			IDLE: begin
				next_RESULT_CMP1 <= RESULT_CMP1;
				next_RESULT_CMP2 <= RESULT_CMP2;
				next_POOLED_RESULT <= POOLED_RESULT;
				DIN_RDY <= 1'b0;
				DOUT_VLD <= 1'b0;
			end
			BYPASS_POOL: begin
				next_RESULT_CMP1 <= RESULT_CMP1;
				next_RESULT_CMP2 <= RESULT_CMP2;
				next_POOLED_RESULT <= POOLED_RESULT;
				DIN_RDY <= DOUT_RDY;
				DOUT_VLD <= DIN_VLD;
			end
			USE_POOL: begin
				next_RESULT_CMP1 <= RESULT_CMP1;
				next_RESULT_CMP2 <= RESULT_CMP2;
				next_POOLED_RESULT <= POOLED_RESULT;
				DIN_RDY <= 1'b1;
				DOUT_VLD <= 1'b0;
			end
			CMP_1: begin
				next_RESULT_CMP1 <= (DIN[63:48] > DIN[47:32])?DIN[63:48]:DIN[47:32];
				next_RESULT_CMP2 <= (DIN[31:16] > DIN[15:0])?DIN[31:16]:DIN[15:0];
				next_POOLED_RESULT <= POOLED_RESULT;
				DIN_RDY <= 1'b0;
				DOUT_VLD <= 1'b0;
			end
			CMP_2: begin
				next_RESULT_CMP1 <= RESULT_CMP1;
				next_RESULT_CMP2 <= RESULT_CMP2;
				next_POOLED_RESULT <= (RESULT_CMP1 > RESULT_CMP2)?RESULT_CMP1:RESULT_CMP2;
				DIN_RDY <= 1'b0;
				DOUT_VLD <= 1'b0;
			end
			WAIT_ENC: begin
				next_RESULT_CMP1 <= RESULT_CMP1;
				next_RESULT_CMP2 <= RESULT_CMP2;
				next_POOLED_RESULT <= POOLED_RESULT;
				DIN_RDY <= 1'b0;
				DOUT_VLD <= 1'b1;
			end
			default: begin
				next_RESULT_CMP1 <= 16'dx;
				next_RESULT_CMP2 <= 16'dx;
				next_POOLED_RESULT <= 16'dx;
				DIN_RDY <= 1'bx;
				DOUT_VLD <= 1'bx;
			end
		endcase
	end

endmodule
