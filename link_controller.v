// ============================================================
// Link Controller
// Quan ly qua trinh khoi tao va trang thai cua lien ket chiplet
//
// States:
//   IDLE     : Lien ket chua duoc kich hoat
//   TRAINING : Kiem tra TX, RX va cac lane
//   ACTIVE   : Lien ket hoat dong binh thuong
//   ERROR    : Phat hien loi, yeu cau training lai
// ============================================================

module link_controller #(
    parameter NUM_LANES = 4
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // Dieu khien lien ket
    input  wire                     link_enable,
    input  wire [1:0]               training_mode,

    // Trang thai TX, RX va cac lane
    input  wire                     tx_ready,
    input  wire                     rx_ready,
    input  wire [NUM_LANES-1:0]     lane_ok,

    // Tin hieu loi da duoc phat hien
    input  wire                     fault_detected,

    // Trang thai lien ket
    output reg                      link_up,
    output reg [NUM_LANES-1:0]      lane_enable,
    output reg [1:0]                link_state,
    output reg                      retrain_req
);

    // ========================================================
    // Khai bao trang thai FSM
    // ========================================================

    localparam [1:0] ST_IDLE     = 2'b00;
    localparam [1:0] ST_TRAINING = 2'b01;
    localparam [1:0] ST_ACTIVE   = 2'b10;
    localparam [1:0] ST_ERROR    = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    // training_mode duoc giu lai de mo rong trong tuong lai.
    // Hien tai moi training mode deu su dung cung dieu kien.
    wire training_complete;

    assign training_complete =
        tx_ready &&
        rx_ready &&
        (&lane_ok);

    // ========================================================
    // Thanh ghi trang thai
    // ========================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // ========================================================
    // Logic chuyen trang thai
    // ========================================================

    always @(*) begin
        next_state = state;

        case (state)

            ST_IDLE: begin
                if (link_enable)
                    next_state = ST_TRAINING;
            end

            ST_TRAINING: begin
                if (!link_enable)
                    next_state = ST_IDLE;
                else if (fault_detected)
                    next_state = ST_ERROR;
                else if (training_complete)
                    next_state = ST_ACTIVE;
            end

            ST_ACTIVE: begin
                if (!link_enable)
                    next_state = ST_IDLE;
                else if (fault_detected)
                    next_state = ST_ERROR;
            end

            ST_ERROR: begin
                if (!link_enable)
                    next_state = ST_IDLE;
                else if (!fault_detected)
                    next_state = ST_TRAINING;
            end

            default: begin
                next_state = ST_IDLE;
            end

        endcase
    end

    // ========================================================
    // Logic ngo ra Moore
    // ========================================================

    always @(*) begin
        // Gia tri mac dinh
        link_up     = 1'b0;
        lane_enable = {NUM_LANES{1'b0}};
        link_state  = state;
        retrain_req = 1'b0;

        case (state)

            ST_IDLE: begin
                link_up     = 1'b0;
                lane_enable = {NUM_LANES{1'b0}};
                retrain_req = 1'b0;
            end

            ST_TRAINING: begin
                link_up     = 1'b0;
                lane_enable = {NUM_LANES{1'b0}};
                retrain_req = 1'b0;
            end

            ST_ACTIVE: begin
                link_up     = 1'b1;
                lane_enable = {NUM_LANES{1'b1}};
                retrain_req = 1'b0;
            end

            ST_ERROR: begin
                link_up     = 1'b0;
                lane_enable = {NUM_LANES{1'b0}};
                retrain_req = 1'b1;
            end

            default: begin
                link_up     = 1'b0;
                lane_enable = {NUM_LANES{1'b0}};
                retrain_req = 1'b0;
            end

        endcase
    end

    // training_mode hien chua duoc su dung.
    // Dong nay ngan mot so cong cu canh bao unused input.
    wire unused_training_mode;

    assign unused_training_mode = ^training_mode;

endmodule