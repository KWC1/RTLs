module tb_Top_IDP;

	reg clk;
	reg rst_n;
	
	//RAM Controller Ports
	wire MEM_REQ;
	wire [31:0]MEM_ADDR;
	wire [3:0]MEM_CMD;
	reg  [31:0]MEM_DIN;
    reg  MEM_FIN;
	reg  MEM_VLD;
	reg  MEM_IDP_SEL;

	wire pxMem_RD_VLD;
	reg pxMem_RD_RDY;
	wire pxMem_RD_GRANT;
	reg pxMem_RD_REQ;
	reg [19:0] pxMem_RD_Addr;
	reg [3:0] pxMem_RD_burst;//(1-16)
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

    reg [31:0] CFG_READ_START_ADDR;//어디서부터 읽기 시작할건가?; Read Region과 Write Region은 매번 서로 교체된다.
    reg [8:0] CFG_WIDTH;
	reg [8:0] CFG_HEIGHT;
    reg [9:0] CFG_NUM_FMAP;


    //clock generation
	initial clk = 0;
	always #10 clk = ~clk;

    Top_IDP uud(clk, rst_n, MEM_REQ, MEM_ADDR, MEM_CMD, MEM_DIN, MEM_FIN, MEM_VLD, MEM_IDP_SEL, pxMem_RD_VLD, pxMem_RD_RDY, pxMem_RD_GRANT, pxMem_RD_REQ
    , pxMem_RD_Addr, pxMem_RD_burst, pxMem_in, track_read, d0_addr, d1_addr, d2_addr, d3_addr, d4_addr, d5_addr, d6_addr, d7_addr, IDP_START, IDP_STATUS
    , CFG_READ_START_ADDR, CFG_WIDTH, CFG_HEIGHT, CFG_NUM_FMAP);

    integer i;
    integer j;

    initial begin
        
        #0 rst_n = 0;
        #0 MEM_DIN = 32'habcd_dcba; MEM_FIN = 0; MEM_VLD = 1; MEM_IDP_SEL = 1;
        #0 pxMem_RD_RDY = 0; pxMem_RD_REQ = 0; pxMem_RD_Addr = 0; pxMem_RD_burst = 0;
        #0 track_read = 0;
        #0 IDP_START = 0;
        #0 CFG_READ_START_ADDR = 32'hffaa_aaff; CFG_WIDTH = 28; CFG_HEIGHT = 32; CFG_NUM_FMAP = 3;
        #5 rst_n = 1;
        #20;

        #20 IDP_START = 1;//idle -> cfg

        #20 IDP_START = 0;//cfg -> sm

        for(j = 0; j < CFG_HEIGHT; j = j + 1) begin
            for(i = 0; i < 6; i = i + 1) begin
                #60;
                #20 MEM_FIN = 1;
                #20 MEM_FIN = 0;
                #100;//sm -> ham finish
                #80;//ham finish -> wait
                #100 MEM_FIN = 1;
                #20 MEM_FIN = 0;
                #820;
                #20;
            end
            #20;
        end

        #0 $stop;
        
        #0 MEM_DIN = 32'habc3_abc3; MEM_FIN = 0; MEM_VLD = 1; MEM_IDP_SEL = 1;
        #0 pxMem_RD_RDY = 0; pxMem_RD_REQ = 0; pxMem_RD_Addr = 0; pxMem_RD_burst = 0;
        #0 track_read = 0;
        #0 IDP_START = 0;
        #0 CFG_READ_START_ADDR = 32'hffaa_aaff; CFG_WIDTH = 28; CFG_HEIGHT = 32; CFG_NUM_FMAP = 3;
        #20;

        #20 IDP_START = 1;//idle -> cfg

        #20 IDP_START = 0;//cfg -> sm

        #60;
        #20 MEM_FIN = 1;
        #20 MEM_FIN = 0;
        for(j = 0; j < CFG_HEIGHT; j = j + 1) begin
            for(i = 0; i < 6; i = i + 1) begin
                #100;//sm -> ham finish
                #80;//ham finish -> wait
                #100 MEM_FIN = 1;
                #20 MEM_FIN = 0;
                #820;
                #20;
            end
            #20;
        end

        #20 $stop;
    end

endmodule
