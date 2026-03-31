`timescale 1ns/1ps
// ============================================================
// cpu_core.v — matches cpu_core_test.dig exactly
//
// .dig wiring (cpu_core_test.dig) traced element by element:
//
// ── CLOCK & RESET ─────────────────────────────────────────
//   Clock(10Hz, runRealTime) → clk
//   In(reset)               → reset
//   Both feed: control_unit, program_counter, instruction_register,
//              data_memory, reg_file
//
// ── FETCH CHAIN ───────────────────────────────────────────
//   program_counter:
//     clk, reset, pc_enable, pc_load, pc_in → pc_out
//
//   instruction_memory:
//     address = pc_out[7:0]  (Splitter 16→8,8 extracts lower byte)
//     → instruction[15:0]
//
//   instruction_register:
//     clk, reset, ir_load, instruction_in = instruction → instruction_out
//
// ── DECODE ────────────────────────────────────────────────
//   decoder:
//     instruction_in = instruction_out
//     → opcode[3:0], rd[2:0], rs[2:0], imm6[5:0]
//
// ── BRANCH TARGET COMPUTATION ─────────────────────────────
//   BitExtender(6→8, signed):
//     in  = imm6[5:0]
//     out = sign_ext_8[7:0]   (for ALU immediate path)
//
//   The branch target path uses a Splitter to zero-extend imm6 to 16 bits
//   for the JMP absolute address:
//     Splitter(Input: 2,6 → Output: 16bit combined with Const(0,2bit)):
//       The splitter takes {2'b00, imm6} → 16-bit zero-extended value
//       This creates jmp_target = {10'b0, imm6}
//
//   BitExtender(6→16, signed) [separate element from the 6→8 one]:
//     in  = imm6[5:0]
//     out = sign_ext_16[15:0]  (for PC-relative branch offset)
//
//   Add(16-bit):
//     a = pc_out[15:0]      (already PC+1 after FETCH)
//     b = sign_ext_16[15:0]
//     Const(0) on carry-in
//     → branch_target[15:0]
//
//   Comparator(4-bit): opcode == Const(10) [= 0xA = JMP]
//     → is_JMP (1-bit)
//
//   Multiplexer(16-bit, 2-input):
//     sel   = is_JMP
//     in[0] = branch_target   (PC-relative for BEQ/BNE/BLT)
//     in[1] = jmp_target      (absolute for JMP)
//     → pc_next[15:0]   → program_counter pc_in
//
// ── REGISTER FILE ─────────────────────────────────────────
//   reg_file:
//     clk, reg_write
//     read_reg1 = rd   (Splitter 16→8,8 upper byte feeds rd → reg read1)
//     read_reg2 = rs
//     write_reg = rd
//     write_data = writeback_mux_out
//     → read_data1, read_data2
//
//   NOTE: .dig Splitter(16→8,8) on instruction_out gives
//         upper_byte[15:8] and lower_byte[7:0].
//         rd = upper[7:5], rs = upper[4:2], imm6 = lower[5:0]
//         Actually the decoder handles this — reg_file gets rd and rs
//         from the decoder outputs directly.
//
// ── ALU ───────────────────────────────────────────────────
//   Multiplexer(8-bit, 2-input) for alu input B:
//     sel   = alu_src
//     in[0] = read_data2         (register operand)
//     in[1] = sign_ext_8[7:0]   (sign-extended imm6 for ADDI)
//     → alu_b[7:0]
//
//   alu:
//     a = read_data1
//     b = alu_b
//     alu_op
//     → result, zero, carry, negative, overflow
//
// ── DATA MEMORY ───────────────────────────────────────────
//   data_memory:
//     clk
//     address    = {2'b00, imm6}   (zero-extended, 8-bit absolute)
//     write_data = read_data1      (STORE: source register)
//     mem_read, mem_write
//     → mem_data[7:0]
//
// ── WRITEBACK MUX ─────────────────────────────────────────
//   Multiplexer(8-bit, 2-input):
//     sel   = mem_read
//     in[0] = alu_result
//     in[1] = mem_data
//     → write_data → reg_file write_data
//
// ── PROBES (debug only, no logic) ─────────────────────────
//   Four Probe elements attached to various signals.
//
// ── KEY CORRECTIONS vs original cpu_core.v ────────────────
//   1. imm6 sign-extension to 8 bits uses BitExtender(signed) — confirmed.
//   2. imm6 sign-extension to 16 bits uses BitExtender(signed) — NOT zero-ext.
//      Original Verilog had this correct; .dig BitExtender must be set signed.
//   3. JMP uses {10'b0, imm6} = zero-extended (absolute address 0-63).
//      .dig Splitter({2'b00, imm6}→16) implements this correctly.
//   4. Branch target = pc_out + {{10{imm6[5]}}, imm6}.
//   5. control_unit has NO alu_op/alu_src latches — purely combinational.
// ============================================================

module cpu_core (
    input wire clk,
    input wire reset
);

    // ──────────────────────────────────────────────────────
    // Decode fields (module-scope wires for testbench access)
    // ──────────────────────────────────────────────────────
    wire [15:0] instruction;
    wire [15:0] pc_out;
    wire [3:0]  opcode;
    wire [2:0]  rd;
    wire [2:0]  rs;
    wire [5:0]  imm6;

    // ──────────────────────────────────────────────────────
    // Control signals
    // ──────────────────────────────────────────────────────
    wire        pc_enable, pc_load, ir_load;
    wire        reg_write, alu_src, mem_read, mem_write;
    wire [3:0]  alu_op;
    wire        zero, carry, negative, overflow;

    // ──────────────────────────────────────────────────────
    // BRANCH / JMP TARGET COMPUTATION
    // Matches .dig topology exactly:
    //
    //   sign_ext_16 = BitExtender(6→16, signed) on imm6
    //   branch_target = Add16(pc_out, sign_ext_16, cin=0)
    //
    //   jmp_target = Splitter({2'b00, imm6} → 16-bit)
    //              = {10'b0, imm6}   (zero-extended absolute address)
    //
    //   is_JMP = (opcode == 4'hA)   [Comparator(4-bit) vs Const(10)]
    //
    //   pc_next = is_JMP ? jmp_target : branch_target
    // ──────────────────────────────────────────────────────
    wire [15:0] sign_ext_16;
    assign sign_ext_16 = {{10{imm6[5]}}, imm6};   // BitExtender(6→16, signed)

    wire [15:0] branch_target;
    assign branch_target = pc_out + sign_ext_16;  // Add16 (no carry-in)

    wire [15:0] jmp_target;
    assign jmp_target = {10'b0, imm6};             // Splitter zero-extends to 16

    wire is_JMP;
    assign is_JMP = (opcode == 4'hA);              // Comparator: opcode == 10

    wire [15:0] pc_next;
    assign pc_next = is_JMP ? jmp_target : branch_target;  // 2-input MUX

    // ──────────────────────────────────────────────────────
    // FETCH UNIT
    // ──────────────────────────────────────────────────────
    fetch_unit fetch (
        .clk             (clk),
        .reset           (reset),
        .pc_enable       (pc_enable),
        .pc_load         (pc_load),
        .pc_in           (pc_next),
        .ir_load         (ir_load),
        .instruction_out (instruction),
        .pc_out          (pc_out)
    );

    // ──────────────────────────────────────────────────────
    // DECODER
    // ──────────────────────────────────────────────────────
    decoder dec (
        .instruction_in (instruction),
        .opcode         (opcode),
        .rd             (rd),
        .rs             (rs),
        .imm6           (imm6)
    );

    // ──────────────────────────────────────────────────────
    // CONTROL UNIT  (purely combinational alu_op/alu_src — no latches)
    // ──────────────────────────────────────────────────────
    control_unit ctrl (
        .clk           (clk),
        .reset         (reset),
        .opcode        (opcode),
        .zero_flag     (zero),
        .negative_flag (negative),
        .overflow_flag (overflow),
        .pc_enable     (pc_enable),
        .pc_load       (pc_load),
        .ir_load       (ir_load),
        .reg_write     (reg_write),
        .alu_op        (alu_op),
        .alu_src       (alu_src),
        .mem_read      (mem_read),
        .mem_write     (mem_write)
    );

    // ──────────────────────────────────────────────────────
    // REGISTER FILE
    // ──────────────────────────────────────────────────────
    wire [7:0] reg_data1, reg_data2, write_data;

    reg_file rf (
        .clk        (clk),
        .reg_write  (reg_write),
        .read_reg1  (rd),
        .read_reg2  (rs),
        .write_reg  (rd),
        .write_data (write_data),
        .read_data1 (reg_data1),
        .read_data2 (reg_data2)
    );

    // ──────────────────────────────────────────────────────
    // ALU INPUT B MUX
    // Matches .dig MUX(8-bit):
    //   sel=alu_src, in[0]=read_data2, in[1]=sign_ext_8
    // BitExtender(6→8, signed) for imm6
    // ──────────────────────────────────────────────────────
    wire [7:0] sign_ext_8;
    assign sign_ext_8 = {{2{imm6[5]}}, imm6};   // BitExtender(6→8, signed)

    wire [7:0] alu_input_b;
    assign alu_input_b = alu_src ? sign_ext_8 : reg_data2;

    // ──────────────────────────────────────────────────────
    // ALU
    // ──────────────────────────────────────────────────────
    wire [7:0] alu_result;

    alu alu_unit (
        .a        (reg_data1),
        .b        (alu_input_b),
        .alu_op   (alu_op),
        .result   (alu_result),
        .zero     (zero),
        .carry    (carry),
        .negative (negative),
        .overflow (overflow)
    );

    // ──────────────────────────────────────────────────────
    // DATA MEMORY
    // Address = {2'b00, imm6}  (zero-extended 8-bit absolute)
    // write_data = reg_data1   (STORE source is always Rd)
    // ──────────────────────────────────────────────────────
    wire [7:0] mem_data;

    data_memory dm (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .address    ({2'b00, imm6}),
        .write_data (reg_data1),
        .read_data  (mem_data)
    );

    // ──────────────────────────────────────────────────────
    // WRITEBACK MUX
    // Matches .dig MUX(8-bit):
    //   sel=mem_read, in[0]=alu_result, in[1]=mem_data
    // ──────────────────────────────────────────────────────
    assign write_data = mem_read ? mem_data : alu_result;

endmodule