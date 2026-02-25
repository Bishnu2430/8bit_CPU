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

reg [8:0] temp;   // 9-bit temp for carry detection

always @(*) begin
    // Default assignments
    result   = 8'b00000000;
    carry    = 1'b0;
    overflow = 1'b0;
    temp     = 9'b0;

    case (alu_op)

        4'b0001: begin  // ADD
            temp   = a + b;
            result = temp[7:0];
            carry  = temp[8];
            overflow = (a[7] == b[7]) && (result[7] != a[7]);
        end

        4'b1001: begin  // ADDI
            temp   = a + b;
            result = temp[7:0];
            carry  = temp[8];
            overflow = (a[7] == b[7]) && (result[7] != a[7]);
        end

        4'b0010: begin  // SUB
            temp   = a - b;
            result = temp[7:0];
            carry  = temp[8];  // borrow indication
            overflow = (a[7] != b[7]) && (result[7] != a[7]);
        end

        4'b0011: begin  // AND
            result = a & b;
        end

        4'b0100: begin  // OR
            result = a | b;
        end

        4'b0101: begin  // XOR
            result = a ^ b;
        end

        4'b1000: begin  // MOV
            result = b;
        end

        default: begin
            result = 8'b00000000;
        end

    endcase

    // Common flag logic
    zero     = (result == 8'b00000000);
    negative = result[7];

end

endmodule
