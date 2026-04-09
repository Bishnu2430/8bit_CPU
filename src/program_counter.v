`timescale 1ns/1ps
// ============================================================
// program_counter.v — RTL translation of program_counter.dig
//
// .dig implementation:
//   A 16-bit counter with three priority-selected inputs built
//   from three Multiplexers, one Adder, and one Register.
//
//   Add(16-bit):
//     A = pc_out, B = Const(1), Cin = Const(0)
//     → produces pc_out + 1 combinationally
//
//   MUX1 (pc_enable gate):
//     sel   = pc_enable
//     in[0] = pc_out      (hold — pass current value)
//     in[1] = pc_out + 1  (increment)
//     out   = pc_enable ? pc_out+1 : pc_out
//
//   MUX2 (pc_load gate):
//     sel   = pc_load
//     in[0] = MUX1_out
//     in[1] = pc_in       (branch/JMP target)
//     out   = pc_load ? pc_in : MUX1_out
//
//   MUX3 (reset gate):
//     sel   = reset
//     in[0] = MUX2_out
//     in[1] = Ground(0x0000)
//     out   = reset ? 0x0000 : MUX2_out
//
//   Register(16-bit):
//     D   = MUX3_out
//     en  = Const(1)   — always enabled; MUX chain handles hold
//     clk = clk
//     Q   = pc_out
//
//   Priority (innermost MUX wins = highest priority):
//     reset > pc_load > pc_enable > hold
//
//   Note: The Register enable pin is hardwired Const(1).
//   The 0x0000 injected by MUX3 on reset is what resets the
//   counter — NOT a synchronous reset input on the Register.
// ============================================================

module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_enable,
    input  wire        pc_load,
    input  wire [15:0] pc_in,
    output reg  [15:0] pc_out
);

    // ---- Combinational MUX chain (mirrors .dig topology) ----
    wire [15:0] incremented;    // Add(16-bit) output
    wire [15:0] after_enable;   // MUX1 output
    wire [15:0] after_load;     // MUX2 output
    wire [15:0] d_next;         // MUX3 output → Register D

    assign incremented  = pc_out + 16'd1;                       // Adder
    assign after_enable = pc_enable ? incremented  : pc_out;    // MUX1
    assign after_load   = pc_load   ? pc_in        : after_enable; // MUX2
    assign d_next       = reset     ? 16'h0000     : after_load;   // MUX3

    // ---- Register (always-enabled, Const(1) on en pin) ------
    always @(posedge clk)
        pc_out <= d_next;

endmodule