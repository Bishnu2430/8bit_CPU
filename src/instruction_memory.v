`timescale 1ns/1ps

// ============================================================
// Instruction Memory (ROM)
// 256 x 16-bit words, asynchronous read
// ============================================================
// BUG FIX v1.1:
//   - Rewrote loop so R6 counts DOWN from 5 to 0 using ADDI with
//     a negative immediate, avoiding the infinite-loop bug where
//     SUB R6, R1 subtracted 5 every iteration making R6 always < R1.
//   - Loop now: R6 = 5, loop: R6 = R6 - 1 (ADDI R6, #-1), BLT exits
//     when R6 >= 0 i.e. the BLT (R6 < R0=0) condition becomes false.
//   - Added NOP sentinel at end of program for clean simulation stop.
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
        // Program: matches example.asm and cpu_execution.md proof.
        // Demonstrates ADDI, BEQ (taken), STORE, LOAD, and a finite
        // BLT countdown loop with unconditional BEQ backward branch.
        // ---------------------------------------------------------

        // PC=0  ADDI R1, #5       → R1 = 0 + 5 = 5
        memory[0]  = 16'b1001_001_000_000101;

        // PC=1  ADDI R2, #5       → R2 = 0 + 5 = 5
        memory[1]  = 16'b1001_010_000_000101;

        // PC=2  BEQ R1, R2, +1    → if R1==R2: PC ← PC_f(3) + 1 = 4 (TAKEN)
        memory[2]  = 16'b1011_001_010_000001;

        // PC=3  ADDI R3, #1       → R3 = 1  ← SKIPPED by BEQ
        memory[3]  = 16'b1001_011_000_000001;

        // PC=4  ADDI R4, #9       → R4 = 9
        memory[4]  = 16'b1001_100_000_001001;

        // PC=5  STORE R4, #10     → MEM[10] ← R4 = 9
        memory[5]  = 16'b0111_100_000_001010;

        // PC=6  LOAD  R5, #10     → R5 ← MEM[10] = 9
        memory[6]  = 16'b0110_101_000_001010;

        // PC=7  ADDI R6, #5       → R6 = 5  (loop counter init)
        memory[7]  = 16'b1001_110_000_000101;

        // ---- Countdown loop: R6 counts 5→4→3→2→1→0→-1 ----
        // LOOP:
        // PC=8  ADDI R6, #-1      → R6 = R6 + (-1)
        //       imm6 = 6'b111111 = -1 (two's complement)
        memory[8]  = 16'b1001_110_000_111111;

        // PC=9  BLT R6, R0, +1    → if R6 < R0(=0): PC ← PC_f(10) + 1 = 11 (END)
        //       Exits loop when R6 goes negative (N^V = 1)
        //       imm6 = 6'b000001 = +1
        memory[9]  = 16'b1101_110_000_000001;

        // PC=10 BEQ R0, R0, -3    → unconditional back to LOOP (PC=8)
        //       R0==R0 always true; PC ← PC_f(11) + (-3) = 8
        //       imm6 = 6'b111101 = -3 (two's complement)
        memory[10] = 16'b1011_000_000_111101;

        // PC=11 NOP — END sentinel (program complete)
        memory[11] = 16'b0000_000_000_000000;

    end

    // Asynchronous read (only lower 8 bits used for 256-word space)
    assign instruction = memory[address[7:0]];

endmodule