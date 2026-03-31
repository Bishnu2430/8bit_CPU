`timescale 1ns/1ps
// ============================================================
// alu.v — matches alu.dig exactly
//
// .dig implementation (traced from wire list):
//
//   OPERATION UNITS (all running in parallel):
//     Add(8-bit)  : result_add[8:0] = {carry_add, sum[7:0]}
//     Sub(8-bit)  : result_sub[8:0] = {borrow,    diff[7:0]}
//     And(8-bit)  : result_and[7:0]
//     Or(8-bit)   : result_or[7:0]
//     XOr(8-bit)  : result_xor[7:0]
//     Ground(0x00): result_nop[7:0] = 0   (MUX input [0] = NOP)
//
//   16-INPUT RESULT MUX (Multiplexer, Bits=8, Selector Bits=4):
//     alu_op selects from 16 slots:
//       [0x0] = 0x00        (NOP / default)
//       [0x1] = Add result  (ADD)
//       [0x2] = Sub result  (SUB)
//       [0x3] = And result  (AND)
//       [0x4] = Or  result  (OR)
//       [0x5] = XOr result  (XOR)
//       [0x6] = 0x00        (LOAD  — ALU unused, .dig wires Ground)
//       [0x7] = 0x00        (STORE — ALU unused)
//       [0x8] = b           (MOV   — pass b through)
//       [0x9] = Add result  (ADDI  — same adder, b = sign_ext(imm6))
//       [0xA..0xF] = 0x00 (unimplemented)
//
//   FLAG GENERATION:
//
//   carry:
//     Multiplexer(1-bit, 2-input):
//       sel   = (alu_op == 0x2)  [Comparator(4-bit) against Const(2)]
//       in[0] = Add carry bit    (bit[8] from Adder output)
//       in[1] = Sub borrow bit   (bit[8] from Sub output)
//     → carry output
//
//   zero:
//     Comparator(8-bit): result == 0x00
//     → zero output
//
//   negative:
//     Splitter(8→1,1,1,1,1,1,1,1): bit[7] of result
//     → negative output
//
//   overflow:
//     Uses three Splitters + XNOR + two XOR + two AND + MUX(1-bit):
//
//     For ADD overflow:
//       XNOR(a[7], b[7])          → signs_equal
//       XOR(result[7], a[7])      → sign_changed
//       AND(signs_equal, sign_changed) → overflow_add
//
//     For SUB overflow:
//       XOR(a[7], b[7])           → signs_differ
//       XOR(result[7], a[7])      → sign_changed (same XOR, different input)
//       AND(signs_differ, sign_changed) → overflow_sub
//
//     MUX(1-bit):
//       sel   = (alu_op == 0x2)   [same Comparator as carry mux]
//       in[0] = overflow_add
//       in[1] = overflow_sub
//     → overflow output
//
//   The .dig uses three separate 8→1,1,1,1,1,1,1,1 Splitters:
//     Splitter_result: taps result bits (for zero/negative/overflow)
//     Splitter_a:      taps a[7] (MSB of operand a)
//     Splitter_b:      taps b[7] (MSB of operand b)
//
// ============================================================

module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [3:0] alu_op,
    output wire [7:0] result,
    output wire       zero,
    output wire       carry,
    output wire       negative,
    output wire       overflow
);

    // ---- Parallel operation units --------------------------------
    wire [8:0] add_full;   // 9-bit: bit[8]=carry
    wire [8:0] sub_full;   // 9-bit: bit[8]=borrow
    wire [7:0] and_result;
    wire [7:0] or_result;
    wire [7:0] xor_result;

    assign add_full   = {1'b0, a} + {1'b0, b};
    assign sub_full   = {1'b0, a} - {1'b0, b};
    assign and_result = a & b;
    assign or_result  = a | b;
    assign xor_result = a ^ b;

    // ---- 16-input result MUX (Multiplexer, Bits=8, Selector Bits=4) ----
    // Inputs wired per .dig topology.  Unconnected slots are 0x00 (Ground).
    assign result =
        (alu_op == 4'h0) ? 8'h00          :  // NOP
        (alu_op == 4'h1) ? add_full[7:0]  :  // ADD
        (alu_op == 4'h2) ? sub_full[7:0]  :  // SUB
        (alu_op == 4'h3) ? and_result      :  // AND
        (alu_op == 4'h4) ? or_result       :  // OR
        (alu_op == 4'h5) ? xor_result      :  // XOR
        (alu_op == 4'h6) ? 8'h00          :  // LOAD  (ALU not used)
        (alu_op == 4'h7) ? 8'h00          :  // STORE (ALU not used)
        (alu_op == 4'h8) ? b               :  // MOV
        (alu_op == 4'h9) ? add_full[7:0]  :  // ADDI (same adder)
                           8'h00;             // default (JMP, BEQ, BNE, BLT, rsvd)

    // ---- zero flag: Comparator(8-bit) result == 0 ----------------
    assign zero = (result == 8'h00);

    // ---- negative flag: Splitter → bit[7] of result ---------------
    assign negative = result[7];

    // ---- carry flag: 2-input MUX, sel = (alu_op == SUB) ----------
    // .dig: Comparator(4-bit) checks alu_op against Const(2)
    wire is_sub;
    assign is_sub = (alu_op == 4'h2);
    assign carry  = is_sub ? sub_full[8] : add_full[8];

    // ---- overflow flag: gate-level matching .dig topology ---------
    //
    // Splitter_a:      a[7]
    // Splitter_b:      b[7]
    // Splitter_result: result[7]
    //
    // ADD path:
    //   XNOR(a[7], b[7])         → same sign inputs
    //   XOR(result[7], a[7])     → output sign changed
    //   AND(above two)           → overflow_add
    //
    // SUB path:
    //   XOR(a[7], b[7])          → different sign inputs
    //   XOR(result[7], a[7])     → output sign changed  (same XOR gate in .dig)
    //   AND(above two)           → overflow_sub
    //
    // MUX: sel = is_sub → output overflow_sub; else overflow_add

    wire a_msb, b_msb, r_msb;
    assign a_msb = a[7];
    assign b_msb = b[7];
    assign r_msb = result[7];

    wire signs_equal;    // XNOR gate
    wire signs_differ;   // XOR gate  (same inputs as XNOR, different function)
    wire sign_changed;   // XOR gate  (result[7] ^ a[7])

    assign signs_equal  = ~(a_msb ^ b_msb);   // XNOR(a[7], b[7])
    assign signs_differ =   a_msb ^ b_msb;    // XOR (a[7], b[7])
    assign sign_changed =   r_msb ^ a_msb;    // XOR (result[7], a[7])

    wire overflow_add, overflow_sub;
    assign overflow_add = signs_equal  & sign_changed;   // AND
    assign overflow_sub = signs_differ & sign_changed;   // AND

    // MUX: sel = is_sub
    assign overflow = is_sub ? overflow_sub : overflow_add;

endmodule