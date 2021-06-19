module tb_PxMemory;
    reg clk;
    reg rst_n;

    reg [2:0] decoder_used;//how many decoders active? 1-8

    wire pxMem_RD_VLD;
	reg [7:0] pxMem_RD_RDY;
	wire [7:0] pxMem_RD_GRANT;
	reg [7:0] pxMem_RD_REQ;
	reg [159:0] pxMem_RD_Addr;
	reg [31:0] pxMem_RD_burst;//(1-16)
	wire [15:0] pxMem_in;

    wire pxMem_WR_RDY;
    reg pxMem_WR_VLD;
	wire pxMem_WR_GRANT;
	reg pxMem_WR_REQ;
    reg [19:0] pxMem_WR_Addr;
	reg [3:0] pxMem_WR_burst;//(1-16)
	reg [15:0] pxMem_out;

	//clock generation
	initial clk = 0;
	always #10 clk = ~clk;
	
	//Test unit
	PxMemory uud(clk, rst_n, decoder_used, pxMem_RD_VLD, pxMem_RD_RDY, pxMem_RD_GRANT, pxMem_RD_REQ, pxMem_RD_Addr, pxMem_RD_burst, pxMem_in,
                 pxMem_WR_RDY, pxMem_WR_VLD, pxMem_WR_GRANT, pxMem_WR_REQ, pxMem_WR_Addr, pxMem_WR_burst, pxMem_out);
	
    integer i;

	initial begin
		#0 decoder_used = 3'd2; pxMem_RD_RDY = 8'd0; pxMem_RD_REQ = 8'b0000_0000; pxMem_RD_Addr = 160'd0; pxMem_RD_burst = 32'd0;
        #0 pxMem_WR_VLD = 1'd0; pxMem_WR_REQ = 1'd0; pxMem_WR_Addr = 20'd0; pxMem_WR_burst = 4'd0; pxMem_out = 16'd0;
		#0 rst_n = 0;
		#5 rst_n = 1;//done reset
		
		//Write 1 data
        #0 pxMem_WR_VLD = 1'd0; pxMem_WR_REQ = 1'd1; pxMem_WR_Addr = 20'd0; pxMem_WR_burst = 4'd0; pxMem_out = 16'he96a;
        #20;//idle->cmd
        #20;//cmd->burst
        #20;//burst->burst
        #0 pxMem_WR_VLD = 1'd1; pxMem_WR_REQ = 1'd0; pxMem_WR_Addr = 20'd0; pxMem_WR_burst = 4'd0; pxMem_out = 16'he96a;
        #20;//handshake, burst -> idle

		//Write 8 data
        #0 pxMem_WR_VLD = 1'd0; pxMem_WR_REQ = 1'd1; pxMem_WR_Addr = 20'd16; pxMem_WR_burst = 4'd7; pxMem_out = 16'he96a;
        #40; //idle -> cmd -> burst
        for(i = 0; i < 8; i=i+1) begin
            #0 pxMem_WR_VLD = 1'd1; pxMem_WR_REQ = 1'd1; pxMem_WR_Addr = 20'd16; pxMem_WR_burst = 4'd0; pxMem_out = 16'he96a + i;
            #20;//consume cycle
        end

		//Write 16 data
        #0 pxMem_WR_VLD = 1'd0; pxMem_WR_REQ = 1'd1; pxMem_WR_Addr = 20'd0; pxMem_WR_burst = 4'd15; pxMem_out = 16'he96a;
        #40; //idle -> cmd -> burst
        for(i = 0; i < 16; i=i+1) begin
            #0 pxMem_WR_VLD = 1'd1; pxMem_WR_REQ = 1'd0; pxMem_WR_Addr = 20'd0; pxMem_WR_burst = 4'd0; pxMem_out = 16'hf000 + i;
            #20;//consume cycle
        end

        //Non valid decoder request
        #0; pxMem_RD_RDY = 8'b0000_0000; pxMem_RD_REQ = 8'b0000_0111; pxMem_RD_Addr = 160'd0; pxMem_RD_burst = 32'd0;
        #20; //should not change state

		//Read 3 data as decoder 1
        #0; pxMem_RD_RDY = 8'b0000_0000; pxMem_RD_REQ = 8'b1100_0000; pxMem_RD_Addr = 160'd0; pxMem_RD_burst = {4'd2, 28'd0};
        #20; //idle -> cmd
        #20; pxMem_RD_RDY = 8'b1000_0000; //cmd -> burst
        #60; //read read idle

        //Non valid decoder request (non-order)
        #0; pxMem_RD_RDY = 8'b0000_0000; pxMem_RD_REQ = 8'b1000_0000; pxMem_RD_Addr = 160'd0; pxMem_RD_burst = 32'd0;
        #20; //should not change state

		//Read 6 data as decoder 2
        #0; pxMem_RD_RDY = 8'b0000_0000; pxMem_RD_REQ = 8'b1100_0000; pxMem_RD_Addr = 160'd0; pxMem_RD_burst = {4'd2, 4'd5, 24'd0};
        #20; //idle -> cmd
        #20; pxMem_RD_RDY = 8'b0100_0000; //cmd -> burst
        #120; //read read idle

        #20 $stop;

	end
endmodule
