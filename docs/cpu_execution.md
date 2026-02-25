# CPU Execution Proof

**Document:** cpu_execution_proof.md  
**Version:** v0.3 — Multi-cycle Branching + Memory Support  
**Architecture:** 8-bit datapath, 16-bit address, Harvard, Multi-cycle FSM  
**Date:** 2026-02-25

---

## 1. Scope and Conventions

This document provides a formal, cycle-accurate mathematical proof of instruction execution for the custom 8-bit RISC CPU. All arithmetic is performed in 8-bit two's complement unless stated otherwise. Register values are unsigned 8-bit integers (0–255) with signed interpretation where applicable. The symbol ⊕ denotes bitwise XOR.

**Notation:**

| Symbol     | Meaning                                       |
| ---------- | --------------------------------------------- |
| PC         | Program Counter (16-bit)                      |
| PC_f       | PC value after FETCH increment (PC + 1)       |
| IR         | Instruction Register (16-bit)                 |
| Rd, Rs     | Decoded destination / source register indices |
| a, b       | ALU input operands (8-bit)                    |
| result     | ALU output (8-bit)                            |
| temp       | 9-bit intermediate (carry detection)          |
| Z, C, N, V | Zero, Carry, Negative, Overflow flags         |

---

## 2. Example Program

The following program exercises ADDI, BEQ (taken), BEQ (not taken via structural skip), STORE, LOAD, and a BLT backward countdown loop.

```
Addr  Encoding (bin)       Mnemonic            Comment
----  -------------------  ------------------  -----------------------------------------
 0    1001_001_000_000101   ADDI R1, #5         R1 ← 0 + 5 = 5
 1    1001_010_000_000101   ADDI R2, #5         R2 ← 0 + 5 = 5
 2    1011_001_010_000001   BEQ  R1, R2, +1     if R1==R2: PC ← PC_f + 1 = 4 (TAKEN)
 3    1001_011_000_000001   ADDI R3, #1         R3 ← 1  ← SKIPPED by BEQ
 4    1001_100_000_001001   ADDI R4, #9         R4 ← 9
 5    0111_100_000_001010   STORE R4, #10       MEM[10] ← R4
 6    0110_101_000_001010   LOAD  R5, #10       R5 ← MEM[10]
 7    1001_110_000_000101   ADDI R6, #5         R6 ← 5   (loop counter init)
 8    1001_110_000_111111   ADDI R6, #-1        R6 ← R6 − 1  [LOOP TOP]
 9    1101_110_000_000001   BLT  R6, R0, END    if R6 < R0: PC ← PC_f + 1 = 11
10    1011_000_000_111101   BEQ  R0, R0, LOOP   unconditional back to 8; offset = −3
11    0000_000_000_000000   NOP                 end sentinel
```

**Initial register state:** R0–R7 = 0x00. FLAGS = 0000.

---

## 3. Formal Instruction Execution Proofs

### 3.1 Instruction at PC=0 — `ADDI R1, #5`

**Encoding:**

```
IR = 1001_001_000_000101
opcode = IR[15:12] = 1001 = 0x9  (ADDI)
rd     = IR[11:9]  = 001  = 1    (R1)
rs     = IR[8:6]   = 000  = 0    (R0, ignored for ADDI)
imm6   = IR[5:0]   = 000101 = 5
```

**Sign extension (8-bit for ALU):**

```
imm6[5] = 0 (positive)
SignExt8(imm6) = {2'b00, 000101} = 00000101 = 5
```

**Pre-execution state:**

```
R1 = 0x00 = 0
```

**ALU operation (ADDI = ADD):**

```
a    = R1 = 0x00 = 0000_0000
b    = 5  = 0x05 = 0000_0101
temp = a + b = 0_0000_0101 (9-bit)

result   = temp[7:0] = 0000_0101 = 5
carry    = temp[8]   = 0
overflow = (a[7] == b[7]) && (result[7] != a[7])
         = (0 == 0) && (0 != 0) = 1 && 0 = 0
zero     = (result == 0) = 0
negative = result[7] = 0
FLAGS    = {V=0, N=0, C=0, Z=0}
```

