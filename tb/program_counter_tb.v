`timescale 1ns/1ps

module program_counter_tb;

reg clk;
reg reset;
reg pc_enable;
reg pc_load;
reg [15:0] pc_in;

wire [15:0] pc_out;

program_counter uut (
    .clk(clk),
    .reset(reset),
    .pc_enable(pc_enable),
    .pc_load(pc_load),
    .pc_in(pc_in),
    .pc_out(pc_out)
);

    // Clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("pc_dump.vcd");
        $dumpvars(0, program_counter_tb);

        // Initial values
        reset = 1;
        pc_enable = 0;
        pc_load = 0;
        pc_in = 0;

        #10;

        // Release reset
        reset = 0;
        pc_enable = 1;

        // Let it count for 4 cycles
        #40;

        // Load new address (jump)
        pc_enable = 0;
        pc_load = 1;
        pc_in = 16'h0040;
        #10;

        pc_load = 0;
        pc_enable = 1;

        // Count more
        #40;

        $finish;
    end

endmodule
