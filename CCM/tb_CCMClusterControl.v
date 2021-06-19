module tb_CCMClusterControl;

    reg clk;
    reg rst_n;

    reg op_start;
    wire busy;

    reg KernRDStart;
    reg KernRDWork;
    reg [15:0] KERN_OUT;
    reg KERN_VLD;

	reg pxMem_RD_VLD;
	reg pxMem_RD_GRANT;
	wire pxMem_RD_REQ;
	wire [19:0] pxMem_RD_Addr;
	reg [15:0] pxMem_in;

    reg [19:0] row0_addr;

    wire [511:0] MAC_OUT;//2 row = 32bits; 2 * 16 pixels = 512 bits
    reg PRE_TAKE_RDY;
    wire PRE_TAKE_VLD;

    reg [8:0] CFG_WIDTH;
	reg [8:0] CFG_HEIGHT;
    reg [9:0] CFG_NUM_FMAP;
    reg [9:0] CFG_NUM_KERNEL;
    reg [2:0] CFG_KERN_SIZE;

    //clock generation
	initial clk = 0;
	always #10 clk = ~clk;

    CCMClusterControl uud(clk, rst_n, op_start, busy, KernRDStart, KernRDWork, KERN_OUT, KERN_VLD, pxMem_RD_VLD, pxMem_RD_GRANT, pxMem_RD_REQ
    , pxMem_RD_Addr, pxMem_in, row0_addr, MAC_OUT, PRE_TAKE_RDY, PRE_TAKE_VLD, CFG_WIDTH, CFG_HEIGHT, CFG_NUM_FMAP, CFG_NUM_KERNEL, CFG_KERN_SIZE);

    initial begin
        #0 rst_n = 0;
        #0 op_start = 0; KernRDStart = 0; KernRDWork = 0; KERN_OUT = 16'h0303; KERN_VLD = 0;
        #0 pxMem_RD_VLD = 1; pxMem_RD_GRANT = 1; pxMem_in = 16'h4319;
        #0 row0_addr = 0;
        #0 PRE_TAKE_RDY = 0;
        #0 CFG_WIDTH = 32; CFG_HEIGHT = 32; CFG_NUM_FMAP = 1; CFG_NUM_KERNEL = 6; CFG_KERN_SIZE = 5;
        #5 rst_n = 1;

        #20 KernRDStart = 1; KernRDWork = 1; KERN_VLD = 1;
        #3020 KernRDStart = 0; KernRDWork = 0; KERN_VLD = 0;

        #20 op_start = 1;
        #20 op_start = 0;

        while(busy) begin
            #20;
            if(PRE_TAKE_VLD) begin
                PRE_TAKE_RDY = 1;
                #20 PRE_TAKE_RDY = 0;
            end
        end

        #20 $stop;
    end

endmodule
