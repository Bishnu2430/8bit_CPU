`timescale 1ns/1ps

// ============================================================
// Instruction Memory (ROM)
// 256 x 16-bit words, asynchronous read
// ============================================================
// v1.3 (final):
//   - ROM contents now match example.asm / assembler output.
//   - Loop uses ADDI R6,#-1 to decrement, BLT R6,R0 to exit
//     when R6 goes negative, and BEQ R0,R0 as unconditional
//     backward branch.
//   - NOP sentinel at end of program for clean simulation stop.
// ============================================================

module instruction_memory (
    input  [15:0] address,
    output [15:0] instruction
);

    reg [15:0] memory [0:255];

    integer i;
    initial begin
        // Zero out all memory first
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 16'b0000_000_000_000000; // NOP

        // ---------------------------------------------------------
        // Program: demonstrates ADDI, BEQ (taken), STORE, LOAD,
        // ADDI (negative imm), BLT, and a finite backward loop.
        // Matches example.asm / assembler output exactly.
        // ---------------------------------------------------------

        memory[0]  = 16'b1001_001_000_000101;  // ADDI R1, #5
        memory[1]  = 16'b1001_010_000_000101;  // ADDI R2, #5
        memory[2]  = 16'b1011_001_010_000001;  // BEQ  R1, R2, +1 (skip addr 3)
        memory[3]  = 16'b1001_011_000_000001;  // ADDI R3, #1     (SKIPPED)
        memory[4]  = 16'b1001_100_000_001001;  // ADDI R4, #9
        memory[5]  = 16'b0111_100_000_001010;  // STORE R4, #10
        memory[6]  = 16'b0110_101_000_001010;  // LOAD  R5, #10
        memory[7]  = 16'b1001_110_000_000101;  // ADDI R6, #5     (loop counter)
        // LOOP (PC=8):
        memory[8]  = 16'b1001_110_000_111111;  // ADDI R6, #-1
        memory[9]  = 16'b1101_110_000_000001;  // BLT  R6, R0, +1 → END (addr 11)
        memory[10] = 16'b1011_000_000_111101;  // BEQ  R0, R0, -3 → LOOP (addr 8)
        // END:
        memory[11] = 16'b0000_000_000_000000;  // NOP (sentinel)

    end

    // Asynchronous read (only lower 8 bits used for 256-word space)
    assign instruction = memory[address[7:0]];

endmodule