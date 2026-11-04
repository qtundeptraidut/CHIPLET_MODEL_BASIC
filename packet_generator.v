// Deterministic ready/valid packet source. A packet remains stable while stalled.
module packet_generator #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [7:0]       traffic_level,
    output reg [WIDTH-1:0]  data_out,
    output reg              valid_out,
    input  wire             ready_in
);
    reg [WIDTH-1:0] packet_id;
    reg [7:0] phase;
    wire [8:0] phase_sum = {1'b0, phase} + {1'b0, traffic_level};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_id <= {WIDTH{1'b0}};
            phase     <= 8'd0;
            data_out  <= {WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (!valid_out || ready_in) begin
            phase <= phase_sum[7:0];
            if (phase_sum[8]) begin
                data_out  <= packet_id;
                valid_out <= 1'b1;
                packet_id <= packet_id + {{(WIDTH-1){1'b0}}, 1'b1};
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule
