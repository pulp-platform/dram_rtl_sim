# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Chi Zhang <chizhang@iis.ee.ethz.ch>

BENDER ?= bender
VLOG_ARGS = -svinputport=compat -override_timescale 1ns/1ps -suppress 2583 -suppress 13314
top_level ?= axi_to_dram_tb
# DRAM model for the parametrized testbench, passed as an elaboration generic.
DRAMType ?= DDR4
# DRAM models swept by `make test-all-drams`.
DRAM_TYPES ?= DDR3 DDR4 LPDDR4 HBM2

DRAM_RTL_SIM_ROOT = $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

# Recipes to build DRAMSys
include dram_rtl_sim.mk

# Path to DRAMsyslib
dramsys_resouces_path ?= ../dramsys_lib/DRAMSys/configs
dramsys_lib_path ?= ../dramsys_lib/DRAMSys/build/lib
# QuestaSim arguments
questa_args    ?=
questa_args += +DRAMSYS_RES=$(dramsys_resouces_path)
questa_args += -sv_lib $(dramsys_lib_path)/libsystemc
questa_args += -sv_lib $(dramsys_lib_path)/libDRAMSys_Simulator

check_transcript = grep -qE '^\# Errors: 0, Warnings: 0$$' vsim/transcript || \
	{ echo "FAIL: QuestaSim reported errors/warnings, see vsim/transcript"; exit 1; }

all: compile
	cd vsim && questa vsim -c work.$(top_level) -gDRAMType=$(DRAMType) -t 1ps -voptargs=+acc $(questa_args) -do start.tcl
	@$(check_transcript)

gui: compile
	cd vsim && questa vsim work.$(top_level) -gDRAMType=$(DRAMType) -t 1ps -voptargs=+acc $(questa_args) -do start.tcl

# Run the parametrized testbench once per DRAM model in $(DRAM_TYPES).
test-all-drams: compile
	@for dt in $(DRAM_TYPES); do \
		echo "==================== DRAMType=$$dt ===================="; \
		( cd vsim && questa vsim -c work.$(top_level) -gDRAMType=$$dt -t 1ps -voptargs=+acc $(questa_args) -do start.tcl ) || exit 1; \
		$(check_transcript); \
	done

compile: vsim/compile.tcl
	echo "exit" >> vsim/compile.tcl
	cd vsim && questa vsim -c -do compile.tcl

vsim/compile.tcl: Bender.yml Makefile $(shell find src -type f) $(shell find test -type f) 
	$(BENDER) script vsim -t test -t rtl --vlog-arg="$(VLOG_ARGS)" > $@

clean:
	cd vsim && rm -rf work/ vsim*  transcript  modelsim.ini compile.tcl .nfs* DRAM*