**PC update:**

```
FETCH:     PC_f = 0 + 1 = 1
WRITEBACK: reg_write = 1; R1 ← 5
           No branch; PC remains 1.
```

**Post-execution state:** R1 = 5, PC = 1, FLAGS = 0000.

---

### 3.2 Instruction at PC=1 — `ADDI R2, #5`

Identical arithmetic to §3.1 with rd=2:

```
a = R2 = 0, b = 5
result = 5, FLAGS = 0000
R2 ← 5, PC_f = 2
```

**Post-execution state:** R1=5, R2=5, PC=2, FLAGS=0000.

---

### 3.3 Instruction at PC=2 — `BEQ R1, R2, +1` (branch TAKEN)

**Encoding:**

```
IR = 1011_001_010_000001
opcode = 1011 (BEQ)
rd     = 001 → R1
rs     = 010 → R2
imm6   = 000001 = +1
```

**Signed offset (16-bit):**

```
imm6[5] = 0
signed_offset = {{10{0}}, 000001} = 0x0001
```

**FETCH:**

```
PC_f = 2 + 1 = 3   ← PC incremented here
```

**EXECUTE (SUB for comparison):**

```
a    = R1 = 5 = 0000_0101
b    = R2 = 5 = 0000_0101
temp = a − b = 5 − 5 = 0_0000_0000 (9-bit)

result   = 0x00
zero     = 1          ← Z flag SET
negative = 0
carry    = 0
overflow = (a[7] != b[7]) && (result[7] != a[7])
         = (0 != 0) && ... = 0
FLAGS    = {V=0, N=0, C=0, Z=1}
```

**BEQ condition evaluation:**

```
Z = 1 → condition TRUE → pc_load = 1
```

**Branch target computation:**

```
branch_target = PC_f + signed_offset
              = 3    + 1
              = 4
PC ← 4   (PC=3, instruction ADDI R3 #1, is SKIPPED)
```

**Proof that BEQ is correct:**

```
R1 == R2  ⟺  R1 − R2 == 0  ⟺  Z = 1  ⟺  pc_load = 1   □
```

---

### 3.4 Instruction at PC=3 — SKIPPED

PC jumped to 4 during WRITEBACK of §3.3. Instruction at address 3 is never fetched.

---

### 3.5 Instruction at PC=4 — `ADDI R4, #9`

```
a = R4 = 0, b = 9
temp = 0 + 9 = 9, result = 0x09
R4 ← 9, FLAGS = 0000, PC_f = 5
```

---

### 3.6 Instruction at PC=5 — `STORE R4, #10`

**Encoding:**

```
IR = 0111_100_000_001010
opcode = 0111 (STORE)
rd     = 100 → R4
imm6   = 001010 = 10
address = {2'b00, 001010} = 0x0A = 10
```

**Memory state transition:**

```
Pre:  MEM[10] = 0x00
Op:   MEM[10] ← reg_data1 = R4 = 9
Post: MEM[10] = 0x09
```

STORE asserts `mem_write` in WRITEBACK. No register writeback occurs. FLAGS unchanged.

**PC_f = 6.**

---

### 3.7 Instruction at PC=6 — `LOAD R5, #10`

**Encoding:**

```
IR = 0110_101_000_001010
opcode = 0110 (LOAD)
rd     = 101 → R5
imm6   = 001010 = 10
address = 0x0A = 10
```

**Memory read sequence:**

```
EXECUTE:   mem_read = 1; DataMEM latches address 0x0A
WRITEBACK: mem_read = 1; read_data = MEM[10] = 0x09 = 9
           reg_write = 1; R5 ← mem_data = 9
```

**Post-execution state:** R5 = 9, MEM[10] = 9, PC = 7.

---

### 3.8 Instruction at PC=7 — `ADDI R6, #5`

```
a = R6 = 0, b = 5
result = 5, R6 ← 5, PC_f = 8
FLAGS = 0000
```

---

### 3.9 Loop body — First iteration (PC=8–10)

#### PC=8 — `ADDI R6, #-1`

