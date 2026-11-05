// TX: one-entry VALID/READY buffer.
// The buffered packet is held while the link is inactive instead of being
// silently dropped, so a manual retrain does not truncate the sequence.
module tx #(
    parameter WIDTH = 32,
    parameter NUM_LANES = 2
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [WIDTH-1:0]         data_in,
    input  wire                     valid_in,
    output wire                     ready_out,

    output reg  [WIDTH-1:0]         data_out,
    output reg                      valid_out,
    input  wire                     ready_in,

    input  wire                     link_up,
    input  wire [NUM_LANES-1:0]     lane_enable
);

    wire link_active = link_up && (|lane_enable);
    wire stage_can_advance = !valid_out || ready_in;

    // Do not accept traffic before the link is ACTIVE.
    assign ready_out = link_active && stage_can_advance;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= {WIDTH{1'b0}};
            valid_out <= 1'b0;
        end
        else if (stage_can_advance) begin
            if (ready_out && valid_in) begin
                data_out  <= data_in;
                valid_out <= 1'b1;
            end
            else if (valid_out && ready_in) begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
