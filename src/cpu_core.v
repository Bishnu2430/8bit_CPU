`timescale 1ns/1ps
// ============================================================
// cpu_core.v — RTL translation of cpu_core_test.dig
//
// This is the top-level integration module. It wires all nine
// sub-components together exactly as in cpu_core_test.dig.
//
// ── CLOCK & RESET ─────────────────────────────────────────────
//   Clock(Frequency=10, runRealTime=true) → clk
//   In(reset) → reset
//   Both feed: control_unit, fetch_unit (pc + ir), data_memory,
//              reg_file
//
// ── FETCH CHAIN ───────────────────────────────────────────────
//   fetch_unit (wraps program_counter + instruction_memory +
//               instruction_register):
//     clk, reset, pc_enable, pc_load, pc_in → pc_out,
//     ir_load, → instruction_out
//
//   Splitter(16→8,8) in .dig extracts pc_out[7:0] for ROM address.
//   instruction_memory.v handles this internally (address[7:0]).
//
// ── DECODE ────────────────────────────────────────────────────
//   decoder:
//     instruction_in = instruction_out
//     → opcode[3:0], rd[2:0], rs[2:0], imm6[5:0]
//
// ── BRANCH / JMP TARGET COMPUTATION ──────────────────────────
//
//   BitExtender(6→8, signed) for ADDI ALU B input:
//     sign_ext_8 = {{2{imm6[5]}}, imm6}
//
//   BitExtender(6→16, signed) for branch offset:
//     sign_ext_16 = {{10{imm6[5]}}, imm6}
//
//   Add(16-bit) for branch target:
//     branch_target = pc_out + sign_ext_16
//     (pc_out is already PC+1 after FETCH increment)
//
//   Splitter({2'b00,imm6[5:0]}→16) for JMP absolute address:
//     jmp_target = {10'b0, imm6}
//     (Const(0,10-bit) as upper bits — limits JMP to 0..63)
//
//   Comparator(4-bit): opcode == Const(10) → is_JMP
//
//   Multiplexer(16-bit, 2-input):
//     sel   = is_JMP
//     in[0] = branch_target  (PC-relative for BEQ/BNE/BLT)
//     in[1] = jmp_target     (absolute for JMP)
//     → pc_next → program_counter.pc_in
//
// ── REGISTER FILE ─────────────────────────────────────────────
//   reg_file:
//     clk, reg_write
//     read_reg1  = rd    (first ALU source)
//     read_reg2  = rs    (second ALU source)
//     write_reg  = rd    (always write back to destination)
//     write_data = write_data (from writeback MUX)
//     → read_data1, read_data2
//
// ── ALU B INPUT MUX ───────────────────────────────────────────
//   Multiplexer(8-bit, 2-input):
//     sel   = alu_src
//     in[0] = read_data2   (register operand for reg-reg ops)
//     in[1] = sign_ext_8   (sign-extended imm6 for ADDI)
//     → alu_input_b
//
// ── ALU ───────────────────────────────────────────────────────
//   alu:
//     a = read_data1
//     b = alu_input_b
//     alu_op → result, zero, carry, negative, overflow
//
// ── DATA MEMORY ───────────────────────────────────────────────
//   data_memory:
//     clk
//     address    = {2'b00, imm6}   (zero-extended 8-bit absolute)
//     write_data = read_data1      (STORE: source is always Rd)
//     mem_read, mem_write
//     → mem_data
//
// ── WRITEBACK MUX ─────────────────────────────────────────────
//   Multiplexer(8-bit, 2-input):
//     sel   = mem_read
//     in[0] = alu_result   (arithmetic/ADDI/MOV result)
//     in[1] = mem_data     (LOAD data from RAM)
//     → write_data → reg_file.write_data
// ============================================================

module cpu_core (
    input wire clk,
    input wire reset
);

    // ── Decode fields (module-scope for testbench probing) ──────
    wire [15:0] instruction;
    wire [15:0] pc_out;
    wire [3:0]  opcode;
    wire [2:0]  rd;
    wire [2:0]  rs;
    wire [5:0]  imm6;

    // ── Control signals ─────────────────────────────────────────
    wire        pc_enable, pc_load, ir_load;
    wire        reg_write, alu_src, mem_read, mem_write;
    wire [3:0]  alu_op;
    wire        zero, carry, negative, overflow;

    // ── Branch / JMP target computation ─────────────────────────

    // BitExtender(6→16, signed) — branch PC-relative offset
    wire [15:0] sign_ext_16;
    assign sign_ext_16 = {{10{imm6[5]}}, imm6};

    // Add(16-bit) — branch_target = pc_out + sign_ext_16
    // pc_out is already PC+1 (incremented during FETCH)
    wire [15:0] branch_target;
    assign branch_target = pc_out + sign_ext_16;

    // Splitter({2'b00,imm6}→16) — JMP absolute target 0..63
    wire [15:0] jmp_target;
    assign jmp_target = {10'b0, imm6};

    // Comparator(4-bit): opcode == Const(10) → is_JMP
    wire is_JMP;
    assign is_JMP = (opcode == 4'hA);

    // Multiplexer(16-bit): sel=is_JMP
    wire [15:0] pc_next;
    assign pc_next = is_JMP ? jmp_target : branch_target;

    // ── Fetch Unit (PC + IMEM + IR) ─────────────────────────────
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

    // ── Decoder ─────────────────────────────────────────────────
    decoder dec (
        .instruction_in (instruction),
        .opcode         (opcode),
        .rd             (rd),
        .rs             (rs),
        .imm6           (imm6)
    );

    // ── Control Unit (purely combinational alu_op/alu_src) ──────
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

    // ── Register File ───────────────────────────────────────────
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

    // ── ALU B input MUX ─────────────────────────────────────────
    // BitExtender(6→8, signed) for ADDI immediate
    wire [7:0] sign_ext_8;
    assign sign_ext_8 = {{2{imm6[5]}}, imm6};

    // Multiplexer(8-bit): sel=alu_src
    wire [7:0] alu_input_b;
    assign alu_input_b = alu_src ? sign_ext_8 : reg_data2;

    // ── ALU ─────────────────────────────────────────────────────
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

    // ── Data Memory ─────────────────────────────────────────────
    // address = {2'b00, imm6} — zero-extended 8-bit absolute
    // write_data = reg_data1  — STORE source is always Rd
    wire [7:0] mem_data;

    data_memory dm (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .address    ({2'b00, imm6}),
        .write_data (reg_data1),
        .read_data  (mem_data)
    );

    // ── Writeback MUX ───────────────────────────────────────────
    // Multiplexer(8-bit): sel=mem_read
    //   in[0] = alu_result  (selected when mem_read=0)
    //   in[1] = mem_data    (selected when mem_read=1, i.e. LOAD WB)
    assign write_data = mem_read ? mem_data : alu_result;

endmodule