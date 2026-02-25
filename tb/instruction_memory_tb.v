`timescale 1ns/1ps

module instruction_memory_tb;

reg [15:0] address;
wire [15:0] instruction;

instruction_memory uut (
    .address(address),
    .instruction(instruction)
);

initial begin
    $dumpfile("imem_dump.vcd");
    $dumpvars(0, instruction_memory_tb);

    address = 0; #10;
    address = 1; #10;
    address = 2; #10;
    address = 3; #10;
    address = 4; #10;

    $finish;
end

endmodule
