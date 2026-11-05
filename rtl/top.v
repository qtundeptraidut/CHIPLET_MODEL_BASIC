// FPGA physical top.
// Keep this wrapper small: only real FPGA I/O is exposed here.
// Research configuration is kept inside the core for synthesis/demo.
// For Cocotb, instantiate chiplet_interconnect_core directly.

module chiplet_interconnect_top(
    input  wire        clk,
    input  wire        rst_n,

    output wire [31:0] data_out,
    output wire        valid_out,
    output wire        link_up
);

    // Default FPGA demo configuration.
    // Change these constants for a hardware demo.
    wire       link_enable      = 1'b1;
    wire [1:0] training_mode    = 2'b00;
    wire [7:0] traffic_level    = 8'hFF;

    wire       fault_enable     = 1'b0;
    wire [1:0] fault_type       = 2'd0;
    wire [7:0] fault_rate       = 8'd0;
    wire [7:0] burst_length     = 8'd0;
    wire [7:0] fault_duration   = 8'd0;
    wire [1:0] fault_lane_mask  = 2'b01;

    // Internal research/status signals.
    wire [1:0] lane_enable;
    wire [1:0] link_state;
    wire retrain_req;
    wire fault_active;
    wire [15:0] fault_inject_count;

    wire [31:0] total_packets;
    wire [31:0] error_packets;
    wire [31:0] lane_error_cnt0;
    wire [31:0] lane_error_cnt1;
    wire [31:0] lane_error_cnt2;
    wire [31:0] lane_error_cnt3;
    wire [31:0] injected_faults;
    wire error_overflow;

    chiplet_interconnect_core #(
        .WIDTH(32),
        .NUM_LANES(2),
        .LANE_WIDTH(16)
    ) u_core (
        .clk                (clk),
        .rst_n              (rst_n),
        .link_enable        (link_enable),
        .training_mode      (training_mode),
        .traffic_level      (traffic_level),
        .fault_enable       (fault_enable),
        .fault_type         (fault_type),
        .fault_rate         (fault_rate),
        .burst_length       (burst_length),
        .fault_duration     (fault_duration),
        .fault_lane_mask    (fault_lane_mask),
        .data_out           (data_out),
        .valid_out          (valid_out),
        .link_up             (link_up),
        .lane_enable        (lane_enable),
        .link_state         (link_state),
        .retrain_req        (retrain_req),
        .fault_active       (fault_active),
        .fault_inject_count (fault_inject_count),
        .total_packets      (total_packets),
        .error_packets      (error_packets),
        .lane_error_cnt0    (lane_error_cnt0),
        .lane_error_cnt1    (lane_error_cnt1),
        .lane_error_cnt2    (lane_error_cnt2),
        .lane_error_cnt3    (lane_error_cnt3),
        .injected_faults    (injected_faults),
        .error_overflow     (error_overflow)
    );

endmodule
