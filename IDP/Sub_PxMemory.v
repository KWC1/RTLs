module PxMemory(
    input clk,
    input rst_n,

    output reg pxMem_RD_VLD,
	output reg pxMem_RD_GRANT,
	input pxMem_RD_REQ,
	input [19:0] pxMem_RD_Addr,
	output [15:0] pxMem_in,

    output reg pxMem_WR_RDY,
    input pxMem_WR_VLD,
	output reg pxMem_WR_GRANT,
	input pxMem_WR_REQ,
    input [19:0] pxMem_WR_Addr,
	input [3:0] pxMem_WR_burst,//(1-16)
	input [15:0] pxMem_out
);

    reg [15:0] PxMEM[0:524287];//Can save one whole decoded image

    reg [2:0] state, next_state;
    reg [19:0] addr, next_addr;
    reg [3:0] burst_len, next_burst_len;

    localparam STA_IDLE = 3'd0;
    
    localparam STA_READ_MODE = 3'd1;

    localparam STA_WRITE_GET_CMD = 3'd2;
    localparam STA_WRITE_BURST = 3'd3;

    assign pxMem_in = PxMEM[pxMem_RD_Addr];

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 3'd0;
            addr <= 20'd0;
            burst_len <= 4'd0;
        end
        else begin
            state <= next_state;
            addr <= next_addr;
            burst_len <= next_burst_len;
        end
    end

    always @(posedge clk) begin
        if(state == STA_WRITE_BURST) begin
            if(pxMem_WR_VLD) PxMEM[addr] <= pxMem_out;
        end
    end

    always @(*) begin
        case(state)
            STA_IDLE: begin
                if(pxMem_WR_REQ) next_state <= STA_WRITE_GET_CMD;
                else if(pxMem_RD_REQ) next_state <= STA_READ_MODE;
                else next_state <= STA_IDLE;
            end
            STA_READ_MODE: begin
                if(pxMem_RD_REQ) next_state <= STA_READ_MODE;
                else next_state <= STA_IDLE;
            end
            STA_WRITE_GET_CMD: begin
                next_state <= STA_WRITE_BURST;
            end
            STA_WRITE_BURST: begin
                if(pxMem_WR_VLD) begin
                    if(burst_len == 4'd0) next_state <= STA_IDLE;
                    else next_state <= STA_WRITE_BURST;
                end
                else begin
                    next_state <= STA_WRITE_BURST;
                end
            end
            default: begin
                next_state <= 3'dx;
            end
        endcase
    end

    always @(*) begin
        case(state)
            STA_IDLE: begin
                pxMem_RD_VLD <= 1'd0;
                pxMem_WR_RDY <= 1'd0;
                pxMem_WR_GRANT <= 1'd0;
                pxMem_RD_GRANT <= 1'd0;
                next_burst_len <= burst_len;
                next_addr <= addr;
            end
            STA_READ_MODE: begin
                pxMem_RD_VLD <= 1'd1;
                pxMem_WR_RDY <= 1'd0;
                pxMem_WR_GRANT <= 1'd0;
                pxMem_RD_GRANT <= 1'd1;
                next_burst_len <= burst_len;
                next_addr <= addr;
            end
            STA_WRITE_GET_CMD: begin
                pxMem_RD_VLD <= 1'd0;
                pxMem_WR_RDY <= 1'd0;
                pxMem_WR_GRANT <= 1'd1;
                pxMem_RD_GRANT <= 1'd0;
                next_burst_len <= pxMem_WR_burst;
                next_addr <= pxMem_WR_Addr;
            end
            STA_WRITE_BURST: begin
                pxMem_RD_VLD <= 1'd0;
                pxMem_WR_RDY <= 1'd1;
                pxMem_WR_GRANT <= 1'd1;
                pxMem_RD_GRANT <= 1'd0;
                if(pxMem_WR_VLD) begin
                    next_burst_len <= burst_len - 4'd1;
                    next_addr <= addr + 20'd1;
                end
                else begin
                    next_burst_len <= burst_len;
                    next_addr <= addr;
                end
            end
            default: begin
                pxMem_RD_VLD <= 1'dx;
                pxMem_WR_RDY <= 1'dx;
                pxMem_WR_GRANT <= 1'dx;
                pxMem_RD_GRANT <= 1'dx;
                next_burst_len <= 4'dx;
                next_addr <= 20'dx;
            end
        endcase
    end

endmodule
	