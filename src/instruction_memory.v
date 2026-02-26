`timescale 1ns/1ps

// ============================================================
// Instruction Memory (ROM)
// 256 x 16-bit words, asynchronous read
// ============================================================
// v1.2:
//   - Loop now uses SUB R6, R7 (R7=1) to decrement R6 each iteration
//     and BNE R6, R0 to branch back while R6 != 0.
//   - Loop: R6 = 5, R7 = 1, LOOP: R6 = R6 - R7, BNE R6, R0, -2
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
        // SUB, and a finite BNE countdown loop.
        // ---------------------------------------------------------

        // R1 = 5
        memory[0] = 16'b1001_001_000_000101;  // ADDI R1, 5

        // R2 = 5
        memory[1] = 16'b1001_010_000_000101;  // ADDI R2, 5

        // BEQ R1, R2, +1  (skip memory[3])
        memory[2] = 16'b1011_001_010_000001;

        // SKIPPED
        memory[3] = 16'b1001_011_000_000001;  // ADDI R3, 1

        // R4 = 9
        memory[4] = 16'b1001_100_000_001001;  // ADDI R4, 9

        // STORE R4 → MEM[10]
        memory[5] = 16'b0111_100_000_001010;

        // LOAD MEM[10] → R5
        memory[6] = 16'b0110_101_000_001010;

        // R6 = 5  (loop counter, small positive value)
        memory[7] = 16'b1001_110_000_000101;  // ADDI R6, 5

        // R7 = 1  (decrement step)
        memory[8] = 16'b1001_111_000_000001;  // ADDI R7, 1

        // LOOP START (PC=9): R6 = R6 - R7
        memory[9] = 16'b0010_110_111_000000;  // SUB R6, R7

        // BNE R6, R0, -2  → if R6 != 0, go back to memory[9]
        // PC after fetch = 11, offset = -2, target = 11 + (-2) = 9
        memory[10] = 16'b1100_110_000_111110; // BNE R6, R0, -2

        // Loop exits here — R6 == 0
        memory[11] = 16'b0000_000_000_000000; // NOP

    end

    // Asynchronous read (only lower 8 bits used for 256-word space)
    assign instruction = memory[address[7:0]];

endmodule