`timescale 1ns/1ps
// ============================================================
// decoder.v — matches decoder.dig exactly
//
// .dig implementation:
//   Single Splitter element (Input Splitting: 16, Output Splitting: 6,3,3,4)
//   Ports:  In:  instruction_in[15:0]
//           Out: imm6[5:0], rs[2:0], rd[2:0], opcode[3:0]
//
// The splitter outputs bits in LSB-first order:
//   imm6   = instruction_in[5:0]
//   rs     = instruction_in[8:6]
//   rd     = instruction_in[11:9]
//   opcode = instruction_in[15:12]
//
// Purely combinational — no clock, no state.
// ============================================================

module decoder (
    input  wire [15:0] instruction_in,
    output wire [3:0]  opcode,
    output wire [2:0]  rd,
    output wire [2:0]  rs,
    output wire [5:0]  imm6
);

    // Direct bit-slice assigns — identical to Digital's Splitter behaviour
    assign imm6   = instruction_in[5:0];
    assign rs     = instruction_in[8:6];
    assign rd     = instruction_in[11:9];
    assign opcode = instruction_in[15:12];

endmodule