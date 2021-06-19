module Top_CCM(
    input clk,
    input rst_n,

    input op_start,
    output status,

    input pxMem_RD_VLD,
    input pxMem_RD_GRANT,
	output pxMem_RD_REQ,
	output [19:0] pxMem_RD_Addr,
	input [15:0] pxMem_in,

    output [31:0]MEM_ADDR,
	output [3:0]MEM_CMD,
	input      [31:0]MEM_DIN,
    input      MEM_FIN,
	input      MEM_VLD,
	input      MEM_CCM_SEL,
    output CCM_REQ,

    output [511:0] MAC_OUT,//2 row = 32bits, 2 * 16 pixels = 512 bits
    input PRE_TAKE_RDY,
    output PRE_TAKE_VLD,

    input [8:0] CFG_WIDTH,
	input [8:0] CFG_HEIGHT,
    input [9:0] CFG_NUM_KERNEL,
    input [31:0] CFG_KERN_START_ADDR,
    input [9:0] CFG_NUM_FMAP,
    input [2:0] CFG_KERN_SIZE
);


    wire KernRDWork;
    wire KernRDStart;
    wire ClusterWork;
    wire ClusterStart;

    wire [15:0] KERN_OUT;
    wire KERN_VLD;

    CCMControl CCMCtrl(clk, rst_n, op_start, status, KernRDWork, KernRDStart, ClusterWork, ClusterStart);
    CCMClusterControl uud(clk, rst_n, ClusterStart, ClusterWork, KernRDStart, KernRDWork, KERN_OUT, KERN_VLD, pxMem_RD_VLD, pxMem_RD_GRANT, pxMem_RD_REQ
    , pxMem_RD_Addr, pxMem_in, , MAC_OUT, PRE_TAKE_RDY, PRE_TAKE_VLD, CFG_WIDTH, CFG_HEIGHT, CFG_NUM_FMAP, CFG_NUM_KERNEL, CFG_KERN_SIZE);
    KernelReader KRD(clk, rst_n, MEM_ADDR, MEM_CMD, MEM_DIN, MEM_FIN, MEM_VLD, MEM_CCM_SEL, CCM_REQ, KernRDStart, KernRDWork, KERN_OUT, KERN_VLD
    , CFG_KERN_START_ADDR, CFG_NUM_FMAP, CFG_NUM_KERNEL, CFG_KERN_SIZE);

endmodule
