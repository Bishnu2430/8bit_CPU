`timescale 1ns/1ps

module instruction_memory (
    input  [15:0] address,
    output [15:0] instruction
);

    reg [15:0] memory [0:255];

    initial begin

        // R1 = 5
        memory[0] = 16'b1001_001_000_000101; // ADDI R1, 5

        // R2 = 5
        memory[1] = 16'b1001_010_000_000101; // ADDI R2, 5

        // BEQ R1, R2, +1  (skip next instruction)
        // branch_target = PC_after_fetch + offset = 3 + 1 = 4
        memory[2] = 16'b1011_001_010_000001;

        // Should be skipped
        memory[3] = 16'b1001_011_000_000001; // ADDI R3, 1

        // Should execute
        memory[4] = 16'b1001_100_000_001001; // ADDI R4, 9

        // STORE R4 → MEM[10]
        memory[5] = 16'b0111_100_000_001010;

        // LOAD MEM[10] → R5
        memory[6] = 16'b0110_101_000_001010;

        // R6 = 1
        memory[7] = 16'b1001_110_000_000001;

        // R6 = R6 - 1
        memory[8] = 16'b0010_110_001_000000; // SUB R6, R1

        // BLT R6, R1, -2 (loop)
        memory[9] = 16'b1101_110_001_111110; // -2 in 6-bit two's complement

    end

    assign instruction = memory[address[7:0]];

endmodule