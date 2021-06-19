module tb_ReLU;

	reg clk, rst_n, en;
	reg [63:0] inImg;
	wire [63:0] outImg;

	//clock generation
	initial clk = 0;
	always #10 clk = ~clk;
	
	//Test unit
	ReLU uud(en, inImg, outImg);
	
	initial begin
		#5  rst_n = 0; en = 0;//reset
		#10 rst_n = 1;//done reset
		
		//Not enabled, positive
		#10 inImg = {16'h0205, 16'h63f1, 16'h0f47, 16'h005a};
		
		//Enabled, positive
		#20 en = 1;
		
		//Enabled, negative
		#20 inImg = {16'h9205, 16'hf3f1, 16'h8f47, 16'h805a};
		
		//Not enabled, negative
		#20 en = 0;

		//Not Enabled, pos neg
		#20 inImg = {16'h0205, 16'hf3f1, 16'h8f47, 16'h0f47};
		
		//Not enabled, negative
		#20 en = 1;
		
		#20 $stop;//wait for cycle and stop
		
	end
endmodule
