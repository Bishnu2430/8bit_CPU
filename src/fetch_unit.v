`timescale 1ns/1ps

module fetch_unit (

    input clk,
    input reset,

    // PC control
    input pc_enable,
    input pc_load,
    input [15:0] pc_in,

    // IR control
    input ir_load,

    // Outputs
    output [15:0] instruction_out,
    output [15:0] pc_out
);

    wire [15:0] instruction_from_mem;

    // Program Counter
    program_counter pc (
        .clk(clk),
        .reset(reset),
        .pc_enable(pc_enable),
        .pc_load(pc_load),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    // Instruction Memory
    instruction_memory imem (
        .address(pc_out),
        .instruction(instruction_from_mem)
    );

    // Instruction Register
    instruction_register ir (
        .clk(clk),
        .reset(reset),
        .ir_load(ir_load),
        .instruction_in(instruction_from_mem),
        .instruction_out(instruction_out)
    );

endmodule
