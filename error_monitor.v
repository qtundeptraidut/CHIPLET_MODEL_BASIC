// ============================================================
// Error Monitor
// Dem packet, packet loi, loi tung lane va so lan tiem loi
// ============================================================

module error_monitor #(
    parameter NUM_LANES     = 4,
    parameter COUNTER_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     pkt_valid,
    input  wire                     pkt_error,
    input  wire [NUM_LANES-1:0]     lane_error,
    input  wire                     link_up,

    input  wire                     fault_enable,
    input  wire [3:0]               fault_type,
    input  wire [7:0]               fault_rate,
    input  wire [7:0]               burst_length,
    input  wire                     fault_active,

    input  wire                     clear_counters,

    output reg [COUNTER_WIDTH-1:0]  total_packets,
    output reg [COUNTER_WIDTH-1:0]  error_packets,

    output reg [COUNTER_WIDTH-1:0]  lane_error_cnt0,
    output reg [COUNTER_WIDTH-1:0]  lane_error_cnt1,
    output reg [COUNTER_WIDTH-1:0]  lane_error_cnt2,
    output reg [COUNTER_WIDTH-1:0]  lane_error_cnt3,

    output reg [COUNTER_WIDTH-1:0]  injected_faults,
    output reg                      error_overflow
);

    // Các tín hi?u c?u h?nh này hi?n ch? ph?c v? m? r?ng
    wire unused_config;

    assign unused_config =
        (^fault_type) ^
        (^fault_rate) ^
        (^burst_length);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_packets   <= {COUNTER_WIDTH{1'b0}};
            error_packets   <= {COUNTER_WIDTH{1'b0}};

            lane_error_cnt0 <= {COUNTER_WIDTH{1'b0}};
            lane_error_cnt1 <= {COUNTER_WIDTH{1'b0}};
            lane_error_cnt2 <= {COUNTER_WIDTH{1'b0}};
            lane_error_cnt3 <= {COUNTER_WIDTH{1'b0}};

            injected_faults <= {COUNTER_WIDTH{1'b0}};
            error_overflow  <= 1'b0;
        end
        else if (clear_counters) begin
            total_packets   <= {COUNTER_WIDTH{1'b0}};
            error_packets   <= {COUNTER_WIDTH{1'b0}};

            lane_error_cnt0 <= {COUNTER_WIDTH{1'b0}};
            lane_error_cnt1 <= {COUNTER_WIDTH{1'b0}};
            lane_error_cnt2 <= {COUNTER_WIDTH{1'b0}};
            lane_error_cnt3 <= {COUNTER_WIDTH{1'b0}};

            injected_faults <= {COUNTER_WIDTH{1'b0}};
            error_overflow  <= 1'b0;
        end
        else if (link_up) begin

            // ------------------------------------------------
            // Ð?m t?ng s? packet và s? packet l?i
            // ------------------------------------------------
            if (pkt_valid) begin
                if (&total_packets) begin
                    error_overflow <= 1'b1;
                end
                else begin
                    total_packets <= total_packets + 1'b1;
                end

                if (pkt_error) begin
                    if (&error_packets) begin
                        error_overflow <= 1'b1;
                    end
                    else begin
                        error_packets <= error_packets + 1'b1;
                    end
                end
            end

            // ------------------------------------------------
            // Ð?m l?i trên t?ng lane
            // Project hi?n s? d?ng c? ð?nh NUM_LANES = 4
            // ------------------------------------------------
            if (lane_error[0]) begin
                if (&lane_error_cnt0)
                    error_overflow <= 1'b1;
                else
                    lane_error_cnt0 <= lane_error_cnt0 + 1'b1;
            end

            if (lane_error[1]) begin
                if (&lane_error_cnt1)
                    error_overflow <= 1'b1;
                else
                    lane_error_cnt1 <= lane_error_cnt1 + 1'b1;
            end

            if (lane_error[2]) begin
                if (&lane_error_cnt2)
                    error_overflow <= 1'b1;
                else
                    lane_error_cnt2 <= lane_error_cnt2 + 1'b1;
            end

            if (lane_error[3]) begin
                if (&lane_error_cnt3)
                    error_overflow <= 1'b1;
                else
                    lane_error_cnt3 <= lane_error_cnt3 + 1'b1;
            end

            // ------------------------------------------------
            // Ð?m s? transfer th?c s? b? tiêm l?i
            // ------------------------------------------------
            if (fault_enable && fault_active) begin
                if (&injected_faults) begin
                    error_overflow <= 1'b1;
                end
                else begin
                    injected_faults <= injected_faults + 1'b1;
                end
            end
        end
    end

endmodule