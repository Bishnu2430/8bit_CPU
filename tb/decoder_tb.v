`timescale 1ns/1ps

module decoder_tb;

reg [15:0] instruction_in;

wire [3:0] opcode;
wire [2:0] rd;
wire [2:0] rs;
wire [5:0] imm6;

decoder uut (
    .instruction_in(instruction_in),
    .opcode(opcode),
    .rd(rd),
    .rs(rs),
    .imm6(imm6)
);

initial begin
    $dumpfile("decoder_dump.vcd");
    $dumpvars(0, decoder_tb);

    // ADD R1, R2
    instruction_in = 16'b0001_001_010_000000; #10;

    // ADDI R4, 5
    instruction_in = 16'b1001_100_000_000101; #10;

    // JMP 2
    instruction_in = 16'b1010_000_000_000010; #10;

    $finish;
end

endmodule
