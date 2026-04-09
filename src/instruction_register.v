`timescale 1ns/1ps
// ============================================================
// instruction_register.v — RTL translation of
//                          instruction_register.dig
//
// .dig implementation:
//
//   OR gate:
//     in[0] = reset
//     in[1] = ir_load
//     out   = enable           → Register en pin AND MUX sel
//
//   MUX(16-bit):
//     in[0] = Ground(0x0000)   — clears IR on reset
//     in[1] = instruction_in   — latches new instruction
//     sel   = OR_out (enable)
//     out   → Register D input
//
//   Register(16-bit):
//     D   = MUX_out
//     en  = OR_out             — only clocks when enable=1
//     clk = clk
//     Q   = instruction_out
//
// Behaviour summary (three cases):
//   reset=1, ir_load=0 : enable=1, MUX→0x0000, IR latches 0x0000
//   reset=0, ir_load=1 : enable=1, MUX→instruction_in, IR latches it
//   reset=0, ir_load=0 : enable=0, Register clock-enable low → hold
//
// The register is enabled only in FETCH (ir_load=1) or during
// active reset. This matches the .dig topology where the Register
// en pin is driven by OR(reset, ir_load), NOT Const(1).
// ============================================================

module instruction_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        ir_load,
    input  wire [15:0] instruction_in,
    output reg  [15:0] instruction_out
);

    // ---- OR gate: enable signal --------------------------------
    wire enable;
    assign enable = reset | ir_load;

    // ---- MUX: select 0x0000 on reset, instruction_in on load --
    wire [15:0] mux_out;
    assign mux_out = reset ? 16'h0000 : instruction_in;

    // ---- Register: clocks only when enable=1 ------------------
    always @(posedge clk) begin
        if (enable)
            instruction_out <= mux_out;
    end

endmodule