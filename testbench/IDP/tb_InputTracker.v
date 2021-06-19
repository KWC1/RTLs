module tb_InputTracker;
	reg clk;
	reg rst_n;

	reg [19:0] din;
	reg read;
	reg write;

	wire [19:0] d0_addr;
	wire [19:0] d1_addr;
	wire [19:0] d2_addr;
	wire [19:0] d3_addr;
	wire [19:0] d4_addr;
	wire [19:0] d5_addr;
	wire [19:0] d6_addr;
	wire [19:0] d7_addr;

	//clock generation
	initial clk = 0;
	always #10 clk = ~clk;
	
	//Test unit
	InputTracker uud(clk, rst_n, din, read, write, d0_addr, d1_addr, d2_addr, d3_addr, d4_addr, d5_addr, d6_addr, d7_addr);
	
    integer i;

	initial begin
		#0  rst_n = 0; read = 0; write = 0;
		#5 rst_n = 1;//done reset
		
		//Insert 256 address
        for(i = 0; i < 256; i=i+1) begin
            #0 din = i+1; read = 1'd0; write = 1'd1;
            #20;
        end

        //Read 256 address
        for(i = 0; i < 128; i=i+1) begin
            #0 din = 0; read = 1'd1; write = 1'd0;
            #20;
        end

        //Insert 512 address
        for(i = 0; i < 512; i=i+1) begin
            #0 din = i+1; read = 1'd0; write = 1'd1;
            #20;
        end

        //Read 512 address
        for(i = 0; i < 256; i=i+1) begin
            #0 din = 0; read = 1'd1; write = 1'd0;
            #20;
        end

        #20 $stop;

	end
endmodule