module SMDecoder(
	input clk,
	input rst_n,

	input op_start,
	output busy,

	input [15:0] SM_in,
	input [3:0] HAMW_in,

	input [15:0] NZVL_in,
	output reg Din_Read,

	input px_READ,
	output reg px_FIN,
	output [15:0] px_value_out,
);	

	localparam STATE_IDLE = 4'd0;//On reset
	localparam STATE_SETUP = 4'd1;//Address, Pixels, etc...

	localparam STATE_MOVE = 4'd11;//Move to next pixel
	localparam STATE_DEC_DATA = 4'd12;//decoding and send data

	localparam STATE_DEC_END = 4'd13;//End SM Segment Decoding, ready for copy

	reg [3:0] state, next_state;

	reg [15:0] px_addr, next_addr;
	reg [15:0] SM, next_SM;

	reg [4:0] px_cnt, next_cnt;//how many pixels in one sm segment
	reg [3:0] bur_len, next_bur_len;

	assign busy = (state != STATE_IDLE);

	reg dBread, dBwrite;
	wire [15:0] dBout;
	wire [4:0] dBcnt;
	SimpleFIFO16 dBuf(clk, rst_n, dBread, dBwrite, pxMem_in, dBout, , , , , , , dBcnt);//it is assured that we will not exceed 16 data

	assign px_burst = bur_len;
	assign px_value_out = dBout;
	
	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) begin//On reset
			state <= 4'd0;
			SM <= 16'd0;
			px_cnt <= 5'd0;
		end
		else begin//On clock
			state <= next_state;
			SM <= next_SM;
			px_cnt <= next_cnt;
		end
	end

	always @(state, op_start, pxMem_GRANT, pxMem_RD_VLD, ham_vld, bur_len, SM, px_RDY, px_cnt) begin
		case(state)
			STATE_IDLE: begin
				if(op_start) next_state <= STATE_SETUP;
				else next_state <= STATE_IDLE;
			end
			STATE_SETUP: begin
				next_state <= STATE_MOVE;
			end
			STATE_MOVE: begin
				if(SM[15]) next_state <= STATE_DEC_DATA;
				else next_state <= STATE_MOVE;
			end
			STATE_DEC_DATA: begin
				if(px_cnt == 5'd1) next_state <= STATE_DEC_END;
				else if(~SM[14]) next_state <= STATE_MOVE;//pixel left, but next sm is empty
				else next_state <= STATE_DEC_DATA;
			end
			STATE_DEC_END: begin
				if(dBCnt == 5'd0) next_state <= STATE_IDLE;
				else next_state <= STATE_DEC_END;
			end
			default: begin
				next_state <= 4'dx;
			end
		endcase
	end

	always @(state, px_addr, SM, cur_row, cur_col, px_cnt, bur_len, start_address, start_row, pxMem_in, hamW, pxMem_RD_VLD, px_RDY) begin
		case(state)
			STATE_IDLE: begin
				ham_start <= 1'b0;
				dBread <= 1'b0;
				dBwrite <= 1'b0;
				px_VLD <= 1'b0;
				pxMem_RD_RDY <= 1'b0;
				pxMem_RD_REQ <= 1'b0;
				next_addr <= px_addr;
				next_SM <= SM;
				next_row <= cur_row;
				next_col <= cur_col;
				next_cnt <= px_cnt;
				next_bur_len <= bur_len;
			end
			STATE_SETUP: begin
				ham_start <= 1'b0;
				dBread <= 1'b0;
				dBwrite <= 1'b0;
				px_VLD <= 1'b0;
				pxMem_RD_RDY <= 1'b0;
				pxMem_RD_REQ <= 1'b0;
				next_addr <= start_address;//set addr
				next_SM <= SM;
				next_cnt <= px_cnt;
				next_bur_len <= bur_len;
			end
			STATE_MOVE: begin
				ham_start <= 1'b0;
				dBread <= 1'b0;
				dBwrite <= 1'b0;
				px_VLD <= 1'b0;
				pxMem_RD_RDY <= 1'b0;
				pxMem_RD_REQ <= 1'b0;
				next_addr <= px_addr;
				if(SM[15]) next_SM <= SM;
				else next_SM <= {SM[14:0], 1'b0};//shift one
				next_row <= cur_row;
				if(SM[15]) next_col <= cur_col;
				else next_col <= cur_col + 1'd1;
				next_cnt <= px_cnt;
				next_bur_len <= bur_len;
			end
			STATE_DEC_DATA: begin
				ham_start <= 1'b0;
				if(px_RDY) dBread <= 1'b1;
				else dBread <= 1'b0;
				dBwrite <= 1'b0;
				px_VLD <= 1'b1;
				pxMem_RD_RDY <= 1'b0;
				pxMem_RD_REQ <= 1'b0;
				if(px_RDY) next_addr <= px_addr + 1'd1;
				else next_addr <= px_addr;
				if(px_RDY) next_SM <= {SM[14:0], 1'b0};//shift one
				else next_SM <= SM;
				next_row <= cur_row;
				if(px_RDY) begin
					next_col <= cur_col + 1'd1;
					next_cnt <= px_cnt - 1'd1;
				end
				else begin
					next_col <= cur_col;
					next_cnt <= px_cnt;
				end
				next_bur_len <= bur_len;
			end
			STATE_DEC_END: begin
				ham_start <= 1'b0;
				dBread <= 1'b0;
				dBwrite <= 1'b0;
				px_VLD <= 1'b0;
				pxMem_RD_RDY <= 1'b0;
				pxMem_RD_REQ <= 1'b0;
				next_addr <= px_addr;
				next_SM <= SM;
				next_row <= cur_row;
				next_col <= cur_col;
				next_cnt <= px_cnt;
				next_bur_len <= bur_len;
			end
			default: begin
				ham_start <= 1'dx;
				dBread <= 1'dx;
				dBwrite <= 1'dx;
				px_VLD <= 1'bx;
				pxMem_RD_RDY <= 1'bx;
				pxMem_RD_REQ <= 1'bx;
				next_addr <= 16'dx;
				next_SM <= 16'dx;
				next_row <= 9'dx;
				next_col <= 9'dx;
				next_cnt <= 5'dx;
				next_bur_len <= 5'dx;
			end
		endcase
	end

endmodule
