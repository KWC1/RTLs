module tb_HammingWeight;
    reg clk;
    reg rst_n;
    reg op_start;
    reg [15:0] din;

    wire hw_vld;
    wire [4:0] hamW;

	//clock generation
	initial clk = 0;
	always #10 clk = ~clk;
	
	//Test unit
	HammingWeight uud(clk, rst_n, op_start, din, hw_vld, hamW);
	
	initial begin
		#5  rst_n = 0; op_start = 0;
		#10 rst_n = 1;//done reset
		
		//Hamming dist of 1 and start
		#10 din = 16'd1; op_start = 1;
        #10 op_start = 0;
        #80;//wait 4 cycle
        #20;

        //Hamming dist of 9 and start
		#10 din = 16'd27834; op_start = 1;
        #10 op_start = 0;
        #80;//wait 4 cycle
		#20;

        //Hamming dist of 9 and start
		#10 din = 16'hffff; op_start = 1;
        #10 op_start = 0;
        #80;//wait 4 cycle
		#20 $stop;//wait for cycle and stop
		
	end
endmodule
