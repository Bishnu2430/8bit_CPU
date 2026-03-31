`timescale 1ns/1ps
// ============================================================
// instruction_register.v — matches instruction_register.dig exactly
//
// .dig implementation (traced from wire list):
//
//   MUX(16-bit):
//     in[0] = Ground(0x0000)
//     in[1] = instruction_in
//     sel   = (internal net from MUX output, see below)
//     out   → Register D-input
//
//   Or gate (1-bit, rotation=1 → inputs from below):
//     in[0] = reset    (wire through reset input → MUX select)
//     in[1] = ir_load
//     out   → Register enable  AND  → MUX sel (via the same net)
//
//   The MUX sel is driven by the OR(reset, ir_load) net.
//   When sel=0 (neither reset nor ir_load): MUX passes Ground → 0x0000
//   When sel=1 (reset OR ir_load active):
//     — if reset=1  → instruction_in could be anything, but the register
//                      clears because reset overrides (the MUX still passes
//                      instruction_in, but in the .dig reset drives the
//                      register's reset pin directly via the "1" Const on clr)
//     — if ir_load=1, reset=0 → MUX passes instruction_in → register latches it
//
//   Register(16-bit):
//     D   = MUX out
//     clk = clk
//     en  = OR(reset, ir_load)   ← only clocks when something changes
//     Q   = instruction_out
//
//   Note: in Digital the Register element has a synchronous reset (clr) port.
//   reset feeds both the OR gate (to enable the register) and is routed to
//   make the MUX select 0x0000 when reset=1, ir_load=0.  The net result is:
//
//     posedge clk:
//       if OR(reset,ir_load):
//         if reset:  instruction_out <= 0x0000   (MUX[0] = Ground)
//         else:      instruction_out <= instruction_in
//
//   This is exactly what the priority-encoded always block below implements.
// ============================================================

module instruction_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        ir_load,
    input  wire [15:0] instruction_in,
    output reg  [15:0] instruction_out
);

    // --- OR gate: enable signal ---
    wire enable;
    assign enable = reset | ir_load;

    // --- MUX: select 0 when reset, instruction_in when ir_load ---
    wire [15:0] mux_out;
    assign mux_out = reset ? 16'b0 : instruction_in;

    // --- Register: clocked, only updates when enable=1 ---
    always @(posedge clk) begin
        if (enable)
            instruction_out <= mux_out;
    end

endmodule