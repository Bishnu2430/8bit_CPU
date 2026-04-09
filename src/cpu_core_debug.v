`timescale 1ns/1ps
// ============================================================
// cpu_core_debug.v — cpu_core.v + debug bus outputs (v0.4)
//
// Extends cpu_core with a non-intrusive read-only debug bus.
// All debug outputs are combinational taps on internal wires.
// Normal execution is completely unaffected when dbg_en=0.
//
// Debug bus interface (from §14 / §9.2 of reference):
//   dbg_en   — enables debug output (gates all dbg_* outputs)
//   dbg_step — reserved for single-step mode (planned v0.4;
//              FSM halt after WRITEBACK not yet wired to ctrl)
//   dbg_pc   — current pc_out (16-bit)
//   dbg_ir   — current instruction register word (16-bit)
//   dbg_state    — current FSM state 2-bit (00/01/10/11)
//   dbg_regfile  — {R7,R6,R5,R4,R3,R2,R1,R0} packed 64-bit
//   dbg_flags    — {overflow, negative, carry, zero} 4-bit
//   dbg_instr_word — instruction word currently in IR (16-bit)
//
// Used by:
//   make verilator  (Verilator C++ sim_main.cpp)
//   FPGA JTAG debug port (future)
// ============================================================

module cpu_core_debug (
    input  wire        clk,
    input  wire        reset,

    // ── Debug Bus ──────────────────────────────────────────────
    input  wire        dbg_en,
    input  wire        dbg_step,
    output wire [15:0] dbg_pc,
    output wire [15:0] dbg_ir,
    output wire [1:0]  dbg_state,
    output wire [63:0] dbg_regfile,
    output wire [3:0]  dbg_flags,
    output wire [15:0] dbg_instr_word
);

    // ── Internal signal declarations ────────────────────────────
    wire [15:0] instruction;
    wire [15:0] pc_out;
    wire [3:0]  opcode;
    wire [2:0]  rd;
    wire [2:0]  rs;
    wire [5:0]  imm6;

    wire        pc_enable, pc_load, ir_load;
    wire        reg_write, alu_src, mem_read, mem_write;
    wire [3:0]  alu_op;
    wire        zero, carry, negative, overflow;

    // ── Branch / JMP target computation (same as cpu_core) ─────
    wire [15:0] sign_ext_16;
    assign sign_ext_16 = {{10{imm6[5]}}, imm6};

    wire [15:0] branch_target;
    assign branch_target = pc_out + sign_ext_16;

    wire [15:0] jmp_target;
    assign jmp_target = {10'b0, imm6};

    wire is_JMP;
    assign is_JMP = (opcode == 4'hA);

    wire [15:0] pc_next;
    assign pc_next = is_JMP ? jmp_target : branch_target;

    // ── Fetch Unit ──────────────────────────────────────────────
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

    // ── Control Unit ────────────────────────────────────────────
    // dbg_step is reserved for future FSM hold integration.
    // Wire kept for API compatibility; not yet wired into ctrl.
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

    // ── ALU ─────────────────────────────────────────────────────
    wire [7:0] sign_ext_8;
    assign sign_ext_8 = {{2{imm6[5]}}, imm6};

    wire [7:0] alu_input_b;
    assign alu_input_b = alu_src ? sign_ext_8 : reg_data2;

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
    assign write_data = mem_read ? mem_data : alu_result;

    // ── Debug Bus Assignments ────────────────────────────────────
    // All combinational taps — gated by dbg_en.
    // Zero overhead when dbg_en=0 (synthesis-friendly).
    assign dbg_pc         = dbg_en ? pc_out      : 16'h0000;
    assign dbg_ir         = dbg_en ? instruction : 16'h0000;
    assign dbg_state      = dbg_en ? ctrl.state  : 2'b00;
    assign dbg_flags      = dbg_en ? {overflow, negative, carry, zero} : 4'h0;
    assign dbg_instr_word = dbg_en ? instruction : 16'h0000;

    // Pack all 8 registers into one 64-bit bus: {R7,R6,R5,R4,R3,R2,R1,R0}
    assign dbg_regfile = dbg_en ?
        {rf.registers[7], rf.registers[6], rf.registers[5], rf.registers[4],
         rf.registers[3], rf.registers[2], rf.registers[1], rf.registers[0]}
        : 64'h0;

endmodule