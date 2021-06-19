module tb_SMDecoder;
	reg clk;
	reg rst_n;

	reg [15:0] start_address;
	reg [9:0] start_row;
	reg [15:0] start_col;

	reg op_start;
	wire busy;

	reg pxMem_RD_VLD;
	wire pxMem_RD_RDY;
	reg pxMem_GRANT;
	wire pxMem_RD_REQ;
	wire [15:0] pxMem_Addr;
	wire [4:0] px_burst;//(1-16)
	reg [15:0] pxMem_in;

	reg px_RDY;
	wire px_VLD;
	wire [15:0] px_value_out;
	wire [9:0] px_row;
	wire [15:0] px_col;//0-65535 for FC support

    //clock generation
	initial clk = 0;
	always #10 clk = ~clk;

    //Test unit
    SMDecoder uud(clk, rst_n, start_address, start_row, start_col, op_start, busy, pxMem_RD_VLD, pxMem_RD_RDY, pxMem_GRANT
    , pxMem_RD_REQ, pxMem_Addr, px_burst, pxMem_in, px_RDY, px_VLD, px_value_out, px_row, px_col);

    integer i;

    localparam test_sm = 16'b0000_1111_0101_0101;
    reg [15:0] test_nzvl[0:15];

    initial begin
        $readmemh("I:/UserData/Desktop/RTL-NNA/testbench/rand_data_16.tv", test_nzvl);
    end

    initial begin
        #0 rst_n = 1'd0;
        #0 start_address = 16'hf7f7; start_row = 10'd600; start_col = 16'd5000;
        #0 op_start = 1'd0;
        #0 pxMem_RD_VLD = 1'd0; pxMem_GRANT = 1'd0; pxMem_in = 16'hf0f0;
        #0 px_RDY = 1'd0;
        #5 rst_n = 1'd1;

        //Simulate no padding
        #20 op_start = 1;//idle -> setup
        #20 op_start = 0;//setup -> wait grant
        #20 pxMem_GRANT = 1'd1;//wait grant -> wait grant
        #20;//wait grant -> command
        #20 pxMem_in = test_sm; pxMem_RD_VLD = 1'd1;
        #20 pxMem_RD_VLD = 1'd0; pxMem_GRANT = 1'd0;
        #80;//wait hamming
        #20;//wait hamming -> save
        #20;//save -> wait grant
        #20 pxMem_GRANT = 1'd1;//wait grant -> wait grant
        #20;//wait grant -> command
        for(i=0; i < 8; i=i+1) begin
            #20 pxMem_in = test_nzvl[i]; pxMem_RD_VLD = 1'd1;
        end
        #20 px_RDY = 1'd1;
        #400;//move
        #20 px_RDY = 1'd0;

        //Simulate empty SM
        #20 op_start = 1;//idle -> setup
        #20 op_start = 0;//setup -> wait grant
        #20 pxMem_GRANT = 1'd1;//wait grant -> wait grant
        #20;//wait grant -> command
        #20 pxMem_in = 16'd0; pxMem_RD_VLD = 1'd1;
        #20 pxMem_RD_VLD = 1'd0; pxMem_GRANT = 1'd0;
        #80;//wait hamming
        #20;//wait hamming -> save
        #20 px_RDY = 1'd0;

        #20 $stop;
    end

endmodule
