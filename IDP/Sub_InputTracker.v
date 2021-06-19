module InputTracker(
	input clk,
	input rst_n,

	input [19:0] din,
	input read,//by ccm
	input write,//by idp
	//input [3:0] move_amount,//how many decoders active? - 1

	output [19:0] d0_addr,
	output [19:0] d1_addr,
	output [19:0] d2_addr,
	output [19:0] d3_addr,
	output [19:0] d4_addr,
	output [19:0] d5_addr,
	output [19:0] d6_addr,
	output [19:0] d7_addr
);

	/* State Definition */
	localparam [1:0] INIT = 2'd0; 
	localparam [1:0] NO_OP = 2'd1;
	localparam [1:0] READ = 2'd2;
	localparam [1:0] WRITE = 2'd3;
	
	/* Registers to Save Needed Information */
	reg [1:0] state;
	reg [1:0] next_state;
	reg [8:0] head, tail;
	reg [8:0] next_head, next_tail;

	reg [19:0] BUFFER[0:511];//Save up to 512 addresses (since we support 512 address)
	//reg [15:0] next_data;

	assign d0_addr = BUFFER[{head + 8'd0}];
	assign d1_addr = BUFFER[{head + 8'd1}];
	assign d2_addr = BUFFER[{head + 8'd2}];
	assign d3_addr = BUFFER[{head + 8'd3}];
	assign d4_addr = BUFFER[{head + 8'd4}];
	assign d5_addr = BUFFER[{head + 8'd5}];
	assign d6_addr = BUFFER[{head + 8'd6}];
	assign d7_addr = BUFFER[{head + 8'd7}];

	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) begin
			state <= 2'd0;
			head <= 9'd0;
			tail <= 9'd0;
		end
		else begin
			state <= next_state;
			head <= next_head;
			tail <= next_tail;
		end
	end

	/* Next State Logic */
	//NOTE: State is Previous Clk Edge Action's result.
	always @(read, write) begin
		case ({read, write})
			2'b00://no operation
				next_state <= NO_OP;
			2'b10://read operation
				next_state <= READ;
			2'b01://write operation
				next_state <= WRITE;
			2'b11://no operation when two input high
				next_state <= NO_OP;
			default:
				next_state <= 2'dx;
		endcase
	end

	always @(posedge clk) begin
		if({write, read} == 2'b10) BUFFER[tail] <= din;
	end

	always @(read, write, head, tail, din) begin
		if({write, read} == 2'b00 || {write, read} == 2'b11) begin//nop
				next_head <= head;
				next_tail <= tail;
				//next_data <= BUFFER[tail];
		end
		else if(write == 1'b1) begin//write
				next_head <= head;
				next_tail <= tail + 1'b1;
				//next_data <= din;
		end
		else if(read == 1'b1) begin
				//next_head <= head + move_amount;
				next_head <= head + 2'd2;//pop two rows
				next_tail <= tail;
				//next_data <= BUFFER[tail];
		end
		else begin//unknown
			{next_head, next_tail} = 18'dx;
			//next_data <= 16'dx;
		end
	end	

endmodule
