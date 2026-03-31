`timescale 1ns/1ps
// ============================================================
// fetch_unit.v — structural wrapper instantiating sub-components
//
// This module is a convenience wrapper; it is not directly
// represented as a single .dig file.  The cpu_core_test.dig
// instantiates program_counter, instruction_memory, and
// instruction_register individually and wires them together.
// This wrapper reproduces those exact connections.
//
// Wiring (from cpu_core_test.dig):
//   program_counter:
//     clk, reset, pc_enable, pc_load, pc_in → pc_out
//
//   instruction_memory:
//     address = pc_out → instruction (async)
//
//   instruction_register:
//     clk, reset, ir_load, instruction_in = imem_out → instruction_out
// ============================================================

module fetch_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_enable,
    input  wire        pc_load,
    input  wire [15:0] pc_in,
    input  wire        ir_load,
    output wire [15:0] instruction_out,
    output wire [15:0] pc_out
);

    wire [15:0] instruction_from_mem;

    program_counter pc (
        .clk       (clk),
        .reset     (reset),
        .pc_enable (pc_enable),
        .pc_load   (pc_load),
        .pc_in     (pc_in),
        .pc_out    (pc_out)
    );

    instruction_memory imem (
        .address     (pc_out),
        .instruction (instruction_from_mem)
    );

    instruction_register ir (
        .clk             (clk),
        .reset           (reset),
        .ir_load         (ir_load),
        .instruction_in  (instruction_from_mem),
        .instruction_out (instruction_out)
    );

endmodule