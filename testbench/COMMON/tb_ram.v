`timescale 1ns/100ps

module tb_ram;
	reg clk;
	reg cen;
	reg wen;
	reg [31:0] addr;
	reg [31:0] din;
	wire [31:0]dout;
	
	//space for testvectors
	reg [31:0] tv[0:63];
	
	//for iteration
	integer i;
	
	//ram instance
	ram uud(clk, cen, wen, addr, din, dout);
	
	//clock generation
	always #10 clk = ~clk;
	
	initial begin
		//$readmemh("./../../testvectors/ram_data.tv",tv); //load vectors from file
		$readmemh("../testvectors/ram_data.tv",tv); //load vectors from file
		
		#0 clk = 0; cen = 0; wen = 0; addr = 16'd0; din = 32'd0;//start from LOW
		#5;//wait 5ns
		
		//init to zero check
		#0 addr = 32'd0;
		for(i = 0; i < 16777215; i = i + 1) begin
			#0 cen = 1; wen = 0;
			#10;//wait for half cycle
			if(dout != 32'b0) begin
				$display("FAIL: Data not empty on Address %d", addr);
				$stop;
			end
			else begin
				$display("OK: Address %d Empty", addr);
			end
			#10 addr = addr + 1;
		end
		
		//data insertion
		#0 addr = 32'd0;
		for(i = 0; i < 64; i = i + 1) begin
			#0 cen = 1; wen = 1; din = tv[i];
			#10;//wait for half cycle
			#10 addr = addr + 1;
		end
		
		//data reading
		#0 addr = 32'd0;
		for(i = 0; i < 64; i = i + 1) begin
			#0 cen = 1; wen = 0;
			#10;//wait for half cycle
			if(dout != tv[i]) begin
				$display("FAIL: Data does not match on Address %d, Expected: %x  Result: %x", addr, tv[i], dout);
				$stop;
			end
			else begin
				$display("OK: Address %d Write/Read Success, Expected: %x  Result: %x", addr, tv[i], dout);
			end
			#10 addr = addr + 1;
		end
		
		//chip disable check
		#0 addr = 32'd0;
		for(i = 0; i < 64; i = i + 1) begin
			#0 cen = 0; wen = 1;
			#10;//wait for half cycle
			if(dout != 32'b0) begin
				$display("FAIL: Chip not disabled %d", addr);
				$stop;
			end
			else begin
				$display("OK: Chip disabled %d", addr);
			end
			#10 addr = addr + 1;
		end
		
		#0 $stop; //simulation end
		
	end
	
	
endmodule
