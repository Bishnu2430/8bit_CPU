`timescale 1ns/1ps

module control_unit_tb;

reg clk;
reg reset;
reg [3:0] opcode;
reg zero_flag;
reg negative_flag;
reg overflow_flag;

wire pc_enable;
wire pc_load;
wire ir_load;
wire reg_write;
wire [3:0] alu_op;
wire alu_src;
wire mem_read;
wire mem_write;

control_unit uut (
    .clk(clk),
    .reset(reset),
    .opcode(opcode),
    .zero_flag(zero_flag),
    .negative_flag(negative_flag),
    .overflow_flag(overflow_flag),
    .pc_enable(pc_enable),
    .pc_load(pc_load),
    .ir_load(ir_load),
    .reg_write(reg_write),
    .alu_op(alu_op),
    .alu_src(alu_src),
    .mem_read(mem_read),
    .mem_write(mem_write)
);

// Clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("control_dump.vcd");
    $dumpvars(0, control_unit_tb);

    reset = 1;
    opcode = 4'b0001; // ADD
    zero_flag = 0;
    negative_flag = 0;
    overflow_flag = 0;

    #10;
    reset = 0;

    #50;

    // Change instruction to ADDI
    opcode = 4'b1001;
    #50;

    // Change to JMP
    opcode = 4'b1010;
    #50;

    $finish;
end

endmodule
