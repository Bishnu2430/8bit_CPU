`timescale 1ns/1ps
// ============================================================
// decoder.v — RTL translation of decoder.dig
//
// .dig implementation:
//   Single Splitter element (Input Splitting: 16,
//                            Output Splitting: 6,3,3,4,
//                            splitterSpreading=4)
//
//   Ports:
//     In:  instruction_in[15:0]
//     Out: imm6[5:0]   = instruction_in[5:0]
//          rs[2:0]     = instruction_in[8:6]
//          rd[2:0]     = instruction_in[11:9]
//          opcode[3:0] = instruction_in[15:12]
//
//   The Digital Splitter outputs bits in LSB-first order.
//   The 6,3,3,4 split starting from bit 0 gives:
//     imm6   = [5:0]
//     rs     = [8:6]
//     rd     = [11:9]
//     opcode = [15:12]
//   This maps exactly to the ISA encoding.
//
//   Purely combinational — no clock, no state.
// ============================================================

module decoder (
    input  wire [15:0] instruction_in,
    output wire [5:0]  imm6,
    output wire [2:0]  rs,
    output wire [2:0]  rd,
    output wire [3:0]  opcode
);

    // Direct bit-slice assigns — identical to Digital's Splitter behaviour
    assign imm6   = instruction_in[5:0];
    assign rs     = instruction_in[8:6];
    assign rd     = instruction_in[11:9];
    assign opcode = instruction_in[15:12];

endmodule