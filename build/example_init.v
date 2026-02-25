// Generated initial block — paste into instruction_memory.v
initial begin
    memory[0] = 16'b1001001000000101; // ADDI R1, #5
    memory[1] = 16'b1001010000000101; // ADDI R2, #5
    memory[2] = 16'b1011001010000001; // BEQ R1, R2, SKIP_R3
    memory[3] = 16'b1001011000000001; // ADDI R3, #1
    memory[4] = 16'b1001100000001001; // ADDI R4, #9
    memory[5] = 16'b0111100000001010; // STORE R4, #10
    memory[6] = 16'b0110101000001010; // LOAD R5, #10
    memory[7] = 16'b1001110000000101; // ADDI R6, #5
    memory[8] = 16'b1001110000111111; // ADDI R6, #-1
    memory[9] = 16'b1101110000000001; // BLT R6, R0, END
    memory[10] = 16'b1011000000111101; // BEQ R0, R0, LOOP
    memory[11] = 16'b0000000000000000; // NOP
end
