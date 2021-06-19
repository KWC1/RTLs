module tb_MCIDPCCM;

    reg clk;
	reg rst_n;
	
    wire pxMem_RD_VLD;
	wire pxMem_RD_GRANT;
	wire pxMem_RD_REQ;
	wire [19:0] pxMem_RD_Addr;
	wire [15:0] pxMem_in;

	reg track_read;//by idp
	wire [19:0] d0_addr;
	wire [19:0] d1_addr;
	wire [19:0] d2_addr;
	wire [19:0] d3_addr;
	wire [19:0] d4_addr;
	wire [19:0] d5_addr;
	wire [19:0] d6_addr;
	wire [19:0] d7_addr;

	reg IDP_START;
    wire IDP_STATUS;
	
	/* Memory Ports */
	wire [31:0] MEM_ADDR;
	wire [31:0] MEM_DOUT;
	wire [31:0] MEM_DIN;
	wire MEM_CEN;
	wire MEM_WR;
	
	/* From/To IDP */
	wire [3:0] IDP_CMD;
	wire [31:0] IDP_ADDR;
	wire IDP_REQ;
	wire MEM_IDP_SEL;
	
	/* From/To CCM */
	wire [3:0] CCM_CMD;
	wire [31:0] CCM_ADDR;
	wire CCM_REQ;
	wire MEM_CCM_SEL;
	
	/* From/To PRE */
	wire [3:0] PRE_CMD;
	wire [31:0] PRE_ADDR;
	wire PRE_REQ;
	wire MEM_PRE_SEL;
	
	/* PRE Module Write Buffering */
	wire PRE_WR_BUF;
	wire [31:0] PRE_DIN;
	
	/* From/To Top */
	wire [3:0] TOP_CMD;
	wire [31:0] TOP_ADDR;
	wire TOP_REQ;
	wire MEM_TOP_SEL;
	
	/* Data Out */
	wire [31:0] DOUT;
	wire MEM_VLD;
	wire MEM_FIN;

    assign TOP_REQ = 0;
    assign PRE_REQ = 0;

    reg CCM_START;
    wire CCM_STATUS;

    wire [511:0] MAC_OUT;//2 row = 32bits, 2 * 16 pixels = 512 bits
    reg PRE_TAKE_RDY;
    wire PRE_TAKE_VLD;

    reg [31:0] CFG_READ_START_ADDR;//어디서부터 읽기 시작할건가?; Read Region과 Write Region은 매번 서로 교체된다.
    reg [8:0] CFG_WIDTH;
	reg [8:0] CFG_HEIGHT;
    reg [9:0] CFG_NUM_FMAP;
    reg [9:0] CFG_NUM_KERNEL;
    reg [31:0] CFG_KERN_START_ADDR;
    reg [2:0] CFG_KERN_SIZE;

    //clock generation
	initial clk = 0;
	always #10 clk = ~clk;

    Top_IDP IDP(clk, rst_n, IDP_REQ, IDP_ADDR, IDP_CMD, DOUT, MEM_FIN, MEM_VLD, MEM_IDP_SEL, pxMem_RD_VLD, pxMem_RD_GRANT, pxMem_RD_REQ
    , pxMem_RD_Addr, pxMem_in, track_read, d0_addr, d1_addr, d2_addr, d3_addr, d4_addr, d5_addr, d6_addr, d7_addr, IDP_START, IDP_STATUS
    , CFG_READ_START_ADDR, CFG_WIDTH, CFG_HEIGHT, CFG_NUM_FMAP);

    Top_CCM CCM(clk, rst_n, CCM_START, CCM_STATUS, pxMem_RD_VLD, pxMem_RD_GRANT, pxMem_RD_REQ, pxMem_RD_Addr, pxMem_in, CCM_ADDR, CCM_CMD, DOUT, MEM_FIN, MEM_VLD, MEM_CCM_SEL
    , CCM_REQ, MAC_OUT, PRE_TAKE_RDY, PRE_TAKE_VLD, CFG_WIDTH, CFG_HEIGHT, CFG_NUM_KERNEL, CFG_KERN_START_ADDR, CFG_NUM_FMAP, CFG_KERN_SIZE);

    SimpleRAM RAM0(clk, MEM_CEN, MEM_WR, MEM_ADDR, MEM_DIN, MEM_DOUT);
    MemoryControl MC(clk, rst_n, MEM_ADDR, MEM_DOUT, MEM_DIN, MEM_CEN, MEM_WR, IDP_CMD, IDP_ADDR, IDP_REQ, MEM_IDP_SEL, CCM_CMD, CCM_ADDR, CCM_REQ, MEM_CCM_SEL, PRE_CMD, PRE_ADDR, PRE_REQ, MEM_PRE_SEL
    , PRE_WR_BUF, PRE_DIN, TOP_CMD, TOP_ADDR, TOP_REQ, TOP_IDP_SEL, DOUT, MEM_VLD, MEM_FIN);

    initial begin
        #0 rst_n = 0;
        #0 track_read = 0;
        #0 IDP_START = 0;
        #0 CFG_READ_START_ADDR = 32'h0000_0000; CFG_WIDTH = 32; CFG_HEIGHT = 32; CFG_NUM_FMAP = 1;
        #0 CFG_NUM_KERNEL = 6; CFG_KERN_START_ADDR = 32'h0000_0100; CFG_KERN_SIZE = 5;
        #5 rst_n = 1;

        #20 IDP_START = 1;//idle -> cfg
        #20 IDP_START = 0;//cfg -> sm

        while(IDP_STATUS) #20;

        /* 
        #20 CCM_START = 1; PRE_START = 1;
        #20 CCM_START = 0; PRE_START = 0;
        */

        #20 $stop;


        #20 CCM_START = 1;//idle -> cfg
        #20 CCM_START = 0;//cfg -> sm
        while(CCM_STATUS) begin
            #20;
            if(PRE_TAKE_VLD) begin
                PRE_TAKE_RDY = 1;
                #20 PRE_TAKE_RDY = 0;
            end
        end
        /* 
        #20 CCM_START = 1; PRE_START = 1;
        #20 CCM_START = 0; PRE_START = 0;
        */

        #20 $stop;

    end

endmodule
