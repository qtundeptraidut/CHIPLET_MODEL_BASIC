// Golden sequence checker for the deterministic packet source.
module packet_checker #(
    parameter WIDTH = 32,
    parameter NUM_LANES = 2
)(
    input wire clk,
    input wire rst_n,
    input wire [WIDTH-1:0] data_in,
    input wire valid_in,
    input wire ready_in,
    output wire packet_error,
    output wire [NUM_LANES-1:0] lane_error
);
    reg [WIDTH-1:0] expected;

    assign packet_error = valid_in && ready_in && (data_in != expected);
    genvar g;
    generate for (g = 0; g < NUM_LANES; g = g + 1) begin: gen_lane_error
        assign lane_error[g] = valid_in && ready_in &&
            (data_in[g*(WIDTH/NUM_LANES) +: (WIDTH/NUM_LANES)] !=
             expected[g*(WIDTH/NUM_LANES) +: (WIDTH/NUM_LANES)]);
    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected <= {WIDTH{1'b0}};
        end else begin
            if (valid_in && ready_in) begin
                expected <= expected + {{(WIDTH-1){1'b0}}, 1'b1};
            end
        end
    end
endmodule
