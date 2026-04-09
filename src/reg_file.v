`timescale 1ns/1ps
// ============================================================
// reg_file.v — RTL translation of reg_file.dig
//
// .dig implementation:
//
// WRITE PATH:
//   Decoder(Selector Bits=3):
//     in  = write_reg[2:0]
//     out = 8 one-hot lines (out[0]..out[7])
//
//   AND gate × 7  (for R1..R7):
//     AND[n].in[0] = decoder_out[n]
//     AND[n].in[1] = reg_write
//     AND[n].out   = write-enable for Register[n]
//
//   R0 special:
//     D = Const(0)         — data input is hardwired zero
//     en = never asserted  — AND gate for R0 is absent in .dig
//     R0 always reads 0x00; writes are silently discarded
//
//   Register(8-bit) × 8:
//     D   = write_data[7:0]   — all registers share write bus
//     clk = clk
//     en  = AND[n].out        — R0: always 0 (never written)
//     Q   = registers[n]
//
// READ PATHS (two identical 8:1 MUX structures):
//   MUX1 (read_data1):
//     Multiplexer(Bits=8, Selector Bits=3)
//     sel      = read_reg1[2:0]    (from decoder output port rd)
//     in[0]    = Const(0x00)       (R0 always returns 0)
//     in[1..7] = Register[1..7].Q
//     out      = read_data1
//
//   MUX2 (read_data2):
//     Multiplexer(Bits=8, Selector Bits=3)
//     sel      = read_reg2[2:0]    (from decoder output port rs)
//     in[0]    = Const(0x00)
//     in[1..7] = Register[1..7].Q
//     out      = read_data2
//
//   Read is ASYNCHRONOUS — no clock on the MUX elements.
//   read_data1 and read_data2 are valid combinationally as soon
//   as read_reg1/read_reg2 are stable.
//
// Connection in cpu_core_test.dig:
//   read_reg1  = rd  (destination field — first ALU source)
//   read_reg2  = rs  (source field     — second ALU source)
//   write_reg  = rd  (always write back to destination)
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

    // ---- 8 × 8-bit register storage ---------------------------
    reg [7:0] registers [0:7];

    integer j;
    initial begin
        for (j = 0; j < 8; j = j + 1)
            registers[j] = 8'h00;
        // registers[0] stays 0 and is NEVER updated (R0 hardwired zero)
    end

    // ---- WRITE PATH -------------------------------------------
    // Decoder produces one-hot; AND[n] gates reg_write to enable.
    // R0 (n=0): no AND gate → never written; stays 0x00 always.
    // genvar loop models: AND(decoder_out[n], reg_write) → Register[n].en
    genvar n;
    generate
        for (n = 1; n < 8; n = n + 1) begin : gen_reg_write
            wire we;
            assign we = reg_write & (write_reg == n[2:0]);
            always @(posedge clk) begin
                if (we)
                    registers[n] <= write_data;
            end
        end
    endgenerate

    // ---- READ PATHS (asynchronous MUX8) ----------------------
    // in[0] = Const(0x00) for both MUXes (R0 always returns 0)
    // in[1..7] = Register[1..7].Q
    assign read_data1 = (read_reg1 == 3'b000) ? 8'h00 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 3'b000) ? 8'h00 : registers[read_reg2];

endmodule