module SimpleRAM(
	input clk,
	input cen,
	input wen,
	input [31:0] addr,
	input [31:0] din,
	output reg [31:0] dout
	);
	
	localparam SZ_MEM = 32'd16777216;
	
	reg [7:0] mem [0:SZ_MEM-1];//memory variable #1 16MB

	integer i;//for loop

	//memory initialization
	initial begin
		//for(i = 0; i < SZ_MEM; i = i+1)
		//	mem[i] <= 8'd0;
		$readmemh("I:/UserData/Desktop/RTL-NNA/testbench/rand_data_8.tv", mem);
	end
	
	//do job by enable signal
	always @(posedge clk) begin
			case ({cen, wen})
				2'b00://chip disabled
					dout <= 32'd0;
				2'b01://chip disabled
					dout <= 32'd0;
				2'b10://chip enabled, write disabled
					dout <= {mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]};
				2'b11: begin//chip enabled, write enabled
					dout <= 32'd0;
					{mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]} <= din;
				end
				default://unknown
					dout <= 32'dx;
			endcase
	end
	
endmodule
	