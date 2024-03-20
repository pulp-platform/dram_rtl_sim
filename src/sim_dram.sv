// Copyright 2023 ETH Zurich and
// University of Bologna

// Solderpad Hardware License
// Version 0.51, see LICENSE for details.

// SPDX-License-Identifier: SHL-0.51

// Author: Chi Zhang <chizhang@iis.ee.ethz.ch>, ETH Zurich
// Date: 07.June.2023

// dram model using dramsys library
import "DPI-C" function int add_dram(input string resources_path, input string simulationJson_path, input longint dram_base_addr);
import "DPI-C" function int dram_get_inflight_read(input int dram_id);
import "DPI-C" function int dram_can_accept_req(input int dram_id);
import "DPI-C" function int dram_has_write_rsp(input int dram_id);
import "DPI-C" function int dram_get_write_rsp(input int dram_id);
import "DPI-C" function int dram_has_read_rsp(input int dram_id);
import "DPI-C" function void dram_write_buffer(input int dram_id, input int byte_int, input int idx);
import "DPI-C" function void dram_write_strobe(input int dram_id, input int strob_int, input int idx);
import "DPI-C" function void dram_send_req(input int dram_id, input longint addr, input longint length , input longint is_write, input longint strob_enable);
import "DPI-C" function void dram_get_read_rsp(input int dram_id, input longint length, inout byte buffer[]);
import "DPI-C" function int dram_get_read_rsp_byte(input int dram_id);
import "DPI-C" function int dram_peek_read_rsp_byte(input int dram_id, input int idx);
import "DPI-C" function void dram_preload_byte(input int dram_id, input longint dram_addr_ofst, input int byte_int);
import "DPI-C" function int dram_check_byte(input int dram_id, input longint dram_addr_ofst);
import "DPI-C" function void dram_load_elf(input string app_path);
import "DPI-C" function void dram_load_memfile(input int dram_id, input longint addr_ofst, input string mem_path);
import "DPI-C" function void close_dram(input int dram_id);


module sim_dram #(
  parameter int unsigned DataWidth      = 32'd512,  // Data signal width
  parameter int unsigned AddrWidth      = 32'd64,    // Addr signal width
  parameter longint unsigned BASE       = 64'h80000000, // DRAM Base addr
  parameter              DRAMType       = "DDR4",   //DRAM type
  parameter              CustomerDRAM   = "none",   //DRAM type
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter type         addr_t         = logic [AddrWidth-1:0],
  parameter type         data_t         = logic [DataWidth-1:0],
  parameter type         strb_t         = logic [DataWidth/8-1:0]
)(
    input  logic                 clk_i,      // Clock
    input  logic                 rst_ni,     // Asynchronous reset active low
    // requests ports
    input  logic                 req_valid_i,// request valid
    output logic                 req_ready_o,// request ready
    input  logic                 we_i,       // write enable
    input  addr_t                addr_i,     // request address
    input  data_t                wdata_i,    // write data
    input  strb_t                wstrb_i,    // write strb
    // response ports
    output logic                 rsp_valid_o,
    input  logic                 rsp_ready_i,
    output data_t                rdata_o,     // read data
    // write response
    output logic                 b_valid_o,
    input  logic                 b_ready_i
);

typedef logic [7:0] my_byte_t;

int dram_id;

//initialize model (CTRL + DRAM)
initial begin
    string resources_path;
    string simulationJson_path;
    string app_path;
    string mem_path;
    void'($value$plusargs("DRAMSYS_RES=%s", resources_path));
    case (DRAMType)
        "DDR4":  simulationJson_path = {resources_path, "/ddr4-example.json"} ;
        "DDR3":  simulationJson_path = {resources_path, "/ddr3-example.json"};
        "HBM2":  simulationJson_path = {resources_path, "/hbm2-example.json"};
        "LPDDR4":  simulationJson_path = {resources_path, "/lpddr4-example.json"};
        default:  simulationJson_path = {resources_path, "/ddr4-example.json"};
    endcase

    if (CustomerDRAM != "none") begin
        simulationJson_path = {resources_path, "/", CustomerDRAM, ".json"};
        $display("[DRAMSys] Use Customer DRAM configuration: %s",simulationJson_path);
    end

    $display("[DRAMSys] resources_path=%s", resources_path);
    $display("[DRAMSys] simulationJson_path=%s", simulationJson_path);
    if (resources_path.len() == 0 || simulationJson_path.len() == 0) begin
        $fatal(1,"[DRAMSys] no DRAMsys configuration found!");
    end
    dram_id = add_dram(resources_path, simulationJson_path, BASE);
    void'($value$plusargs("ONE_DRAM_PRELOAD=%s", app_path));
    if (app_path.len() != 0) begin
        $display("[DRAMSys] Preloading elf: %s\n", app_path);
        dram_load_elf(app_path);
    end

    void'($value$plusargs("MEM=%s", mem_path));
    if (mem_path.len() != 0) begin
        $display("[DRAMSys] Preloading mem: %s\n", mem_path);
        dram_load_memfile(dram_id, 0, mem_path);
    end
end

//interface to manualy modify DRAM
task load_a_byte_to_dram(input longint dram_addr_ofst, input int data_byte );
    dram_preload_byte(dram_id, dram_addr_ofst, data_byte);
endtask

//interface to check a byte in DRAM
task check_a_byte_in_dram(input longint dram_addr_ofst, output logic[7:0] data_byte );
    automatic int byte_int;
    byte_int = dram_check_byte(dram_id, dram_addr_ofst);
    data_byte = byte_int;
endtask

//interface to manualy modify DRAM
task preload_elf_binary(input string elf_binary );
    dram_load_elf(elf_binary);
endtask

always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dram
    if(~rst_ni) begin
        req_ready_o <= 1'b0;
        rsp_valid_o <= 1'b0;
        b_valid_o <= 1'b0;
        rdata_o <= '0;
    end else begin
        // Default assignments
        rsp_valid_o <= 1'b0;
        b_valid_o <= 1'b0;
        req_ready_o <= 1'b0;

        // Request
        if (req_valid_i & req_ready_o) begin
            for (int i = 0; i < (DataWidth/8); i++) begin
                dram_write_buffer(dram_id, wdata_i[8*i +: 8], i);
                dram_write_strobe(dram_id, wstrb_i[i], i);
            end
            dram_send_req(dram_id, longint'(addr_i), (DataWidth/8), longint'(we_i), !(&wstrb_i) && we_i);
        end

        if (dram_can_accept_req(dram_id)) begin
            req_ready_o <= 1'b1;
        end

        // Read response
        if (rsp_valid_o & rsp_ready_i) begin
            for (int i = 0; i < (DataWidth/8); i++) begin
                void'(dram_get_read_rsp_byte(dram_id));
            end
        end

        if (dram_has_read_rsp(dram_id)) begin
            rsp_valid_o <= 1'b1;
            for (int i = 0; i < (DataWidth/8); i++) begin
                rdata_o[8*i +: 8] <= dram_peek_read_rsp_byte(dram_id, i);
            end
        end


        // Write response
        if (b_valid_o & b_ready_i) begin
            void'(dram_get_write_rsp(dram_id));
        end

        if (dram_has_write_rsp(dram_id)) begin
            b_valid_o <= 1;
        end
    end
end

final begin
    close_dram(dram_id);
end

endmodule : sim_dram
