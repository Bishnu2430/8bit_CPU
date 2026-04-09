`timescale 1ns/1ps
// ============================================================
// instruction_memory.v — RTL translation of
//                        instruction_memory.dig
//
// .dig implementation:
//   ROM element (AddrBits=8, Bits=16)
//   Always-enabled via Const(1) on the ROM enable pin.
//   Read is asynchronous (combinational) — no clock pin on ROM.
//
//   address input:  8-bit — driven by pc_out[7:0] from
//                   cpu_core_test.dig via Splitter(16→8,8).
//                   Upper 8 bits of the 16-bit PC are discarded,
//                   limiting program size to 256 instructions.
//
//   instruction output: 16-bit, combinationally valid whenever
//                       address changes.
//
// ROM data string (from instruction_memory.dig, corrected):
//   Entry 0x0B was 0xA00B (JMP #11 → infinite loop).
//   Corrected to 0x0000 (NOP) to match assembler output.
//
//   Address  Hex     Disassembly
//   0x00     0x9205  ADDI R1, #5
//   0x01     0x9405  ADDI R2, #5
//   0x02     0xB281  BEQ  R1, R2, +1  (skip 0x03, branch to 0x04)
//   0x03     0x9601  ADDI R3, #1      (skipped)
//   0x04     0x9809  ADDI R4, #9
//   0x05     0x780A  STORE R4, #10
//   0x06     0x6A0A  LOAD  R5, #10
//   0x07     0x9C05  ADDI R6, #5      (loop counter init)
//   0x08     0x9C3F  ADDI R6, #-1    (LOOP top)
//   0x09     0xDC01  BLT  R6, R0, +1  (exit if R6 < 0)
//   0x0A     0xB03D  BEQ  R0, R0, -3  (unconditional → 0x08)
//   0x0B     0x0000  NOP              (END sentinel)
//   0x0C-FF  0x0000  NOP              (all remaining slots zeroed)
// ============================================================

module instruction_memory (
    input  wire [15:0] address,
    output wire [15:0] instruction
);

    reg [15:0] memory [0:255];

    integer i;
    initial begin
        // Zero all slots first (NOP = 0x0000)
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 16'h0000;

        // ---- ROM contents matching .dig data string (corrected) ----
        memory[8'h00] = 16'h9205;   // ADDI R1, #5
        memory[8'h01] = 16'h9405;   // ADDI R2, #5
        memory[8'h02] = 16'hB281;   // BEQ  R1, R2, +1
        memory[8'h03] = 16'h9601;   // ADDI R3, #1   (skipped by BEQ)
        memory[8'h04] = 16'h9809;   // ADDI R4, #9
        memory[8'h05] = 16'h780A;   // STORE R4, #10
        memory[8'h06] = 16'h6A0A;   // LOAD  R5, #10
        memory[8'h07] = 16'h9C05;   // ADDI R6, #5   (loop counter init)
        memory[8'h08] = 16'h9C3F;   // ADDI R6, #-1  (LOOP top)
        memory[8'h09] = 16'hDC01;   // BLT  R6, R0, +1
        memory[8'h0A] = 16'hB03D;   // BEQ  R0, R0, -3
        memory[8'h0B] = 16'h0000;   // NOP  (END sentinel) — was 0xA00B in .dig
        // [0x0C..0xFF] remain 0x0000 (NOP)
    end

    // Asynchronous read — Digital ROM has no clock on read port
    assign instruction = memory[address[7:0]];

endmodule