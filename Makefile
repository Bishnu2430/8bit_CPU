# Makefile — Custom 8-bit RISC CPU
# Targets: sim (iverilog), verilator, asm, clean

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

SRC      = src/alu.v src/control_unit.v src/data_memory.v src/decoder.v \
           src/fetch_unit.v src/instruction_memory.v src/instruction_register.v \
           src/program_counter.v src/reg_file.v src/cpu_core.v

TB       = tb/cpu_core_tb.v
BUILD    = build
BIN      = $(BUILD)/cpu_test
VCD      = $(BUILD)/cpu_dump.vcd

.PHONY: all sim wave asm verilator clean

all: sim

$(BUILD):
	mkdir -p $(BUILD)

# ── Iverilog simulation ──────────────────────────────────────
$(BIN): $(SRC) $(TB) | $(BUILD)
	$(IVERILOG) -o $@ $(SRC) $(TB)

sim: $(BIN)
	cd $(BUILD) && ../$(BIN)

wave: $(VCD)
	$(GTKWAVE) $(VCD)

$(VCD): sim

# ── Assembler ────────────────────────────────────────────────
asm:
	python assembler.py example.asm \
	        -o $(BUILD)/example.mem
	python assembler.py example.asm \
	        -o $(BUILD)/example.hex --format hex
	python assembler.py example.asm \
	        -o $(BUILD)/example_init.v --format vinit

# ── Verilator simulation ─────────────────────────────────────
verilator:
	verilator --cc --exe --build -Isrc \
	          src/alu.v src/control_unit.v src/data_memory.v \
	          src/decoder.v src/fetch_unit.v src/instruction_memory.v \
	          src/instruction_register.v src/program_counter.v \
	          src/reg_file.v src/cpu_core_debug.v \
	          sim_main.cpp \
	          --top-module cpu_core_debug
	./obj_dir/Vcpu_core_debug

# ── Clean ────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD) obj_dir

help:
	@echo "Targets:"
	@echo "  make sim        — Compile and run iverilog simulation"
	@echo "  make wave       — Open VCD in GTKWave"
	@echo "  make asm        — Run assembler on example.asm"
	@echo "  make verilator  — Build and run Verilator C++ simulation"
	@echo "  make clean      — Remove build artifacts"