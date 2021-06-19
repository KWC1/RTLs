module Top_PRE(
    input clk,
    input rst_n,

    //Control Pooling
    input PRE_START,

    //From CCM
	input [511:0] MAC_OUT,//up to 2 row * 16 at once
	input DIN_VLD,
	output DIN_RDY,

    //To MEMCont.
    output PRE_WR_BUF,
    output [31:0]PRE_DIN,
    output PRE_REQ,
    output [3:0] PRE_CMD,
    output [31:0] PRE_ADDR,
    input MEM_PRE_SEL,
    input MEM_FIN,

    input [9:0] CFG_NUM_FMAP
);

    reg [15:0] poolBuf[0:7];

    reg [15:0] r0OutBuf[0:15];
    reg [15:0] r1OutBuf[0:15];

    reg [15:0] SM, next_SM;

    localparam STA_IDLE = ;
    localparam STA_WAIT_CCM = ;

    localparam STA_CCM_TAKE_DATA = ;

    localparam STA_DO_POOL = ;
    localparam STA_DO_POOL_ENCODE = ;
    localparam STA_PRE_INSERT_MEM_BUFFER = ;

    localparam STA_PRE_WRITE_REQ = ;
    localparam STA_PRE_WRITE_CMD = ;
    localparam STA_PRE_WRITE_WAIT = ;

endmodule