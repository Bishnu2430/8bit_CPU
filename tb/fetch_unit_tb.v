`timescale 1ns/1ps

module fetch_unit_tb;

reg clk;
reg reset;

reg pc_enable;
reg pc_load;
reg [15:0] pc_in;

reg ir_load;

wire [15:0] instruction_out;
wire [15:0] pc_out;

fetch_unit uut (
    .clk(clk),
    .reset(reset),
    .pc_enable(pc_enable),
    .pc_load(pc_load),
    .pc_in(pc_in),
    .ir_load(ir_load),
    .instruction_out(instruction_out),
    .pc_out(pc_out)
);

// Clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("fetch_dump.vcd");
    $dumpvars(0, fetch_unit_tb);

    reset = 1;
    pc_enable = 0;
    pc_load = 0;
    pc_in = 0;
    ir_load = 0;

    #10;
    reset = 0;

    // Enable fetching
    pc_enable = 1;
    ir_load = 1;

    // Let it fetch first 4 instructions
    #50;

    // Jump to address 2
    pc_enable = 0;
    pc_load = 1;
    pc_in = 16'd2;
    #10;

    pc_load = 0;
    pc_enable = 1;

    #40;

    $finish;
end

endmodule
