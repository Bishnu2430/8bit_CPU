`timescale 1ns/1ps
// ============================================================
// data_memory.v — matches data_memory.dig exactly
//
// .dig implementation:
//   RAMDualPort element (AddrBits=8, Bits=8)
//
//   RAMDualPort in Digital has TWO independent ports:
//     Port A (write port):
//       A_addr  = address[7:0]
//       A_din   = write_data[7:0]
//       A_we    = mem_write       (write-enable)
//       A_clk   = clk
//
//     Port B (read port):
//       B_addr  = address[7:0]   (same address bus wired to both ports in .dig)
//       B_dout  = read_data[7:0]
//       B_re    = mem_read        (read-enable)
//       B_clk   = clk
//
//   Both ports are synchronous (registered on posedge clk).
//   Read data is registered — mem_read must be held for one cycle
//   before read_data is valid (matches the two-cycle LOAD in the FSM).
//
//   Wire tracing from data_memory.dig:
//     address    → RAMDualPort port at pos x=360 (address input top)
//     write_data → RAMDualPort (data input)
//     mem_write  → RAMDualPort write-enable
//     mem_read   → RAMDualPort read-enable
//     clk        → RAMDualPort clock
//     read_data  ← RAMDualPort data output (pos x=420,y=100 → Out at 460)
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
            memory[i] = 8'b0;
    end

    // Port A — synchronous write
    // Port B — synchronous read (registered output, matching RAMDualPort)
    always @(posedge clk) begin
        // Write port (A)
        if (mem_write)
            memory[address] <= write_data;

        // Read port (B) — registered, same address bus
        // RAMDualPort: read captures address on posedge when re=1,
        // output is valid the same posedge (registered-through, not next cycle)
        // Digital's RAMDualPort read output updates on the same rising edge
        // that re is sampled, matching the FSM's two-cycle LOAD.
        if (mem_read)
            read_data <= memory[address];
    end

endmodule