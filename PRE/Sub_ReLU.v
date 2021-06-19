/*
	ReLU function for NNAccelerator
	Author: SooHyun Kim (soohyunkim@kw.ac.kr)
*/

module ReLU(
	input en,
	input  [63:0] inImg,
	output [63:0] outImg
	);
	
	wire [63:0] resultImg;
	
	//Can process up to 4 pixels
	assign resultImg = (en)?{inImg[63]?16'd0:inImg[63:48], inImg[47]?16'd0:inImg[47:32],inImg[31]?16'd0:inImg[31:16],inImg[15]?16'd0:inImg[15:0]}:inImg;
	assign outImg = resultImg;

endmodule
