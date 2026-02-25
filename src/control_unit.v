`timescale 1ns/1ps

module control_unit (

    input clk,
    input reset,
    input [3:0] opcode,
    input zero_flag,
    input negative_flag,
    input overflow_flag,

    output reg pc_enable,
    output reg pc_load,
    output reg ir_load,
    output reg reg_write,
    output reg [3:0] alu_op,
    output reg alu_src,

    output reg mem_read,
    output reg mem_write
);

    reg [1:0] state;

    // Latched ALU control (captured in EXECUTE, held through WRITEBACK)
    reg [3:0] alu_op_latched;
    reg       alu_src_latched;

    // Combinational ALU control for the EXECUTE stage
    reg [3:0] alu_op_exec;
    reg       alu_src_exec;

    localparam FETCH     = 2'b00;
    localparam DECODE    = 2'b01;
    localparam EXECUTE   = 2'b10;
    localparam WRITEBACK = 2'b11;

    // ALU control decode (used by EXECUTE stage and latched for WRITEBACK)
    always @(*) begin
        alu_op_exec  = 4'b0000;
        alu_src_exec = 1'b0;

        // Branch comparisons use SUB
        if (opcode == 4'b1011 ||  // BEQ
            opcode == 4'b1100 ||  // BNE
            opcode == 4'b1101) begin // BLT

            alu_op_exec  = 4'b0010;  // SUB
            alu_src_exec = 1'b0;
        end
        else begin
            alu_op_exec = opcode;

            if (opcode == 4'b1001) // ADDI
                alu_src_exec = 1'b1;
        end
    end

    // FSM state transition + latch EXECUTE-stage ALU control
    always @(posedge clk) begin
        if (reset) begin
            state <= FETCH;
            alu_op_latched  <= 4'b0000;
            alu_src_latched <= 1'b0;
        end
        else begin
            if (state == EXECUTE) begin
                alu_op_latched  <= alu_op_exec;
                alu_src_latched <= alu_src_exec;
            end

            state <= state + 1;
        end
    end

    // Control logic
    always @(*) begin

        // Default values
        pc_enable = 0;
        pc_load   = 0;
        ir_load   = 0;
        reg_write = 0;
        alu_op    = 4'b0000;
        alu_src   = 0;
        mem_read  = 0;
        mem_write = 0;

        case (state)

            FETCH: begin
                pc_enable = 1;
                ir_load   = 1;
            end

            EXECUTE: begin
                alu_op  = alu_op_exec;
                alu_src = alu_src_exec;

                // Data memory read is synchronous; start LOAD read here.
                if (opcode == 4'b0110) begin
                    mem_read = 1;
                end
            end

            WRITEBACK: begin

                // Hold ALU controls stable during WRITEBACK so ALU results/flags
                // correspond to the EXECUTE-stage operation (multi-cycle).
                alu_op  = alu_op_latched;
                alu_src = alu_src_latched;

                case (opcode)

                    // Arithmetic
                    4'b0001,
                    4'b0010,
                    4'b0011,
                    4'b0100,
                    4'b0101,
                    4'b1001:
                        reg_write = 1;

                    // LOAD
                    4'b0110: begin
                        mem_read  = 1;
                        reg_write = 1;
                    end

                    // STORE
                    4'b0111:
                        mem_write = 1;

                    // JMP
                    4'b1010:
                        pc_load = 1;

                    // BEQ
                    4'b1011:
                        if (zero_flag)
                            pc_load = 1;

                    // BNE
                    4'b1100:
                        if (!zero_flag)
                            pc_load = 1;

                    // BLT (signed)
                    4'b1101:
                        if (negative_flag ^ overflow_flag)
                            pc_load = 1;

                endcase
            end

        endcase
    end

endmodule