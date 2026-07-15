# 5-Stage Pipelined RISC-V Processor on iCESugar (iCE40UP5K)

A fully functional 5-stage pipelined RISC-V processor written in Verilog, synthesized and deployed on the MuseLab iCESugar v1.5 FPGA board using the open-source OSS CAD Suite toolchain.

**Simulation status: 17 / 17 tests passing**  
**FPGA status: Synthesizes, fits, programs, and runs on iCE40UP5K**

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Pipeline Stages](#pipeline-stages)
- [Supported Instructions](#supported-instructions)
- [Project Structure](#project-structure)
- [Toolchain & Prerequisites](#toolchain--prerequisites)
- [Build & Flash](#build--flash)
- [Simulation](#simulation)
- [FPGA Debug Interface](#fpga-debug-interface)
- [Key Engineering Decisions](#key-engineering-decisions)
- [Bugs Found & Fixed](#bugs-found--fixed)
- [Resource Utilization](#resource-utilization)
- [Future Work](#future-work)

---

## Architecture Overview

```
  ┌────┐   ┌────┐   ┌────┐   ┌─────┐   ┌────┐
  │ IF │──►│ ID │──►│ EX │──►│ MEM │──►│ WB │
  └────┘   └────┘   └────┘   └─────┘   └────┘
     ▲         │       ▲         │
     │   Hazard│  Forwarding     │
     │   Unit  │  Unit           │
     └─────────┴─────────────────┘
```

The processor implements the classic 5-stage RISC-V pipeline with:

- **Full data forwarding** — EX→EX and MEM→EX paths, eliminating most data hazards without stalling
- **Load-use hazard detection** — automatic 1-cycle stall when a load result is consumed by the immediately following instruction
- **Branch predictor** — 4-entry Branch Target Buffer (BTB) with 2-bit Bimodal History Table (BHT), flushing the pipeline on misprediction
- **UART debug interface** — streams PC and register values over USB serial for on-hardware inspection

---

## Pipeline Stages

| Stage | Module | Responsibility |
|-------|--------|----------------|
| **IF** | `PC.v`, `Instr_Mem_loop.v` | Fetch instruction at current PC; branch predictor predicts next PC |
| **ID** | `Reg_File.v`, `Control_Unit.v`, `Imm_Gen.v`, `ALU_Control.v` | Decode instruction, read registers, generate immediates and control signals |
| **EX** | `ALU.v`, `Forwarding_Unit.v` | Execute ALU operation with forwarded operands |
| **MEM** | `Data_Mem.v` | Load/store to data memory |
| **WB** | `MemWb.v` | Write ALU result or loaded value back to register file |

### Pipeline Registers

`IfId.v` → `IdEx.v` → `Ex_Mem.v` → `MemWb.v`

Each register carries the instruction's control signals and data fields forward through the pipeline. During a stall, `IfId` is frozen and `IdEx` is loaded with a bubble (all control signals zeroed, all register fields zeroed via `cntrl` gating).

---

## Supported Instructions

| Category | Instructions |
|----------|-------------|
| **R-type** | `add`, `sub`, `or`, `and` |
| **I-type** | `addi`, `lw` |
| **S-type** | `sw` |
| **B-type** | `beq` |

Instruction memory is word-addressed. All accesses are word-aligned (standard RISC-V base ISA).

---

## Project Structure

```
Pipelined-RISC-V/
├── src/
│   ├── Main_Module.v          # Top-level CPU integrating all stages
│   ├── PC.v                   # Program Counter with stall/flush control
│   ├── Instr_Mem_loop.v       # Instruction ROM (word-addressed, looping program)
│   ├── Reg_File.v             # 32×32-bit register file (x0 hardwired to 0)
│   ├── ALU.v                  # Arithmetic Logic Unit
│   ├── ALU_Control.v          # Maps funct3/funct7 + ALUOp → ALU control signal
│   ├── Control_Unit.v         # Main decode: generates all control signals
│   ├── Imm_Gen.v              # Immediate sign-extension (I/S/B types)
│   ├── Hazard_Detection_Unit.v # Load-use stall logic
│   ├── Forwarding_Unit.v      # EX-EX and MEM-EX forwarding mux selects
│   ├── Branch_Predictor.v     # 4-entry BTB + 2-bit BHT
│   ├── IfId.v                 # IF/ID pipeline register
│   ├── IdEx.v                 # ID/EX pipeline register
│   ├── Ex_Mem.v               # EX/MEM pipeline register
│   ├── MemWb.v                # MEM/WB pipeline register
│   └── Data_Mem.v             # Data memory (word-addressed, BRAM-friendly)
├── fpga/
│   ├── top.v                  # FPGA wrapper: clock, reset, LED, UART
│   ├── uart_tx.v              # UART transmitter (transport layer)
│   ├── debug_uart.v           # Debug formatter (PC / register output)
│   ├── icesugar.pcf           # Pin constraints for iCESugar v1.5
│   └── Makefile               # Yosys → nextpnr → icepack → icesprog
└── sim/
    ├── tb_PROC.v              # Self-checking testbench (17 tests)
    └── proc.vcd               # Last simulation waveform dump
```

---

## Toolchain & Prerequisites

### OSS CAD Suite (recommended — bundles everything)

Download from [https://github.com/YosysHQ/oss-cad-suite-build/releases](https://github.com/YosysHQ/oss-cad-suite-build/releases) and add to PATH.

Included tools used by this project:

| Tool | Purpose |
|------|---------|
| `yosys` | RTL synthesis |
| `nextpnr-ice40` | Place & route for iCE40 |
| `icepack` | Bitstream packing |
| `icesprog` | Flash programming for iCESugar (CMSIS-DAP) |
| `iverilog` / `vvp` | Simulation |

> **Important:** iCESugar uses a **CMSIS-DAP** programmer. Use `icesprog`, **not** `iceprog`. Using the wrong tool causes silent programming failures where the board continues running the previous design.

---

## Build & Flash

```bash
# From the fpga/ directory

# Full build + flash in one step
make

# Or step by step:
make synth      # Yosys synthesis  → top.json
make pnr        # nextpnr-ice40   → top.asc
make pack       # icepack          → top.bin
make flash      # icesprog         → programs the board
```

### Makefile targets

```makefile
DEVICE  = up5k
PACKAGE = sg48
TOP     = top
PCF     = icesugar.pcf
```

The synthesis flow uses `synth_ice40 -top top` with BRAM inference enabled (default). With word-addressed memories, the design fits comfortably within the UP5K's 5,280 LUTs.

---

## Simulation

```bash
# From the sim/ directory (requires iverilog)
iverilog -o proc_sim tb_PROC.v ../src/*.v
vvp proc_sim

# With waveform dump
vvp proc_sim
gtkwave proc.vcd
```

The self-checking testbench validates 17 scenarios including:

- `x0` always-zero protection
- ALU operations (add, sub, or, and, addi)
- Load/store correctness
- Load-use hazard stalling
- EX→EX and MEM→EX forwarding
- Branch taken / not-taken
- Back-to-back dependent instructions

---

## FPGA Debug Interface

The FPGA wrapper exposes two debug mechanisms:

**RGB LEDs** — The lower 3 bits of a selected register drive the onboard RGB LED, providing a visual indicator that the CPU is running and producing results.

**UART over USB** — `debug_uart.v` formats and streams debug output at a configurable baud rate through the iCESugar's built-in USB-serial bridge (no external hardware needed). Currently streams the program counter:

```
PC=00000000
PC=00000004
PC=00000008
...
```

Connect any serial terminal at the configured baud rate to the iCESugar's COM port.

---

## Key Engineering Decisions

### Word-Addressed Memory (critical for FPGA fit)

The original byte-addressed data memory used the pattern:

```verilog
// DO NOT USE — prevents BRAM inference, causes LUT explosion
d_mem[addr]   <= wr_data[7:0];
d_mem[addr+1] <= wr_data[15:8];
d_mem[addr+2] <= wr_data[23:16];
d_mem[addr+3] <= wr_data[31:24];
```

This creates four simultaneous write ports to four different dynamic addresses in a single clock cycle — a pattern no FPGA RAM primitive supports. Yosys was forced to flatten all 1,024 bytes into individual flip-flops, each with four 32-bit address comparators for write-enable decode. This produced ~50,000 SB_LUT4s from data memory alone, far exceeding the UP5K's 5,280 LUT budget.

The fix converts both memories to **word-addressed** with a **single write port**:

```verilog
// Data memory — word-addressed, BRAM-inferrable
reg [31:0] d_mem [0:255];         // 256 words = 1024 bytes

always @(posedge clk)
    if (mem_write) d_mem[addr[9:2]] <= wr_data;  // single write port

always @(*)
    rd_data = mem_read ? d_mem[addr[9:2]] : 32'b0;
```

```verilog
// Instruction ROM — word-addressed
reg [31:0] i_mem [0:63];          // 64 words = 256 bytes

assign instr = i_mem[PC[7:2]];   // single read port, no offset arithmetic
```

This reduced LUT usage by over 42,000 and allowed the design to fit on the UP5K.

### Stall Bubble Hygiene

When the hazard detection unit inserts a stall bubble, `id_control_sig` is zeroed to prevent any register write or memory access. However, `id_rs1`, `id_rs2`, and `id_rd` were still sourced from the frozen `IfId` register, causing the forwarding unit to fire falsely on the bubble.

The fix gates all three register fields through `cntrl` at the `IdEx` instantiation in `Main_Module.v`:

```verilog
.id_rs1(cntrl ? id_rs1 : 5'b0),
.id_rs2(cntrl ? id_rs2 : 5'b0),
.id_rd (cntrl ? id_rd  : 5'b0),
```

This makes the bubble fully clean (zero control signals + zero register fields), matching what a flush already does explicitly.

### Separated ALU Control Encodings

The ALU control module originally used the same numeric constants as both RISC-V `funct` field values (case labels) and internal ALU operation codes. For `add`, the RISC-V encoding `{funct7[5], funct3} = 4'b0000` matched the `AND` case label, causing `add` to execute as bitwise AND.

The fix uses two distinct sets of localparams with separate prefixes:

```verilog
// RISC-V funct field encodings (case labels)
localparam [3:0] RV_ADD = 4'b0000, RV_SUB = 4'b1000,
                 RV_OR  = 4'b0110, RV_AND = 4'b0111;

// Internal ALU operation codes (outputs, must match ALU.v)
localparam [3:0] ALU_AND = 4'b0000, ALU_OR  = 4'b0001,
                 ALU_ADD = 4'b0010, ALU_SUB = 4'b0110;
```

---

## Bugs Found & Fixed

| # | Bug | Symptom | Root Cause | Fix |
|---|-----|---------|------------|-----|
| 1 | LUT explosion | ~54,000 LUTs synthesized (10× over budget) | Byte-offset writes in data memory created 4 dynamic write ports; yosys flattened to flip-flops with per-bit write-enable decode | Converted both memories to word-addressed with single write port |
| 2 | ALU control misdecode | `add x3, x2, x1` → x3=5 instead of 10; `or` executed as `sub` | ALU opcode constants reused as RISC-V `funct` case labels — different encoding schemes collided numerically | Separated `RV_*` and `ALU_*` localparam namespaces |
| 3 | False forwarding on stall bubble | Forwarding unit fired on bubble cycle; fragile but harmless in practice | `IdEx` received live rs1/rs2/rd from frozen `IfId` even when control signals were zeroed | Gated rs1/rs2/rd through `cntrl` at `IdEx` port connections |
| 4 | Silent programming failure | Board ran old LED blink design after `make flash` | Wrong programmer: `iceprog` does not support CMSIS-DAP (iCESugar's interface) | Switched to `icesprog` |
| 5 | Large PC values over UART | UART showed seemingly random large PC numbers | CPU executed millions of cycles between each timed UART snapshot; not a CPU bug | Expected behavior; UART infrastructure confirmed correct |

---

## Resource Utilization

After BRAM-friendly memory conversion (iCE40UP5K, synth_ice40):

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| SB_LUT4 | ~1,300 | 5,280 | ~25% |
| SB_DFFE/DFF | ~1,200 | 5,280 | ~23% |
| ICESTORM_RAM | 2 | 30 | ~7% |

*Before the fix: ~54,184 SB_LUT4 (10× over budget — does not fit).*

---

## Future Work

- `debug_monitor.v` — unified debug module combining:
  - Instruction tracing (PC + disassembled opcode over UART)
  - Register writeback logging
  - Memory access tracing (address + data for loads/stores)
  - Hazard event tracing (stall cycles, flush events)
  - Branch predictor accuracy visualization
- UART simulation testbench (currently only verified on hardware)
- Extend ISA: `jalr`, `jal`, `lui`, `auipc`, `slti`, `sltiu`
- SB_RAM40_4K async-read mode for register file (eliminating read-mux LUTs)
- Formal verification of the forwarding and hazard unit interaction

---

## Board

**MuseLab iCESugar v1.5** — iCE40UP5K-SG48, 12 MHz oscillator, onboard RGB LED, USB-serial bridge (CMSIS-DAP), PMOD expansion headers.

## Author

Aditya Varshney