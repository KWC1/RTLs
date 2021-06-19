module MemoryControl
(
	input clk,
	input rst_n,
	
	/* Memory Ports */
	output [31:0] MEM_ADDR,
	output [31:0] MEM_DOUT,
	input  [31:0] MEM_DIN,
	output reg MEM_CEN,
	output reg MEM_WR,
	
	/* From/To IDP */
	input [3:0] IDP_CMD,
	input [31:0] IDP_ADDR,
	input IDP_REQ,
	output MEM_IDP_SEL,
	
	/* From/To CCM */
	input [3:0] CCM_CMD,
	input [31:0] CCM_ADDR,
	input CCM_REQ,
	output MEM_CCM_SEL,
	
	/* From/To PRE */
	input [3:0] PRE_CMD,
	input [31:0] PRE_ADDR,
	input PRE_REQ,
	output MEM_PRE_SEL,
	
	/* PRE Module Write Buffering */
	input PRE_WR_BUF,
	input [31:0] PRE_DIN,
	
	/* From/To Top */
	input [3:0] TOP_CMD,
	input [31:0] TOP_ADDR,
	input TOP_REQ,
	output MEM_TOP_SEL,
	
	/* Data Out */
	output [31:0] DOUT,
	output reg MEM_VLD,
	output reg MEM_FIN
);
	
	/* State Definition */
	localparam STA_IDLE = 4'd0;
	
	localparam STA_SEL_REQ_WAIT = 4'd1;
	localparam STA_SEL_TOP = 4'd2;
	localparam STA_SEL_CCM = 4'd3;
	localparam STA_SEL_IDP = 4'd4;
	localparam STA_SEL_PRE = 4'd5;
	
	localparam STA_DECODE_CMD = 4'd6;
	
	localparam STA_READ_REQ = 4'd7;
	localparam STA_READ_WAIT = 4'd8;
	localparam STA_READ_BUFF = 4'd9;
	localparam STA_POP_RD_BUFF = 4'd10;
	
	localparam STA_WRT_REQ = 4'd11;
	localparam STA_WRT_WAIT = 4'd12;
	localparam STA_WRT_BUFF = 4'd13;
	
	/* Reg Variables */
	reg [3:0] state, next_state;

	reg [3:0] SELECT_ORDER, next_SELECT_ORDER;
	reg [3:0] SELECTED_DEVICE, next_SELECTED_DEVICE;
	reg [3:0] DEV_CMD, next_DEV_CMD;
	reg [31:0] DEV_ADDR, next_DEV_ADDR;
	reg WrBufRead, RdBufRead, RdBufWrite;

	reg [3:0] waitCntr, next_wait_cntr;
	
	/* Wire Assignments */
	assign MEM_IDP_SEL = SELECTED_DEVICE[3];
	assign MEM_PRE_SEL = SELECTED_DEVICE[2];
	assign MEM_CCM_SEL = SELECTED_DEVICE[1];
	assign MEM_TOP_SEL = SELECTED_DEVICE[0];
	assign MEM_ADDR = DEV_ADDR;
	
	//Write Buffer
	wire WrBuf_WRACK, WrBuf_RDACK;
	wire WrBuf_empty, WrBuf_full;
	SimpleFIFO _WrBuf(clk, rst_n, PRE_WR_BUF, WrBufRead, PRE_DIN, MEM_DIN, WrBuf_RDACK, WrBuf_WRACK);
	
	//Read Buffer
	wire RdBuf_WRACK, RdBuf_RDACK;
	wire RdBuf_empty, RdBuf_full;
	wire [4:0] rdCnt;
	SimpleFIFO _RdBuf(clk, rst_n, RdBufRead, RdBufWrite, MEM_DOUT, DOUT, RdBuf_full, RdBuf_empty, RdBuf_RDACK, , RdBuf_WRACK, , rdCnt);

	/* Register Update Logic */
	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) begin
			state <= 4'b0000;
			SELECT_ORDER <= 4'b1000;
			SELECTED_DEVICE <= 4'b0000;
			DEV_CMD <= 4'b0000;
			DEV_ADDR <= 32'd0;
			waitCntr <= 4'd0;
		end
		else begin
			state <= next_state;
			SELECT_ORDER <= next_SELECT_ORDER;
			SELECTED_DEVICE <= next_SELECTED_DEVICE;
			DEV_CMD <= next_DEV_CMD;
			DEV_ADDR <= next_DEV_ADDR;
			waitCntr <= next_wait_cntr;
		end
	end
	
	/*
		[3:0] XXX_CMD
		-----------------------
		| RW[1] | BURST_LEN[3]|
		-----------------------
	*/

	/* Next State Logic */
	always @(*) begin
		case(state)
		STA_IDLE: begin
			if(IDP_REQ||TOP_REQ||CCM_REQ||PRE_REQ) next_state <= STA_SEL_REQ_WAIT;
			else next_state <= STA_IDLE;
		end
		
		STA_SEL_REQ_WAIT: begin
			if     ((SELECT_ORDER[0] == 1'b1 & TOP_REQ) || (TOP_REQ&~CCM_REQ&~IDP_REQ&~PRE_REQ)) next_state <= STA_SEL_TOP;
			else if((SELECT_ORDER[1] == 1'b1 & CCM_REQ) || (~TOP_REQ&CCM_REQ&~IDP_REQ&~PRE_REQ)) next_state <= STA_SEL_CCM;
			else if((SELECT_ORDER[2] == 1'b1 & IDP_REQ) || (~TOP_REQ&~CCM_REQ&IDP_REQ&~PRE_REQ)) next_state <= STA_SEL_IDP;
			else if((SELECT_ORDER[3] == 1'b1 & PRE_REQ) || (~TOP_REQ&~CCM_REQ&~IDP_REQ&PRE_REQ)) next_state <= STA_SEL_PRE;
			else next_state <= STA_SEL_REQ_WAIT;
		end
		
		STA_SEL_TOP: begin
			next_state <= STA_DECODE_CMD;
		end
		
		STA_SEL_CCM: begin
			next_state <= STA_DECODE_CMD;
		end
		
		STA_SEL_IDP: begin
			next_state <= STA_DECODE_CMD;
		end
		
		STA_SEL_PRE: begin
			next_state <= STA_DECODE_CMD;
		end
		
		STA_DECODE_CMD: begin
			if(DEV_CMD[3] == 1'b0) next_state <= STA_READ_REQ;//read mode
			else next_state <= STA_WRT_REQ;//write mode
		end
		
		STA_READ_REQ: begin//Command memory
			next_state <= STA_READ_WAIT;
		end
		
		STA_READ_WAIT: begin//Get data from memory
		/* NOTE: assume 1 cycle delay after read */
			if(waitCntr == 4'd15) next_state <= STA_READ_BUFF;
			else next_state <= STA_READ_WAIT;
		end
		
		STA_READ_BUFF: begin//Insert 
			if(DEV_CMD[2:0] > 0) next_state <= STA_READ_REQ;//more read required
			else next_state <= STA_POP_RD_BUFF;//pop from buffer
		end
		
		STA_POP_RD_BUFF: begin
			if(rdCnt == 1) next_state <= STA_IDLE;//till empty
			else next_state <= STA_POP_RD_BUFF;
		end
		
		STA_WRT_REQ: begin
			next_state <= STA_WRT_WAIT;
		end
		
		STA_WRT_WAIT: begin
			next_state <= STA_WRT_BUFF;
		end
		
		STA_WRT_BUFF: begin
			if(DEV_CMD[2:0] > 0) next_state <= STA_WRT_REQ;//more write required
			else next_state <= STA_IDLE;//finish write
		end
		
		default: 
			next_state <= 4'dx;
		
		endcase
	end
	
	/* State Actions */
	always @(*) begin
		case(state)
		STA_IDLE: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_SEL_REQ_WAIT: begin
			next_SELECT_ORDER <= {SELECT_ORDER[2:0], SELECT_ORDER[3]};//rotate left
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_SEL_TOP: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= 4'b0001;
			next_DEV_CMD <= TOP_CMD;
			next_DEV_ADDR <= TOP_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_SEL_CCM: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= 4'b0010;
			next_DEV_CMD <= CCM_CMD;
			next_DEV_ADDR <= CCM_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_SEL_PRE: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= 4'b0100;
			next_DEV_CMD <= PRE_CMD;
			next_DEV_ADDR <= PRE_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end

		STA_SEL_IDP: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= 4'b1000;
			next_DEV_CMD <= IDP_CMD;
			next_DEV_ADDR <= IDP_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_DECODE_CMD: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= 4'd0;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_READ_REQ: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_READ_WAIT: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b1;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr + 1;
		end
		
		STA_READ_BUFF: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <=  {DEV_CMD[3], DEV_CMD[2:0] - 3'd1};
			next_DEV_ADDR <= DEV_ADDR + 32'd4;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b1;
			if(DEV_CMD[2:0] == 3'd0) MEM_VLD <= 1'b1;//no more read
			else MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_POP_RD_BUFF: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b1;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			if(rdCnt == 1) MEM_FIN <= 1'b1;
			else MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_WRT_REQ: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b1;
			WrBufRead <= 1'b1;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_WRT_WAIT: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= DEV_CMD;
			next_DEV_ADDR <= DEV_ADDR;
			MEM_CEN <= 1'b1;
			MEM_WR <= 1'b1;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		STA_WRT_BUFF: begin
			next_SELECT_ORDER <= SELECT_ORDER;
			next_SELECTED_DEVICE <= SELECTED_DEVICE;
			next_DEV_CMD <= {DEV_CMD[3], DEV_CMD[2:0] - 3'd1};//decr left burst
			next_DEV_ADDR <= DEV_ADDR + 32'd4;
			MEM_CEN <= 1'b0;
			MEM_WR <= 1'b0;
			WrBufRead <= 1'b0;
			RdBufRead <= 1'b0;
			RdBufWrite <= 1'b0;
			MEM_VLD <= 1'b0;
			if(DEV_CMD[2:0] == 3'd1) MEM_FIN <= 1'b1;
			else MEM_FIN <= 1'b0;
			next_wait_cntr <= waitCntr;
		end
		
		default: begin
			next_SELECT_ORDER <= 4'dx;
			next_SELECTED_DEVICE <= 4'dx;
			next_DEV_CMD <= 32'dx;
			next_DEV_ADDR <= 32'dx;
			MEM_CEN <= 1'bx;
			MEM_WR <= 1'bx;
			WrBufRead <= 1'bx;
			RdBufRead <= 1'bx;
			RdBufWrite <= 1'bx;
			MEM_VLD <= 1'bx;
			MEM_FIN <= 1'dx;
			next_wait_cntr <= 4'dx;
		end
		endcase
	end

endmodule
