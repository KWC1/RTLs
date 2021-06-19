/*
	Top Controller for NNAccelerator
	Author: SooHyun Kim (soohyunkim@kw.ac.kr)
*/

module TopControl(
	input clk,
	output rst_n,

	//RAM Controller Ports
	output reg MEM_REQ,

	output reg [31:0]MEM_ADDR,
	output reg [3:0]MEM_CMD,
	input      [31:0]MEM_DIN,
	input      MEM_VLD,
	input      MEM_TOP_SEL,
	
	input      [1:0] IDP_STATUS,
	input      [1:0]CCM_STATUS,
	input      [1:0] PRE_STATUS,

	input      OP_START,

	output     IDP_START,
	output     CCM_START,

	//INTERRUPT & STATUS
	input      CTRL_INTR_CLR,
	output reg CTRL_INTR,
	output reg [1:0] CTRL_STATUS,

	//Configuration register Ports
	output [3:0] CFG_TYPE_LAYER,
	output [8:0] CFG_WIDTH,
	output [8:0] CFG_HEIGHT,
	output [9:0] CFG_NUM_FMAP,
	output [9:0] CFG_NUM_KERNEL,//filter channels
	output CFG_PADDING,
	output CFG_ENABLE_POOL,
	output CFG_ENABLE_RELU,
	output [2:0] CFG_SIZE_KERNEL,
	output [31:0] CFG_KERN_START_ADDR,
	output [31:0] CFG_ACTMAP_START_ADDR
	);

	//On reset and idle
	localparam STA_INIT = 5'd0;
	
	//For Configuration
	localparam STA_CFG_RDY = 5'd1;
	localparam STA_CFG_WRITE = 5'd2;
	localparam STA_CFG_WR_END = 5'd3;
	
	//Start by loading configuration
	localparam STA_LD_RDY = 5'd4
	localparam STA_LD_HEADER = 5'd5;
	
	//Layer load
	//One layer packet is 48bit length
	localparam STA_LD_LAYER_RDY = 5'd6;
	localparam STA_LD_LAYER_1 = 5'd7;//load first 4 byte here
	localparam STA_LD_LAYER_2 = 5'd8;//load second 2 byte here
	
	//For Convolution
	localparam STA_LOAD_PARAMETERS = 5'd9;
	localparam STA_START_OPERATION = 5'd11;
	localparam STA_WAIT_OPERATION = 5'd12;
	
	//Softmax post-processing (using SW, nios2 processing? or use ARM core?)
	localparam STA_REQ_SW_PROC = 5'd13;
	localparam STA_WAIT_SW_PROC = 5'd14;
	
	//End
	localparam STA_WAIT_FINISH = 5'd15;
	localparam STA_FINISH_CLEANUP = 5'd16;
	
	//State update
	reg [4:0] state, next_state;
	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) state <= STA_INIT;
		else state <= next_state;
	end
	
	//Reg update
	reg isConfigDone;
	reg isCMDBurstMode;
	reg totalLayerCnt;
	reg currentLayerCnt;
	
	
	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) begin
		end
		else begin
		end
	end
	
	//Next state logic
	always @(state, MEM_GRANT, MEM_RDY, IDP_RDY, IDP_WORK, CTRL_INTR_CLEAR, CMD_VLD, OP_START, CONFIG_DONE) begin
		case(state)
			STA_INIT: begin
				if(CMD_OP_START & CONFIG_DONE) next_state <= STA_LD_RDY;//Load ready
				else if(CMD_VLD) next_state <= STA_CFG_RDY;//Configuration ready
				else next_state <= STA_INIT;//Maintain idle if the coditions does not match
			end
			
			STA_CFG_RDY: begin
				if(MEM_GRANT) next_state <= STA_CFG_WRITE;//Check granted and go to next state, anyway this controller has highest priority for memory
				else next_state <= STA_CFG_RDY;
			end
				
			STA_CFG_WRITE: begin
				if(CMD_STOP) next_state <= STA_CFG_WR_END;
				else next_state <= STA_CFG_WRITE;
			end
			
			STA_CFG_WR_END: begin
			end
			
			STA_LD_RDY: begin
				if(MEM_GRANT) next_state <= STA_LD_HEADER;//Check granted and go to next state, anyway this controller has highest priority for memory
				else next_state <= STA_LD_RDY;
			end
			
			STA_LD_HEADER: begin
			end
			
			STA_LD_LAYER_RDY: begin
			end
			
			STA_LD_LAYER_1: begin
			end
			
			STA_LD_LAYER_2: begin
			end
			
			STA_LD_FILTER: begin
			end
			
			STA_LD_INIT_IMAGE: begin
			end
			
			STA_LD_START_CONVOL: begin
			end
			
			STA_WAIT_CONV_END: begin
			end
			
			STA_LD_WEIGHT: begin
			end
			
			STA_LD_NEURON: begin
			end
			
			STA_SATRT_FC: begin
			end
			
			STA_WAIT_FC_END: begin
				
			end
			
			STA_REQ_SW_PROC: begin
			end
				
			STA_WAIT_SW_PROC: begin
			end
				
			STA_WAIT_FINISH: begin
			end
				
			STA_FINISH_CLEANUP: begin
				if(CTRL_INTR_CLR) next_state <= STA_INIT;
				else next_state <= STA_FINISH_CLEANUP;
			end
			
			default:
				next_state <= 5'dx;
		endcase
	end
	
	//Actions
	always @(state) begin
		case(state)
			STA_INIT: begin
				
			end
			STA_CFG_RDY: begin
				
			end
			STA_CFG_WRITE: begin
				
			end
			STA_CFG_WR_END: begin
				
			end
			STA_LD_RDY: begin
				
			end
			STA_LD_HEADER: begin
				
			end
			STA_LD_LAYER_CFG: begin
				
			end
			STA_LD_FILTER: begin
				
			end
			STA_LD_INIT_IMAGE: begin
				
			end
			STA_LD_START_CONVOL: begin
				
			end
			STA_WAIT_CONV_END: begin
				
			end
			STA_LD_WEIGHT: begin
				
			end
			STA_LD_NEURON: begin
				
			end
			STA_SATRT_FC: begin
				
			end
			STA_WAIT_FC_END: begin
				
			end
			STA_REQ_SW_PROC: begin
				
			end
			STA_WAIT_SW_PROC: begin
				
			end
			STA_WAIT_FINISH: begin
				
			end
			STA_CLEANUP: begin
				
			end
			default: begin
				
			end
		endcase
	end
	
endmodule
