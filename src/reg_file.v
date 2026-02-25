`timescale 1ns/1ps

module reg_file (
    input clk,
    input reg_write,

    input  [2:0] read_reg1,
    input  [2:0] read_reg2,
    input  [2:0] write_reg,

    input  [7:0] write_data,

    output [7:0] read_data1,
    output [7:0] read_data2
);

    // 8 registers of 8 bits
    reg [7:0] registers [0:7];

    // Initialize registers to 0 (required for simulation;
    // for synthesis/FPGA, add synchronous reset logic instead)
    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1)
            registers[i] = 8'b0;
    end

    // Asynchronous read
    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    // Synchronous write
    always @(posedge clk) begin
        if (reg_write) begin
            registers[write_reg] <= write_data;
        end
    end

endmodule
