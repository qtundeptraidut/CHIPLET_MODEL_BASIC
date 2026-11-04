// Fault signatures:
// 0: intermittent open; selected lanes are forced low while activated.
// 1: data-dependent bridge; a nonzero lane 0 flips bit 0 of selected victim lanes.
// Scheduling advances only on accepted transfers (valid_in && ready_out).
// A fault is only reported on fault_active when its signature really changes
// the data, so injected_faults and observed packet errors stay consistent.
module fault_injector #(
    parameter WIDTH = 32,
    parameter NUM_LANES = 2,
    parameter LANE_WIDTH = WIDTH / NUM_LANES,
    parameter [15:0] SEED = 16'hACE1
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [WIDTH-1:0]         data_in,
    input  wire                     valid_in,
    output wire                     ready_in,
    output wire [WIDTH-1:0]         data_out,
    output wire                     valid_out,
    input  wire                     ready_out,
    input  wire                     fault_enable,
    input  wire [1:0]               fault_type,
    input  wire [7:0]               fault_rate,
    input  wire [7:0]               burst_length,
    input  wire [7:0]               fault_duration,
    input  wire [NUM_LANES-1:0]     lane_mask,
    output wire                     fault_active,
    output reg [15:0]               fault_inject_count
);
    localparam [15:0] NONZERO_SEED = (SEED == 16'd0) ? 16'hACE1 : SEED;

    reg [15:0] lfsr;
    reg [7:0] active_left;
    reg [WIDTH-1:0] transformed;
    reg request_due;
    reg signature_applies;
    integer lane;

    wire accepted_transfer = valid_in && ready_out;
    wire [7:0] activation_length =
        (fault_type == 2'd0) ? fault_duration : burst_length;

    assign valid_out = valid_in;
    assign ready_in  = ready_out;
    assign data_out  = transformed;

    // Only count a fault that is actually applied to an accepted transfer.
    assign fault_active = signature_applies && accepted_transfer;

    // Rate zero never requests; 255 is an explicit always-request boundary.
    // The LFSR state advances per accepted transfer, not per clock.
    always @* begin
        request_due = 1'b0;
        if (fault_enable && valid_in) begin
            if (active_left != 0)
                request_due = 1'b1;
            else if (fault_rate == 8'hFF)
                request_due = 1'b1;
            else if (fault_rate != 8'd0)
                request_due = (lfsr[7:0] < fault_rate);
        end

        signature_applies = 1'b0;
        transformed = data_in;

        if (request_due && accepted_transfer) begin
            if (fault_type == 2'd0) begin
                // An open fault is only observable on a lane that is nonzero.
                for (lane = 0; lane < NUM_LANES; lane = lane + 1)
                    if (lane_mask[lane] &&
                        (|data_in[lane*LANE_WIDTH +: LANE_WIDTH]))
                        signature_applies = 1'b1;

                if (signature_applies)
                    for (lane = 0; lane < NUM_LANES; lane = lane + 1)
                        if (lane_mask[lane])
                            transformed[lane*LANE_WIDTH +: LANE_WIDTH] = {LANE_WIDTH{1'b0}};
            end
            else if ((fault_type == 2'd1) && (NUM_LANES > 1)) begin
                // Lane 0 is the aggressor; selected higher lanes are victims.
                for (lane = 1; lane < NUM_LANES; lane = lane + 1)
                    if (lane_mask[lane] && (|data_in[0 +: LANE_WIDTH])) begin
                        signature_applies = 1'b1;
                        transformed[lane*LANE_WIDTH +: LANE_WIDTH] =
                            data_in[lane*LANE_WIDTH +: LANE_WIDTH] ^
                            {{(LANE_WIDTH-1){1'b0}}, 1'b1};
                    end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= NONZERO_SEED;
            active_left <= 8'd0;
            fault_inject_count <= 16'd0;
        end
        else if (accepted_transfer) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            if (!fault_enable) begin
                active_left <= 8'd0;
            end
            else if (active_left != 0) begin
                // Duration/burst is measured in accepted transfers; stalls and
                // valid gaps preserve the remaining activation window.
                active_left <= active_left - 8'd1;
            end
            else if (fault_active) begin
                if (activation_length > 8'd1)
                    active_left <= activation_length - 8'd1;
                else
                    active_left <= 8'd0;
            end

            if (fault_active && (fault_inject_count != 16'hFFFF))
                fault_inject_count <= fault_inject_count + 16'd1;
        end
    end
endmodule
