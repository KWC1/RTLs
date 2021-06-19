module SMEncoder(
    input clk,
    input rst_n,

    input [63:0] DIN,
    input DIN_VLD,
    input DIN_RDY,

    output PRE_WR_BUF,
    output [31:0]PRE_DIN,
    output PRE_REQ,
    output [3:0] PRE_CMD,
    output [31:0] PRE_ADDR,
    input MEM_PRE_SEL,

	//configurations
	input USE_POOL,
	input [31:0] CFG_ACTMAP_START_ADDR

	);

	reg [127:0] outPxBuff;
	reg []
	reg [3:0] pxCnt;


	localparam IDLE = ;
	localparam CALC_ADDR = ;
	localparam READ_PX_WAIT = ;
	localparam ENCODE = ;
	localparam PX_WRITE_BUFF = ;
	localparam PX_WRITE_REQ = ;
	localparam PX_WRITE_WAIT = ;
	localparam SM_WRITE_BUFF = ;
	localparam SM_WRITE_REQ = ;
	localparam SM_WRITE_WAIT = ;


endmodule
