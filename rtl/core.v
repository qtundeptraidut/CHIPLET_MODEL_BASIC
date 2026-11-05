// Core of the Chiplet Interconnect.
// All research/control signals remain inside the core so they do not
// become physical FPGA I/O pins.

module chiplet_interconnect_core #(
    parameter WIDTH      = 32,
    parameter NUM_LANES  = 2,
    parameter LANE_WIDTH = WIDTH / NUM_LANES
)(
    input wire                     clk,
    input wire                     rst_n,

    input wire                     link_enable,
    input wire [1:0]               training_mode,
    input wire [7:0]               traffic_level,

    input wire                     fault_enable,
    input wire [1:0]               fault_type,
    input wire [7:0]               fault_rate,
    input wire [7:0]               burst_length,
    input wire [7:0]               fault_duration,
    input wire [NUM_LANES-1:0]     fault_lane_mask,

    output wire [WIDTH-1:0]        data_out,
    output wire                    valid_out,
    output wire                    link_up,

    output wire [NUM_LANES-1:0]    lane_enable,
    output wire [1:0]              link_state,
    output wire                    retrain_req,
    output wire                    fault_active,
    output wire [15:0]             fault_inject_count,

    output wire [31:0]             total_packets,
    output wire [31:0]             error_packets,
    output wire [31:0]             lane_error_cnt0,
    output wire [31:0]             lane_error_cnt1,
    output wire [31:0]             lane_error_cnt2,
    output wire [31:0]             lane_error_cnt3,
    output wire [31:0]             injected_faults,
    output wire                    error_overflow
);

    wire [WIDTH-1:0] pg_data;
    wire pg_valid, pg_ready;

    wire [WIDTH-1:0] tx_data;
    wire tx_valid, tx_ready;

    wire [WIDTH-1:0] fault_data;
    wire fault_valid, fault_ready;

    wire [WIDTH-1:0] link_data;
    wire link_valid, link_ready;

    wire [WIDTH-1:0] rx_data;
    wire rx_valid, rx_ready;

    wire [LANE_WIDTH-1:0] lane0, lane1, lane2, lane3;
    wire [NUM_LANES-1:0] lane_ok;
    wire tx_ready_status, rx_ready_status;

    wire fault_detected;
    wire pkt_error;
    wire [NUM_LANES-1:0] checked_lane_error;
    wire [3:0] lane_error;
    assign lane_error[NUM_LANES-1:0] = checked_lane_error;
    generate if (NUM_LANES < 4) begin: gen_unused_error_lanes
        assign lane_error[3:NUM_LANES] = {(4-NUM_LANES){1'b0}};
    end endgenerate

    // Baseline training uses healthy lanes; fault outcomes are measured by the checker.
    assign lane_ok = {NUM_LANES{1'b1}};

    // Faults are measured as packet/lane errors. Retraining is deliberately
    // disabled so one corrupted packet does not truncate a characterization run.
    assign fault_detected = 1'b0;

    // RX has no downstream consumer in this baseline.
    assign rx_ready = 1'b1;

    // Training readiness must not depend on link_up.
    assign tx_ready_status = 1'b1;
    assign rx_ready_status = 1'b1;

    packet_generator #(
        .WIDTH(WIDTH)
    ) u_packet_generator (
        .clk       (clk),
        .rst_n     (rst_n),
        .traffic_level (traffic_level),
        .data_out  (pg_data),
        .valid_out (pg_valid),
        .ready_in  (pg_ready)
    );

    tx #(
        .WIDTH(WIDTH),
        .NUM_LANES(NUM_LANES)
    ) u_tx (
        .clk         (clk),
        .rst_n        (rst_n),
        .data_in     (pg_data),
        .valid_in    (pg_valid),
        .ready_out   (pg_ready),
        .data_out    (tx_data),
        .valid_out   (tx_valid),
        .ready_in    (tx_ready),
        .link_up     (link_up),
        .lane_enable (lane_enable)
    );

    fault_injector #(
        .WIDTH(WIDTH),
        .NUM_LANES(NUM_LANES),
        .LANE_WIDTH(LANE_WIDTH)
    ) u_fault_injector (
        .clk                (clk),
        .rst_n              (rst_n),
        .data_in            (tx_data),
        .valid_in           (tx_valid),
        .ready_in           (tx_ready),
        .data_out           (fault_data),
        .valid_out          (fault_valid),
        .ready_out          (fault_ready),
        .fault_enable       (fault_enable),
        .fault_type         (fault_type),
        .fault_rate         (fault_rate),
        .burst_length       (burst_length),
        .fault_duration     (fault_duration),
        .lane_mask          (fault_lane_mask),
        .fault_active       (fault_active),
        .fault_inject_count (fault_inject_count)
    );

    multi_lane_link #(
        .WIDTH(WIDTH),
        .NUM_LANES(NUM_LANES),
        .LANE_WIDTH(LANE_WIDTH)
    ) u_multi_lane_link (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_in     (fault_data),
        .valid_in    (fault_valid),
        .ready_in    (fault_ready),
        .data_out    (link_data),
        .valid_out   (link_valid),
        .ready_out   (link_ready),
        .lane0       (lane0),
        .lane1       (lane1),
        .lane2       (lane2),
        .lane3       (lane3),
        .lane_enable (lane_enable)
    );

    rx #(
        .WIDTH(WIDTH),
        .NUM_LANES(NUM_LANES)
    ) u_rx (
        .clk         (clk),
        .rst_n        (rst_n),
        .data_in     (link_data),
        .valid_in    (link_valid),
        .ready_out   (link_ready),
        .data_out    (rx_data),
        .valid_out   (rx_valid),
        .ready_in    (rx_ready),
        .link_up     (link_up),
        .lane_enable (lane_enable)
    );

    assign data_out  = rx_data;
    assign valid_out = rx_valid;

    packet_checker #(
        .WIDTH(WIDTH),
        .NUM_LANES(NUM_LANES)
    ) u_packet_checker (
        .clk          (clk),
        .rst_n        (rst_n),
        .data_in      (rx_data),
        .valid_in     (rx_valid),
        .ready_in     (rx_ready),
        .packet_error (pkt_error),
        .lane_error   (checked_lane_error)
    );

    link_controller #(
        .NUM_LANES(NUM_LANES)
    ) u_link_controller (
        .clk            (clk),
        .rst_n          (rst_n),
        .link_enable    (link_enable),
        .training_mode  (training_mode),
        .tx_ready       (tx_ready_status),
        .rx_ready       (rx_ready_status),
        .lane_ok        (lane_ok),
        .fault_detected (fault_detected),
        .link_up        (link_up),
        .lane_enable    (lane_enable),
        .link_state     (link_state),
        .retrain_req    (retrain_req)
    );

    error_monitor u_error_monitor (
        .clk               (clk),
        .rst_n              (rst_n),
        .pkt_valid         (rx_valid),
        .pkt_error         (pkt_error),
        .lane_error        (lane_error),
        .link_up           (link_up),
        .fault_enable      (fault_enable),
        .fault_type        ({2'b00, fault_type}),
        .fault_rate        (fault_rate),
        .burst_length      (burst_length),
        .fault_active      (fault_active),
        .clear_counters    (1'b0),
        .total_packets     (total_packets),
        .error_packets     (error_packets),
        .lane_error_cnt0   (lane_error_cnt0),
        .lane_error_cnt1   (lane_error_cnt1),
        .lane_error_cnt2   (lane_error_cnt2),
        .lane_error_cnt3   (lane_error_cnt3),
        .injected_faults   (injected_faults),
        .error_overflow    (error_overflow)
    );

endmodule
