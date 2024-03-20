// Copyright 2023 ETH Zurich and
// University of Bologna

// Solderpad Hardware License
// Version 0.51, see LICENSE for details.

// SPDX-License-Identifier: SHL-0.51

// Author: Chi Zhang <chizhang@iis.ee.ethz.ch>, ETH Zurich
// Date: 07.June.2023


import "DPI-C" function void run_ns(input int ns);

// clock engine for dram simulation
module dram_sim_engine #(
	parameter time ClkPeriod	= 1ns
) (
	input logic clk_i,	// Clock
	input logic rst_ni	// Asynchronous reset active low
);

	always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dram_engine
		if(rst_ni) begin
			// run DRAMsys every clk
			run_ns(int'(ClkPeriod / 1ns));
		end
	end

endmodule : dram_sim_engine
