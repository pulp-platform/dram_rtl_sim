// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Full-bandwidth AXI4 to AXI4-Lite converter for single-beat traffic.
//
// Replaces axi_to_axi_lite in front of sim_dram. axi_to_axi_lite routes every
// transaction through axi_burst_splitter, whose id_queue (FULL_BW = 0) serves
// either an AR allocation or an R lookup per cycle, capping reads at one every
// two cycles. Traffic into the DRAM model is single-beat only, so no splitting
// is needed: AR/AW/W pass straight through, and the AXI IDs are reflected onto
// R/B through one FIFO per direction. This relies on the DRAM model returning
// reads in read order and writes in write order, which dramsys_conv does.
//
// User bits are not handled here; axi_dram_sim restores them separately.

module axi_single_beat_to_lite #(
  /// AXI ID width
  parameter int unsigned AxiIdWidth  = 32'd0,
  /// Outstanding reads and outstanding writes, each
  parameter int unsigned MaxTxns     = 32'd128,
  /// AXI4 request/response types (slave side)
  parameter type         full_req_t  = logic,
  parameter type         full_resp_t = logic,
  /// AXI4-Lite request/response types (master side)
  parameter type         lite_req_t  = logic,
  parameter type         lite_resp_t = logic
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  full_req_t  slv_req_i,
  output full_resp_t slv_resp_o,
  output lite_req_t  mst_req_o,
  input  lite_resp_t mst_resp_i
);

  typedef logic [AxiIdWidth-1:0] id_t;

  logic r_id_full, r_id_empty, b_id_full, b_id_empty;
  id_t  r_id, b_id;
  logic ar_hs, r_hs, aw_hs, b_hs;

  // A new AR/AW is only taken while its ID can be stored for the response,
  // and a response is only passed on while an ID is waiting for it, as in
  // axi_to_axi_lite_id_reflect
  always_comb begin
    mst_req_o  = '0;
    slv_resp_o = '0;

    mst_req_o.ar.addr     = slv_req_i.ar.addr;
    mst_req_o.ar.prot     = slv_req_i.ar.prot;
    mst_req_o.ar_valid    = slv_req_i.ar_valid & ~r_id_full;
    slv_resp_o.ar_ready   = mst_resp_i.ar_ready & ~r_id_full;

    slv_resp_o.r.id       = r_id;
    slv_resp_o.r.data     = mst_resp_i.r.data;
    slv_resp_o.r.resp     = mst_resp_i.r.resp;
    slv_resp_o.r.last     = 1'b1;
    slv_resp_o.r_valid    = mst_resp_i.r_valid & ~r_id_empty;
    mst_req_o.r_ready     = slv_req_i.r_ready & ~r_id_empty;

    mst_req_o.aw.addr     = slv_req_i.aw.addr;
    mst_req_o.aw.prot     = slv_req_i.aw.prot;
    mst_req_o.aw_valid    = slv_req_i.aw_valid & ~b_id_full;
    slv_resp_o.aw_ready   = mst_resp_i.aw_ready & ~b_id_full;

    mst_req_o.w.data      = slv_req_i.w.data;
    mst_req_o.w.strb      = slv_req_i.w.strb;
    mst_req_o.w_valid     = slv_req_i.w_valid & ~b_id_full;
    slv_resp_o.w_ready    = mst_resp_i.w_ready & ~b_id_full;

    slv_resp_o.b.id       = b_id;
    slv_resp_o.b.resp     = mst_resp_i.b.resp;
    slv_resp_o.b_valid    = mst_resp_i.b_valid & ~b_id_empty;
    mst_req_o.b_ready     = slv_req_i.b_ready & ~b_id_empty;
  end

  assign ar_hs = slv_req_i.ar_valid & slv_resp_o.ar_ready;
  assign r_hs  = slv_resp_o.r_valid & slv_req_i.r_ready;
  assign aw_hs = slv_req_i.aw_valid & slv_resp_o.aw_ready;
  assign b_hs  = slv_resp_o.b_valid & slv_req_i.b_ready;

  fifo_v3 #(
    .FALL_THROUGH ( 1'b0       ),
    .DATA_WIDTH   ( AxiIdWidth ),
    .DEPTH        ( MaxTxns    )
  ) i_r_id_fifo (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0                 ),
    .testmode_i ( 1'b0                 ),
    .full_o     ( r_id_full            ),
    .empty_o    ( r_id_empty           ),
    .usage_o    (                      ),
    .data_i     ( slv_req_i.ar.id      ),
    .push_i     ( ar_hs                ),
    .data_o     ( r_id                 ),
    .pop_i      ( r_hs                 )
  );

  fifo_v3 #(
    .FALL_THROUGH ( 1'b0       ),
    .DATA_WIDTH   ( AxiIdWidth ),
    .DEPTH        ( MaxTxns    )
  ) i_b_id_fifo (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0                 ),
    .testmode_i ( 1'b0                 ),
    .full_o     ( b_id_full            ),
    .empty_o    ( b_id_empty           ),
    .usage_o    (                      ),
    .data_i     ( slv_req_i.aw.id      ),
    .push_i     ( aw_hs                ),
    .data_o     ( b_id                 ),
    .pop_i      ( b_hs                 )
  );

  // Bursts are not supported: every transaction must be a single beat
`ifndef SYNTHESIS
  ar_single_beat: assert property (@(posedge clk_i) disable iff (!rst_ni)
    slv_req_i.ar_valid |-> (slv_req_i.ar.len == '0)) else $error("AR burst not supported");
  aw_single_beat: assert property (@(posedge clk_i) disable iff (!rst_ni)
    slv_req_i.aw_valid |-> (slv_req_i.aw.len == '0)) else $error("AW burst not supported");
  w_single_beat: assert property (@(posedge clk_i) disable iff (!rst_ni)
    slv_req_i.w_valid |-> slv_req_i.w.last) else $error("W burst not supported");
`endif

endmodule
