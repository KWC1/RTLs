module PxAllocator(
    input clk,
    input rst_n,

    input push_col,
    input pop_col,
    input flush,
    
    input [79:0] px_row, //0 - 1023
	input [127:0] px_col, //0-65535 for FC support
    input [127:0] dec_px_in,

    input  [7:0] dec_enabled,//how much decoders enabled?
    input  [7:0] px_VLD,
    output reg px_RDY,
    output [127:0] out_pixels//8 pixels at once
);

    //Just a big fifo with wide memory

    //카운터의 칼럼 값과 좌표는 매치가 되어야 함. 즉, 디코더에서 뱉은게 0인 경우 Skip이 필요
    reg [15:0] col_cnt, next_col_cnt;

    wire [9:0] d0_row, d1_row, d2_row, d3_row, d4_row, d5_row, d6_row, d7_row;
    wire [15:0] d0_col, d1_col, d2_col, d3_col, d4_col, d5_col, d6_col, d7_col;
    assign {d0_row, d1_row, d2_row, d3_row, d4_row, d5_row, d6_row, d7_row} = px_row;
    assign {d0_col, d1_col, d2_col, d3_col, d4_col, d5_col, d6_col, d7_col} = px_col;

    //each column is used only once
    reg [15:0] r0_values[0:15];//space for one segment
    reg [15:0] r1_values[0:15];
    reg [15:0] r2_values[0:15];
    reg [15:0] r3_values[0:15];
    reg [15:0] r4_values[0:15];
    reg [15:0] r5_values[0:15];
    reg [15:0] r6_values[0:15];
    reg [15:0] r7_values[0:15];

    reg [3:0] tail, next_tail;
    reg [3:0] head, next_head;
    reg [4:0] dat_cnt, next_dat_cnt;

    wire [127:0] colBufWire;
    assign colBufWire = {r0_values[tail], r1_values[tail], r2_values[tail], r3_values[tail], r4_values[tail], r5_values[tail], r6_values[tail], r7_values[tail]};
    assign out_pixels = {r0_values[head], r1_values[head], r2_values[head], r3_values[head], r4_values[head], r5_values[head], r6_values[head], r7_values[head]};

    reg [2:0] state, next_state;

    wire [7:0] decoderColChkUp;
    assign decoderColChkUp[0] = (col_cnt == d0_col) & (dec_enabled[0]);//disabled = 0, column not match = 0
    assign decoderColChkUp[1] = (col_cnt == d1_col) & (dec_enabled[1]);
    assign decoderColChkUp[2] = (col_cnt == d2_col) & (dec_enabled[2]);
    assign decoderColChkUp[3] = (col_cnt == d3_col) & (dec_enabled[3]);
    assign decoderColChkUp[4] = (col_cnt == d4_col) & (dec_enabled[4]);
    assign decoderColChkUp[5] = (col_cnt == d5_col) & (dec_enabled[5]);
    assign decoderColChkUp[6] = (col_cnt == d6_col) & (dec_enabled[6]);
    assign decoderColChkUp[7] = (col_cnt == d7_col) & (dec_enabled[7]);

    localparam STA_IDLE = 3'd0;
    localparam STA_SKIP_ZERO_PIXELS = 3'd1;
    localparam STA_IF_SKIP_MORE_ZERO = 3'd2;
    localparam STA_SAVE_PIXELS = 3'd3;
    localparam STA_POP_COLUMNS = 3'd4;
    localparam STA_FLUSH_PARAMS = 3'd5;

    always @(posedge clk, negedge rst_n) begin
       if(~rst_n) begin
           state <= 3'd0;
           tail <= 4'd0;
           head <= 4'd0;
           dat_cnt <= 5'd0;
           col_cnt <= 16'd0;    
       end
       else begin
            state <= next_state;
            tail <= next_tail;
            head <= next_head;
            dat_cnt <= next_dat_cnt;
            col_cnt <= next_col_cnt;
       end
    end

    always @(posedge clk) begin
        case(state)
            STA_SKIP_ZERO_PIXELS: begin
                if(decoderColChkUp[0]) r0_values[tail] <= 16'd0;
                if(decoderColChkUp[1]) r1_values[tail] <= 16'd0;
                if(decoderColChkUp[2]) r2_values[tail] <= 16'd0;
                if(decoderColChkUp[3]) r3_values[tail] <= 16'd0;
                if(decoderColChkUp[4]) r4_values[tail] <= 16'd0;
                if(decoderColChkUp[5]) r5_values[tail] <= 16'd0;
                if(decoderColChkUp[6]) r6_values[tail] <= 16'd0;
                if(decoderColChkUp[7]) r7_values[tail] <= 16'd0;
            end
            STA_SAVE_PIXELS: begin
                out_pixels <= dec_px_in;
            end
        endcase
    end

    always @(state) begin
        case(state)
            STA_IDLE: begin
                if(flush) next_state <= STA_FLUSH_PARAMS;
                else if(push_col) begin
                    if(&(px_VLD | ~dec_enabled)) begin//디코더 준비 완료시
                        if(dat_cnt == 4'd16) next_state <= STA_IDLE;//가득 찬 경우 무시
                        else if(|decoderColChkUp) next_state <= STA_SAVE_PIXELS;//저장할게 하나 이상 있으면
                        else next_state <= STA_SKIP_ZERO_PIXELS;//현재 내가 가지고 있는 열의 수랑 디코더중에 한놈이라도 뱉는 열의 수가 맞지 않을때(예: 제로패딩, 0스킵)
                    end
                    else next_state <= STA_IDLE;//디코더 아직 준비 안됨
                end
                else if(pop_col) next_state <= STA_POP_COLUMNS;
                else next_state <= STA_IDLE;
            end
            STA_SKIP_ZERO_PIXELS: begin
                next_state <= STA_IF_SKIP_MORE_ZERO;
            end
            STA_IF_SKIP_MORE_ZERO: begin
                if(dat_cnt == 5'd16) next_state <= STA_IDLE;//가득 참
                else if(|decoderColChkUp) next_state <= STA_SAVE_PIXELS;//저장할게 하나 이상 있으면
                else next_state <= STA_SKIP_ZERO_PIXELS;//현재 내가 가지고 있는 열의 수랑 디코더중에 한놈이라도 뱉는 열의 수가 맞지 않을때(예: 제로패딩, 0스킵)
            end
            STA_SAVE_PIXELS: begin
                next_state <= STA_IDLE;
            end
            STA_POP_COLUMNS: begin
                if(pop_col) next_state <= STA_POP_COLUMNS;
                else next_state <= STA_IDLE;
            end
            STA_FLUSH_PARAMS: begin
                next_state <= STA_IDLE;
            end
            default: begin
                next_state <= 3'dx;
            end
        endcase
    end

    always @(state) begin
        case(state)
            STA_IDLE: begin
                next_col_cnt <= col_cnt;
                px_RDY <= 1'd0;
                next_head <= head;
                next_tail <= tail;
                next_dat_cnt <= dat_cnt;
            end
            STA_SKIP_ZERO_PIXELS: begin
                next_col_cnt <= col_cnt + 16'd1;
                px_RDY <= 1'd0;
                next_head <= head;
                next_tail <= tail;
                next_dat_cnt <= dat_cnt + 5'd1;
            end
            STA_IF_SKIP_MORE_ZERO: begin
                next_col_cnt <= col_cnt;
                px_RDY <= 1'd0;
                next_head <= head;
                next_tail <= tail;
                next_dat_cnt <= dat_cnt;
            end
            STA_SAVE_PIXELS: begin
                next_col_cnt <= col_cnt + 16'd1;
                px_RDY <= 1'd1;
                next_head <= head;
                next_tail <= tail;
                next_dat_cnt <= dat_cnt + 5'd1;
            end
            STA_POP_COLUMNS: begin
                next_col_cnt <= col_cnt;
                px_RDY <= 1'd0;
                next_head <= head + 1'd1;
                next_tail <= tail;
                next_dat_cnt <= dat_cnt - 5'd1;
            end
            STA_FLUSH_PARAMS: begin
                next_col_cnt <= 5'd0;
                px_RDY <= 1'd0;
                next_head <= 4'd0;
                next_tail <= 4'd0;
                next_dat_cnt <= 5'd0;
            end
            default: begin
                next_col_cnt <= 16'dx;
                px_RDY <= 1'dx;
                next_head <= 4'dx;
                next_tail <= 4'dx;
                next_dat_cnt <= 5'dx;
            end
        endcase
    end

endmodule
