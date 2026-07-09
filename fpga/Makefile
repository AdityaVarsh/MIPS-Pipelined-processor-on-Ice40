ORIG = ../Pipelined_RISCV

PROJECT = cpu

SRCS = \
    main_fpga.v \
    Data_Mem_fpga.v \
    $(ORIG)/ALU.v \
    $(ORIG)/ALU_Control.v \
    $(ORIG)/Branch_Predictor.v \
    $(ORIG)/Control_Unit.v \
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