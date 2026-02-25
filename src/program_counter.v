`timescale 1ns/1ps
module program_counter (
    input clk, input reset,
    input pc_enable, input pc_load,
    input [15:0] pc_in,
    output reg [15:0] pc_out
);
always @(posedge clk) begin
    if (reset)        pc_out <= 16'b0;
    else if (pc_load) pc_out <= pc_in;
    else if (pc_enable) pc_out <= pc_out + 16'd1;
end
endmodule