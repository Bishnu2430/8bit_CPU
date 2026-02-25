#!/usr/bin/env python3
"""
assembler.py — Two-pass assembler for custom 8-bit/16-bit RISC CPU

ISA:  16-bit fixed-width instructions
      [15:12] opcode  [11:9] rd  [8:6] rs  [5:0] imm6

Usage:
    python3 assembler.py input.asm -o output.mem
    python3 assembler.py input.asm -o output.hex --format hex
"""

import sys
import argparse
import re

# ─────────────────────────────────────────────────────────────
# Opcode table
# ─────────────────────────────────────────────────────────────
OPCODES = {
    "NOP":   0x0,
    "ADD":   0x1,
    "SUB":   0x2,
    "AND":   0x3,
    "OR":    0x4,
    "XOR":   0x5,
    "LOAD":  0x6,
    "STORE": 0x7,
    "MOV":   0x8,
    "ADDI":  0x9,
    "JMP":   0xA,
    "BEQ":   0xB,
    "BNE":   0xC,
    "BLT":   0xD,
}

# Instructions that use (rd, rs, imm6) — all branch/memory
# Instructions that use (rd, rs) only — reg-reg ALU
# Instructions that use (rd, imm6) — ADDI
# Instructions that use imm6 only — JMP
# Instructions with no operands — NOP

# Instruction format categories
FMT_NONE    = "none"     # NOP
FMT_RR      = "rr"      # ADD, SUB, AND, OR, XOR, MOV  → rd, rs
FMT_RI      = "ri"      # ADDI                          → rd, #imm
FMT_MEM     = "mem"     # LOAD, STORE                   → rd, #addr
FMT_BRANCH  = "branch"  # BEQ, BNE, BLT                → rd, rs, label/#offset
FMT_JUMP    = "jump"    # JMP                           → label/#target

FORMATS = {
    "NOP":   FMT_NONE,
    "ADD":   FMT_RR,
    "SUB":   FMT_RR,
    "AND":   FMT_RR,
    "OR":    FMT_RR,
    "XOR":   FMT_RR,
    "MOV":   FMT_RR,
    "ADDI":  FMT_RI,
    "LOAD":  FMT_MEM,
    "STORE": FMT_MEM,
    "BEQ":   FMT_BRANCH,
    "BNE":   FMT_BRANCH,
    "BLT":   FMT_BRANCH,
    "JMP":   FMT_JUMP,
}

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

def parse_register(token, line_num):
    """Parse 'R0'–'R7', return integer 0–7."""
    m = re.fullmatch(r'R([0-7])', token.upper())
    if not m:
        raise AssemblerError(line_num, f"Invalid register '{token}'. Expected R0–R7.")
    return int(m.group(1))

def parse_immediate(token, line_num):
    """Parse '#value' → signed integer."""
    m = re.fullmatch(r'#(-?\d+)', token)
    if not m:
        raise AssemblerError(line_num, f"Invalid immediate '{token}'. Expected #value.")
    return int(m.group(1))

def to_imm6(value, line_num, signed=True):
    """
    Convert integer to 6-bit field.
    signed=True  → range −32..+31  (branch offsets, ADDI)
    signed=False → range   0..63   (memory addresses)
    """
    if signed:
        if value < -32 or value > 31:
            raise AssemblerError(line_num,
                f"Immediate {value} out of signed 6-bit range (−32..+31).")
        return value & 0x3F  # two's complement 6-bit
    else:
        if value < 0 or value > 63:
            raise AssemblerError(line_num,
                f"Address {value} out of unsigned 6-bit range (0..63).")
        return value & 0x3F

def encode(opcode, rd=0, rs=0, imm6=0):
    """Pack fields into 16-bit instruction word."""
    return ((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs & 0x7) << 6) | (imm6 & 0x3F)

class AssemblerError(Exception):
    def __init__(self, line_num, message):
        super().__init__(f"Line {line_num}: {message}")

# ─────────────────────────────────────────────────────────────
# Pre-processing: strip comments, blank lines, collect tokens
# ─────────────────────────────────────────────────────────────

def preprocess(source_lines):
    """
    Returns list of (original_line_num, tokens) tuples.
    Labels are stripped into a separate dict: label → PC address.
    Blank lines and comment-only lines are excluded.
    """
    cleaned = []
    for line_num, raw in enumerate(source_lines, start=1):
        line = raw.split(';')[0].strip()  # strip comments
        if not line:
            continue
        cleaned.append((line_num, line))
    return cleaned

# ─────────────────────────────────────────────────────────────
# Pass 1: Symbol table (label → address)
# ─────────────────────────────────────────────────────────────

def pass1(cleaned_lines):
    """
    Scan lines for label definitions (token ending with ':').
    Returns symbol_table and instruction_lines (without labels).
    """
    symbol_table = {}   # label string → PC word address
    instr_lines  = []   # (line_num, mnemonic, operands_string, PC)
    pc = 0

    for line_num, line in cleaned_lines:
        tokens = line.split()
        idx = 0

        # Consume label(s)
        while idx < len(tokens) and tokens[idx].endswith(':'):
            label = tokens[idx][:-1].upper()
            if label in symbol_table:
                raise AssemblerError(line_num, f"Duplicate label '{label}'.")
            symbol_table[label] = pc
            idx += 1

        if idx >= len(tokens):
            continue  # label-only line

        mnemonic = tokens[idx].upper()
        if mnemonic not in OPCODES:
            raise AssemblerError(line_num, f"Unknown mnemonic '{mnemonic}'.")

        operand_str = ' '.join(tokens[idx+1:])
        instr_lines.append((line_num, mnemonic, operand_str, pc))
        pc += 1

    return symbol_table, instr_lines

