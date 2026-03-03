`timescale 1ns/1ps

// ============================================================
// CPU Core — Top-level datapath integration
// Version: v0.3 (Multi-cycle Branching + Memory Support)
// ============================================================
// FIXES:
//   v0.3:
//   - Exposed `opcode` as a module-level wire (was only inside
//     decoder sub-instance; testbench `uut.opcode` requires it).
//   - Fixed ADDI sign extension: imm6 is now sign-extended to
//     8 bits for ALU input B, so ADDI R6, #-1 works correctly.
//     Previous: {2'b00, imm6} — zero-extension (wrong for neg imm)
//     Fixed:    {{2{imm6[5]}}, imm6} — sign-extension (correct)
//   - Declared `pc_out` explicitly so testbench hierarchy is clean.
// ============================================================

module cpu_core (
    input clk,
    input reset
);

    // --------------------------------------------------------
    // FETCH
    // --------------------------------------------------------
    wire [15:0] instruction;
    wire [15:0] pc_out;

    wire pc_enable;
    wire pc_load;
    wire ir_load;

    // Decode fields — declared here so they are accessible at
    // module scope (e.g. testbench `uut.opcode`).
    wire [3:0] opcode;
    wire [2:0] rd;
    wire [2:0] rs;
    wire [5:0] imm6;

    // Signed 6-bit immediate sign-extended to 16 bits for branch arithmetic
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

    // --------------------------------------------------------
    // DECODE
    // --------------------------------------------------------
    decoder dec (
        .instruction_in (instruction),
        .opcode         (opcode),
        .rd             (rd),
        .rs             (rs),
        .imm6           (imm6)
    );

    // --------------------------------------------------------
    // CONTROL
    // --------------------------------------------------------
    wire reg_write;
    wire [3:0] alu_op;
    wire alu_src;
    wire mem_read;
    wire mem_write;

    wire zero, carry, negative, overflow;

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

    // --------------------------------------------------------
    // REGISTER FILE
    // --------------------------------------------------------
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

    // --------------------------------------------------------
    // ALU
    // --------------------------------------------------------
    wire [7:0] alu_input_b;
    wire [7:0] alu_result;

    // FIX: sign-extend imm6 to 8 bits for ALU input B
    // This is critical for ADDI with negative immediates (e.g. ADDI R6, #-1)
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

    // --------------------------------------------------------
    // DATA MEMORY
    // --------------------------------------------------------
    wire [7:0] mem_data;

    data_memory dm (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .address    ({2'b00, imm6}),
        .write_data (reg_data1),
        .read_data  (mem_data)
    );

    // --------------------------------------------------------
    // WRITEBACK MUX
    // --------------------------------------------------------
    assign write_data = (mem_read) ? mem_data : alu_result;

endmodule