# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Nils Wistoff <nwistoff@iis.ee.ethz.ch>

BENDER ?= bender
CMAKE ?= cmake
DRAM_RTL_SIM_ROOT ?= $(shell $(BENDER) path axi_dram_sim)
DRAMSYS_ROOT ?= $(DRAM_RTL_SIM_ROOT)/dramsys_lib/DRAMSys
DRAMSYS_BUILD_DIR ?= $(DRAMSYS_ROOT)/build

dramsys: $(DRAMSYS_BUILD_DIR)/lib/libsystemc.so

$(DRAMSYS_BUILD_DIR):
	mkdir -p $@

# Clone and patch DRAMSys
$(DRAMSYS_ROOT)/.patched:
	git clone https://github.com/tukl-msd/DRAMSys.git $(DRAMSYS_ROOT)
	cd $(DRAMSYS_ROOT) && git reset --hard 8e021ea && git apply $(DRAM_RTL_SIM_ROOT)/dramsys_lib/dramsys_lib_patch
	@touch $@

# Build DRAMSys
$(DRAMSYS_BUILD_DIR)/lib/libsystemc.so: $(DRAMSYS_ROOT)/.patched $(DRAMSYS_BUILD_DIR)
	cd $(DRAMSYS_BUILD_DIR) && $(CMAKE) -DCMAKE_CXX_FLAGS=-fPIC -DCMAKE_C_FLAGS=-fPIC -D DRAMSYS_WITH_DRAMPOWER=ON $(DRAMSYS_ROOT)
	$(MAKE) -C $(DRAMSYS_BUILD_DIR)
