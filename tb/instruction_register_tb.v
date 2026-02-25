`timescale 1ns/1ps

module instruction_register_tb;

reg clk;
reg reset;
reg ir_load;
reg [15:0] instruction_in;

wire [15:0] instruction_out;

instruction_register uut (
    .clk(clk),
    .reset(reset),
    .ir_load(ir_load),
    .instruction_in(instruction_in),
    .instruction_out(instruction_out)
);

// Clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("ir_dump.vcd");
    $dumpvars(0, instruction_register_tb);

    reset = 1;
    ir_load = 0;
    instruction_in = 16'h0000;

    #10;
    reset = 0;

    // Load first instruction
    instruction_in = 16'h1280;
    ir_load = 1;
    #10;

    // Change input but do not load
    instruction_in = 16'h2280;
    ir_load = 0;
    #10;

    // Load new instruction
    ir_load = 1;
    #10;

    $finish;
end

endmodule
