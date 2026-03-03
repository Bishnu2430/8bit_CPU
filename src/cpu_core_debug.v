`timescale 1ns/1ps

// ============================================================
// CPU Core with Debug Bus — v0.4
// ============================================================
// Debug bus is non-intrusive: all outputs are wires tapped
// from internal signals. Normal execution is unaffected.
// dbg_en gates the output (synthesis-friendly).
// dbg_step halts the FSM after each WRITEBACK for single-step.
// ============================================================

module cpu_core_debug (
    input  clk,
    input  reset,

    // ── Debug Bus ──────────────────────────────────────────
    // Connect to Verilator C++ wrapper or FPGA debug port.
    // All signals valid when dbg_en = 1.
    input         dbg_en,       // enable debug output latching
    input         dbg_step,     // 1 = pause FSM after each WB
    output [15:0] dbg_pc,       // current PC
    output [15:0] dbg_ir,       // current instruction register
    output [1:0]  dbg_state,    // current FSM state
    output [63:0] dbg_regfile,  // {R7,R6,R5,R4,R3,R2,R1,R0} packed
    output [3:0]  dbg_flags,    // {overflow, negative, carry, zero}
    output [15:0] dbg_instr_word // instruction currently being executed
);

    // ── Internal signals ───────────────────────────────────
    wire [15:0] instruction;
    wire [15:0] pc_out;
    wire        pc_enable;
    wire        pc_load;
    wire        ir_load;

    wire [3:0] opcode;
    wire [2:0] rd;
    wire [2:0] rs;
    wire [5:0] imm6;

    wire [15:0] signed_offset;
    assign signed_offset = {{10{imm6[5]}}, imm6};

    // Branch: PC-relative    (pc_out already = PC+1 from FETCH)
    wire [15:0] branch_target;
    assign branch_target = pc_out + signed_offset;

    // JMP: absolute target   (zero-extended imm6)
    wire [15:0] jmp_target;
    assign jmp_target = {10'b0, imm6};

    // Mux: JMP uses absolute address, branches use PC-relative
    wire [15:0] pc_next;
    assign pc_next = (opcode == 4'b1010) ? jmp_target : branch_target;

    // ── Fetch Unit ─────────────────────────────────────────
    fetch_unit fetch (
        .clk            (clk),
        .reset          (reset),
        .pc_enable      (pc_enable),
        .pc_load        (pc_load),
        .pc_in          (pc_next),
        .ir_load        (ir_load),
        .instruction_out(instruction),
        .pc_out         (pc_out)
    );

    // ── Decoder ────────────────────────────────────────────
    decoder dec (
        .instruction_in (instruction),
        .opcode         (opcode),
        .rd             (rd),
        .rs             (rs),
        .imm6           (imm6)
    );

    // ── Control Unit ───────────────────────────────────────
    wire reg_write;
    wire [3:0] alu_op;
    wire alu_src;
    wire mem_read;
    wire mem_write;
    wire zero, carry, negative, overflow;

    // Note: single-step (dbg_step) is a planned feature; the FSM does not
    // yet honour fsm_hold.  The wire is kept for future integration.
    wire fsm_hold;
    assign fsm_hold = dbg_en & dbg_step & (ctrl.state == 2'b11);

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

    // ── Register File ──────────────────────────────────────
    wire [7:0] reg_data1;
    wire [7:0] reg_data2;
    wire [7:0] write_data;

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

    // ── ALU ────────────────────────────────────────────────
    wire [7:0] alu_input_b;
    wire [7:0] alu_result;
    assign alu_input_b = (alu_src) ? {{2{imm6[5]}}, imm6} : reg_data2;

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

    // ── Data Memory ────────────────────────────────────────
    wire [7:0] mem_data;
    data_memory dm (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .address    ({2'b00, imm6}),
        .write_data (reg_data1),
        .read_data  (mem_data)
    );

    // ── Writeback Mux ──────────────────────────────────────
    assign write_data = (mem_read) ? mem_data : alu_result;

    // ── Debug Bus Assignments ──────────────────────────────
    // All combinational taps — zero synthesis overhead when dbg_en=0
    // because the signals are already being driven internally.
    assign dbg_pc         = dbg_en ? pc_out     : 16'b0;
    assign dbg_ir         = dbg_en ? instruction : 16'b0;
    assign dbg_state      = dbg_en ? ctrl.state  : 2'b0;
    assign dbg_flags      = dbg_en ? {overflow, negative, carry, zero} : 4'b0;
    assign dbg_instr_word = dbg_en ? instruction : 16'b0;

    // Pack all 8 registers into a single 64-bit bus for easy DPI access
    assign dbg_regfile = dbg_en ?
        {rf.registers[7], rf.registers[6], rf.registers[5], rf.registers[4],
         rf.registers[3], rf.registers[2], rf.registers[1], rf.registers[0]}
        : 64'b0;

endmodule