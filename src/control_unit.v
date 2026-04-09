`timescale 1ns/1ps
// ============================================================
// control_unit.v — RTL translation of control_unit.dig
//
// .dig implementation:
//
// ── FSM STATE COUNTER ────────────────────────────────────────
//   Register(2-bit):
//     D   = MUX_out
//     en  = Const(1)   — always enabled
//     clk = clk
//     Q   = state[1:0]
//
//   Add(2-bit): A=state, B=Const(1,2-bit), Cin=Const(0)
//     → state + 1 (wraps 3→0 automatically via 2-bit overflow)
//
//   Mux(2-bit):
//     sel   = reset
//     in[0] = Add_out     (state + 1)
//     in[1] = Const(0,2-bit)  (reset target)
//     → d_next
//
//   Wraps: 00→01→10→11→00 every cycle automatically.
//
// ── STATE DECODE (four Comparators, 2-bit) ───────────────────
//   is_FETCH     = (state == 2'b00)  Const(0)
//   is_DECODE    = (state == 2'b01)  Const(1)
//   is_EXECUTE   = (state == 2'b10)  Const(2)
//   is_WRITEBACK = (state == 2'b11)  Const(3)
//
// ── OPCODE DECODE (13 Comparators, 4-bit) ────────────────────
//   is_ADD   = (opcode == Const(1))
//   is_SUB   = (opcode == Const(2))
//   is_AND   = (opcode == Const(3))
//   is_OR    = (opcode == Const(4))
//   is_XOR   = (opcode == Const(5))
//   is_LOAD  = (opcode == Const(6))
//   is_STORE = (opcode == Const(7))
//   is_MOV   = (opcode == Const(8))
//   is_ADDI  = (opcode == Const(9))
//   is_JMP   = (opcode == Const(10))
//   is_BEQ   = (opcode == Const(11))
//   is_BNE   = (opcode == Const(12))
//   is_BLT   = (opcode == Const(13))
//
// ── OUTPUT SIGNAL GENERATION (AND/OR trees — NO latches) ─────
//
//   ir_load    = AND(is_FETCH, Const(1))
//              = is_FETCH
//
//   pc_enable  = AND(is_FETCH, Const(1))
//              = is_FETCH
//
//   mem_write  = AND(is_WRITEBACK, is_STORE)
//
//   mem_read   = OR( AND(is_EXECUTE,   is_LOAD),
//                    AND(is_WRITEBACK, is_LOAD) )
//              = (is_EXECUTE | is_WRITEBACK) & is_LOAD
//
//   reg_write  = 8-input OR of AND(is_WRITEBACK, is_X)
//               for X ∈ {ADD,SUB,AND,OR,XOR,MOV,ADDI,LOAD}
//              = is_WRITEBACK &
//                (is_ADD|is_SUB|is_AND|is_OR|is_XOR|is_MOV|is_ADDI|is_LOAD)
//
//   alu_src    = AND(is_EXECUTE|is_WRITEBACK, is_ADDI)
//              = (is_EXECUTE | is_WRITEBACK) & is_ADDI
//              NOTE: purely combinational — NO latch in .dig
//
//   alu_op     = 5-MUX chain (see §2.4 of reference):
//     Default (FETCH/DECODE, all opcodes): 0x0  (Ground)
//     EXECUTE or WRITEBACK, branch ops:   0x2  (SUB for comparison)
//     EXECUTE or WRITEBACK, LOAD/STORE/JMP: 0x0 (ALU unused)
//     EXECUTE or WRITEBACK, arith/MOV/ADDI: opcode (opcode IS alu_op)
//     NOTE: purely combinational — NO latch in .dig
//
//   pc_load    = 4-input OR:
//     AND(is_WRITEBACK, is_JMP)                        — always
//     AND(is_WRITEBACK, is_BEQ, zero_flag)             — Z=1
//     AND(is_WRITEBACK, is_BNE, NOT(zero_flag))        — Z=0
//     AND(is_WRITEBACK, is_BLT, XOR(neg,ov))           — N⊕V=1
//
// ── CRITICAL: No alu_op or alu_src pipeline registers ────────
//   The .dig has NO latch between EXECUTE and WRITEBACK for these
//   signals. They are driven purely combinationally from the
//   current opcode and state comparators every cycle.
// ============================================================

module control_unit (
    input  wire       clk,
    input  wire       reset,
    input  wire [3:0] opcode,
    input  wire       zero_flag,
    input  wire       negative_flag,
    input  wire       overflow_flag,

    output wire       pc_enable,
    output wire       pc_load,
    output wire       ir_load,
    output wire       reg_write,
    output wire [3:0] alu_op,
    output wire       alu_src,
    output wire       mem_read,
    output wire       mem_write
);

    // ================================================================
    // FSM STATE COUNTER
    // 2-bit Register always enabled; Mux injects 2'b00 on reset.
    // Add(2-bit) wraps naturally: 3+1 = 0 in 2-bit arithmetic.
    // ================================================================
    reg [1:0] state;

    wire [1:0] state_next;
    assign state_next = reset ? 2'b00 : (state + 2'b01);

    always @(posedge clk)
        state <= state_next;

    // ================================================================
    // STATE DECODE — four Comparators, 2-bit
    // ================================================================
    wire is_FETCH, is_DECODE, is_EXECUTE, is_WRITEBACK;
    assign is_FETCH     = (state == 2'b00);   // Const(0)
    assign is_DECODE    = (state == 2'b01);   // Const(1)
    assign is_EXECUTE   = (state == 2'b10);   // Const(2)
    assign is_WRITEBACK = (state == 2'b11);   // Const(3)

    // ================================================================
    // OPCODE DECODE — 13 Comparators, 4-bit
    // ================================================================
    wire is_ADD, is_SUB, is_AND, is_OR,  is_XOR;
    wire is_LOAD, is_STORE, is_MOV, is_ADDI;
    wire is_JMP, is_BEQ, is_BNE, is_BLT;

    assign is_ADD   = (opcode == 4'd1);
    assign is_SUB   = (opcode == 4'd2);
    assign is_AND   = (opcode == 4'd3);
    assign is_OR    = (opcode == 4'd4);
    assign is_XOR   = (opcode == 4'd5);
    assign is_LOAD  = (opcode == 4'd6);
    assign is_STORE = (opcode == 4'd7);
    assign is_MOV   = (opcode == 4'd8);
    assign is_ADDI  = (opcode == 4'd9);
    assign is_JMP   = (opcode == 4'd10);
    assign is_BEQ   = (opcode == 4'd11);
    assign is_BNE   = (opcode == 4'd12);
    assign is_BLT   = (opcode == 4'd13);

    // Shorthand groups
    wire is_arith_reg;   // Register-writing arithmetic ops
    wire is_branch;
    assign is_arith_reg = is_ADD | is_SUB | is_AND | is_OR | is_XOR;
    assign is_branch    = is_BEQ | is_BNE | is_BLT;

    // ================================================================
    // OUTPUT SIGNALS — purely combinational AND/OR trees
    // ================================================================

    // ir_load: AND(is_FETCH, Const(1)) = is_FETCH
    assign ir_load   = is_FETCH;

    // pc_enable: AND(is_FETCH, Const(1)) = is_FETCH
    assign pc_enable = is_FETCH;

    // mem_write: AND(is_WRITEBACK, is_STORE)
    assign mem_write = is_WRITEBACK & is_STORE;

    // mem_read: OR(AND(is_EXECUTE,is_LOAD), AND(is_WRITEBACK,is_LOAD))
    assign mem_read  = (is_EXECUTE | is_WRITEBACK) & is_LOAD;

    // reg_write: 8-input OR of AND(is_WRITEBACK, is_X)
    assign reg_write = is_WRITEBACK &
                       (is_arith_reg | is_MOV | is_ADDI | is_LOAD);

    // alu_src: AND((is_EXECUTE|is_WRITEBACK), is_ADDI)
    // Purely combinational — NO latch register in .dig
    assign alu_src = (is_EXECUTE | is_WRITEBACK) & is_ADDI;

    // alu_op: 5-MUX chain result — purely combinational off opcode+state
    //   FETCH / DECODE              → 0x0 (Ground, ALU idle)
    //   EXECUTE/WB, branch ops      → 0x2 (SUB for comparison)
    //   EXECUTE/WB, LOAD/STORE/JMP  → 0x0 (ALU result not used)
    //   EXECUTE/WB, arith/MOV/ADDI  → opcode (opcode IS alu_op for 0x1–0x9)
    assign alu_op =
        (is_FETCH | is_DECODE)          ? 4'h0    :   // idle
        is_branch                       ? 4'h2    :   // SUB for BEQ/BNE/BLT
        (is_LOAD | is_STORE | is_JMP)   ? 4'h0    :   // ALU not used
                                          opcode;     // arith/MOV/ADDI: opcode = alu_op

    // pc_load: 4-input OR (WRITEBACK only, conditional on flags)
    //   AND(is_WB, is_JMP)
    //   AND(is_WB, is_BEQ,  zero_flag)
    //   AND(is_WB, is_BNE,  NOT(zero_flag))
    //   AND(is_WB, is_BLT,  XOR(negative_flag, overflow_flag))
    wire blt_condition;
    assign blt_condition = negative_flag ^ overflow_flag;   // XOR gate in .dig

    assign pc_load = is_WRITEBACK & (
                       is_JMP                         |
                       (is_BEQ & zero_flag)           |
                       (is_BNE & ~zero_flag)          |
                       (is_BLT & blt_condition)
                     );

endmodule