**Encoding:**

```
IR = 1001_110_000_111111
imm6 = 111111 (two's complement) = −1 (decimal)
```

**Sign extension (8-bit):**

```
imm6[5] = 1 (negative)
SignExt8(111111) = {2'b11, 111111} = 1111_1111 = 0xFF = −1 (signed)
```

**ALU operation (first iteration, R6=5):**

```
a    = R6 = 5 = 0000_0101
b    = −1   = 1111_1111
temp = a + b = 0_0000_0100  (9-bit: 5 + 255 = 260 = 0x104)

result   = temp[7:0] = 0000_0100 = 4
carry    = temp[8]   = 1
overflow = (a[7] == b[7]) && (result[7] != a[7])
         = (0 == 1) && ... = 0
zero     = 0
negative = 0
FLAGS    = {V=0, N=0, C=1, Z=0}
R6 ← 4
```

> Note: 5 + (−1) = 4. Carry=1 is the borrow indicator from unsigned addition perspective but the signed result is mathematically correct.

**PC_f = 9.**

#### PC=9 — `BLT R6, R0, END` (+1, first iteration R6=4)

**Encoding:**

```
IR = 1101_110_000_000001
opcode = 1101 (BLT)
rd = 110 → R6
rs = 000 → R0
imm6 = 000001 = +1 → signed_offset = 0x0001
```

**FETCH:** PC_f = 9 + 1 = 10

**EXECUTE — SUB R6, R0:**

```
a    = R6 = 4 = 0000_0100
b    = R0 = 0 = 0000_0000
temp = 4 − 0 = 4
result = 0x04, zero=0, negative=0, carry=0
overflow = (a[7] != b[7]) && ... = (0 != 0) && ... = 0
FLAGS = {V=0, N=0, C=0, Z=0}
```

**BLT condition:**

```
N ⊕ V = 0 ⊕ 0 = 0 → condition FALSE → no branch
PC remains 10
```

**BLT correctness proof (first iteration):**

```
R6=4, R0=0: 4 < 0 is FALSE (signed)  →  N⊕V must = 0
N=0, V=0: N⊕V = 0   ✓
```

#### PC=10 — `BEQ R0, R0, LOOP` (offset = −3, R6=4)

**Encoding:**

```
IR = 1011_000_000_111101
opcode = 1011 (BEQ)
rd = rs = 000 → R0, R0
imm6 = 111101 → two's complement = −3
signed_offset = {{10{1}}, 111101} = 1111111111111101 = −3 (16-bit)
```

**FETCH:** PC_f = 10 + 1 = 11

**EXECUTE — SUB R0, R0:**

```
a = b = R0 = 0
result = 0, zero = 1
FLAGS: Z=1, others 0
```

**BEQ condition:**

```
Z = 1 → pc_load = 1
branch_target = PC_f + signed_offset = 11 + (−3) = 8
PC ← 8  (back to LOOP top)
```

---

### 3.10 Final BLT iteration — Exit condition (R6 = 0 → ADDI → R6 = −1)

After 5 ADDI R6, #-1 iterations: R6 = 5 − 5 = 0. Next iteration:

**ADDI R6, #-1 (R6=0):**

```
a    = R6 = 0 = 0000_0000
b    = −1   = 1111_1111
temp = 0 + 255 = 255 = 0_1111_1111

result   = 1111_1111 = 0xFF = −1 (signed) = 255 (unsigned)
carry    = 0
overflow = (0 == 1) && ... = 0
negative = result[7] = 1
zero     = 0
FLAGS    = {V=0, N=1, C=0, Z=0}
R6 ← 0xFF (−1 signed)
```

**BLT R6, R0 (R6=−1, R0=0):**

```
a    = R6 = 0xFF = 1111_1111 = −1 (signed)
b    = R0 = 0x00 = 0
temp = a − b = −1 − 0 = 0xFF (no underflow in 8-bit)
result   = 1111_1111
negative = 1
overflow = (a[7] != b[7]) && (result[7] != a[7])
         = (1 != 0) && (1 != 1) = 1 && 0 = 0
FLAGS    = {V=0, N=1, C=0, Z=0}

N ⊕ V = 1 ⊕ 0 = 1 → branch TAKEN
PC_f = 10, signed_offset = +1
branch_target = 10 + 1 = 11  (END / NOP)
```

