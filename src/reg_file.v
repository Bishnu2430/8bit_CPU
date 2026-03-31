`timescale 1ns/1ps
// ============================================================
// reg_file.v — matches reg_file.dig exactly
//
// .dig implementation (traced from wire list):
//
//   WRITE PATH:
//     Decoder(Selector Bits=3):
//       in  = write_reg[2:0]
//       out = 8 one-hot lines (out[0]..out[7])
//
//     7 And gates (one per register R1..R7):
//       AND[n].in[0] = decoder_out[n]
//       AND[n].in[1] = reg_write
//       AND[n].out   = enable for Register[n]
//
//     R0 is hardwired: its D-input = Const(0) and its enable = Const(0).
//     (In .dig: Const(0) feeds R0's D, reg_write_enable for R0 never asserted)
//
//     Register[n] (8-bit, for n=0..7):
//       D   = write_data[7:0]   (all registers share the same write bus)
//       clk = clk
//       en  = AND[n].out        (R0: always 0)
//       Q   = registers[n]
//
//   READ PATH (two identical MUX8 trees):
//     read_data1:
//       Multiplexer(Bits=8, Selector Bits=3)
//         sel      = read_reg1[2:0]   (comes from right side, rotation=2)
//         in[0]    = Const(0x00)      (R0 always reads 0)
//         in[1..7] = Register[1..7].Q
//         out      = read_data1
//
//     read_data2:
//       Multiplexer(Bits=8, Selector Bits=3)
//         sel      = read_reg2[2:0]   (comes from right side, rotation=2)
//         in[0]    = Const(0x00)
//         in[1..7] = Register[1..7].Q
//         out      = read_data2
//
//   Both MUX selectors arrive from the right (rotation=2 = input from right),
//   which in Digital means the signal flows right-to-left — no logical change,
//   just visual orientation.  The MUX in[0] is 0x00 constant (R0 = zero).
// ============================================================

module reg_file (
    input  wire        clk,
    input  wire        reg_write,
    input  wire [2:0]  read_reg1,
    input  wire [2:0]  read_reg2,
    input  wire [2:0]  write_reg,
    input  wire [7:0]  write_data,
    output wire [7:0]  read_data1,
    output wire [7:0]  read_data2
);

    // --- 8 × 8-bit registers ---
    reg [7:0] registers [0:7];

    integer j;
    initial begin
        for (j = 0; j < 8; j = j + 1)
            registers[j] = 8'b0;
    end

    // --- WRITE PATH ---
    // Decoder produces one-hot; each AND gate enables exactly one register.
    // R0 never gets a write-enable (matches .dig Const(0) on R0 enable).
    // This is a direct behavioural model of: Decoder → AND[n](dec[n], reg_write) → Register[n].en
    genvar n;
    generate
        for (n = 1; n < 8; n = n + 1) begin : gen_write
            // AND gate: decoder_out[n] & reg_write
            wire we;
            assign we = reg_write & (write_reg == n[2:0]);
            always @(posedge clk) begin
                if (we)
                    registers[n] <= write_data;
            end
        end
    endgenerate

    // R0: D = Const(0), enable = Const(0) → always reads 0, never written
    // registers[0] stays 0 from initialisation and is never updated.

    // --- READ PATH ---
    // Two 8:1 MUXes, in[0] = Const(0x00), in[1..7] = Register[1..7].Q
    assign read_data1 = (read_reg1 == 3'b000) ? 8'b0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 3'b000) ? 8'b0 : registers[read_reg2];

endmodule