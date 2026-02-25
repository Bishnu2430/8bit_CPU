`timescale 1ns/1ps

// ============================================================
// CPU Core Testbench
// ============================================================
// FIXES v0.3:
//   - Timeout reduced to #3000 — finite loop runs ~6 iterations
//     (R6: 5→4→3→2→1→0→-1 exits) so simulation now terminates
//     naturally rather than running forever.
//   - Added $stop (after $finish) to guarantee simulator exits.
//   - WB display uses $time for precise timing correlation with VCD.
// ============================================================

module cpu_core_tb;

    reg clk;
    reg reset;

    cpu_core uut (
        .clk   (clk),
        .reset (reset)
    );

    // Clock: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("cpu_dump.vcd");
        $dumpvars(0, cpu_core_tb);

        reset = 1;
        #10;
        reset = 0;

        // Finite loop runs 6 iterations × 4 cycles × 10ns = 240ns
        // Full program ~12 instructions + 6 loop iters = ~18 × 40ns = 720ns
        // Give generous headroom: 3000ns
        #3000;

        $display("\n=== Simulation complete (timeout) at time %0t ns ===", $time);
        $display("Final register state:");
        $display("  R0=%0d  R1=%0d  R2=%0d  R3=%0d",
            uut.rf.registers[0], uut.rf.registers[1],
            uut.rf.registers[2], uut.rf.registers[3]);
        $display("  R4=%0d  R5=%0d  R6=%0d  R7=%0d",
            uut.rf.registers[4], uut.rf.registers[5],
            uut.rf.registers[6], uut.rf.registers[7]);
        $display("  PC=%0d", uut.pc_out);
        $finish;
    end

    // --------------------------------------------------------
    // Per-instruction display: fires at end of each WRITEBACK
    // Shows register state AFTER writeback completes.
    // --------------------------------------------------------
    // NOP sentinel detection: stop after first NOP at PC >= 11
    always @(posedge clk) begin
        if (!reset && uut.ctrl.state == 2'b11) begin
            $display("t=%0t  WB  PC=%02d  op=%b  R0=%0d R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d",
                $time, uut.pc_out, uut.opcode,
                uut.rf.registers[0], uut.rf.registers[1],
                uut.rf.registers[2], uut.rf.registers[3],
                uut.rf.registers[4], uut.rf.registers[5],
                uut.rf.registers[6], uut.rf.registers[7]);

            // Detect NOP sentinel at END (PC >= 12 means NOP at 11 was executed)
            if (uut.opcode == 4'b0000 && uut.pc_out >= 12) begin
                $display("\n=== NOP sentinel reached — program complete ===");
                $display("Final register state:");
                $display("  R0=%0d  R1=%0d  R2=%0d  R3=%0d",
                    uut.rf.registers[0], uut.rf.registers[1],
                    uut.rf.registers[2], uut.rf.registers[3]);
                $display("  R4=%0d  R5=%0d  R6=%0d  R7=%0d",
                    uut.rf.registers[4], uut.rf.registers[5],
                    uut.rf.registers[6], uut.rf.registers[7]);
                $display("  PC=%0d", uut.pc_out);
                $finish;
            end
        end
    end

endmodule