**BLT exit proof:**

```
R6 = −1, R0 = 0: (−1 < 0) = TRUE → N⊕V must = 1
N=1, V=0: N⊕V = 1   ✓   □
```

---

## 4. FSM Timing Analysis

The following table shows the cycle-by-cycle control signal state for `BEQ R1, R2, +1` (PC=2):

| Cycle |   State   | PC (pc_out) |    IR     | alu_op | reg_write | pc_load |  Z  |  N  |  V  |
| :---: | :-------: | :---------: | :-------: | :----: | :-------: | :-----: | :-: | :-: | :-: |
|   0   |   FETCH   |      2      |  (prev)   |  0000  |     0     |    0    |  —  |  —  |  —  |
|   1   |  DECODE   |     3\*     | BEQ instr |  0000  |     0     |    0    |  —  |  —  |  —  |
|   2   |  EXECUTE  |      3      | BEQ instr |  0010  |     0     |    0    |  1  |  0  |  0  |
|   3   | WRITEBACK |      3      | BEQ instr |  0010  |     0     |  **1**  |  1  |  0  |  0  |
|   4   |   FETCH   |    **4**    |     —     |  0000  |     0     |    0    |  —  |  —  |  —  |

\*PC increments to 3 at the rising edge of FETCH (cycle 0 → 1 transition).

**Signal explanations:**

- **Cycle 0 (FETCH):** `pc_enable=1` increments PC from 2 to 3. `ir_load=1` captures the BEQ instruction into IR.
- **Cycle 1 (DECODE):** No side-effects. Decoder combinationally produces opcode=1011, rd=1, rs=2, imm6=1.
- **Cycle 2 (EXECUTE):** Control sets `alu_op=0010` (SUB). ALU computes R1−R2=0. Z flag becomes 1.
- **Cycle 3 (WRITEBACK):** `zero_flag=1` causes `pc_load=1`. PC loads branch_target = 3 + 1 = 4.
- **Cycle 4 (FETCH):** PC=4. Fetch proceeds from ADDI R4 instruction. Instruction at address 3 never entered FETCH.

---

## 5. GTKWave Signal Correlation

The following VCD signals correspond to the mathematical proof in §3.3:

| VCD Signal           | Expected value at BEQ WRITEBACK   |
| -------------------- | --------------------------------- |
| `uut.pc_out`         | 0x0003 (incremented during FETCH) |
| `uut.instruction`    | 0xB281 (BEQ R1,R2,+1)             |
| `uut.opcode`         | 0xB (1011)                        |
| `uut.rd`             | 1                                 |
| `uut.rs`             | 2                                 |
| `uut.alu_result`     | 0x00                              |
| `uut.zero`           | 1                                 |
| `uut.negative`       | 0                                 |
| `uut.overflow`       | 0                                 |
| `uut.ctrl.pc_load`   | 1                                 |
| `uut.ctrl.reg_write` | 0                                 |
| `uut.ctrl.mem_read`  | 0                                 |
| `uut.ctrl.mem_write` | 0                                 |

**GTKWave correlation example:**

At time T = 125 ns in GTKWave (3 instructions × 4 cycles × 10 ns/cycle + 5 ns offset):

```
pc_out      = 0x0003
instruction = 0xB281
opcode      = 0xB  (1011 = BEQ)
alu_result  = 0x00
zero        = 1
ctrl.state  = 2'b11 (WRITEBACK)
pc_load     = 1

Therefore: BEQ condition (Z=1) is TRUE.
PC will load branch_target = 0x0003 + 0x0001 = 0x0004 on next rising edge.
Instruction at address 0x0003 (ADDI R3, #1) is never fetched.
```

**Verification in GTKWave:**

