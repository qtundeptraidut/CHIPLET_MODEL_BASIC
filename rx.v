// RX: one-entry VALID/READY buffer.
// The buffered packet is held across a link outage. valid_out is only
// asserted while the link is active, so the packet is delivered after the
// link returns instead of being silently dropped.
module rx #(
    parameter WIDTH = 32,
    parameter NUM_LANES = 2
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [WIDTH-1:0]         data_in,
    input  wire                     valid_in,
    output wire                     ready_out,

    output reg  [WIDTH-1:0]         data_out,
    output wire                     valid_out,
    input  wire                     ready_in,

    input  wire                     link_up,
    input  wire [NUM_LANES-1:0]     lane_enable
);

    reg valid_pending;

    wire link_active = link_up && (|lane_enable);
    wire stage_can_advance = !valid_pending || ready_in;

    assign ready_out = link_active && stage_can_advance;
    assign valid_out = valid_pending && link_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out      <= {WIDTH{1'b0}};
            valid_pending <= 1'b0;
        end
        else if (stage_can_advance) begin
            if (ready_out && valid_in) begin
                data_out      <= data_in;
                valid_pending <= 1'b1;
            end
            else if (valid_pending && ready_in && link_active) begin
                valid_pending <= 1'b0;
            end
        end
    end

endmodule
