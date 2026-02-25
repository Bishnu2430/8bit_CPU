`timescale 1ns/1ps
module instruction_register (
    input clk, input reset, input ir_load,
    input [15:0] instruction_in,
    output reg [15:0] instruction_out
);
always @(posedge clk) begin
    if (reset)        instruction_out <= 16'b0;
    else if (ir_load) instruction_out <= instruction_in;
end
endmodule