`timescale 1ns/1ps
module reg_file (
    input clk, input reg_write,
    input [2:0] read_reg1, input [2:0] read_reg2, input [2:0] write_reg,
    input [7:0] write_data,
    output [7:0] read_data1, output [7:0] read_data2
);
    reg [7:0] registers [0:7];
    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1) registers[i] = 8'b0;
    end
    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];
    always @(posedge clk) begin
        // R0 is hardwired to zero — writes to register 0 are silently ignored
        if (reg_write && write_reg != 3'b000)
            registers[write_reg] <= write_data;
    end
endmodule