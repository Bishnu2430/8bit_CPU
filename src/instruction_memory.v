`timescale 1ns/1ps
// ============================================================
// instruction_memory.v — matches instruction_memory.dig exactly
//
// .dig implementation:
//   ROM element (AddrBits=8, Bits=16)
//   Data string: 9205,9405,b281,9601,9809,780a,6a0a,9c05,9c3f,dc01,b03d,0000
//   (12 entries; remaining 244 addresses read as 0x0000 = NOP)
//
//   The .dig file in the repository has "a00b" as the 12th entry (index 11).
//   That is JMP #11, which creates an infinite loop and does NOT match the
//   Verilog simulation output in build/sim_output.txt (which terminates on
//   NOP).  The assembler output (build/example.hex) also has NOP at [011].
//   This file corrects entry [11] to 0x0000 (NOP) to match assembler output.
//
//   In: address[7:0]  (only lower 8 bits used, upper 8 ignored — matches .dig)
//       Const(1) tied to the ROM's enable pin — always enabled
//   Out: instruction[15:0]
//   Read: asynchronous (combinational assign)
// ============================================================

module instruction_memory (
    input  wire [15:0] address,
    output wire [15:0] instruction
);

    reg [15:0] memory [0:255];

    integer i;
    initial begin
        // Zero all slots first (NOP)
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 16'h0000;

        // ---- ROM contents matching instruction_memory.dig data string ----
        // 9205,9405,b281,9601,9809,780a,6a0a,9c05,9c3f,dc01,b03d,0000
        memory[0]  = 16'h9205;   // ADDI R1, #5
        memory[1]  = 16'h9405;   // ADDI R2, #5
        memory[2]  = 16'hB281;   // BEQ  R1, R2, +1
        memory[3]  = 16'h9601;   // ADDI R3, #1  (skipped)
        memory[4]  = 16'h9809;   // ADDI R4, #9
        memory[5]  = 16'h780A;   // STORE R4, #10
        memory[6]  = 16'h6A0A;   // LOAD  R5, #10
        memory[7]  = 16'h9C05;   // ADDI R6, #5
        memory[8]  = 16'h9C3F;   // ADDI R6, #-1   (LOOP top)
        memory[9]  = 16'hDC01;   // BLT  R6, R0, +1
        memory[10] = 16'hB03D;   // BEQ  R0, R0, -3
        memory[11] = 16'h0000;   // NOP  (END sentinel)
        // [12..255] remain 0x0000
    end

    // Asynchronous read — Digital ROM has no clock on read port
    assign instruction = memory[address[7:0]];

endmodule