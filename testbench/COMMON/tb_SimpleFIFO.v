`timescale 1ns/100ps

module tb_SimpleFIFO;
	reg clk; /* Clock */
	reg reset_n; /* Active Low Reset */
	reg rd_en; /* Read Enable */
	reg wr_en; /* Write Enable */
	reg [31:0] d_in; /* Data In */
	wire [31:0] d_out; /* Data Out */
	wire full; /* Full Flag */
	wire empty; /* Empty Flag */
	wire wr_ack; /* Write Acknowledge Flag */
	wire wr_err; /* Write Error Flag */
	wire rd_ack; /* Read Acknowledge Flag */
	wire rd_err; /* Read Error Flag */
	wire [4:0] data_count; /* Data Count Vector */
	
	SimpleFIFO UUD(clk, reset_n, rd_en, wr_en, d_in, d_out, full, empty, wr_ack, wr_err, rd_ack, rd_err, data_count);
	
	always #10 clk = ~clk;
	
	initial begin
	#0 clk = 0; reset_n = 0; rd_en = 0; wr_en = 0; d_in = 32'h0000_0000;//init with reset
	#2 reset_n = 1;//reset end
	#3 wr_en = 1;//write enable
	#1 d_in = 32'h6b3c_3ad9;//0
	#20 d_in = 32'hf414_ecaa;//1
	#20 d_in = 32'hd55a_0c94;//2
	#20 d_in = 32'h1c9f_fec6;//3
	#20 d_in = 32'h20af_b913;//4
	#20 d_in = 32'h1a6b_d0b2;//5
	#20 d_in = 32'h2ab6_c1da;//6
	#20 d_in = 32'hefb3_8994;//7
	#20 d_in = 32'hc9bb_a56a;//8
	#20 d_in = 32'h4327_ef7b;//9
	#20 d_in = 32'h0d6b_edf6;//10
	#20 d_in = 32'h7d35_dbee;//11
	#20 d_in = 32'hcb96_72b6;//12
	#20 d_in = 32'hacc0_2fe5;//13
	#20 d_in = 32'ha299_b552;//14
	#20 d_in = 32'hc3ed_57cf;//15
	#20 d_in = 32'h1721_3d35;//already full, this write will fail
	#20 d_in = 32'h8c77_6fa6;//already full, this write will fail
	#20 wr_en = 0; rd_en = 0;//go nop state
	#20 wr_en = 1; rd_en = 1;//go nop state
	#20 wr_en = 0; rd_en = 1;//read
	#120 wr_en = 1; rd_en = 0; d_in = 32'h80ae_f943;//6 read test and write 5 more
	#20;
	#20 d_in = 32'h87bd_2c7b;
	#20 d_in = 32'ha938_5939;
	#20 d_in = 32'he8e5_6cf4;
	#20 d_in = 32'hc2cd_2a56; wr_en = 0; rd_en = 1;
	#700;//7 read will success, other read will fail
	#10 $stop;//end
	end
	
endmodule
