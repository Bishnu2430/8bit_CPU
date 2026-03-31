`timescale 1ns/1ps
// ============================================================
// program_counter.v — matches program_counter.dig exactly
//
// .dig implementation (traced from wire list):
//
//   pc_out fed back to:
//     Adder(16-bit) input A   (with Const(1) on input B, Const(0) on carry-in)
//     Output of adder = pc_out + 1
//
//   Three 16-bit Multiplexers in sequence:
//
//   MUX1 (pc_enable gate):
//     sel = pc_enable
//     in[0] = pc_out   (hold — pass current value unchanged)
//     in[1] = pc_out+1 (increment)
//     out   = pc_enable ? pc_out+1 : pc_out
//
//   MUX2 (pc_load gate):
//     sel  = pc_load
//     in[0] = MUX1 output
//     in[1] = pc_in
//     out   = pc_load ? pc_in : MUX1_out
//
//   MUX3 (reset gate):
//     sel  = reset  [Const(1) drives the reset input of the register,
//                    implemented via a mux selecting Ground(0x0000)]
//     in[0] = MUX2 output
//     in[1] = 0x0000
//     out   = reset ? 0 : MUX2_out
//
//   Register(16-bit):
//     D   = MUX3 output
//     clk = clk
//     en  = Const(1)  (always enabled — the mux chain handles hold)
//     Q   = pc_out
//
// Priority encoded by mux chain: reset > pc_load > pc_enable > hold
// ============================================================

module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_enable,
    input  wire        pc_load,
    input  wire [15:0] pc_in,
    output reg  [15:0] pc_out
);

    // --- combinational mux chain (mirrors .dig mux topology) ---
    wire [15:0] incremented;
    wire [15:0] after_enable;
    wire [15:0] after_load;
    wire [15:0] d_next;

    assign incremented  = pc_out + 16'd1;                        // Adder
    assign after_enable = pc_enable  ? incremented  : pc_out;   // MUX1
    assign after_load   = pc_load    ? pc_in        : after_enable; // MUX2
    assign d_next       = reset      ? 16'b0        : after_load;   // MUX3

    // --- register (always-enabled, clock edge commits) ---
    always @(posedge clk)
        pc_out <= d_next;

endmodule