`timescale 1ns/1ps
module data_memory (
    input clk, input mem_read, input mem_write,
    input [7:0] address, input [7:0] write_data,
    output reg [7:0] read_data
);
    reg [7:0] memory [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) memory[i] = 8'b0;
    end
    always @(posedge clk) begin
        if (mem_write) memory[address] <= write_data;
        if (mem_read)  read_data <= memory[address];
    end
endmodule