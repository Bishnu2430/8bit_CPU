`timescale 1ns/1ps

module reg_file_tb;

reg clk;
reg reg_write;

reg [2:0] read_reg1;
reg [2:0] read_reg2;
reg [2:0] write_reg;
reg [7:0] write_data;

wire [7:0] read_data1;
wire [7:0] read_data2;

reg_file uut (
    .clk(clk),
    .reg_write(reg_write),
    .read_reg1(read_reg1),
    .read_reg2(read_reg2),
    .write_reg(write_reg),
    .write_data(write_data),
    .read_data1(read_data1),
    .read_data2(read_data2)
);

    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("reg_dump.vcd");
        $dumpvars(0, reg_file_tb);

        // Initial values
        reg_write = 0;
        read_reg1 = 0;
        read_reg2 = 0;
        write_reg = 0;
        write_data = 0;

        #10;

        // Write 55 to R1
        reg_write = 1;
        write_reg = 3'b001;
        write_data = 8'd55;
        #10;

        // Write 100 to R2
        write_reg = 3'b010;
        write_data = 8'd100;
        #10;

        reg_write = 0;

        // Read R1 and R2
        read_reg1 = 3'b001;
        read_reg2 = 3'b010;
        #10;

        // Read R0 (should be default X or 0 depending on sim)
        read_reg1 = 3'b000;
        #10;

        $finish;
    end

endmodule
