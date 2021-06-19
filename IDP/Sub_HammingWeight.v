module HammingWeight(
    input clk,
    input rst_n,
    input op_start,
    input [15:0] din,

    output hw_vld,
    output [4:0] hamW//maintained till new calculation is started
);

    reg [2:0] state, next_state;
    reg [15:0] t0, next_t0;

    localparam STA_IDLE = 3'd0;
    localparam STA_C1 = 3'd1;
    localparam STA_C2 = 3'd2;
    localparam STA_C3 = 3'd3;
    localparam STA_C4 = 3'd4;

    //Pre-defined constants
    localparam M1 = 16'h5555;
    localparam M2 = 16'h3333;
    localparam M4 = 16'h0f0f;
    localparam M8 = 16'h00ff;

    assign hw_vld = (state == STA_IDLE);//always valid when idle
    assign hamW = t0[4:0];//low 4 bit is result

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 3'd0;
            t0 <= 16'd0;
        end
        else begin
            state <= next_state;
            t0 <= next_t0;
        end
    end

    always @(state, op_start, t0, M1, M2, M4, M8, din) begin
        case(state)
            STA_IDLE: begin
                next_t0 <= t0;
                if(op_start) next_state <= STA_C1;
                else next_state <= STA_IDLE;
            end
            STA_C1: begin
                next_t0 <= (din & M1) + ((din >> 1) & M1);
                next_state <= STA_C2;
            end
            STA_C2: begin
                next_t0 <= (t0 & M2) + ((t0 >> 2) & M2);
                next_state <= STA_C3;
            end
            STA_C3: begin
                next_t0 <= (t0 & M4) + ((t0 >> 4) & M4);
                next_state <= STA_C4;
            end
            STA_C4: begin
                next_t0 <= (t0 & M8) + ((t0 >> 8) & M8);
                next_state <= STA_IDLE;
            end
            default: begin
                next_t0 <= 16'dx;
                next_state <= 3'dx;
            end
        endcase
    end

endmodule