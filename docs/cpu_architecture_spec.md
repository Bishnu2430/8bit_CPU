## CPU Type

- 8-bit datapath
- 16-bit address bus
- Harvard architecture (separate instruction & data memory)
- Multi-cycle design (NOT single cycle)
- RISC-style load/store

---

## Register Set

| Register | Width  | Purpose                       |
| -------- | ------ | ----------------------------- |
| R0–R7    | 8-bit  | General purpose (8 registers) |
| PC       | 16-bit | Program Counter               |
| IR       | 16-bit | Instruction Register          |
| MAR      | 16-bit | Memory Address Register       |
| MDR      | 8-bit  | Memory Data Register          |
| SP       | 16-bit | Stack Pointer                 |
| FLAGS    | 4-bit  | Z, C, N, V                    |

---

## Flags Definition

- Z → Zero
- C → Carry
- N → Negative
- V → Overflow

---

## Instruction Format

```
[15:12]  Opcode (4 bits)
[11:9]   Destination Register (3 bits)
[8:6]    Source Register (3 bits)
[5:0]    Immediate / unused / offset (6 bits)
```

---

## Instruction Set

| Opcode | Mnemonic | Description       |
| ------ | -------- | ----------------- | --- |
| 0000   | NOP      | No operation      |
| 0001   | ADD      | Rd = Rd + Rs      |
| 0010   | SUB      | Rd = Rd - Rs      |
| 0011   | AND      | Rd = Rd & Rs      |
| 0100   | OR       | Rd = Rd           | Rs  |
| 0101   | XOR      | Rd = Rd ^ Rs      |
| 0110   | LD       | Rd = MEM[address] |
| 0111   | ST       | MEM[address] = Rd |
| 1000   | MOV      | Rd = Rs           |
| 1001   | ADDI     | Rd = Rd + imm     |
| 1010   | JMP      | PC = address      |
| 1011   | BEQ      | if Z=1 branch     |
| 1100   | PUSH     |                   |
| 1101   | POP      |                   |
| 1110   | CALL     |                   |
| 1111   | RET      |                   |

---

## Register Architecture

- 8 registers → R0–R7
- Each 8-bit
- 2 read ports (asynchronous)
- 1 write port (synchronous)

---

## Program Counter

- 16-bit register
- Synchronous reset
- Increment by 1
- Load new address (for jump/branch)
- Controlled by enable signals

---

## Instruction Memory (ROM)

- 16-bit instruction width
- 16-bit address input (from PC)
- Asynchronous read
- Preloaded with sample instructions
- 256-word ROM (for now)
- Addressed by pc_out[7:0]
- Each word = 16 bits

---

## Instruction Register

- Stores the current instruction
- Loads on clock edge
- Holds instruction stable for decode stage
- Is 16-bit wide

---

## Fetch Unit

        +------------------+
        |  Program Counter |
        +------------------+
                  |
                  v
        +------------------+
        | Instruction Mem  |
        +------------------+
                  |
                  v
        +------------------+
        | Instruction Reg  |
        +------------------+

---

## Decoder Module

```
instruction_in [15:0]
```

```
opcode [3:0]
rd     [2:0]
rs     [2:0]
imm6   [5:0]
```

---

## Multi-Cycle Control Unit (FSM)

### State Definitions

```
FETCH = 2'b00
DECODE = 2'b01
EXECUTE = 2'b10
WRITEBACK = 2'b11
```

### Control Signals

```
pc_enable
pc_load
ir_load
reg_write
alu_op[3:0]
alu_src (0=register, 1=immediate)
```

### Control Behavior

🟢 FETCH

```
pc_enable = 1
ir_load = 1
```

🟢 DECODE

```
Just transition state
```

🟢 EXECUTE

```
Depends on opcode:
Set ALU operation
Set ALU source
```

🟢 WRITEBACK

```
If arithmetic instruction:
    reg_write = 1
If JMP:
    pc_load = 1
```

---

## CPU Datapath

                ┌──────────────┐
                │  Fetch Unit  │
                │PC + IMEM + IR│
                └──────┬───────┘
                       │ instruction_out
                       ▼
                ┌──────────────┐
                │   Decoder    │
                └──────┬───────┘
         rd, rs, imm6  │ opcode
                       ▼
                ┌──────────────┐
                │ Control Unit │
                └──────┬───────┘
          control signals
                       ▼
        ┌─────────────────────────┐
        │ Register File + ALU     │
        └─────────────────────────┘

---

## Branching

For BEQ:
`BEQ R1, R2, offset`

Meaning:

```
if (R1 == R2)
    PC = PC + offset
```

Otherwise:
`continue normally`

---

## BNE

Behavior

```
BNE R1, R2, offset
if (R1 != R2)
    PC = PC + offset
```

Since BEQ already uses zero_flag:

`zero = 1 → equal`

`zero = 0 → not equal`

So BNE is simply:

```
if (!zero_flag)
    pc_load = 1;
```

---

## BLT

We must detect:

`if (R1 < R2)`

Since we already compute SUB for BEQ:

`R1 - R2`

For signed comparison:

`Less than = negative XOR overflow`

Classic signed arithmetic rule.
