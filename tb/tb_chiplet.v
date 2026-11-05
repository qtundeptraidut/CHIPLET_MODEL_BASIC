`timescale 1ns/1ps
// ============================================================
// Self-checking testbench for the simple chiplet interconnect.
//
// Covered:
//   1. Reset values
//   2. Link training (IDLE -> TRAINING -> ACTIVE)
//   3. Clean traffic, no errors
//   4. Intermittent-open fault on lane 0
//   5. Data-dependent bridge fault (lane 0 aggressor, lane 1 victim)
//   6. Link down / retrain without losing a packet
// ============================================================

module tb_chiplet;

    // ---------------- Clock / DUT control ----------------
    reg clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    reg        rst_n;
    reg        link_enable;
    reg [1:0]  training_mode;
    reg [7:0]  traffic_level;

    reg        fault_enable;
    reg [1:0]  fault_type;
    reg [7:0]  fault_rate;
    reg [7:0]  burst_length;
    reg [7:0]  fault_duration;
    reg [1:0]  fault_lane_mask;

    // ---------------- DUT outputs ----------------
    wire [31:0] data_out;
    wire        valid_out;
    wire        link_up;
    wire [1:0]  lane_enable;
    wire [1:0]  link_state;
    wire        retrain_req;
    wire        fault_active;
    wire [15:0] fault_inject_count;

    wire [31:0] total_packets;
    wire [31:0] error_packets;
    wire [31:0] lane_error_cnt0;
    wire [31:0] lane_error_cnt1;
    wire [31:0] lane_error_cnt2;
    wire [31:0] lane_error_cnt3;
    wire [31:0] injected_faults;
    wire        error_overflow;

    integer errors;
    integer i;

    reg [31:0] t0, e0, i0, l0, l1, l2, l3;
    reg [31:0] tb_expected;
    reg        clean_check;
    reg        tb_seq_error;

    chiplet_interconnect_core #(
        .WIDTH      (32),
        .NUM_LANES  (2),
        .LANE_WIDTH (16)
    ) dut (
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
        .link_up            (link_up),
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

    // Independent golden-sequence monitor on the top-level output.
    always @(posedge clk) begin
        if (!rst_n) begin
            tb_expected <= 32'd0;
        end
        else if (valid_out) begin
            if (clean_check && (data_out !== tb_expected)) begin
                $display("FAIL  [tb] data mismatch: got %0d, expected %0d at t=%0t",
                         data_out, tb_expected, $time);
                tb_seq_error <= 1'b1;
            end
            tb_expected <= tb_expected + 32'd1;
        end
    end

    // ---------------- Helper tasks ----------------
    task check;
        input        cond;
        input [8*80-1:0] msg;
        begin
            if (cond)
                $display("PASS  %0s", msg);
            else begin
                $display("FAIL  %0s  (t=%0t)", msg, $time);
                errors = errors + 1;
            end
        end
    endtask

    task snap;
        begin
            t0 = total_packets;
            e0 = error_packets;
            i0 = injected_faults;
            l0 = lane_error_cnt0;
            l1 = lane_error_cnt1;
            l2 = lane_error_cnt2;
            l3 = lane_error_cnt3;
        end
    endtask

    task wait_link_up;
        begin
            i = 0;
            while ((link_up !== 1'b1) && (i < 32)) begin
                @(posedge clk);
                i = i + 1;
            end
        end
    endtask

    // ---------------- Test sequence ----------------
    initial begin
        $dumpfile("build/tb_chiplet.vcd");
        $dumpvars(0, tb_chiplet);

        errors       = 0;
        clean_check  = 1'b0;
        tb_expected  = 32'd0;
        tb_seq_error = 1'b0;

        rst_n          = 1'b0;
        link_enable    = 1'b0;
        training_mode  = 2'b00;
        traffic_level  = 8'hFF;
        fault_enable   = 1'b0;
        fault_type     = 2'd0;
        fault_rate     = 8'd0;
        burst_length   = 8'd1;
        fault_duration = 8'd1;
        fault_lane_mask= 2'b01;

        repeat (5) @(posedge clk);
        #1;
        check(link_up     === 1'b0,  "reset: link is down");
        check(lane_enable === 2'b00, "reset: lanes disabled");
        check(valid_out   === 1'b0,  "reset: no valid output");

        // -------- 1. Link training --------
        rst_n = 1'b1;
        @(negedge clk);
        link_enable = 1'b1;
        wait_link_up;
        #1;
        check(link_up     === 1'b1,  "training: link_up asserted");
        check(link_state  === 2'b10, "training: state ACTIVE");
        check(lane_enable === 2'b11, "training: both lanes enabled");
        check(retrain_req === 1'b0,  "training: no retrain request");

        // -------- 2. Clean traffic --------
        clean_check = 1'b1;
        snap;
        repeat (400) @(posedge clk);
        #1;
        check((total_packets - t0) > 350,   "clean: packets flowing");
        check(error_packets === e0,         "clean: no packet errors");
        check(injected_faults === i0,       "clean: no injected faults");
        check(lane_error_cnt0 === l0,       "clean: lane0 clean");
        check(lane_error_cnt1 === l1,       "clean: lane1 clean");
        check(error_overflow === 1'b0,      "clean: no counter overflow");
        check(tb_seq_error === 1'b0,        "clean: top-level data matches golden sequence");

        // -------- 3. Intermittent-open fault on lane 0 --------
        clean_check = 1'b0;
        @(negedge clk);
        fault_enable = 1'b0;
        repeat (10) @(posedge clk);
        snap;
        @(negedge clk);
        fault_enable    = 1'b1;
        fault_type      = 2'd0;
        fault_rate      = 8'hFF;
        fault_duration  = 8'd4;
        burst_length    = 8'd4;
        fault_lane_mask = 2'b01;
        repeat (600) @(posedge clk);
        @(negedge clk);
        fault_enable = 1'b0;
        repeat (10) @(posedge clk);
        #1;
        check((injected_faults - i0) > 0,                          "open: faults injected");
        check((error_packets - e0) > 0,                            "open: errors observed");
        check((injected_faults - i0) === (error_packets - e0),     "open: injected == observed");
        check((lane_error_cnt0 - l0) === (injected_faults - i0),   "open: lane0 errors == injected");
        check((lane_error_cnt1 - l1) === 32'd0,                    "open: lane1 untouched");
        check((fault_inject_count) === injected_faults[15:0],      "open: inject counter matches");
        check(error_overflow === 1'b0,                             "open: no counter overflow");

        // -------- 4. Bridge fault (lane0 aggressor -> lane1 victim) --------
        @(negedge clk);
        fault_enable = 1'b0;
        repeat (10) @(posedge clk);
        snap;
        @(negedge clk);
        fault_enable    = 1'b1;
        fault_type      = 2'd1;
        fault_rate      = 8'hFF;
        burst_length    = 8'd4;
        fault_duration  = 8'd1;
        fault_lane_mask = 2'b10;
        repeat (600) @(posedge clk);
        @(negedge clk);
        fault_enable = 1'b0;
        repeat (10) @(posedge clk);
        #1;
        check((injected_faults - i0) > 0,                          "bridge: faults injected");
        check((error_packets - e0) > 0,                            "bridge: errors observed");
        check((injected_faults - i0) === (error_packets - e0),     "bridge: injected == observed");
        check((lane_error_cnt1 - l1) === (injected_faults - i0),   "bridge: lane1 errors == injected");
        check((lane_error_cnt0 - l0) === 32'd0,                    "bridge: lane0 untouched");
        check(error_overflow === 1'b0,                             "bridge: no counter overflow");

        // -------- 5. Link down / retrain, no packet loss --------
        clean_check = 1'b0;
        @(negedge clk);
        link_enable = 1'b0;
        repeat (6) @(posedge clk);
        #1;
        check(link_up     === 1'b0,  "link down: link_up deasserted");
        check(link_state  === 2'b00, "link down: state IDLE");
        check(lane_enable === 2'b00, "link down: lanes disabled");
        check(valid_out   === 1'b0,  "link down: no valid output");

        @(negedge clk);
        link_enable = 1'b1;
        wait_link_up;
        #1;
        check(link_up    === 1'b1,  "retrain: link_up asserted");
        check(link_state === 2'b10, "retrain: state ACTIVE");

        clean_check = 1'b1;
        snap;
        repeat (300) @(posedge clk);
        #1;
        check((error_packets - e0) === 32'd0, "retrain: no sequence errors (no packet loss)");
        check((total_packets - t0) > 250,     "retrain: traffic resumed");
        check(tb_seq_error === 1'b0,          "retrain: top-level data still matches");

        // -------- Summary --------
        if (tb_seq_error)
            errors = errors + 1;

        $display("========================================");
        if (errors == 0) begin
            $display("SUMMARY: ALL TESTS PASSED");
            $display("  total_packets   = %0d", total_packets);
            $display("  error_packets   = %0d", error_packets);
            $display("  injected_faults = %0d", injected_faults);
            $display("  lane_err[0..3]  = %0d %0d %0d %0d",
                     lane_error_cnt0, lane_error_cnt1, lane_error_cnt2, lane_error_cnt3);
            $display("========================================");
            $finish;
        end
        else begin
            $display("SUMMARY: %0d TEST(S) FAILED", errors);
            $display("========================================");
            $finish;
        end
    end

endmodule
