module IDPManager(
	input clk,
	input rst_n,

    //RAM Controller Ports
	output reg MEM_REQ,
	output [31:0]MEM_ADDR,
	output reg   [3:0]MEM_CMD,
	input      [31:0]MEM_DIN,
	input      MEM_VLD,
    input      MEM_FIN,
	input      MEM_IDP_SEL,

    /* Pixel Memory Ports */
	input pxMem_WR_RDY,
    output pxMem_WR_VLD,
	input pxMem_GRANT,
	output reg pxMem_WR_REQ,
	output [19:0] pxMem_Addr,
	output [3:0] pxMem_burst,//(1-16)
	output [15:0] pxMem_out,

    /* Tracker */
    output [19:0] track_din,
	output reg track_write,

    input IDP_START,
    output IDP_STATUS,

    input [31:0] CFG_READ_START_ADDR,//어디서부터 읽기 시작할건가?, Read Region과 Write Region은 매번 서로 교체된다.
    input [8:0] CFG_WIDTH,
	input [8:0] CFG_HEIGHT,
    input [9:0] CFG_NUM_FMAP
);

    //Warn: 멀티 채널 이미지라면 A A A A A 순이 아닌 A B C D E 순으로 저장되어야 함
    //그래야만 Convolution에 문제가 없음

    localparam STA_IDLE = 5'd0;
    localparam STA_LOAD_CFG = 5'd1;//설정 읽기

    //Sparsity map 읽기 (하나 읽고 하위 16 버림, 주소 4 증가)
    localparam STA_LD_SM_GRANT_REQ = 5'd2;
    localparam STA_LD_SM_CMD = 5'd3;
    localparam STA_LD_SM_WAIT = 5'd4;
    localparam STA_LD_SM_WRT_BUFFER = 5'd5;

    //한 세그먼트에 몇개의 픽셀이 있는가?
    localparam STA_REQ_HAM_WEIGHT = 5'd6;//1 cycle
    localparam STA_WAIT_HAM_WEIGHT = 5'd7;//4 cycle
    localparam STA_LD_PX_DETERM_READ = 5'd8;//읽어야 할 개수 결정, 개수 = HammW, 만약 0개면 바로 Decode 진행

    //픽셀 개수만큼 메모리 읽기 ㄱㄱ (0개 아닐때만)
    localparam STA_LD_PX_GRANT_REQ = 5'd9;
    localparam STA_LD_PX_CMD = 5'd10;
    localparam STA_LD_PX_WAIT = 5'd11;
    localparam STA_LD_PX_WRT_BUFFER = 5'd12;//32to16 FIFO에 Write

    //Decode & 픽셀 메모리로 복사 (raw pixels)
    localparam STA_MOVE_EMPTY = 5'd13;
    localparam STA_DEC_NONEMPTY = 5'd14;//Total 18 Cycle approx

    localparam STA_CPY_PX_GRANT_REQ = 5'd15;//1Cycle
    localparam STA_CPY_PX_CMD = 5'd16;//1 Cycle
    localparam STA_CPY_PX_BURST = 5'd17;//16Cycle

    //남은 픽셀 개수 계산 및 주소 삽입
    localparam STA_PX_CALC_COLUMN_POSITION = 5'd18;//남은 픽셀 계산(무조건 16 더함)
    /*
        픽셀 개수 계산 방법
        16 더함 -> 더한게 열보다 크면 이미지 인덱스 하나 증가시키고 열 값은 0으로 바꿔부러
        
        cur_col > cur_col + 16 then cur_idx = 0, cur_idx += 1;
    */
    localparam STA_PX_CHECK_ROW_FINISH = 5'd19;
    localparam STA_SET_ROW_TRACK_ADDR = 5'd20;//트래커에 주소 삽입

    localparam STA_CHECK_NEXT_ITERATION = 5'd21;//다음 세그먼트로 이동, 그리고 FIFO에 뭐 남아 있으면 바로 Hamming weight 읽으러감

    localparam STA_FINISH = 5'd22;//종료

    reg [4:0] state, next_state;

    reg [9:0] cur_idx, next_idx;
    reg [8:0] cur_col, next_col;
    reg [8:0] cur_row, next_row;

    reg [20:0] cur_pxm_addr, next_pxm_addr;

    reg [31:0] cur_ext_mem_read_addr, next_ext_mem_read_addr;
    reg [3:0] cur_burst, next_burst;

    reg [15:0] cur_SM, next_SM;
    reg [4:0] px_cnt, next_px_cnt;

    reg memBufRead, memBufWrite;
    wire [15:0] memBufout; wire [4:0] memBufcnt;
    SimpleFIFO32to16 memRdBuffer(clk, rst_n, memBufRead, memBufWrite, MEM_DIN, memBufout, , , , , , , memBufcnt);

	reg decBufread, decBwrite;
    wire [15:0] decBufin;
	wire [15:0] decBufout; wire [4:0] decBufcnt;
    assign decBufin = (state == STA_MOVE_EMPTY)?16'd0:memBufout;
	SimpleFIFO16 decodeBuf(clk, rst_n, decBufread, decBwrite, decBufin, decBufout, , , , , , , decBufcnt);//it is assured that we will not exceed 16 data

    wire [4:0] hamW;
    wire ham_vld;
    wire ham_start;
    assign ham_start = (state == STA_REQ_HAM_WEIGHT);
    HammingWeight hamCalc(clk, rst_n, ham_start, cur_SM, ham_vld, hamW);

    assign MEM_ADDR = cur_ext_mem_read_addr;
    assign IDP_STATUS = (state != STA_IDLE);
    assign pxMem_burst = 4'd15;
    assign pxMem_out = decBufout;
    assign track_din = cur_pxm_addr - CFG_NUM_FMAP * 16 * (((CFG_WIDTH - 1) / 16) + 1);
    assign pxMem_WR_VLD = (state == STA_CPY_PX_BURST);
    assign pxMem_Addr = cur_pxm_addr;

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= 5'd0;
            cur_idx <= 10'd0;
            cur_col <= 9'd0;
            cur_row <= 9'd0;
            cur_pxm_addr <= 20'd0;
            cur_ext_mem_read_addr <= 32'd0;
            cur_burst <= 4'd0;
            cur_SM <= 16'd0;
            px_cnt <= 5'd0;
        end
        else begin
            state <= next_state;
            cur_idx <= next_idx;
            cur_col <= next_col;
            cur_row <= next_row;
            cur_pxm_addr <= next_pxm_addr;
            cur_ext_mem_read_addr <= next_ext_mem_read_addr;
            cur_burst <= next_burst;
            cur_SM <= next_SM;
            px_cnt <= next_px_cnt;
        end
    end

    always @(*) begin
        case(state)
            STA_IDLE: begin
                //#0 $stop;//for test
                if(IDP_START) next_state <= STA_LOAD_CFG;
                else next_state <= STA_IDLE;
            end
            STA_LOAD_CFG: next_state <= STA_LD_SM_GRANT_REQ;

            //Load Sparsity map
            STA_LD_SM_GRANT_REQ: begin
                if(MEM_IDP_SEL) next_state <= STA_LD_SM_CMD;
                else next_state <= STA_LD_SM_GRANT_REQ;
            end
            STA_LD_SM_CMD: next_state <= STA_LD_SM_WAIT;
            STA_LD_SM_WAIT: begin
                if(MEM_VLD) next_state <= STA_LD_SM_WRT_BUFFER;
                else next_state <= STA_LD_SM_WAIT;
            end
            STA_LD_SM_WRT_BUFFER: begin
                if(MEM_FIN) next_state <= STA_REQ_HAM_WEIGHT;
                else next_state <= STA_LD_SM_WRT_BUFFER;
            end

            //Get hamming weight
            STA_REQ_HAM_WEIGHT: next_state <= STA_WAIT_HAM_WEIGHT;
            STA_WAIT_HAM_WEIGHT: begin
                if(ham_vld) next_state <= STA_LD_PX_DETERM_READ;
                else next_state <= STA_WAIT_HAM_WEIGHT;
            end

            //NZV Read
            STA_LD_PX_DETERM_READ: begin
                if(hamW == 5'd0) next_state <= STA_MOVE_EMPTY;
                next_state <= STA_LD_PX_GRANT_REQ;
            end
            STA_LD_PX_GRANT_REQ: begin
                if(MEM_IDP_SEL) next_state <= STA_LD_PX_CMD;
                else next_state <= STA_LD_PX_GRANT_REQ;
            end
            STA_LD_PX_CMD: next_state <= STA_LD_PX_WAIT;
            STA_LD_PX_WAIT: begin
                if(MEM_VLD) next_state <= STA_LD_PX_WRT_BUFFER;
                else next_state <= STA_LD_PX_WAIT;
            end
            STA_LD_PX_WRT_BUFFER: begin
                if(MEM_FIN) begin
                    if(cur_SM[15]) next_state <= STA_DEC_NONEMPTY;
                    else next_state <= STA_MOVE_EMPTY;
                end
                else next_state <= STA_LD_PX_WRT_BUFFER;
            end
            
            //Decode
            STA_MOVE_EMPTY: begin
                if(cur_SM[15]) next_state <= STA_DEC_NONEMPTY;
                else if(px_cnt == 5'd1) next_state <= STA_CPY_PX_GRANT_REQ;
				else next_state <= STA_MOVE_EMPTY;
            end
            STA_DEC_NONEMPTY: begin
				if(px_cnt == 5'd1) next_state <= STA_CPY_PX_GRANT_REQ;
				else if(~cur_SM[14]) next_state <= STA_MOVE_EMPTY;//pixel left, but next sm is empty
				else next_state <= STA_DEC_NONEMPTY;
            end

            //To pixel mem
            STA_CPY_PX_GRANT_REQ: begin
                if(pxMem_GRANT) next_state <= STA_CPY_PX_CMD;
                else next_state <= STA_CPY_PX_GRANT_REQ;
            end
            STA_CPY_PX_CMD: next_state <= STA_CPY_PX_BURST;
            STA_CPY_PX_BURST: begin
                if(decBufcnt == 4'd1) next_state <= STA_PX_CALC_COLUMN_POSITION;
                else next_state <= STA_CPY_PX_BURST;
            end

            STA_PX_CALC_COLUMN_POSITION: next_state <= STA_PX_CHECK_ROW_FINISH;
            STA_PX_CHECK_ROW_FINISH: begin
                if(CFG_NUM_FMAP == cur_idx) next_state <= STA_SET_ROW_TRACK_ADDR;
                else next_state <= STA_CHECK_NEXT_ITERATION;
            end
            STA_SET_ROW_TRACK_ADDR: next_state <= STA_CHECK_NEXT_ITERATION;
            STA_CHECK_NEXT_ITERATION: begin
                if(CFG_HEIGHT == cur_row) next_state <= STA_FINISH;
                else begin
                    if(memBufcnt) next_state <= STA_REQ_HAM_WEIGHT;
                    else next_state <= STA_LD_SM_GRANT_REQ;
                end
            end
            STA_FINISH: next_state <= STA_IDLE;
            default: next_state <= 4'dx;
        endcase
    end

    wire [4:0]aab = hamW;

    always @(*) begin
        case(state)
            STA_IDLE: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LOAD_CFG: begin
                next_idx <= 10'd0;
                next_col <= 9'd0;
                next_row <= 9'd0;
                next_pxm_addr <= 20'd0;
                next_ext_mem_read_addr <= CFG_READ_START_ADDR;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_SM_GRANT_REQ: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd1;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_SM_CMD: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd1;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_SM_WAIT: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_SM_WRT_BUFFER: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr + 2;
                next_burst <= cur_burst;
                next_SM <= MEM_DIN[31:16];
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end

            //Get hamming weight
            STA_REQ_HAM_WEIGHT: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_WAIT_HAM_WEIGHT: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end

            //NZV Read
            STA_LD_PX_DETERM_READ: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= 5'd16;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_PX_GRANT_REQ: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd1;
                MEM_CMD <= {1'd0, aab[3:1]};//항상 짝수로만 읽도록, 남는건 나중에 또 쓸거임
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_PX_CMD: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr + aab[3:1] * 4 + 4;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd1;
                MEM_CMD <= {1'd0, aab[3:1]};//항상 짝수로만 읽도록, 남는건 나중에 또 쓸거임
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_PX_WAIT: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd1;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_LD_PX_WRT_BUFFER: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd1;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            
            //Decode
            STA_MOVE_EMPTY: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                if(cur_SM[15]) begin
                    next_SM <= cur_SM;
                    next_px_cnt <= px_cnt;
                    decBwrite <= 1'd0;
                end
                else begin
                    next_SM <= {cur_SM[14:0], 1'd0};
                    next_px_cnt <= px_cnt - 1'd1;
                    decBwrite <= 1'd1;
                end
            end
            STA_DEC_NONEMPTY: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= {cur_SM[14:0], 1'd0};
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd1;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                next_px_cnt <= px_cnt - 1'd1;
                decBwrite <= 1'd1;
            end

            //To pixel mem
            STA_CPY_PX_GRANT_REQ: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= 4'd15;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd1;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_CPY_PX_CMD: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd1;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_CPY_PX_BURST: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr + 1;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd1;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd1;
                decBwrite <= 1'd0;
            end

            STA_PX_CALC_COLUMN_POSITION: begin
                if(cur_col + 16 >= CFG_WIDTH) begin
                    next_idx <= cur_idx + 1;
                    next_col <= 0;
                end
                else begin
                    next_idx <= cur_idx;
                    next_col <= cur_col + 16;
                end
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_PX_CHECK_ROW_FINISH: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_SET_ROW_TRACK_ADDR: begin
                next_idx <= 10'd0;
                next_col <= cur_col;
                next_row <= cur_row + 1;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd1;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            STA_CHECK_NEXT_ITERATION: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
                if(memBufcnt) begin
                    memBufRead <= 1'd1;
                    next_SM <= memBufout;
                end
                else begin
                    memBufRead <= 1'd0;
                    next_SM <= cur_SM;
                end
            end
            STA_FINISH: begin
                next_idx <= cur_idx;
                next_col <= cur_col;
                next_row <= cur_row;
                next_pxm_addr <= cur_pxm_addr;
                next_ext_mem_read_addr <= cur_ext_mem_read_addr;
                next_burst <= cur_burst;
                next_SM <= cur_SM;
                next_px_cnt <= px_cnt;
                MEM_REQ <= 1'd0;
                MEM_CMD <= 4'd0;
                pxMem_WR_REQ <= 1'd0;
                track_write <= 1'd0;
                memBufRead <= 1'd0;
                memBufWrite <= 1'd0;
                decBufread <= 1'd0;
                decBwrite <= 1'd0;
            end
            default: begin
                next_idx <= 10'dx;
                next_col <= 9'dx;
                next_row <= 9'dx;
                next_pxm_addr <= 20'dx;
                next_ext_mem_read_addr <= 32'dx;
                next_burst <= 32'dx;
                next_SM <= 32'dx;
                next_px_cnt <= 32'dx;
                MEM_REQ <= 1'dx;
                MEM_CMD <= 1'dx;
                pxMem_WR_REQ <= 1'dx;
                track_write <= 1'dx;
                memBufRead <= 1'dx;
                memBufWrite <= 1'dx;
                decBufread <= 1'dx;
                decBwrite <= 1'dx;
            end
        endcase
    end



endmodule

