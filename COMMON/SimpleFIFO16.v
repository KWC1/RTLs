module SimpleFIFO16(
	input clk,
	input rst_n,
	input read,
	input write,
	input [15:0] d_in,
	output [15:0] d_out,
	output full, /* Full Flag */
	output empty, /* Empty Flag */
	output reg wr_ack, /* Write Acknowledge Flag */
	output reg wr_err, /* Write Error Flag */
	output reg rd_ack, /* Read Acknowledge Flag */
	output reg rd_err, /* Read Error Flag */
	output reg [4:0] data_count /* Data Count Vector */
);

	/* State Definition */
	localparam [2:0] INIT = 3'b000; 
	localparam [2:0] NO_OP = 3'b001;
	localparam [2:0] READ = 3'b010;
	localparam [2:0] RD_ERROR = 3'b011;
	localparam [2:0] WRITE = 3'b100;
	localparam [2:0] WR_ERROR = 3'b101;

	/* Registers to Save Needed Information */
	reg [2:0] state;
	reg [2:0] next_state;
	reg [4:0] next_data_count;
	reg [3:0] head, tail;
	reg [3:0] next_head, next_tail;

	reg [15:0] BUFFER[0:15];//array
	reg [15:0] next_data;

	//wire signals
	assign full = (data_count == 5'd16)?1'b1:1'b0;
	assign empty = (data_count == 5'd0)?1'b1:1'b0;
	assign d_out = BUFFER[head];

	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) {state, data_count, head, tail} <= 13'b000;//reset
		else begin//update the register with next value
			state <= next_state;
			data_count <= next_data_count;
			head <= next_head;
			tail <= next_tail;
			BUFFER[tail] <= next_data;
		end
	end
	
	/* Next State Logic */
	//NOTE: State is Previous Clk Edge Action's result.
	always @(read, write, data_count, state) begin
		case ({read, write})
			2'b00://no operation
				next_state <= NO_OP;
			2'b10://read operation
				if(data_count > 0) next_state <= READ;
				else next_state <= RD_ERROR;
			2'b01://write operation
				if(data_count < 16) next_state <= WRITE;
				else next_state <= WR_ERROR;
			2'b11://no operation when two input high
				next_state <= NO_OP;
			default:
				next_state <= 3'bxxx;
		endcase
	end

	always @(read, write, data_count, head, tail, d_in) begin
		if({write, read} == 2'b00 || {write, read} == 2'b11) begin//nop
				next_head <= head;
				next_tail <= tail;
				next_data_count <= data_count;
				next_data <= BUFFER[tail];
		end
		else if(write == 1'b1) begin//write
			if(data_count == 16) begin//full => no write
				next_head <= head;
				next_tail <= tail;
				next_data_count <= data_count;
				next_data <= BUFFER[tail];
			end
			else begin//write
				next_head <= head;
				next_tail <= tail + 1'b1;
				next_data_count <= data_count + 1'b1;
				next_data <= d_in;
			end
		end
		else if(read == 1'b1) begin
			if(data_count == 0) begin//empty => no read
				next_head <= head;
				next_tail <= tail;
				next_data_count <= data_count;
				next_data <= BUFFER[tail];
			end
			else begin//read
				next_head <= head + 1'b1;
				next_tail <= tail;
				next_data_count <= data_count - 1'b1;
				next_data <= BUFFER[tail];
			end
		end
		else begin//unknown
			{next_head, next_tail, next_data_count} = 13'bxxxx_xxxx_xxxx;
			next_data <= 16'dx;
		end
	end	

	always @(state) begin
		case(state)
			INIT:
				{wr_ack, wr_err, rd_ack, rd_err} = 4'b0000;
			NO_OP:
				{wr_ack, wr_err, rd_ack, rd_err} = 4'b0000;
			READ:
				{wr_ack, wr_err, rd_ack, rd_err} = 4'b0010;
			RD_ERROR: 
				{wr_ack, wr_err, rd_ack, rd_err} = 4'b0001;
			WRITE:
				{wr_ack, wr_err, rd_ack, rd_err} = 4'b1000;
			WR_ERROR:
				{wr_ack, wr_err, rd_ack, rd_err} = 4'b0100;
			default://unknown
				{wr_ack, wr_err, rd_ack, rd_err} <= 4'bx;
		endcase
	end

endmodule
