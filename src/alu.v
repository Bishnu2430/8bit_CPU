`timescale 1ns/1ps

module alu (
    input  [7:0] a,
    input  [7:0] b,
    input  [3:0] alu_op,
    output reg [7:0] result,
    output reg zero,
    output reg carry,
    output reg negative,
    output reg overflow
);

reg [8:0] temp;

always @(*) begin
    result   = 8'b00000000;
    carry    = 1'b0;
    overflow = 1'b0;
    temp     = 9'b0;

    case (alu_op)
        4'b0001: begin  // ADD
            temp     = a + b;
            result   = temp[7:0];
            carry    = temp[8];
            overflow = (a[7] == b[7]) && (result[7] != a[7]);
        end
        4'b1001: begin  // ADDI
            temp     = a + b;
            result   = temp[7:0];
            carry    = temp[8];
            overflow = (a[7] == b[7]) && (result[7] != a[7]);
        end
        4'b0010: begin  // SUB
            temp     = a - b;
            result   = temp[7:0];
            carry    = temp[8];
            overflow = (a[7] != b[7]) && (result[7] != a[7]);
        end
        4'b0011: result = a & b;  // AND
        4'b0100: result = a | b;  // OR
        4'b0101: result = a ^ b;  // XOR
        4'b1000: result = b;      // MOV
        default: result = 8'b00000000;
    endcase

    zero     = (result == 8'b00000000);
    negative = result[7];
end

endmodule