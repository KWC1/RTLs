module KernelReader(
    input clk,
    input rst_n,

    output [31:0]MEM_ADDR,
	output reg [3:0]MEM_CMD,
	input      [31:0]MEM_DIN,
    input      MEM_FIN,
	input      MEM_VLD,
	input      MEM_CCM_SEL,
    output reg CCM_REQ,

    input op_start,
    output KernRDWork,

    output [15:0] KERN_OUT,
    output reg KERN_VLD,

    input [31:0] CFG_KERN_START_ADDR,
    input [9:0] CFG_NUM_FMAP,
    input [9:0] CFG_NUM_KERN,
    input [2:0] CFG_KERN_SIZE
);

    //Kernel은 특정 주소 영역에 순서대로 싹 저장되어 있음
    //한번에 읽어야 할 총 데이터 = 16bit * KER_SIZE * KER_SIZE * Input Channel 개수 * Kernel Set 개수 + Kernel Set 개수

    reg [31:0] memAddr, next_memAddr;
    reg [4:0] read_params, next_read_params;
    reg [23:0] left_params, next_left_params;
    reg [2:0] state, next_state;

    reg memBufRead, memBufWrite;
    wire [15:0] memBufout; wire [4:0] memBufcnt;
    SimpleFIFO32to16 memRdBuffer(clk, rst_n, memBufRead, memBufWrite, MEM_DIN, memBufout, , , , , , , memBufcnt);

    assign MEM_ADDR = memAddr;
    assign KERN_OUT = memBufout;

    localparam STA_IDLE = 3'd0;
    localparam STA_LOAD_CFG = 3'd1;

    localparam STA_CALC_PARAM_TO_READ = 3'd2;//읽을 개수 계산
    
    //메모리 읽기
    localparam STA_LD_PX_GRANT_REQ = 3'd3;
    localparam STA_LD_PX_CMD = 3'd4;
    localparam STA_LD_PX_WAIT = 3'd5;
    localparam STA_LD_PX_WRT_BUFFER = 3'd6;//32to16 FIFO에 Write

    localparam STA_WRITE_KERNEL = 3'd7;//다시 밖으로 준다

    assign KernRDWork = (state != STA_IDLE);

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 3'd0;
            left_params <= 24'd0;
            read_params <= 5'd0;
            memAddr <= 32'd0;
        end
        else begin
            state <= next_state;
            left_params <= next_left_params;
            read_params <= next_read_params;
            memAddr <= next_memAddr;
        end
    end

    always @(*) begin
        case(state)
            STA_IDLE: begin
                if(op_start) next_state <= STA_LOAD_CFG;
                else next_state <= STA_IDLE;
            end 
            STA_LOAD_CFG: next_state <= STA_CALC_PARAM_TO_READ;
            STA_CALC_PARAM_TO_READ: next_state <= STA_LD_PX_GRANT_REQ;
            STA_LD_PX_GRANT_REQ: begin
                if(MEM_CCM_SEL) next_state <= STA_LD_PX_CMD;
                else next_state <= STA_LD_PX_GRANT_REQ;
            end
            STA_LD_PX_CMD: next_state <= STA_LD_PX_WAIT;
            STA_LD_PX_WAIT: begin
                if(MEM_VLD) next_state <= STA_LD_PX_WRT_BUFFER;
                else next_state <= STA_LD_PX_WAIT;
            end
            STA_LD_PX_WRT_BUFFER: begin
                if(MEM_FIN) next_state <= STA_WRITE_KERNEL;
                else next_state <= STA_LD_PX_WRT_BUFFER;
            end
            STA_WRITE_KERNEL: begin
                if(memBufcnt == 5'd1) begin
                    if(left_params == 24'd0) next_state <= STA_IDLE;
                    else next_state <= STA_CALC_PARAM_TO_READ;
                end
                else next_state <= STA_WRITE_KERNEL;
            end
            default: next_state <= 3'dx;
        endcase
    end

    wire [4:0]aab = read_params;
    always @(*) begin
        case(state)
            STA_IDLE: begin
                next_left_params <= left_params;
                next_read_params <= read_params;
                next_memAddr <= memAddr;
                MEM_CMD <= 4'd0;
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
            end 
            STA_LOAD_CFG: begin
                next_left_params <= CFG_NUM_FMAP * CFG_NUM_KERN * CFG_KERN_SIZE * CFG_KERN_SIZE + CFG_NUM_KERN;
                next_memAddr <= CFG_KERN_START_ADDR;
                next_read_params <= read_params;
                MEM_CMD <= 4'd0;
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
            end
            STA_CALC_PARAM_TO_READ: begin
                next_left_params <= (left_params < 16)?0:left_params - 16;
                next_read_params <= (left_params < 16)?left_params:15;
                next_memAddr <= memAddr;
                MEM_CMD <= 4'd0;
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
            end
            STA_LD_PX_GRANT_REQ: begin
                next_left_params <= left_params;
                next_read_params <= read_params;
                next_memAddr <= memAddr;
                MEM_CMD <= {1'b0, aab[3:1]};
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd1;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
            end
            STA_LD_PX_CMD: begin
                next_left_params <= left_params;
                next_read_params <= read_params;
                next_memAddr <= memAddr;
                MEM_CMD <= {1'b0, aab[3:1]};
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd1;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
            end
            STA_LD_PX_WAIT: begin
                next_left_params <= left_params;
                next_read_params <= read_params;
                next_memAddr <= memAddr;
                MEM_CMD<= {1'b0, aab[3:1]};
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd1;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
            end
            STA_LD_PX_WRT_BUFFER: begin
                next_left_params <= left_params;
                next_read_params <= read_params;
                next_memAddr <= memAddr;
                MEM_CMD <= 4'd0;
                KERN_VLD <= 1'd0;
                CCM_REQ <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd1;
            end
            STA_WRITE_KERNEL: begin
                next_left_params <= left_params;
                next_read_params <= read_params;
                next_memAddr <= memAddr;
                MEM_CMD <= 4'd0;
                KERN_VLD <= 1'd1;
                CCM_REQ <= 1'd0;
                memBufRead <= 1'd1;
                memBufWrite <= 1'd0;
            end
            default: begin
                next_left_params <= 24'dx;
                next_read_params <= 24'dx;
                next_memAddr <= 32'dx;
                MEM_CMD <= 4'dx;
                KERN_VLD <= 1'dx;
                CCM_REQ <= 1'dx;
                memBufRead <= 1'dx;
                memBufWrite <= 1'dx;
            end
        endcase
    end

endmodule