1. Open `build/cpu_dump.vcd`
2. Add signals: `uut/pc_out`, `uut/instruction`, `uut/zero`, `uut/ctrl/pc_load`, `uut/ctrl/state`
3. Navigate to the clock edge at ~125 ns
4. Confirm `pc_load=1` while `state=2'b11` and `zero=1`
5. Confirm the next FETCH (`state=2'b00`) shows `pc_out=4`, not 3

---

## 6. Formal Consistency Check

### 6.1 ISA Consistency Validation

| Property                           | Status |
| ---------------------------------- | ------ |
| All opcodes 0x0–0xD defined        | ✓      |
| 0xE, 0xF reserved (no decode)      | ✓      |
| PUSH/POP/CALL/RET removed from ISA | ✓      |
| 4-cycle FSM for all instructions   | ✓      |
| Instruction width fixed at 16 bits | ✓      |
| Opcode field width = 4 bits        | ✓      |
| Register field width = 3 bits      | ✓      |
| Immediate field width = 6 bits     | ✓      |

### 6.2 Flag Logic Validation

```
Zero:     result[7:0] == 8'h00                                  ✓
Carry:    temp[8] from 9-bit a+b or a-b                         ✓
Negative: result[7]  (MSB of 8-bit result)                      ✓
Overflow ADD:  (a[7] == b[7]) && (result[7] != a[7])            ✓
Overflow SUB:  (a[7] != b[7]) && (result[7] != a[7])            ✓
```

### 6.3 Signed Comparison Correctness (BLT)

The BLT condition `N ⊕ V = 1` is the standard IEEE/RISC signed less-than check:

| Case       | a[7] | b[7] | result[7] |  N  |  V  | N⊕V | a<b? |
| ---------- | :--: | :--: | :-------: | :-: | :-: | :-: | :--: |
| 4 < 9      |  0   |  0   |     1     |  1  |  0  |  1  |  ✓   |
| 9 < 4      |  0   |  0   |     0     |  0  |  0  |  0  |  ✓   |
| -1 < 0     |  1   |  0   |     1     |  1  |  0  |  1  |  ✓   |
| 127 < -128 |  0   |  1   |     1     |  1  |  1  |  0  |  ✓   |
| -128 < 127 |  1   |  0   |     0     |  0  |  1  |  1  |  ✓   |

All cases correct. □

### 6.4 Branch Offset Correctness

```
Branch target = pc_out + signed_offset
pc_out        = PC + 1  (incremented during FETCH)
signed_offset = {{10{imm6[5]}}, imm6}

For imm6 = 111110 = −2:
  signed_offset = 1111_1111_1111_1110 = 0xFFFE = −2 (16-bit two's complement)
  branch_target = (PC + 1) + (−2) = PC − 1

For imm6 = 000001 = +1:
  branch_target = (PC + 1) + 1 = PC + 2

Skipping next instruction: imm6 = +1 → jumps over addr PC+1 to PC+2  ✓
Back 2 instructions: imm6 = −2 → arrives at PC−1                      ✓
```

### 6.5 Multi-cycle Timing Correctness

```
Every instruction occupies exactly 4 clock cycles:
  Cycle 0 (FETCH):     IR captures instruction; PC increments
  Cycle 1 (DECODE):    Combinational decode; no state change
  Cycle 2 (EXECUTE):   ALU computes; mem_read initiated for LOAD
  Cycle 3 (WRITEBACK): Register write / branch / memory store commits

Hazard analysis:
  - Register file read is asynchronous → rd data available same cycle as decode
  - Register file write is synchronous (posedge) → committed at end of WRITEBACK
  - ALU flag result available combinationally from EXECUTE → stable in WRITEBACK
  - LOAD: mem_read asserted EXECUTE + WRITEBACK; read_data valid at WRITEBACK
    posedge → write_data = mem_data routes correctly through WB mux
  - No pipeline; no data hazards possible in multi-cycle design
  - Branch condition evaluated from flags set in EXECUTE; pc_load fires in
    WRITEBACK — 1 cycle after flag generation → no race condition
```

**Conclusion:** The multi-cycle timing is formally correct for the described instruction set. All arithmetic, branching, and memory operations produce results consistent with the ISA specification.

---

_End of Document_
