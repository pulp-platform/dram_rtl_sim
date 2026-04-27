# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Chi Zhang <chizhang@iis.ee.ethz.ch>

BENDER ?= bender
QUESTA ?= questa
CMAKE ?= cmake



VLOG_ARGS = -svinputport=compat -override_timescale 1ns/1ps -suppress 2583 -suppress 13314
library ?= work
top_level ?= axi_to_dram_tb

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

all: compile
	cd vsim && $(QUESTA) vsim -c $(library).$(top_level) -t 1ps -voptargs=+acc $(questa_args) -do start.tcl

gui: compile
	cd vsim && $(QUESTA) vsim $(library).$(top_level) -t 1ps -voptargs=+acc $(questa_args) -do start.tcl

compile: vsim/compile.tcl dramsys
	echo "exit" >> vsim/compile.tcl
	cd vsim && $(QUESTA) vsim -c -do compile.tcl

vsim/compile.tcl: Bender.yml Makefile $(shell find src -type f) $(shell find test -type f) 
	$(BENDER) script vsim -t test -t rtl --vlog-arg="$(VLOG_ARGS)" > $@

clean: dramsys-clean
	cd vsim && rm -rf work/ vsim*  transcript  modelsim.ini compile.tcl .nfs* DRAM*
