ORIG = ../Pipelined_RISCV

PROJECT = cpu

ORIG = ../Pipelined_RISCV

PROJECT = top

SRCS = \
    top.v \
    debug_uart.v \
    uart_tx.v \
    main_fpga.v \
    Data_Mem_fpga.v \
    $(ORIG)/ALU.v \
    $(ORIG)/ALU_Control.v \
    $(ORIG)/Branch_Predictor.v \
    $(ORIG)/Control_Unit.v \
    $(ORIG)/Data_Memory_Controller.v \
    $(ORIG)/Ex_Mem.v \
    $(ORIG)/Forwarding_Unit.v \
    $(ORIG)/Hazard_Detection_Unit.v \
    $(ORIG)/IdEx.v \
    $(ORIG)/IfId.v \
    $(ORIG)/Imm_Gen.v \
    $(ORIG)/Instr_Mem_loop.v \
    $(ORIG)/MemWb.v \
    $(ORIG)/PC.v \
    $(ORIG)/Reg_File.v

all:
	yosys -p "synth_ice40 -top top -json $(PROJECT).json" $(SRCS)
	nextpnr-ice40 --up5k --package sg48 --pcf icesugar.pcf --json $(PROJECT).json --asc $(PROJECT).asc
	icepack $(PROJECT).asc $(PROJECT).bin

flash:
	icesprog -w $(PROJECT).bin

clean:
	del /Q *.json *.asc *.bin *.log 2>nul