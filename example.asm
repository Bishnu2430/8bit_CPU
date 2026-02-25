; example.asm — demonstration program for custom 8-bit RISC CPU
; Assembler: assembler.py
; ISA version: v0.3
;
; Program behavior:
;   R1 = 5
;   R2 = 5
;   BEQ R1, R2 → taken (branch to SKIP_R3)
;   R3 = 1     → skipped
; SKIP_R3:
;   R4 = 9
;   MEM[10] = R4
;   R5 = MEM[10]
;   R6 = 5     ; loop counter
; LOOP:
;   R6 = R6 - 1
;   if R6 < R0 (0): exit loop   (BLT, taken when R6 goes negative)
;   goto LOOP
; END:
;   NOP        ; program halt sentinel

        ADDI    R1, #5          ; R1 = 5
        ADDI    R2, #5          ; R2 = 5

        BEQ     R1, R2, SKIP_R3 ; branch if R1 == R2 (taken)
        ADDI    R3, #1          ; R3 = 1 — SKIPPED

SKIP_R3:
        ADDI    R4, #9          ; R4 = 9
        STORE   R4, #10         ; MEM[10] = R4
        LOAD    R5, #10         ; R5 = MEM[10] = 9
        ADDI    R6, #5          ; R6 = 5 (loop counter)

LOOP:
        ADDI    R6, #-1         ; R6 = R6 - 1
        BLT     R6, R0, END     ; if R6 < 0: exit (branch when N^V = 1)
        BEQ     R0, R0, LOOP   ; unconditional branch back to LOOP (R0==R0 always)

END:
        NOP                     ; program complete