// Multi-lane link: one-entry VALID/READY stage that slices the packet into
// per-lane words. The stage holds its packet while the link is inactive so a
// link-down/retrain event does not drop an in-flight packet.
module multi_lane_link #(
    parameter WIDTH      = 32,
    parameter NUM_LANES  = 2,
    parameter LANE_WIDTH = WIDTH / NUM_LANES
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [WIDTH-1:0]         data_in,
    input  wire                     valid_in,
    output wire                     ready_in,

    output reg  [WIDTH-1:0]         data_out,
    output reg                      valid_out,
    input  wire                     ready_out,

    output wire [LANE_WIDTH-1:0]    lane0,
    output wire [LANE_WIDTH-1:0]    lane1,
    output wire [LANE_WIDTH-1:0]    lane2,
    output wire [LANE_WIDTH-1:0]    lane3,

    input  wire [NUM_LANES-1:0]     lane_enable
);

    wire link_active = |lane_enable;
    wire stage_can_advance = !valid_out || ready_out;

    assign ready_in = link_active && stage_can_advance;

    assign lane0 = data_out[0*LANE_WIDTH +: LANE_WIDTH];
    generate if (NUM_LANES > 1) begin: gen_lane1
        assign lane1 = data_out[1*LANE_WIDTH +: LANE_WIDTH];
    end else begin: gen_no_lane1
        assign lane1 = {LANE_WIDTH{1'b0}};
    end endgenerate
    generate if (NUM_LANES > 2) begin: gen_lane2
        assign lane2 = data_out[2*LANE_WIDTH +: LANE_WIDTH];
    end else begin: gen_no_lane2
        assign lane2 = {LANE_WIDTH{1'b0}};
    end endgenerate
    generate if (NUM_LANES > 3) begin: gen_lane3
        assign lane3 = data_out[3*LANE_WIDTH +: LANE_WIDTH];
    end else begin: gen_no_lane3
        assign lane3 = {LANE_WIDTH{1'b0}};
    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= {WIDTH{1'b0}};
            valid_out <= 1'b0;
        end
        else if (stage_can_advance) begin
            if (ready_in && valid_in) begin
                data_out  <= data_in;
                valid_out <= 1'b1;
            end
            else if (valid_out && ready_out) begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