# ─────────────────────────────────────────────────────────────
# Pass 2: Encode instructions
# ─────────────────────────────────────────────────────────────

def pass2(instr_lines, symbol_table):
    """
    Encode each instruction to a 16-bit word.
    Returns list of (pc, word, source_annotation).
    """
    words = []

    for (line_num, mnemonic, operand_str, pc) in instr_lines:
        fmt = FORMATS[mnemonic]
        op  = OPCODES[mnemonic]

        # Split operands on commas, strip whitespace
        operands = [o.strip() for o in operand_str.split(',')] if operand_str else []

        if fmt == FMT_NONE:
            # NOP
            word = encode(op)

        elif fmt == FMT_RR:
            # ADD R1, R2  |  MOV R3, R5
            if len(operands) != 2:
                raise AssemblerError(line_num, f"{mnemonic} requires 2 operands (rd, rs).")
            rd = parse_register(operands[0], line_num)
            rs = parse_register(operands[1], line_num)
            word = encode(op, rd, rs)

        elif fmt == FMT_RI:
            # ADDI R1, #-1
            if len(operands) != 2:
                raise AssemblerError(line_num, f"{mnemonic} requires 2 operands (rd, #imm).")
            rd  = parse_register(operands[0], line_num)
            imm = parse_immediate(operands[1], line_num)
            word = encode(op, rd, 0, to_imm6(imm, line_num, signed=True))

        elif fmt == FMT_MEM:
            # LOAD R5, #10  |  STORE R4, #10
            if len(operands) != 2:
                raise AssemblerError(line_num, f"{mnemonic} requires 2 operands (rd, #addr).")
            rd   = parse_register(operands[0], line_num)
            addr = parse_immediate(operands[1], line_num)
            word = encode(op, rd, 0, to_imm6(addr, line_num, signed=False))

        elif fmt == FMT_BRANCH:
            # BEQ R1, R2, LABEL  |  BEQ R1, R2, #-2
            if len(operands) != 3:
                raise AssemblerError(line_num,
                    f"{mnemonic} requires 3 operands (rd, rs, label/#offset).")
            rd = parse_register(operands[0], line_num)
            rs = parse_register(operands[1], line_num)
            target_tok = operands[2]

            if target_tok.startswith('#'):
                offset = parse_immediate(target_tok, line_num)
            else:
                label = target_tok.upper()
                if label not in symbol_table:
                    raise AssemblerError(line_num, f"Undefined label '{label}'.")
                # Branch target = symbol_address
                # offset = target − (PC + 1)  because PC increments during FETCH
                offset = symbol_table[label] - (pc + 1)

            word = encode(op, rd, rs, to_imm6(offset, line_num, signed=True))

        elif fmt == FMT_JUMP:
            # JMP LABEL  |  JMP #5
            if len(operands) != 1:
                raise AssemblerError(line_num, f"JMP requires 1 operand (label/#addr).")
            target_tok = operands[0]

            if target_tok.startswith('#'):
                target = parse_immediate(target_tok, line_num)
            else:
                label = target_tok.upper()
                if label not in symbol_table:
                    raise AssemblerError(line_num, f"Undefined label '{label}'.")
                target = symbol_table[label]

            word = encode(op, 0, 0, to_imm6(target, line_num, signed=False))

        else:
            raise AssemblerError(line_num, f"Internal error: unknown format '{fmt}'.")

        annotation = f"{mnemonic} {operand_str}".strip()
        words.append((pc, word, annotation))

    return words

# ─────────────────────────────────────────────────────────────
# Output formatters
# ─────────────────────────────────────────────────────────────

def write_mem(words, out_path):
    """Verilog $readmemb compatible .mem file (binary, one word per line)."""
    with open(out_path, 'w') as f:
        f.write("// Generated by cpu_assembler.py\n")
        for pc, word, ann in words:
            f.write(f"{word:016b}  // [{pc:03d}] {ann}\n")

def write_hex(words, out_path):
    """Intel-HEX style hex values, one per line."""
    with open(out_path, 'w') as f:
        f.write("// Generated by cpu_assembler.py\n")
        for pc, word, ann in words:
            f.write(f"{word:04X}  // [{pc:03d}] {ann}\n")

def write_verilog_init(words, out_path):
    """Verilog initial block snippet for direct paste into instruction_memory.v."""
    with open(out_path, 'w') as f:
        f.write("// Generated initial block — paste into instruction_memory.v\n")
        f.write("initial begin\n")
        for pc, word, ann in words:
            f.write(f"    memory[{pc}] = 16'b{word:016b}; // {ann}\n")
        f.write("end\n")

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def assemble(source_path, out_path, fmt='mem'):
    with open(source_path, 'r') as f:
        source_lines = f.readlines()

    cleaned    = preprocess(source_lines)
    sym, instrs = pass1(cleaned)
    words      = pass2(instrs, sym)

    if fmt == 'mem':
        write_mem(words, out_path)
    elif fmt == 'hex':
        write_hex(words, out_path)
    elif fmt == 'vinit':
        write_verilog_init(words, out_path)
    else:
        raise ValueError(f"Unknown output format '{fmt}'.")

    print(f"Assembled {len(words)} instructions → {out_path}")
    print(f"Symbol table: {sym}")
    return words

def main():
    parser = argparse.ArgumentParser(description='CPU Assembler v1.0')
    parser.add_argument('input',  help='Assembly source file (.asm)')
    parser.add_argument('-o', '--output', required=True, help='Output file path')
    parser.add_argument('--format', choices=['mem', 'hex', 'vinit'], default='mem',
                        help='Output format: mem (binary), hex, vinit (Verilog init)')
    args = parser.parse_args()

    try:
        assemble(args.input, args.output, args.format)
    except AssemblerError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()