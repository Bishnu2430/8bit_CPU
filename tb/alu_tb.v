`timescale 1ns/1ps

module alu_tb;

reg  [7:0] a;
reg  [7:0] b;
reg  [3:0] alu_op;

wire [7:0] result;
wire zero;
wire carry;
wire negative;
wire overflow;

alu uut (
    .a(a),
    .b(b),
    .alu_op(alu_op),
    .result(result),
    .zero(zero),
    .carry(carry),
    .negative(negative),
    .overflow(overflow)
);

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, alu_tb);

    // ADD normal
    a = 8'd10; b = 8'd5; alu_op = 4'b0001; #10;

    // ADD overflow
    a = 8'd127; b = 8'd1; alu_op = 4'b0001; #10;

    // SUB normal
    a = 8'd20; b = 8'd5; alu_op = 4'b0010; #10;

    // SUB negative
    a = 8'd5; b = 8'd10; alu_op = 4'b0010; #10;

    // AND
    a = 8'b11001100; b = 8'b10101010; alu_op = 4'b0011; #10;

    // OR
    a = 8'b11001100; b = 8'b10101010; alu_op = 4'b0100; #10;

    // XOR
    a = 8'b11001100; b = 8'b10101010; alu_op = 4'b0101; #10;

    // MOV
    a = 8'd0; b = 8'd55; alu_op = 4'b1000; #10;

    $finish;
end

endmodule
