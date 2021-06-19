module CCMClusterControl(
    input clk,
    input rst_n,

    input op_start,
    output busy,

    input KernRDStart,
    input KernRDWork,
    input [15:0] KERN_OUT,
    input KERN_VLD,

	input pxMem_RD_VLD,
	input pxMem_RD_GRANT,
	output reg pxMem_RD_REQ,
	output [19:0] pxMem_RD_Addr,
	input [15:0] pxMem_in,

    input [19:0] row0_addr,

    output [511:0] MAC_OUT,//2 row = 32bits, 2 * 16 pixels = 512 bits
    input PRE_TAKE_RDY,
    output reg PRE_TAKE_VLD,

    input [8:0] CFG_WIDTH,
	input [8:0] CFG_HEIGHT,
    input [9:0] CFG_NUM_FMAP,
    input [9:0] CFG_NUM_KERNEL,
    input [2:0] CFG_KERN_SIZE
);

    reg [15:0] MAC_CLK_GATE;
    always@(CFG_NUM_KERNEL) begin
        case(CFG_NUM_KERNEL)
            10'd0:   MAC_CLK_GATE <= 16'b0000_0000_0000_0000;
            10'd1:   MAC_CLK_GATE <= 16'b1000_0000_0000_0000;
            10'd2:   MAC_CLK_GATE <= 16'b1100_0000_0000_0000;
            10'd3:   MAC_CLK_GATE <= 16'b1110_0000_0000_0000;
            10'd4:   MAC_CLK_GATE <= 16'b1111_0000_0000_0000;
            10'd5:   MAC_CLK_GATE <= 16'b1111_1000_0000_0000;
            10'd6:   MAC_CLK_GATE <= 16'b1111_1100_0000_0000;
            10'd7:   MAC_CLK_GATE <= 16'b1111_1110_0000_0000;
            10'd8:   MAC_CLK_GATE <= 16'b1111_1111_0000_0000;
            10'd9:   MAC_CLK_GATE <= 16'b1111_1111_1000_0000;
            10'd10:  MAC_CLK_GATE <= 16'b1111_1111_1100_0000;
            10'd11:  MAC_CLK_GATE <= 16'b1111_1111_1110_0000;
            10'd12:  MAC_CLK_GATE <= 16'b1111_1111_1111_0000;
            10'd13:  MAC_CLK_GATE <= 16'b1111_1111_1111_1000;
            10'd14:  MAC_CLK_GATE <= 16'b1111_1111_1111_1100;
            10'd15:  MAC_CLK_GATE <= 16'b1111_1111_1111_1110;
            default: MAC_CLK_GATE <= 16'b1111_1111_1111_1111;
        endcase
    end

    reg [3:0] state, next_state;

    reg [7:0] kern_cnt, next_kern_cnt;
    reg [15:0] kern_target_mac, next_target;//row가 다 차면 shift

    reg [19:0] px_addr, next_px_addr;
    reg [11:0] kern_addr, next_kern_addr;
    reg conv_row, next_conv_row;

    //iteration vars
    reg [9:0] cur_inp_chn, next_inp_chn;
    reg [2:0] cur_filt_row, next_filt_row;
    reg [2:0] cur_filt_col, next_filt_col;
    reg [8:0] cur_out_col, next_out_col;
    reg [8:0] cur_out_row, next_out_row;

    reg mac_start;
    reg mac_start_with_bias;
    reg init_buffer;

    wire [15:0] mac_work;
    wire [15:0] mac_init;
    wire [15:0] MAC_GATED_CLK;

    assign pxMem_RD_Addr = px_addr;
    assign MAC_GATED_CLK = MAC_CLK_GATE & {clk, clk, clk, clk, clk, clk, clk, clk, clk, clk, clk, clk, clk, clk, clk, clk};

    MAC MAC00(MAC_GATED_CLK[15], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[0] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[0], MAC_OUT[511:480]);
    MAC MAC01(MAC_GATED_CLK[14], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[1] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[1], MAC_OUT[479:448]);
    MAC MAC02(MAC_GATED_CLK[13], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[2] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[2], MAC_OUT[447:416]);
    MAC MAC03(MAC_GATED_CLK[12], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[3] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[3], MAC_OUT[415:384]);
    MAC MAC04(MAC_GATED_CLK[11], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[4] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[4], MAC_OUT[383:352]);
    MAC MAC05(MAC_GATED_CLK[10], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[5] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[5], MAC_OUT[351:320]);
    MAC MAC06(MAC_GATED_CLK[9], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[6] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[6], MAC_OUT[319:288]);
    MAC MAC07(MAC_GATED_CLK[8], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[7] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[7], MAC_OUT[287:256]);
    MAC MAC08(MAC_GATED_CLK[7], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[8] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[8], MAC_OUT[255:224]);
    MAC MAC09(MAC_GATED_CLK[6], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[9] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[9], MAC_OUT[223:192]);
    MAC MAC10(MAC_GATED_CLK[5], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[10] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[10], MAC_OUT[191:160]);
    MAC MAC11(MAC_GATED_CLK[4], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[11] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[11], MAC_OUT[159:128]);
    MAC MAC12(MAC_GATED_CLK[3], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[12] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[12], MAC_OUT[127:96]);
    MAC MAC13(MAC_GATED_CLK[2], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[13] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[13], MAC_OUT[95:64]);
    MAC MAC14(MAC_GATED_CLK[1], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[14] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[14], MAC_OUT[63:32]);
    MAC MAC15(MAC_GATED_CLK[0], rst_n, pxMem_in, kern_addr, KERN_OUT, KernRDWork
    , kern_target_mac[15] & KERN_VLD, init_buffer, conv_row, mac_start, mac_start_with_bias, mac_work[15], MAC_OUT[31:0]);


    localparam STA_IDLE = 4'd0;
    localparam STA_LD_KERNEL = 4'd1;//몇번째인지 기억하고 valid뜨면 집어넣어

    localparam STA_START_SETUP = 4'd2;
    localparam STA_GIVE_BIAS = 4'd3;//bias 주소 주기
    localparam STA_GIVE_BIAS_WAIT = 4'd4;//다 쓸때까지 대기

    localparam STA_MAC_START = 4'd5;
    localparam STA_MAC_START_BIAS = 4'd13;
    localparam STA_MAC_WAIT = 4'd6;

    localparam STA_NEXT_INP_CHANNEL = 4'd7;//여러개의 input channel이 존재하는 경우
    localparam STA_NEXT_FILT_COL = 4'd8;//Filter col
    localparam STA_NEXT_FILT_ROW = 4'd9;//Filter row
    localparam STA_NEXT_OUT_ROW = 4'd10;
    localparam STA_NEXT_OUT_COL = 4'd11;

    localparam STA_ENC_TAKE = 4'd12;//인코더가 가져가기 대기

    assign busy = (state != STA_IDLE);

    always@(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 4'd0;
            kern_cnt <= 0;
            kern_target_mac <= 16'b0000_0000_0000_0001;
            px_addr <= 0;
            kern_addr <= 0;
            conv_row <= 0;
            cur_inp_chn <= 0;
            cur_filt_row <= 0;
            cur_filt_col <= 0;
            cur_out_col <= 0;
            cur_out_row <= 0;
        end
        else begin
            state <= next_state;
            kern_cnt <= next_kern_cnt;
            kern_target_mac <= next_target;
            px_addr <= next_px_addr;
            kern_addr <= next_kern_addr;
            conv_row <= next_conv_row;
            cur_inp_chn <= next_inp_chn;
            cur_filt_row <= next_filt_row;
            cur_filt_col <= next_filt_col;
            cur_out_col <= next_out_col;
            cur_out_row <= next_out_row;
        end
    end

    always@(*) begin
        case(state)
            STA_IDLE: begin
                if(KernRDStart) next_state <= STA_LD_KERNEL;
                else if(op_start) next_state <= STA_START_SETUP;
                else next_state <= STA_IDLE;
            end
            STA_LD_KERNEL: begin
                if(KernRDWork) next_state <= STA_LD_KERNEL;
                else next_state <= STA_IDLE;
            end
            STA_START_SETUP: next_state <= STA_GIVE_BIAS;
            STA_GIVE_BIAS: next_state <= STA_GIVE_BIAS_WAIT;
            STA_GIVE_BIAS_WAIT: begin
                if(|mac_work) next_state <= STA_GIVE_BIAS_WAIT;
                else next_state <= STA_MAC_START_BIAS;
            end
            STA_MAC_START: next_state <= STA_MAC_WAIT;
            STA_MAC_WAIT: begin
               if(|mac_work) next_state <= STA_MAC_WAIT;
               else next_state <= STA_NEXT_INP_CHANNEL;
            end
            STA_NEXT_INP_CHANNEL: begin
                if(cur_inp_chn + 1 == CFG_NUM_FMAP) next_state <= STA_NEXT_FILT_COL;
                else next_state <= STA_MAC_START;
            end
            STA_NEXT_FILT_COL: begin
                if(cur_filt_col + 1 == CFG_KERN_SIZE) next_state <= STA_NEXT_FILT_ROW;
                else next_state <= STA_MAC_START;
            end
            STA_NEXT_FILT_ROW: begin
                if(cur_filt_row + 1 == CFG_KERN_SIZE) next_state <= STA_NEXT_OUT_ROW;
                else next_state <= STA_MAC_START;
            end
            STA_NEXT_OUT_ROW: begin
                if(conv_row) next_state <= STA_ENC_TAKE;//2개 row 단위로 완성
                else if(cur_out_row + 1 == CFG_HEIGHT - CFG_KERN_SIZE + 1) next_state <= STA_NEXT_OUT_COL;
                else next_state <= STA_MAC_START;
            end
            STA_NEXT_OUT_COL: begin
                if(cur_out_col + 1 != CFG_WIDTH - CFG_KERN_SIZE + 1) next_state <= STA_MAC_START;
                else begin
                    if(conv_row) next_state <= STA_ENC_TAKE;
                    else next_state <= STA_IDLE;
                end
            end
            STA_ENC_TAKE: begin
                if(PRE_TAKE_RDY) begin
                   if(conv_row) next_state <= STA_IDLE;//마지막 row가 홀수일 때
                   else begin
                        if(cur_out_row == CFG_HEIGHT - CFG_KERN_SIZE + 1) next_state <= STA_NEXT_OUT_COL;
                        else next_state <= STA_MAC_START_BIAS;
                   end
                end
                else next_state <= STA_ENC_TAKE;
            end
            STA_MAC_START_BIAS: next_state <= STA_MAC_WAIT;
            default: next_state <= 4'dx;
        endcase
    end

    always@(*) begin
        case(state)
            STA_IDLE: begin
                next_kern_cnt <= CFG_KERN_SIZE * CFG_KERN_SIZE;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd0;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_LD_KERNEL: begin
                if(~KERN_VLD) begin
                    next_target <= kern_target_mac;
                    next_kern_cnt <= kern_cnt;
                    next_kern_addr <= kern_addr;
                end
                else if(kern_cnt == 1) begin//one channel finish
                    next_target <= {kern_target_mac[14:0], kern_target_mac[15]};
                    next_kern_cnt <= CFG_KERN_SIZE * CFG_KERN_SIZE;
                    next_kern_addr <= 0;
                end
                else begin//not changed
                    next_target <= kern_target_mac;
                    next_kern_cnt <= kern_cnt - 1;
                    next_kern_addr <= kern_addr + 1;
                end
                next_px_addr <= px_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_START_SETUP: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= 20'd0;
                next_kern_addr <= 16'd0;
                next_conv_row <= 1'd0;
                next_inp_chn <= 10'd0;
                next_filt_row <= 3'd0;
                next_filt_col <= 3'd0;
                next_out_col <= 9'd0;
                next_out_row <= 9'd0;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_GIVE_BIAS: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd1;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_GIVE_BIAS_WAIT: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                if(|mac_work) next_kern_addr <= kern_addr;
                else next_kern_addr <= kern_addr + 1;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_MAC_START: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd1;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_MAC_WAIT: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_NEXT_INP_CHANNEL: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn + 1;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_NEXT_FILT_COL: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= 0;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col + 1;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_NEXT_FILT_ROW: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row + 1;
                next_filt_col <= 0;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_NEXT_OUT_ROW: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= ~conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= 0;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row + 1;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_NEXT_OUT_COL: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col + 1;
                next_out_row <= 0;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            STA_ENC_TAKE: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd0;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd1;
            end
            STA_MAC_START_BIAS: begin
                next_kern_cnt <= kern_cnt;
                next_target <= kern_target_mac;
                next_px_addr <= px_addr;
                next_kern_addr <= kern_addr;
                next_conv_row <= conv_row;
                next_inp_chn <= cur_inp_chn;
                next_filt_row <= cur_filt_row;
                next_filt_col <= cur_filt_col;
                next_out_col <= cur_out_col;
                next_out_row <= cur_out_row;
                mac_start <= 1'd0;
                mac_start_with_bias <= 1'd1;
                init_buffer <= 1'd0;
                pxMem_RD_REQ <= 1'd1;
                PRE_TAKE_VLD <= 1'd0;
            end
            default: begin
                next_kern_cnt <= 3'dx;
                next_target <= 16'dx;
                next_px_addr <= 20'dx;
                next_kern_addr <= 16'dx;
                next_conv_row <= 1'bx;
                next_inp_chn <= 10'dx;
                next_filt_row <= 3'dx;
                next_filt_col <= 3'dx;
                next_out_col <= 9'dx;
                next_out_row <= 9'dx;
                mac_start <= 1'dx;
                init_buffer <= 1'dx;
                pxMem_RD_REQ <= 1'dx;
                PRE_TAKE_VLD <= 1'dx;
            end
        endcase
    end

endmodule
