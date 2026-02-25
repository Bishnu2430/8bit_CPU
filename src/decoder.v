`timescale 1ns/1ps

module decoder (

    input  [15:0] instruction_in,

    output [3:0] opcode,
    output [2:0] rd,
    output [2:0] rs,
    output [5:0] imm6
);

    assign opcode = instruction_in[15:12];
    assign rd     = instruction_in[11:9];
    assign rs     = instruction_in[8:6];
    assign imm6   = instruction_in[5:0];

endmodule
