module MAC(
    input clk,
    input rst_n,

    input [15:0] px_val,//픽셀 관리는 Controller/PxAllocator 책임, PxAllocator는 filter size * (filter size + 1) 만큼 저장 가능

    input [11:0] kern_addr,//Controller가 주는 주소
    input [15:0] kern_give_data,
    input kern_input_mode,//kernel 메모리 초기화 모드 진입
    input kern_accept,//받아 들일 것인지 여부

    input init_buffer,

    input conv_row,
    input mac_start,//시작
    input mac_start_with_bias,
    output reg MAC_work,//동작중

    output [31:0] result_px//extract 2 row at once
);

    reg [15:0] KernMem[0:2303];//4.5KB Kernel Memory
    //reg [15:0] KernMem[0:65535];

    localparam STA_IDLE = 4'd0;//대기

    localparam STA_GET_BIAS = 4'd1;//bias 값을 저장
    localparam STA_INIT_BIAS = 4'd2;//bias 값을 버퍼에 씌워서 초기화

    localparam STA_MUL_RUN = 4'd3;//곱셈기 실행
    localparam STA_MUL_WAIT = 4'd4;//대기
    localparam STA_ACC_FIRST_ROW = 4'd5;//첫번째 Row에서 Accumulate
    localparam STA_ACC_SECOND_ROW = 4'd6;//두번째 Row에서 Accumulate
    
    localparam STA_KER_MEM_WRITE = 4'd7;//커널 메모리 작성 모드

    reg [3:0] state, next_state;
    reg [15:0] bias, next_bias;

    //How many internal buffer(result buffer) needed?
    //Note that the multiplication result is 32 bit, we will use 32bit length for internal
    reg [31:0] acc_buff_r0[0:0];
    reg [31:0] acc_buff_r1[0:0];

    wire [15:0] currentKernel;
    assign currentKernel = KernMem[kern_addr];

    reg mul_start;
    wire [31:0] mul_result;
    wire mul_finish;
    MUL16 M0(clk, rst_n, mul_start, mul_finish, px_val, currentKernel, mul_result);

    wire [31:0] add_result;
    wire A_cout;
    KSA32 A0(mul_result, (conv_row)?acc_buff_r1[0]:acc_buff_r0[0], 1'b0, add_result, A_cout);

    //Output is always quantized
    wire [15:0] q0_result, q1_result, q2_result, q3_result;
    Quantizer q0(acc_buff_r0[0], q0_result);
    Quantizer q1(acc_buff_r1[0], q1_result);
    assign result_px = {q0_result, q1_result};

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 4'd0;
            bias <= 16'd0;
            acc_buff_r0[0] <= 0;
            acc_buff_r1[0] <= 0;
        end
        else begin
            state <= next_state;
            bias <= next_bias;
        end
    end

    always @(posedge clk) begin
        case(state)
            STA_INIT_BIAS: begin
                acc_buff_r0[0] <= {(bias[15])?16'hffff:16'd0, bias};
                acc_buff_r1[0] <= {(bias[15])?16'hffff:16'd0, bias};
            end
            STA_ACC_FIRST_ROW: begin
                acc_buff_r0[0] <= add_result;
            end
            STA_ACC_SECOND_ROW: begin
                acc_buff_r1[0] <= add_result;
            end
            STA_KER_MEM_WRITE: begin
               if(kern_accept) KernMem[kern_addr] <= kern_give_data; 
            end
        endcase
    end

    always @(*) begin
        case(state)
            STA_IDLE: begin
                if(mac_start) begin
                    if(currentKernel == 0 || px_val == 0) next_state <= STA_IDLE;
                    else next_state <= STA_MUL_RUN;
                end
                else if(mac_start_with_bias) begin
                    next_state <= STA_INIT_BIAS;
                end
                else if(init_buffer) next_state <= STA_GET_BIAS;
                else if(kern_input_mode) next_state <= STA_KER_MEM_WRITE;
                else next_state <= STA_IDLE;
            end
            STA_GET_BIAS: begin
                next_state <= STA_IDLE;//already pop'd at CCMClusterController
            end
            STA_INIT_BIAS: begin
                next_state <= STA_MUL_RUN;
            end
            STA_MUL_RUN: begin
                next_state <= STA_MUL_WAIT;
            end
            STA_MUL_WAIT: begin
                if(mul_finish) begin
                    if(~conv_row) next_state <= STA_ACC_FIRST_ROW;
                    else next_state <= STA_ACC_SECOND_ROW;
                end
                else next_state <= STA_MUL_WAIT;
            end
            STA_ACC_FIRST_ROW: begin
                next_state <= STA_IDLE;
            end
            STA_ACC_SECOND_ROW: begin
                next_state <= STA_IDLE;
            end
            STA_KER_MEM_WRITE: begin
                if(kern_input_mode) next_state <= STA_KER_MEM_WRITE;
                else next_state <= STA_IDLE;
            end
            default: begin
                next_state <= 4'dx;
            end
        endcase
    end

    always @(*) begin
        case(state)
            STA_IDLE: begin
                next_bias <= bias;
                mul_start <= 1'd0;
                MAC_work <= 1'd0;
            end
            STA_GET_BIAS: begin
                next_bias <= currentKernel;
                mul_start <= 1'd0;
                MAC_work <= 1'd1;
            end
            STA_INIT_BIAS: begin
                next_bias <= bias;
                mul_start <= 1'd0;
                MAC_work <= 1'd1;
            end
            STA_MUL_RUN: begin
                next_bias <= bias;
                mul_start <= 1'd1;
                MAC_work <= 1'd1;
            end
            STA_MUL_WAIT: begin
                next_bias <= bias;
                mul_start <= 1'd0;
                MAC_work <= 1'd1;
            end
            STA_ACC_FIRST_ROW: begin
                next_bias <= bias;
                mul_start <= 1'd0;
                MAC_work <= 1'd1;
            end
            STA_ACC_SECOND_ROW: begin
                next_bias <= bias;
                mul_start <= 1'd0;
                MAC_work <= 1'd1;
            end
            STA_KER_MEM_WRITE: begin
                next_bias <= bias;
                mul_start <= 1'd0;
                MAC_work <= 1'd1;
            end
            default: begin
                next_bias <= 16'dx;
                mul_start <= 1'dx;
                MAC_work <= 1'dx;
            end
        endcase
    end
    

endmodule
