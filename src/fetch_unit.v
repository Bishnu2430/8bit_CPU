`timescale 1ns/1ps
// ============================================================
// fetch_unit.v — Structural wrapper grouping PC, IMEM, IR
//
// This module is a convenience wrapper; it does not correspond
// to a single .dig file. In cpu_core_test.dig the three
// components (program_counter, instruction_memory,
// instruction_register) are instantiated individually and wired
// directly. This wrapper reproduces those exact connections.
//
// Wiring (from cpu_core_test.dig):
//
//   program_counter:
//     clk, reset, pc_enable, pc_load, pc_in → pc_out
//
//   instruction_memory:
//     address = pc_out   (Splitter in cpu_core_test.dig extracts
//                         pc_out[7:0]; instruction_memory.v uses
//                         address[7:0] internally)
//     → instruction (asynchronous)
//
//   instruction_register:
//     clk, reset, ir_load
//     instruction_in = instruction_from_mem
//     → instruction_out
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

    // ---- Program Counter ----------------------------------------
    program_counter pc_inst (
        .clk       (clk),
        .reset     (reset),
        .pc_enable (pc_enable),
        .pc_load   (pc_load),
        .pc_in     (pc_in),
        .pc_out    (pc_out)
    );

    // ---- Instruction Memory (ROM, asynchronous read) ------------
    instruction_memory imem_inst (
        .address     (pc_out),
        .instruction (instruction_from_mem)
    );

    // ---- Instruction Register -----------------------------------
    instruction_register ir_inst (
        .clk             (clk),
        .reset           (reset),
        .ir_load         (ir_load),
        .instruction_in  (instruction_from_mem),
        .instruction_out (instruction_out)
    );

endmodule