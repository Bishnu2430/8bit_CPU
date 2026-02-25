`timescale 1ns/1ps

module cpu_core_tb;

reg clk;
reg reset;

cpu_core uut (
    .clk(clk),
    .reset(reset)
);

// Clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("build/cpu_dump.vcd");
    $dumpvars(0, cpu_core_tb);

    reset = 1;
    #10;
    reset = 0;

    // Run long enough to execute full program including BLT loop (~27 iterations)
    #4000;
    $display("\n=== Force stop (timeout) at time %0t ===", $time);
    $display("R0=%0d R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d",
        uut.rf.registers[0], uut.rf.registers[1],
        uut.rf.registers[2], uut.rf.registers[3],
        uut.rf.registers[4], uut.rf.registers[5],
        uut.rf.registers[6], uut.rf.registers[7]);
    $display("PC=%0d", uut.pc_out);
    $finish;
end

// Display only at WRITEBACK completion (state 3→0 transition)
// This shows one line per instruction — much less I/O than per-clock
always @(posedge clk) begin
    if (!reset && uut.ctrl.state == 2'b11) begin
        $display("t=%0t  WB  PC=%0d  op=%b  R0=%0d R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d",
            $time, uut.pc_out, uut.opcode,
            uut.rf.registers[0], uut.rf.registers[1],
            uut.rf.registers[2], uut.rf.registers[3],
            uut.rf.registers[4], uut.rf.registers[5],
            uut.rf.registers[6], uut.rf.registers[7]);
    end
end

endmodule
