module CCMControl(
    input clk,
    input rst_n,

    input op_start,
    output status,

    input KernRDWork,
    output reg KernRDStart,

    input ClusterWork,
    output reg ClusterStart
    //output reg ClusterEnable
);

    localparam STATE_IDLE = 3'd0;
    //localparam STATE_CALC_CLUSTER_CNT = 3'd3;
    localparam STATE_LD_KERN_REQ = 3'd1;
    localparam STATE_LD_KERN_WAIT = 3'd2;
    localparam STATE_CLUSTER_START = 3'd4;
    localparam STATE_CLUSTER_WAIT = 3'd5;

    reg [2:0] state, next_state;
    //reg [7:0] CLUST_Cnt, next_cnt;

    assign status = (state != STATE_IDLE);

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 3'd0;
            //CLUST_Cnt <= 8'd0;
        end
        else begin
            state <= next_state;
            //CLUST_Cnt <= next_cnt;
        end
    end

    always @(*) begin
        case(state)
            STATE_IDLE: begin
                if(op_start) next_state <= STATE_LD_KERN_REQ;
                else next_state <= STATE_IDLE;
            end
            /*
            STATE_CALC_CLUSTER_CNT: begin
                next_state <= STATE_LD_KERN_REQ;
            end
            */
            STATE_LD_KERN_REQ: begin
                next_state <= STATE_LD_KERN_WAIT;
            end
            STATE_LD_KERN_WAIT: begin
                if(KernRDWork) next_state <= STATE_LD_KERN_WAIT;
                else next_state <= STATE_CLUSTER_START;
            end
            STATE_CLUSTER_START: begin
                next_state <= STATE_CLUSTER_WAIT;
            end
            STATE_CLUSTER_WAIT: begin
                if(ClusterWork) next_state <= STATE_CLUSTER_WAIT;
                else next_state <= STATE_IDLE;
            end
            default: begin
                next_state <= 3'dx;
            end
        endcase
    end

    always @(state) begin
        case(state)
            STATE_IDLE: begin
                //next_cnt <= CLUST_Cnt;
                KernRDStart <= 1'd0;
                ClusterStart <= 1'd0;
            end
            /*
            STATE_CALC_CLUSTER_CNT: begin
                next_cnt[0] <= 1'b1;
                next_cnt[1] <= (CFG_NUM_KERNEL > 16);
                next_cnt[2] <= (CFG_NUM_KERNEL > 32);
                next_cnt[3] <= (CFG_NUM_KERNEL > 48);
                next_cnt[4] <= (CFG_NUM_KERNEL > 64);
                next_cnt[5] <= (CFG_NUM_KERNEL > 80);
                next_cnt[6] <= (CFG_NUM_KERNEL > 96);
                next_cnt[7] <= (CFG_NUM_KERNEL > 112);
                KernRDStart <= 1'd0;
                ClusterStart <= 1'd0;
            end
            */
            STATE_LD_KERN_REQ: begin
                //next_cnt <= CLUST_Cnt;
                KernRDStart <= 1'd1;
                ClusterStart <= 1'd0;
            end
            STATE_LD_KERN_WAIT: begin
                //next_cnt <= CLUST_Cnt;
                KernRDStart <= 1'd0;
                ClusterStart <= 1'd0;
            end
            STATE_CLUSTER_START: begin
                //next_cnt <= CLUST_Cnt;
                KernRDStart <= 1'd0;
                ClusterStart <= 1'd1;
            end
            STATE_CLUSTER_WAIT: begin
                //next_cnt <= CLUST_Cnt;
                KernRDStart <= 1'd0;
                ClusterStart <= 1'd0;
            end
            default: begin
                //next_cnt <= 8'dx;
                KernRDStart <= 1'dx;
                ClusterStart <= 1'dx;
            end
        endcase
    end

endmodule
