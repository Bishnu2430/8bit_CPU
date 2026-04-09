`timescale 1ns/1ps
// ============================================================
// data_memory.v — RTL translation of data_memory.dig
//
// .dig implementation:
//   RAMDualPort element (AddrBits=8, Bits=8)
//   256 × 8-bit synchronous dual-port RAM.
//
//   Port A (write port):
//     A_addr  = address[7:0]   — same wire as Port B address
//     A_din   = write_data[7:0]
//     A_we    = mem_write       — asserted in WRITEBACK for STORE
//     A_clk   = clk
//
//   Port B (read port):
//     B_addr  = address[7:0]   — same wire as Port A address
//     B_dout  = read_data[7:0]
//     B_re    = mem_read        — asserted in EXECUTE + WRITEBACK for LOAD
//     B_clk   = clk
//
//   CRITICAL: The single 'address' In port in data_memory.dig
//   connects to BOTH the Port A address input and the Port B
//   address input. Both ports share the same address bus.
//
//   Both ports are synchronous — registered on posedge clk.
//   The read output is registered, so LOAD requires two cycles:
//
//   Two-cycle LOAD sequence:
//     EXECUTE:   mem_read=1; RAMDualPort Port B captures address
//                on this posedge clk
//     WRITEBACK: mem_read=1 held; read_data is now valid;
//                reg_write=1 routes mem_data to register file
//
//   Address source from cpu_core_test.dig:
//     address = {2'b00, imm6[5:0]} — zero-extended to 8-bit
//     Accessible range: 0x00–0x3F (0–63) in v0.3
// ============================================================

module data_memory (
    input  wire       clk,
    input  wire       mem_read,
    input  wire       mem_write,
    input  wire [7:0] address,
    input  wire [7:0] write_data,
    output reg  [7:0] read_data
);

    reg [7:0] memory [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 8'h00;
    end

    // ---- Port A: synchronous write --------------------------------
    // ---- Port B: synchronous read (registered output) ------------
    // Both ports share the same address bus, clocked on posedge.
    // This matches RAMDualPort behaviour in Digital exactly:
    // the read output updates on the same rising edge that re is
    // sampled, so read_data is valid in the cycle AFTER mem_read
    // is asserted — i.e. valid in WRITEBACK when asserted in EXECUTE.
    always @(posedge clk) begin
        // Port A — write
        if (mem_write)
            memory[address] <= write_data;

        // Port B — registered read
        // read_data valid one cycle after mem_read asserted
        if (mem_read)
            read_data <= memory[address];
    end

endmodule