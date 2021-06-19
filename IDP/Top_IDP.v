module Top_IDP(
	input clk,
	input rst_n,
	
	//RAM Controller Ports
	output MEM_REQ,
	output [31:0]MEM_ADDR,
	output [3:0]MEM_CMD,
	input  [31:0]MEM_DIN,
	input MEM_FIN,
	input  MEM_VLD,
	input  MEM_IDP_SEL,

	output pxMem_RD_VLD,
	output pxMem_RD_GRANT,
	input  pxMem_RD_REQ,
	input  [19:0] pxMem_RD_Addr,
	output [15:0] pxMem_in,

	input track_read,//by idp
	output [19:0] d0_addr,
	output [19:0] d1_addr,
	output [19:0] d2_addr,
	output [19:0] d3_addr,
	output [19:0] d4_addr,
	output [19:0] d5_addr,
	output [19:0] d6_addr,
	output [19:0] d7_addr,

	input IDP_START,
    output IDP_STATUS,

    input [31:0] CFG_READ_START_ADDR,//어디서부터 읽기 시작할건가?, Read Region과 Write Region은 매번 서로 교체된다.
    input [8:0] CFG_WIDTH,
	input [8:0] CFG_HEIGHT,
    input [9:0] CFG_NUM_FMAP
);

	wire pxMem_WR_RDY;
    wire pxMem_WR_VLD;
	wire pxMem_GRANT;
	wire pxMem_WR_REQ;
	wire [19:0] pxMem_Addr;
	wire [3:0] pxMem_burst;//(1-16)
	wire [15:0] pxMem_out;

	wire [19:0] track_din;

	InputTracker Tracker(clk, rst_n, track_din, track_read, track_write, d0_addr, d1_addr, d2_addr, d3_addr, d4_addr, d5_addr, d6_addr, d7_addr);
	PxMemory PxMem(clk, rst_n, pxMem_RD_GRANT, pxMem_RD_VLD, pxMem_RD_REQ, pxMem_RD_Addr, pxMem_in, pxMem_WR_RDY, pxMem_WR_VLD
	, pxMem_GRANT, pxMem_WR_REQ, pxMem_Addr, pxMem_burst, pxMem_out);
	IDPManager IDPMan(clk, rst_n, MEM_REQ, MEM_ADDR, MEM_CMD, MEM_DIN, MEM_VLD, MEM_FIN, MEM_IDP_SEL, pxMem_WR_RDY, pxMem_WR_VLD, pxMem_GRANT
	, pxMem_WR_REQ, pxMem_Addr, pxMem_burst, pxMem_out, track_din, track_write, IDP_START, IDP_STATUS, CFG_READ_START_ADDR, CFG_WIDTH, CFG_HEIGHT, CFG_NUM_FMAP);

endmodule
