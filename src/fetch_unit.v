`timescale 1ns/1ps
module fetch_unit (
    input clk, input reset,
    input pc_enable, input pc_load,
    input [15:0] pc_in, input ir_load,
    output [15:0] instruction_out,
    output [15:0] pc_out
);
    wire [15:0] instruction_from_mem;
    program_counter pc (.clk(clk),.reset(reset),.pc_enable(pc_enable),
        .pc_load(pc_load),.pc_in(pc_in),.pc_out(pc_out));
    instruction_memory imem (.address(pc_out),.instruction(instruction_from_mem));
    instruction_register ir (.clk(clk),.reset(reset),.ir_load(ir_load),
        .instruction_in(instruction_from_mem),.instruction_out(instruction_out));
endmodule