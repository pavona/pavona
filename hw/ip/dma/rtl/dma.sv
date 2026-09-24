// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module dma
  import tlul_pkg::*;
  import dma_pkg::*;
  import dma_reg_pkg::*;
#(
    parameter logic [NumAlerts-1:0] AlertAsyncOn = {NumAlerts{1'b1}},
    // Number of cycles of differential skew to be tolerated on the alert signal
    parameter int unsigned AlertSkewCycles = 1,
    parameter bit EnableDataIntgGen = 1'b1,
    parameter bit EnableRspDataIntgCheck = 1'b1,
    parameter bit EnableRacl = 1'b0,
    parameter bit RaclErrorRsp = EnableRacl,
    parameter top_racl_pkg::racl_policy_sel_t RaclPolicySelVec[NumRegs] = '{NumRegs{0}},
    // Generic host port descriptor. `NumPorts` and the `PortDesc` array default to the
    // `dma_pkg` values and can be overridden together at the top level.
    parameter int unsigned NumPorts = dma_pkg::NumPortsDefault,
    parameter dma_pkg::dma_port_desc_t PortDesc[NumPorts] = dma_pkg::DmaPortDesc,
    // Per-class host port counts; size the boundary port vectors and let topgen size the
    // matching top-level nets. On override they are supplied in lock-step (checked below).
    parameter int unsigned NumTlul32 = dma_pkg::NumTlul32Default,
    parameter int unsigned NumTlul64 = dma_pkg::NumTlul64Default,
    // Inline-AES build options. SecAesMasking=0 ties off the masking PRNG/EDN (non-production, faster
    // DV); SecAllowForcingMasks=1 allows force_masks for DV.
    parameter bit SecAesMasking = 1'b1,
    parameter bit SecAllowForcingMasks = 1'b0,
    // Secure netlist constants for the inline-AES clearing/masking PRNGs, threaded down into aes_core
    // so the seeds/permutations are per-tapeout random, not fixed defaults. topgen drives them.
    parameter aes_pkg::clearing_lfsr_seed_t   RndCnstClearingLfsrSeed   =
      aes_pkg::RndCnstClearingLfsrSeedDefault,
    parameter aes_pkg::clearing_lfsr_perm_t   RndCnstClearingLfsrPerm   =
      aes_pkg::RndCnstClearingLfsrPermDefault,
    parameter aes_pkg::clearing_lfsr_perm_t   RndCnstClearingSharePerm  =
      aes_pkg::RndCnstClearingSharePermDefault,
    parameter aes_pkg::masking_lfsr_seed_t    RndCnstMaskingLfsrSeed    =
      aes_pkg::RndCnstMaskingLfsrSeedDefault,
    parameter aes_pkg::masking_lfsr_perm_t    RndCnstMaskingLfsrPerm    =
      aes_pkg::RndCnstMaskingLfsrPermDefault
) (
    input  logic                                                              clk_i,
    input  logic                                                              rst_ni,
    input  prim_mubi_pkg::mubi4_t                                             scanmode_i,
    // DMA interrupts and incoming LSIO triggers
    output logic                                                              intr_dma_done_o,
    output logic                                                              intr_dma_chunk_done_o,
    output logic                                                              intr_dma_error_o,
    input  lsio_trigger_t                                                     lsio_trigger_i,
    // Alerts
    input  prim_alert_pkg::alert_rx_t      [                   NumAlerts-1:0] alert_rx_i,
    output prim_alert_pkg::alert_tx_t      [                   NumAlerts-1:0] alert_tx_o,
    // RACL interface
    input  top_racl_pkg::racl_policy_vec_t                                    racl_policies_i,
    output top_racl_pkg::racl_error_log_t                                     racl_error_o,
    // Device port
    input  tlul_pkg::tl_h2d_t                                                 tl_d_i,
    output tlul_pkg::tl_d2h_t                                                 tl_d_o,
    // 32-bit TLUL host ports; xbar-vs-p2p routing is resolved at the top level. Width is
    // clamped to >= 1 so a zero count yields a single tied-off placeholder port.
    output tlul_pkg::tl_h2d_t              [dma_pkg::dma_max1(NumTlul32)-1:0] host32_tl_h_o,
    input  tlul_pkg::tl_d2h_t              [dma_pkg::dma_max1(NumTlul32)-1:0] host32_tl_h_i,
    // 64-bit TLUL host ports (off-bus, point-to-point)
    output dma_tlul_pkg::dma_tl_h2d_t      [dma_pkg::dma_max1(NumTlul64)-1:0] host64_h2d_o,
    input  tlul_pkg::tl_d2h_t              [dma_pkg::dma_max1(NumTlul64)-1:0] host64_d2h_i,
    // Inline AES: EDN entropy (separate clock domain), keymgr sideload key, LC escalation.
    input  logic                                                              clk_edn_i,
    input  logic                                                              rst_edn_ni,
    output edn_pkg::edn_req_t                                                 edn_o,
    input  edn_pkg::edn_rsp_t                                                 edn_i,
    input  keymgr_pkg::hw_key_req_t                                           keymgr_key_i,
    input  lc_ctrl_pkg::lc_tx_t                                               lc_escalate_en_i
);
  import prim_mubi_pkg::*;
  import prim_sha2_pkg::*;

  dma_reg2hw_t reg2hw;
  dma_hw2reg_t hw2reg;

  localparam int unsigned TRANSFER_BYTES_WIDTH = $bits(reg2hw.total_data_size.q);
  localparam int unsigned INTR_CLEAR_SOURCES_WIDTH = $clog2(NumIntClearSources);
  localparam int unsigned NR_SHA_DIGEST_ELEMENTS = 16;

  // Port-index width derived from the (possibly-overridden) module `NumPorts`, rather than
  // dma_pkg::DmaPortIdxW which is fixed to the package-default port count.
  localparam int unsigned PortIdxW = prim_util_pkg::vbits(NumPorts);

  // Module-local descriptor helpers indexing the module parameter `PortDesc` directly so
  // they constant-fold in generate/`ASSERT_INIT` contexts (the `dma_pkg` versions take an
  // open array and serve block-level DV on the package-default descriptor).
  function automatic int unsigned dma_count_class_local(dma_pkg::dma_port_class_e cls);
    dma_count_class_local = 0;
    for (int unsigned i = 0; i < NumPorts; i++) begin
      if (PortDesc[i].cls == cls) dma_count_class_local = dma_count_class_local + 1;
    end
  endfunction

  function automatic int unsigned dma_class_subidx_local(int unsigned p);
    dma_class_subidx_local = 0;
    for (int unsigned i = 0; i < p; i++) begin
      if (PortDesc[i].cls == PortDesc[p].cls) dma_class_subidx_local = dma_class_subidx_local + 1;
    end
  endfunction

  // Count descriptor matches to reject ambiguous ASID assignments at elaboration.
  function automatic int unsigned dma_count_asid_local(dma_pkg::asid_encoding_e asid);
    dma_count_asid_local = 0;
    for (int unsigned i = 0; i < NumPorts; i++) begin
      if (PortDesc[i].asid == asid) dma_count_asid_local = dma_count_asid_local + 1;
    end
  endfunction

  // Unified per-port signals feeding the class-agnostic FSM. The generate loop below
  // routes each port to its boundary array (32-bit or 64-bit) by its descriptor class.
  logic [NumPorts-1:0] port_req, port_we, port_gnt;
  logic [NumPorts-1:0] port_rvalid, port_err, port_intg_err;
  logic [NumPorts-1:0][DMA_ADDR_WIDTH-1:0] port_addr;
  logic [NumPorts-1:0][top_pkg::TL_DW-1:0] port_wdata, port_rdata;
  logic [NumPorts-1:0][top_pkg::TL_DBW-1:0] port_be;

  // Aggregated TL-UL response integrity error (OR-reduced over all host ports).
  logic                                     dma_tlul_rsp_intg_err;

  // Unified interrupt-clear trigger (resolved index selects the target port).
  logic                                     dma_clear_intr;

  logic                                     capture_return_data;
  logic [top_pkg::TL_DW-1:0] read_return_data_q, read_return_data_d, dma_rsp_data;
  logic [DMA_ADDR_WIDTH-1:0] new_src_addr, new_dst_addr;

  // -------------------------------------------------------------------------------------------
  // Read-ahead burst datapath (fast path for plain copies over TL-UL ports)
  // -------------------------------------------------------------------------------------------
  // A burst of back-to-back reads is issued into the data FIFO (only reads are outstanding, so
  // their responses are unambiguous), then drained as back-to-back writes. This keeps multiple
  // reads in flight and hides memory/bus read latency. Active only when fast_mode_q is set.
  localparam int unsigned BURST_CNT_W = $clog2(DMA_BURST_FIFO_DEPTH + 1);

  logic fast_mode_q, fast_mode_d, capture_fast_mode;

  // Read-issue byte position (writes reuse transfer_byte_q for completion accounting).
  logic [TRANSFER_BYTES_WIDTH-1:0] rd_byte_q, rd_byte_d;
  logic capture_rd_byte;

  // Outstanding read / write request counters for the burst datapath.
  logic [BURST_CNT_W-1:0] rd_outstanding_q, rd_outstanding_d;
  logic [BURST_CNT_W-1:0] wr_outstanding_q, wr_outstanding_d;

  // Per-TL-UL-port outstanding-transaction counters (count ALL accepted requests - reads,
  // writes and interrupt-clear writes - minus their responses). These guarantee that a new
  // transfer is not started while responses from a prior aborted/errored transfer are still
  // in flight; otherwise those stale responses would be consumed by - and corrupt - the next
  // transfer. Width holds up to NUM_MAX_OUTSTANDING_REQS in flight with margin.
  localparam int unsigned PORT_OUTST_W = $clog2(NUM_MAX_OUTSTANDING_REQS + 2);
  logic [NumPorts-1:0][PORT_OUTST_W-1:0] port_outst_q, port_outst_d;
  logic dma_drained;
  logic abort_complete;

  // Per-beat metadata FIFO (pushed at read issue, popped at read response to steer + form the
  // data FIFO entry) and the data FIFO (pushed at read response, popped at write issue).
  typedef struct packed {
    logic [DMA_ADDR_WIDTH-1:0]  dst_addr;
    logic [top_pkg::TL_DBW-1:0] dst_be;
    logic [top_pkg::TL_DBW-1:0] src_be;
    logic [2:0]                 width;
  } dma_burst_meta_t;
  typedef struct packed {
    logic [top_pkg::TL_DW-1:0]  data;
    logic [DMA_ADDR_WIDTH-1:0]  dst_addr;
    logic [top_pkg::TL_DBW-1:0] dst_be;
  } dma_burst_data_t;

  dma_burst_meta_t meta_wdata, meta_rdata;
  logic meta_wvalid, meta_wready, meta_rvalid, meta_rready;
  dma_burst_data_t data_wdata, data_rdata;
  logic data_wvalid, data_wready, data_rvalid, data_rready;
  logic [BURST_CNT_W-1:0] data_depth;
  logic meta_fifo_err, data_fifo_err;  // FIFO over/underflow (-> fatal alert)

  // Burst control / unified bus-request intent (shared by serial and burst datapaths).
  logic burst_rd_issue, burst_wr_issue;
  logic rd_issue, wr_issue;
  logic [DMA_ADDR_WIDTH-1:0] rd_issue_addr, wr_issue_addr;
  logic [top_pkg::TL_DBW-1:0] rd_issue_be, wr_issue_be;
  logic [top_pkg::TL_DW-1:0] wr_issue_data;
  logic [top_pkg::TL_DW-1:0] burst_steered_data;

  logic dma_state_error;
  logic aes_session_q;
  // SEC_CM: FSM.SPARSE
  dma_ctrl_state_e ctrl_state_q, ctrl_state_d;
  logic set_error_code, clear_go, clear_status, clear_sha_status, chunk_done;

  logic [INTR_CLEAR_SOURCES_WIDTH-1:0] clear_index_d, clear_index_q;
  logic clear_index_en, intr_clear_tlul_rsp_valid;
  logic intr_clear_tlul_gnt, intr_clear_tlul_rsp_error;

  logic [DmaErrLast-1:0] next_error;

  // Read request grant
  logic read_gnt;
  // Read response
  logic read_rsp_valid;
  // Read error occurred
  //   (Note: in use `read_rsp_error` must be qualified with `read_rsp_valid`)
  logic read_rsp_error;

  // Write request grant
  logic write_gnt;
  // Write response
  logic write_rsp_valid;
  // Write error occurred
  //   (Note: in use `write_rsp_error` must be qualified with `write_rsp_valid`)
  logic write_rsp_error;

  logic cfg_abort_en;
  assign cfg_abort_en = reg2hw.control.abort.q;

  logic cfg_handshake_en;

  // Decode scan mode enable MuBi signal.
  logic scanmode;
  assign scanmode = mubi4_test_true_strict(scanmode_i);

  logic sw_reg_wr, sw_reg_wr1, sw_reg_wr2;
  assign sw_reg_wr = reg2hw.control.go.qe;
  prim_flop #(
      .Width(1)
  ) aff_reg_wr1 (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .d_i   (sw_reg_wr),
      .q_o   (sw_reg_wr1)
  );
  prim_flop #(
      .Width(1)
  ) aff_reg_wr2 (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .d_i   (sw_reg_wr1),
      .q_o   (sw_reg_wr2)
  );

  // Stretch out CR writes to make sure new value can propagate through logic
  logic sw_reg_wr_extended;
  assign sw_reg_wr_extended = sw_reg_wr || sw_reg_wr1 || sw_reg_wr2;

  logic gated_clk_en, gated_clk;
  assign gated_clk_en = reg2hw.control.go.q       ||
                        (ctrl_state_q != DmaIdle) ||
                        aes_session_q              ||
                        sw_reg_wr_extended         ||
      // Keep the core clocked while any TL-UL transaction is still
      // outstanding so that late responses (e.g. from an aborted/errored
      // transfer) are always accounted for and drained, never missed.
      (|port_outst_q);

  prim_clock_gating #(
      .FpgaBufGlobal(1'b0)  // Instantiate a local instead of a global clock buffer on FPGAs
  ) dma_clk_gate (
      .clk_i    (clk_i),
      .en_i     (gated_clk_en),
      .test_en_i(scanmode),      ///< Test On to turn off the clock gating during test
      .clk_o    (gated_clk)
  );

  logic reg_intg_error;
  // SEC_CM: BUS.INTEGRITY
  // SEC_CM: RANGE.CONFIG.REGWEN_MUBI
  dma_reg_top #(
      .EnableRacl      (EnableRacl),
      .RaclErrorRsp    (RaclErrorRsp),
      .RaclPolicySelVec(RaclPolicySelVec)
  ) u_dma_reg (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .tl_i      (tl_d_i),
      .tl_o      (tl_d_o),
      .reg2hw,
      .hw2reg,
      .racl_policies_i,
      .racl_error_o,
      .intg_err_o(reg_intg_error)
  );

  // Inline AES wrapper status/alert signals (driven by u_dma_aes below).
  logic aes_alert_recov;
  logic aes_alert_fatal;
  logic aes_tag_mismatch_set;

  // Alerts
  logic [NumAlerts-1:0] alert_test, alerts;
  assign alert_test[AlertFatalFaultIdx] =
      reg2hw.alert_test.fatal_fault.q & reg2hw.alert_test.fatal_fault.qe;
  assign alert_test[AlertRecovFaultIdx] =
      reg2hw.alert_test.recov_fault.q & reg2hw.alert_test.recov_fault.qe;

  assign alerts[AlertFatalFaultIdx] = reg_intg_error       ||
                                      dma_tlul_rsp_intg_err ||
                                      dma_state_error       ||
                                      meta_fifo_err         ||
                                      data_fifo_err         ||
                                      aes_alert_fatal;
  assign alerts[AlertRecovFaultIdx] = aes_alert_recov | aes_tag_mismatch_set;

  for (genvar i = 0; i < NumAlerts; i++) begin : gen_alert_tx
    prim_alert_sender #(
        .AsyncOn(AlertAsyncOn[i]),
        .SkewCycles(AlertSkewCycles),
        .IsFatal(AlertIsFatal[i])
    ) u_prim_alert_sender (
        .clk_i,
        .rst_ni,
        .alert_test_i (alert_test[i]),
        .alert_req_i  (alerts[i]),
        .alert_ack_o  (),
        .alert_state_o(),
        .alert_rx_i   (alert_rx_i[i]),
        .alert_tx_o   (alert_tx_o[i])
    );
  end

  //////////////////////////////////////////////////////////////////////////////
  // Inline AES engine
  //////////////////////////////////////////////////////////////////////////////
  // The wrapper is instantiated and its inter-signals (EDN / keymgr / LC) are wired here. The
  // block-streaming datapath is tied off for now; the dma.sv AES sub-FSM that feeds/drains it
  // (gather -> wrapper -> scatter, tag handling) lands in the next change. The engine is therefore
  // present but inactive (start_i never pulsed).
  //
  // Configuration decode: the wrapper samples these at start_i; the CSRs are regwen-locked while the
  // DMA is busy. CONTROL.aes_op is the plain encoding {Off, Enc, Dec} (dma_aes_op_e).
  aes_pkg::aes_mode_e aes_cfg_mode;
  aes_pkg::ciph_op_e  aes_cfg_op;
  aes_pkg::key_len_e  aes_cfg_key_len;
  aes_pkg::prs_rate_e aes_cfg_reseed_rate;
  logic               aes_cfg_sideload;

  // Drive op/mode from the CAPTURED control state, not live reg2hw: CONTROL is not regwen-locked
  // (it carries go/abort), so a mid-transfer write to aes_op/aes_mode could otherwise reach the
  // wrapper's config commit and diverge from the FSM (which uses control_q). key_len/sideload/
  // reseed live in AES_CTRL (regwen CFG_REGWEN, locked while busy) so reading them live is safe.
  assign aes_cfg_op          = control_q.aes_decrypt ? aes_pkg::CIPH_INV : aes_pkg::CIPH_FWD;
  assign aes_cfg_mode        = control_q.aes_gcm ? aes_pkg::AES_GCM : aes_pkg::AES_CTR;
  assign aes_cfg_key_len     = aes_pkg::key_len_e'(reg2hw.aes_ctrl.key_len.q);
  assign aes_cfg_reseed_rate = aes_pkg::prs_rate_e'(reg2hw.aes_ctrl.prng_reseed_rate.q);
  // SEC_CM: KEY.SIDELOAD
  // sideload selects the keymgr sideload key over the KEY_SHARE CSRs; the key-mux isolation is in
  // aes_core (keymgr_key_i is routed there and consumed only when sideload is set).
  assign aes_cfg_sideload    = reg2hw.aes_ctrl.sideload.q;  // 1 = keymgr sideload key

  // Pack the key-share and IV CSR arrays for the wrapper.
  // SEC_CM: KEY.SW_UNREADABLE
  // KEY_SHARE0/1 and TAG_IN are write-only (reggen swaccess=wo): software cannot read them back;
  // only this HW path consumes them.
  logic [7:0][31:0] aes_key_share0, aes_key_share1;
  logic [3:0][31:0] aes_iv;
  always_comb begin
    for (int unsigned i = 0; i < 8; i++) begin
      aes_key_share0[i] = reg2hw.key_share0[i].q;
      aes_key_share1[i] = reg2hw.key_share1[i].q;
    end
    for (int unsigned i = 0; i < 4; i++) begin
      aes_iv[i] = reg2hw.iv[i].q;
    end
  end

  // ---- Block-serial AES datapath ----
  // Each 16-byte AES block is gathered from 4 read beats and scattered as 4 write beats (the DMA
  // datapath is 32-bit; AES enforces a 4-byte transfer width). Chunks contain full blocks.
  logic [127:0] aes_gather_q, aes_gather_d;
  logic aes_gather_capture;
  logic [127:0] aes_scatter_q, aes_scatter_d;
  logic aes_scatter_capture;
  logic [1:0] aes_word_cnt_q, aes_word_cnt_d;
  logic aes_word_cnt_en;
  logic aes_blk_consumed_q, aes_blk_consumed_d, aes_blk_consumed_en;
  logic aes_rd_inflight_q, aes_rd_inflight_d;
  logic aes_wr_inflight_q, aes_wr_inflight_d;
  logic aes_read_rsp_qual, aes_write_rsp_qual;

  // Wrapper handshake / streaming / tag signals.
  logic aes_start, aes_clear;
  // Keep configuration locked across software-paced chunks while the cipher retains its state.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) aes_session_q <= 1'b0;
    else if (aes_clear) aes_session_q <= 1'b0;
    else if (aes_start) aes_session_q <= 1'b1;
  end
  logic aes_blk_valid_in, aes_blk_ready_in;
  logic [127:0] aes_blk_data_in;
  logic [127:0] aes_blk_data_out;
  logic aes_blk_valid_out, aes_blk_ready_out;
  logic [127:0] aes_tag_out;
  logic         aes_tag_valid;
  logic         aes_tag_valid_set;

  // GCM AAD streaming + block counts.
  logic         aes_decrypt;
  logic [  3:0] aes_aad_blocks;
  logic [ 12:0] aes_text_blocks;
  logic         aes_feeding_aad;
  logic [1:0] aes_aad_blk_cnt_q, aes_aad_blk_cnt_d;
  logic         aes_aad_blk_cnt_en;
  logic [127:0] aes_aad_block;

  assign aes_decrypt      = control_q.aes_decrypt;
  assign aes_aad_blocks   = reg2hw.aes_ctrl.aad_blocks.q;
  // 16-byte text block count = total_data_size / 16 (a 16-byte-multiple total is enforced). v1
  // supports up to 13 bits of blocks; the wrapper builds the GHASH length block from this.
  assign aes_text_blocks  = reg2hw.total_data_size.q[16:4];

  // The DMA drains a produced block by latching it into the scatter buffer, so it presents
  // blk_ready_i exactly when it captures.
  assign aes_blk_ready_in = aes_scatter_capture;

  // The gathered word lands in the current 32-bit slot; the rest of the block is preserved.
  always_comb begin
    aes_gather_d = aes_gather_q;
    aes_gather_d[aes_word_cnt_q*32+:32] = dma_rsp_data;
  end
  assign aes_scatter_d = aes_blk_data_out;

  // Current AAD block = 4 consecutive AAD words selected by the AAD block counter.
  always_comb begin
    aes_aad_block = '0;
    for (int unsigned w = 0; w < 4; w++) begin
      aes_aad_block[w*32+:32] = reg2hw.aad[{aes_aad_blk_cnt_q, w[1:0]}].q;
    end
  end
  // Wrapper input: the AAD block while streaming AAD, otherwise the gathered text block.
  assign aes_blk_data_in = aes_feeding_aad ? aes_aad_block : aes_gather_q;

  // Expected tag (decrypt) and the glitch-resistant tag compare (SEC_CM: CTRL.CONSISTENCY). Two
  // independent comparisons computed differently must agree to accept; the FSM accepts ONLY on
  // aes_tag_ok and defaults to reject, so a single fault on either comparator cannot force accept.
  logic [127:0] aes_tag_in;
  always_comb begin
    aes_tag_in = '0;
    for (int unsigned i = 0; i < 4; i++) begin
      aes_tag_in[i*32+:32] = reg2hw.tag_in[i].q;
    end
  end
  logic aes_tag_eq;  // direct equality
  logic aes_tag_ne;  // independent inequality (bitwise XOR reduction)
  logic aes_tag_ok;  // accept only when equal AND not-unequal (redundant, fail-closed)
  assign aes_tag_eq = (aes_tag_out == aes_tag_in);
  assign aes_tag_ne = |(aes_tag_out ^ aes_tag_in);
  assign aes_tag_ok = aes_tag_eq & ~aes_tag_ne;

  prim_flop_en #(
      .Width(128)
  ) u_aes_gather (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(aes_gather_capture),
      .d_i(aes_gather_d),
      .q_o(aes_gather_q)
  );
  prim_flop_en #(
      .Width(128)
  ) u_aes_scatter (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(aes_scatter_capture),
      .d_i(aes_scatter_d),
      .q_o(aes_scatter_q)
  );
  prim_flop_en #(
      .Width(2)
  ) u_aes_word_cnt (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(aes_word_cnt_en),
      .d_i(aes_word_cnt_d),
      .q_o(aes_word_cnt_q)
  );
  prim_flop_en #(
      .Width(1)
  ) u_aes_blk_consumed (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(aes_blk_consumed_en),
      .d_i(aes_blk_consumed_d),
      .q_o(aes_blk_consumed_q)
  );
  prim_flop_en #(
      .Width(2)
  ) u_aes_aad_blk_cnt (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(aes_aad_blk_cnt_en),
      .d_i(aes_aad_blk_cnt_d),
      .q_o(aes_aad_blk_cnt_q)
  );
  prim_flop #(
      .Width(1)
  ) u_aes_rd_inflight (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .d_i(aes_rd_inflight_d),
      .q_o(aes_rd_inflight_q)
  );
  prim_flop #(
      .Width(1)
  ) u_aes_wr_inflight (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .d_i(aes_wr_inflight_d),
      .q_o(aes_wr_inflight_q)
  );

  dma_aes #(
      .SecMasking              (SecAesMasking),
      .SecSBoxImpl             (aes_pkg::SBoxImplDom),
      .SecAllowForcingMasks    (SecAllowForcingMasks),
      .AES192Enable            (1),
      .EntropyWidth            (edn_pkg::ENDPOINT_BUS_WIDTH),
      .RndCnstClearingLfsrSeed (RndCnstClearingLfsrSeed),
      .RndCnstClearingLfsrPerm (RndCnstClearingLfsrPerm),
      .RndCnstClearingSharePerm(RndCnstClearingSharePerm),
      .RndCnstMaskingLfsrSeed  (RndCnstMaskingLfsrSeed),
      .RndCnstMaskingLfsrPerm  (RndCnstMaskingLfsrPerm)
  ) u_dma_aes (
      .clk_i,
      .rst_ni,
      .clk_edn_i,
      .rst_edn_ni,
      .mode_i           (aes_cfg_mode),
      .op_i             (aes_cfg_op),
      .key_len_i        (aes_cfg_key_len),
      .sideload_i       (aes_cfg_sideload),
      .reseed_rate_i    (aes_cfg_reseed_rate),
      .key_share0_i     (aes_key_share0),
      .key_share1_i     (aes_key_share1),
      .iv_i             (aes_iv),
      .keymgr_key_i     (keymgr_key_i),
      .blk_data_i       (aes_blk_data_in),
      .blk_valid_i      (aes_blk_valid_in),
      .blk_ready_o      (aes_blk_ready_out),
      .blk_data_o       (aes_blk_data_out),
      .blk_valid_o      (aes_blk_valid_out),
      .blk_ready_i      (aes_blk_ready_in),
      .gcm_phase_i      (aes_pkg::GCM_INIT),
      .num_valid_bytes_i(5'd16),
      .aad_blocks_i     ({9'd0, aes_aad_blocks}),
      .text_blocks_i    (aes_text_blocks),
      .tag_o            (aes_tag_out),
      .tag_valid_o      (aes_tag_valid),
      .start_i          (aes_start),
      .clear_i          (aes_clear),
      .edn_o            (edn_o),
      .edn_i            (edn_i),
      .alert_recov_o    (aes_alert_recov),
      .alert_fatal_o    (aes_alert_fatal),
      .lc_escalate_en_i (lc_escalate_en_i)
  );

  // Generic host-port datapath: instantiate the host adapter for each port's class,
  // routing it to the 32-bit or 64-bit boundary vector.
  for (genvar p = 0; p < NumPorts; p++) begin : gen_host_port
    if (PortDesc[p].cls == PortTlul32) begin : g_tlul32
      // Standard 32-bit TLUL host adapter.
      tlul_adapter_host #(
          .MAX_REQS(NUM_MAX_OUTSTANDING_REQS),
          .EnableDataIntgGen(EnableDataIntgGen),
          .EnableRspDataIntgCheck(EnableRspDataIntgCheck)
      ) u_host (
          .clk_i       (gated_clk),
          .rst_ni      (rst_ni),
          // do not make a request unless there is room for the response
          .req_i       (port_req[p]),
          .gnt_o       (port_gnt[p]),
          .addr_i      (port_addr[p][top_pkg::TL_AW-1:0]),
          .we_i        (port_we[p]),
          .wdata_i     (port_wdata[p]),
          .wdata_intg_i(TL_A_USER_DEFAULT.data_intg),
          .be_i        (port_be[p]),
          .instr_type_i(MuBi4False),
          .user_rsvd_i (PortDesc[p].user_rsvd),
          .valid_o     (port_rvalid[p]),
          .rdata_o     (port_rdata[p]),
          .rdata_intg_o(),
          .err_o       (port_err[p]),
          .intg_err_o  (port_intg_err[p]),
          .tl_o        (host32_tl_h_o[dma_class_subidx_local(p)]),
          .tl_i        (host32_tl_h_i[dma_class_subidx_local(p)])
      );
    end else begin : g_tlul64
      // Wide 64-bit TLUL host adapter (off-bus, point-to-point).
      dma_tlul_adapter_host #(
          .MAX_REQS(NUM_MAX_OUTSTANDING_REQS),
          .EnableDataIntgGen(EnableDataIntgGen),
          .EnableRspDataIntgCheck(EnableRspDataIntgCheck)
      ) u_host (
          .clk_i       (gated_clk),
          .rst_ni      (rst_ni),
          // do not make a request unless there is room for the response
          .req_i       (port_req[p]),
          .gnt_o       (port_gnt[p]),
          .addr_i      (port_addr[p]),
          .we_i        (port_we[p]),
          .wdata_i     (port_wdata[p]),
          .wdata_intg_i(TL_A_USER_DEFAULT.data_intg),
          .be_i        (port_be[p]),
          .instr_type_i(MuBi4False),
          // Wide a_user reserved field is DmaRsvdWidth (not stock RsvdWidth) bits.
          .user_rsvd_i (dma_tlul_pkg::DmaRsvdWidth'(PortDesc[p].user_rsvd)),
          .valid_o     (port_rvalid[p]),
          .rdata_o     (port_rdata[p]),
          .rdata_intg_o(),
          .err_o       (port_err[p]),
          .intg_err_o  (port_intg_err[p]),
          .tl_o        (host64_h2d_o[dma_class_subidx_local(p)]),
          .tl_i        (host64_d2h_i[dma_class_subidx_local(p)])
      );
    end
  end

  // Zero-count handling: tie off the placeholder boundary vector (default the output,
  // absorb the input) when a class has no ports.
  if (NumTlul32 == 0) begin : gen_no_tl32
    assign host32_tl_h_o = '{default: tlul_pkg::TL_H2D_DEFAULT};
    logic unused_host32_tl_h_i;
    assign unused_host32_tl_h_i = ^{host32_tl_h_i};
  end
  if (NumTlul64 == 0) begin : gen_no_tl64
    assign host64_h2d_o = '{default: dma_tlul_pkg::DMA_TL_H2D_DEFAULT};
    logic unused_host64_d2h_i;
    assign unused_host64_d2h_i = ^{host64_d2h_i};
  end

  // Aggregate the per-port response-integrity errors into the single alert path.
  assign dma_tlul_rsp_intg_err = |port_intg_err;

  // Masking incoming handshake triggers with their enables
  lsio_trigger_t lsio_trigger;
  always_comb begin
    lsio_trigger = '0;

    for (int i = 0; i < NumIntClearSources; i++) begin
      lsio_trigger[i] = lsio_trigger_i[i] && reg2hw.handshake_intr_enable.q[i];
    end
  end

  // During the active DMA operation, most of the DMA registers are locked with a hardware-
  // controlled REGWEN. However, this mechanism is not possible for all registers. For example,
  // some registers already have a different REGWEN attached (range locking) or the CONTROL
  // register, which needs to be partly writable. To lock those registers, we capture their value
  // during the start of the operation and, later on, only use the captured value in the state
  // machine. The captured state is stored in control_q.
  control_state_t control_d, control_q;
  logic capture_state;

  // Fiddle out control bits into captured state
  always_comb begin
    control_d.read_en = reg2hw.control.read_en.q;
    control_d.write_en = reg2hw.control.write_en.q;
    control_d.digest_sel = dma_digest_e'(reg2hw.control.digest.q);
    control_d.cfg_handshake_en = reg2hw.control.hardware_handshake_enable.q;
    control_d.cfg_digest_swap = reg2hw.control.digest_swap.q;
    control_d.range_valid = reg2hw.range_valid.q;
    control_d.enabled_memory_range_base = reg2hw.enabled_memory_range_base.q;
    control_d.enabled_memory_range_limit = reg2hw.enabled_memory_range_limit.q;
    // Inline AES: aes_op {Off, Enc, Dec} (plain); the reserved value is caught as DmaOpcodeErr in
    // DmaAddrSetup. Active when either Enc or Dec.
    control_d.aes_en      = (dma_aes_op_e'(reg2hw.control.aes_op.q) == DmaAesOpEnc) ||
                            (dma_aes_op_e'(reg2hw.control.aes_op.q) == DmaAesOpDec);
    control_d.aes_decrypt = (dma_aes_op_e'(reg2hw.control.aes_op.q) == DmaAesOpDec);
    control_d.aes_gcm = reg2hw.control.aes_mode.q;
  end

  prim_flop_en #(
      .Width($bits(control_state_t))
  ) u_control (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_state),
      .d_i   (control_d),
      .q_o   (control_q)
  );

  `PRIM_FLOP_SPARSE_FSM(aff_ctrl_state_q, ctrl_state_d, ctrl_state_q, dma_ctrl_state_e, DmaIdle,
                        gated_clk, rst_ni)

  logic [TRANSFER_BYTES_WIDTH-1:0] transfer_byte_q, transfer_byte_d;
  logic [TRANSFER_BYTES_WIDTH-1:0] transfer_remaining_bytes;
  logic [TRANSFER_BYTES_WIDTH-1:0] chunk_remaining_bytes;
  logic [TRANSFER_BYTES_WIDTH-1:0] remaining_bytes;
  // Counters selecting which beat the address/BE setup computes (see p_addr_be_setup):
  // either the current registered counts (first beat) or the post-advance counts (folded).
  logic [TRANSFER_BYTES_WIDTH-1:0] setup_transfer_byte, setup_chunk_byte;
  // Range-check span: transfer-word width for fixed-address, remaining bytes otherwise.
  logic [TRANSFER_BYTES_WIDTH-1:0] xfer_width_bytes;
  logic [TRANSFER_BYTES_WIDTH-1:0] src_range_span, dst_range_span;
  // Bytes the current beat actually commits (full width, or the partial final-beat remainder).
  logic [TRANSFER_BYTES_WIDTH-1:0] beat_bytes, committed_remaining;
  logic capture_transfer_byte;
  prim_flop_en #(
      .Width(TRANSFER_BYTES_WIDTH)
  ) aff_transfer_byte (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_transfer_byte),
      .d_i   (transfer_byte_d),
      .q_o   (transfer_byte_q)
  );

  logic [TRANSFER_BYTES_WIDTH-1:0] chunk_byte_q, chunk_byte_d;
  logic capture_chunk_byte;
  prim_flop_en #(
      .Width(TRANSFER_BYTES_WIDTH)
  ) aff_chunk_byte (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_chunk_byte),
      .d_i   (chunk_byte_d),
      .q_o   (chunk_byte_q)
  );

  logic capture_transfer_width;
  logic [2:0] transfer_width_q, transfer_width_d;
  prim_flop_en #(
      .Width(3)
  ) aff_transfer_width (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_transfer_width),
      .d_i   (transfer_width_d),
      .q_o   (transfer_width_q)
  );

  logic capture_addr;
  logic [DMA_ADDR_WIDTH-1:0] src_addr_q, src_addr_d;
  logic [DMA_ADDR_WIDTH-1:0] dst_addr_q, dst_addr_d;
  prim_flop_en #(
      .Width(DMA_ADDR_WIDTH)
  ) aff_src_addr (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_addr),
      .d_i   (src_addr_d),
      .q_o   (src_addr_q)
  );

  prim_flop_en #(
      .Width(DMA_ADDR_WIDTH)
  ) aff_dst_addr (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_addr),
      .d_i   (dst_addr_d),
      .q_o   (dst_addr_q)
  );

  logic capture_be;
  logic [top_pkg::TL_DBW-1:0] req_src_be_q, req_src_be_d;
  logic [top_pkg::TL_DBW-1:0] req_dst_be_q, req_dst_be_d;
  prim_flop_en #(
      .Width(top_pkg::TL_DBW)
  ) aff_req_src_be (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_be),
      .d_i   (req_src_be_d),
      .q_o   (req_src_be_q)
  );

  prim_flop_en #(
      .Width(top_pkg::TL_DBW)
  ) aff_req_dst_be (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_be),
      .d_i   (req_dst_be_d),
      .q_o   (req_dst_be_q)
  );

  prim_flop_en #(
      .Width(INTR_CLEAR_SOURCES_WIDTH)
  ) u_clear_index (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (clear_index_en),
      .d_i   (clear_index_d),
      .q_o   (clear_index_q)
  );

  logic use_inline_hashing;
  logic sha2_hash_start, sha2_hash_process;
  logic sha2_valid, sha2_ready, sha2_digest_set;
  sha_fifo32_t sha2_data;
  digest_mode_e sha2_mode;
  sha_word64_t [7:0] sha2_digest;

  // Decode of the captured control fields into the datapath enables. All consumers derive
  // from captured `control_q`, never the live register interface.
  logic do_read, do_write;
  dma_digest_e                      digest_sel;
  logic        [top_pkg::TL_DW-1:0] fill_value;
  assign do_read    = control_q.read_en;
  assign do_write   = control_q.write_en;
  assign digest_sel = control_q.digest_sel;
  // Memset fill pattern (captured `src_addr_lo`); replicated across the bus width by the
  // destination transfer width so any address alignment / final partial beat is covered.
  // Little-endian: the partial final beat (dst BE 0001/0011/0111) writes the low byte(s).
  // Independent of any read steering since memset performs no source read.
  logic [top_pkg::TL_DW-1:0] fill_replicate;
  assign fill_value = src_addr_q[31:0];
  always_comb begin
    unique case (transfer_width_q)
      3'b001:  fill_replicate = {4{fill_value[7:0]}};
      3'b010:  fill_replicate = {2{fill_value[15:0]}};
      default: fill_replicate = fill_value[31:0];
    endcase
  end

  assign use_inline_hashing = (digest_sel != DigestNone);
  // When reaching DmaShaFinalize, we are consuming data and start computing the digest value
  assign sha2_hash_process  = (ctrl_state_q == DmaShaFinalize);

  logic sha2_consumed_d, sha2_consumed_q;
  prim_flop #(
      .Width(1)
  ) u_sha2_consumed (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .d_i   (sha2_consumed_d),
      .q_o   (sha2_consumed_q)
  );

  logic sha2_hash_done;
  logic sha2_hash_done_d, sha2_hash_done_q;
  prim_flop #(
      .Width(1)
  ) u_sha2_hash_done (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .d_i   (sha2_hash_done_d),
      .q_o   (sha2_hash_done_q)
  );

  // The SHA engine requires the message length in bits. Widen the 32-bit total_data_size to 64 bits
  // BEFORE the <<3, otherwise the shift is evaluated at 32-bit and the top 3 bits are lost - giving a
  // wrong length (and thus wrong digest) for hashed transfers >= 512 MiB.
  logic [63:0] sha2_message_len_bits;
  assign sha2_message_len_bits = 64'(reg2hw.total_data_size.q) << 3;

  // Translate the digest selector to the SHA2 digest mode
  always_comb begin
    unique case (digest_sel)
      DigestSha256: sha2_mode = SHA2_256;
      DigestSha384: sha2_mode = SHA2_384;
      DigestSha512: sha2_mode = SHA2_512;
      default:      sha2_mode = SHA2_None;
    endcase
  end

  // SHA2 engine for inline hashing operations
  prim_sha2_32 #(
      .MultimodeEn(1)
  ) u_sha2 (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .wipe_secret_i   (1'b0),
      .wipe_v_i        (32'b0),
      .fifo_rvalid_i   (sha2_valid),
      .fifo_rdata_i    (sha2_data),
      .fifo_rready_o   (sha2_ready),
      .sha_en_i        (1'b1),
      .hash_start_i    (sha2_hash_start),
      .hash_stop_i     (1'b0),
      .hash_continue_i (1'b0),
      .digest_mode_i   (sha2_mode),
      .hash_process_i  (sha2_hash_process),
      .hash_done_o     (sha2_hash_done),
      .message_length_i(sha2_message_len_bits),
      .digest_i        ('0),
      .digest_we_i     ('0),
      .digest_o        (sha2_digest),
      .digest_on_blk_o (),
      .hash_running_o  (),
      .idle_o          ()
  );

  // Fiddle ASIDs out for better readability during the rest of the code
  logic [ASID_WIDTH-1:0] src_asid, dst_asid;
  assign src_asid = reg2hw.addr_space_id.src_asid.q;
  assign dst_asid = reg2hw.addr_space_id.dst_asid.q;

  // Note: bus signals shall be asserted only when configured and active, to ensure
  // that address and - especially - data are not leaked to other buses.

  // Unified read/write request intent and payload. Driven either by the serial datapath
  // (DmaSendRead/DmaSendWrite, from the registered setup) or the read-ahead burst datapath
  // (DmaReadBurst issuing from the live read position; DmaWriteBurst from the data FIFO head).
  always_comb begin
    if (fast_mode_q && ((ctrl_state_q == DmaReadBurst) || (ctrl_state_q == DmaRunPipe))) begin
      rd_issue      = burst_rd_issue;
      rd_issue_addr = src_addr_d;
      rd_issue_be   = req_src_be_d;
    end else if (ctrl_state_q == DmaAesGather) begin
      rd_issue      = !aes_rd_inflight_q;
      rd_issue_addr = {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q};
      if (reg2hw.src_config.increment.q == AddrIncrement) begin
        rd_issue_addr += DMA_ADDR_WIDTH'(chunk_byte_q) + DMA_ADDR_WIDTH'(aes_word_cnt_q * 4);
      end
      rd_issue_be = {top_pkg::TL_DBW{1'b1}};
    end else begin
      rd_issue      = do_read && (ctrl_state_q == DmaSendRead);
      rd_issue_addr = src_addr_q;
      rd_issue_be   = req_src_be_q;
    end

    if (fast_mode_q && ((ctrl_state_q == DmaWriteBurst) || (ctrl_state_q == DmaRunPipe))) begin
      wr_issue      = burst_wr_issue;
      wr_issue_addr = data_rdata.dst_addr;
      wr_issue_be   = data_rdata.dst_be;
      wr_issue_data = data_rdata.data;
    end else if (ctrl_state_q == DmaAesScatter) begin
      wr_issue      = !aes_wr_inflight_q;
      wr_issue_addr = {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q};
      if (reg2hw.dst_config.increment.q == AddrIncrement) begin
        wr_issue_addr += DMA_ADDR_WIDTH'(chunk_byte_q);
      end
      wr_issue_be   = {top_pkg::TL_DBW{1'b1}};
      wr_issue_data = aes_scatter_q[aes_word_cnt_q*32+:32];
    end else begin
      wr_issue      = do_write && (ctrl_state_q == DmaSendWrite);
      wr_issue_addr = dst_addr_q;
      wr_issue_be   = req_dst_be_q;
      wr_issue_data = do_read ? read_return_data_q : fill_replicate;
    end
  end

  // Per-port "is 32-bit?" vector (constant), indexed by the upper-bits-zero checks below.
  logic [NumPorts-1:0] PortIs32;
  for (genvar p = 0; p < NumPorts; p++) begin : gen_port_is32
    assign PortIs32[p] = (PortDesc[p].cls != PortTlul64);
  end

  // ASID -> port-index reverse lookup; a miss drives the ASID validity error below.
  logic [PortIdxW-1:0] src_port_idx, dst_port_idx;
  logic src_asid_valid, dst_asid_valid;
  always_comb begin
    src_port_idx   = '0;
    dst_port_idx   = '0;
    src_asid_valid = 1'b0;
    dst_asid_valid = 1'b0;
    for (int unsigned i = 0; i < NumPorts; i++) begin
      if (PortDesc[i].asid == asid_encoding_e'(src_asid)) begin
        src_port_idx   = PortIdxW'(i);
        src_asid_valid = 1'b1;
      end
      if (PortDesc[i].asid == asid_encoding_e'(dst_asid)) begin
        dst_port_idx   = PortIdxW'(i);
        dst_asid_valid = 1'b1;
      end
    end
  end

  // Each interrupt source selects any configured port by its encoded ASID.
  logic [PortIdxW-1:0] clr_port_idx;
  logic clr_asid_valid;
  always_comb begin
    clr_port_idx   = '0;
    clr_asid_valid = 1'b0;
    for (int unsigned i = 0; i < NumPorts; i++) begin
      if (PortDesc[i].asid == reg2hw.clear_intr_asid[clear_index_q].q) begin
        clr_port_idx   = PortIdxW'(i);
        clr_asid_valid = 1'b1;
      end
    end
  end

  // Bus signals are asserted only when configured and active, so address/data are not
  // leaked to other buses: only the resolved port is driven, everything else is '0.
  always_comb begin
    port_req   = '0;
    port_we    = '0;
    port_addr  = '0;
    port_wdata = '0;
    port_be    = '0;

    if (!cfg_abort_en && rd_issue) begin
      port_req[src_port_idx]  = 1'b1;
      port_addr[src_port_idx] = rd_issue_addr;
      port_be[src_port_idx]   = rd_issue_be;
    end
    if (!cfg_abort_en && wr_issue) begin
      port_req  [dst_port_idx] = 1'b1;
      port_we   [dst_port_idx] = 1'b1;
      port_addr [dst_port_idx] = wr_issue_addr;
      port_wdata[dst_port_idx] = wr_issue_data;
      port_be   [dst_port_idx] = wr_issue_be;
    end
    if (!cfg_abort_en && dma_clear_intr && clr_asid_valid) begin
      port_req  [clr_port_idx] = 1'b1;
      port_we   [clr_port_idx] = 1'b1;
      port_addr [clr_port_idx] = DMA_ADDR_WIDTH'(reg2hw.intr_src_addr[clear_index_q].q);
      port_wdata[clr_port_idx] = reg2hw.intr_src_wr_val[clear_index_q].q;
      port_be   [clr_port_idx] = {top_pkg::TL_DBW{1'b1}};
    end
  end

  // Response / read-data muxing: index the per-port arrays by the resolved indices.
  assign read_gnt = port_gnt[src_port_idx];
  assign read_rsp_valid = port_rvalid[src_port_idx];
  assign read_rsp_error = port_err[src_port_idx];

  assign write_gnt = port_gnt[dst_port_idx];
  assign write_rsp_valid = port_rvalid[dst_port_idx];
  assign write_rsp_error = port_err[dst_port_idx];

  assign aes_read_rsp_qual = read_rsp_valid && (aes_rd_inflight_q || (rd_issue && read_gnt));
  assign aes_write_rsp_qual = write_rsp_valid && (aes_wr_inflight_q || (wr_issue && write_gnt));

  // Interrupt-clear response muxing: index by the resolved clear-target port.
  assign intr_clear_tlul_gnt = port_gnt[clr_port_idx];
  assign intr_clear_tlul_rsp_valid = port_rvalid[clr_port_idx];
  assign intr_clear_tlul_rsp_error = port_err[clr_port_idx];

  // Collect read data from the appropriate port.
  assign dma_rsp_data = port_rdata[src_port_idx];

  always_comb begin
    ctrl_state_d           = ctrl_state_q;

    capture_transfer_byte  = 1'b0;
    transfer_byte_d        = transfer_byte_q;
    capture_chunk_byte     = 1'b0;
    chunk_byte_d           = chunk_byte_q;
    capture_transfer_width = 1'b0;
    capture_return_data    = 1'b0;
    capture_state          = 1'b0;

    // Address/BE/width datapath values (src_addr_d, dst_addr_d, req_*_be_d, transfer_width_d)
    // are driven combinationally by p_addr_be_setup based on these setup counters. Default to
    // the current registered counts (first beat of a chunk); the folded per-beat copy path
    // overrides them with the post-advance counts.
    setup_transfer_byte    = transfer_byte_q;
    setup_chunk_byte       = chunk_byte_q;

    next_error             = '0;
    capture_addr           = 1'b0;
    capture_be             = '0;

    // Read-ahead burst datapath defaults
    fast_mode_d            = fast_mode_q;
    capture_fast_mode      = 1'b0;
    rd_byte_d              = rd_byte_q;
    capture_rd_byte        = 1'b0;
    rd_outstanding_d       = rd_outstanding_q;
    wr_outstanding_d       = wr_outstanding_q;
    burst_rd_issue         = 1'b0;
    burst_wr_issue         = 1'b0;
    meta_wvalid            = 1'b0;
    meta_rready            = 1'b0;
    data_wvalid            = 1'b0;
    data_rready            = 1'b0;

    dma_clear_intr         = 1'b0;
    clear_index_d          = '0;
    clear_index_en         = '0;

    clear_go               = 1'b0;
    chunk_done             = 1'b0;

    dma_state_error        = 1'b0;

    sha2_hash_start        = 1'b0;
    sha2_valid             = 1'b0;
    sha2_digest_set        = 1'b0;
    sha2_consumed_d        = sha2_consumed_q;

    // Inline AES sub-FSM strobe defaults.
    aes_start              = 1'b0;
    aes_clear              = 1'b0;
    aes_blk_valid_in       = 1'b0;
    aes_feeding_aad        = 1'b0;
    aes_gather_capture     = 1'b0;
    aes_scatter_capture    = 1'b0;
    aes_word_cnt_d         = aes_word_cnt_q;
    aes_word_cnt_en        = 1'b0;
    aes_blk_consumed_d     = aes_blk_consumed_q;
    aes_blk_consumed_en    = 1'b0;
    aes_aad_blk_cnt_d      = aes_aad_blk_cnt_q;
    aes_aad_blk_cnt_en     = 1'b0;
    aes_tag_valid_set      = 1'b0;
    aes_tag_mismatch_set   = 1'b0;
    aes_rd_inflight_d      = aes_rd_inflight_q;
    aes_wr_inflight_d      = aes_wr_inflight_q;

    // Make `SHA2 Done` sticky to not miss a single-cycle done event during any outstanding writes
    if (ctrl_state_q == DmaIdle) begin
      sha2_hash_done_d = 1'b0;
    end else begin
      sha2_hash_done_d = sha2_hash_done_q | sha2_hash_done;
    end

    // Default assignments for the muxed config signals for the idle state
    cfg_handshake_en = control_q.cfg_handshake_en;

    // Abort has the highest priority. Stop issuing immediately, but keep the controller busy and
    // its port-selecting CSRs locked until all previously accepted transactions have responded.
    if (cfg_abort_en) begin
      // Flush the inline AES engine and all its block state on abort, so nothing replays into the
      // next transfer.
      aes_clear           = 1'b1;
      aes_word_cnt_d      = 2'd0;
      aes_word_cnt_en     = 1'b1;
      aes_blk_consumed_d  = 1'b0;
      aes_blk_consumed_en = 1'b1;
      aes_aad_blk_cnt_d   = 2'd0;
      aes_aad_blk_cnt_en  = 1'b1;
      aes_rd_inflight_d   = 1'b0;
      aes_wr_inflight_d   = 1'b0;
      if (dma_drained) begin
        ctrl_state_d = DmaIdle;
        clear_go     = 1'b1;
      end
    end else begin
      unique case (ctrl_state_q)
        DmaIdle: begin
          chunk_byte_d       = '0;
          capture_chunk_byte = 1'b1;

          // In DmaIdle we need to determine if we are really idling or we are doing a roundtrip
          // via idle. If we are really idling, we need to take the config from the register
          // interface; otherwise we need to take the captured data.
          if (!reg2hw.status.busy.q && !aes_session_q) begin
            // We are idling
            cfg_handshake_en = reg2hw.control.hardware_handshake_enable.q;
          end
          // else, we are doing a roundtrip, and signaling is covered by the default assignment

          // Wait for `go` bit to be set to proceed with data movement
          if (reg2hw.control.go.q || reg2hw.status.busy.q) begin
            // Clear the transferred bytes only on the very first iteration
            if (reg2hw.control.initial_transfer.q && !reg2hw.status.busy.q && !aes_session_q) begin
              transfer_byte_d       = '0;
              capture_transfer_byte = 1'b1;
              // Capture unlocked state when starting the transfer.
              capture_state         = 1'b1;
            end
            // if not handshake start transfer
            if (!cfg_handshake_en) begin
              ctrl_state_d = DmaCfgValidate;
            end else if (cfg_handshake_en && |lsio_trigger) begin
              // if handshake wait for interrupt
              if (|reg2hw.clear_intr_src.q) begin
                clear_index_en = 1'b1;
                clear_index_d  = '0;
                ctrl_state_d   = DmaClearIntrSrc;
              end else begin
                ctrl_state_d = DmaCfgValidate;
              end
            end
            // A suspended message must be resumed, or explicitly aborted before replacement.
            if (aes_session_q && reg2hw.control.initial_transfer.q) begin
              next_error[DmaOpcodeErr] = 1'b1;
              ctrl_state_d = DmaError;
            end
          end
        end

        DmaClearIntrSrc: begin
          // Clear the interrupt by writing
          if (reg2hw.clear_intr_src.q[clear_index_q] && !clr_asid_valid) begin
            next_error[DmaAsidErr] = 1'b1;
            ctrl_state_d = DmaError;
          end else if (reg2hw.clear_intr_src.q[clear_index_q]) begin
            // Send 'clear interrupt' write to the bus selected by clr_port_idx
            dma_clear_intr = 1'b1;

            if (intr_clear_tlul_gnt) begin
              ctrl_state_d = DmaWaitIntrSrcResponse;
            end

            // Writes also get a resp valid, but no data.
            // Need to wait for this to not overrun TL-UL adapter
            // The response might come immediately
            if (intr_clear_tlul_rsp_valid) begin
              if (intr_clear_tlul_rsp_error) begin
                next_error[DmaBusErr] = 1'b1;
                ctrl_state_d = DmaError;
              end else if (32'(clear_index_q) >= (NumIntClearSources - 1)) begin
                ctrl_state_d = DmaCfgValidate;  // Proceed now we've handled all
              end else begin
                clear_index_en = 1'b1;
                clear_index_d  = clear_index_q + INTR_CLEAR_SOURCES_WIDTH'(1'b1);
                ctrl_state_d   = DmaClearIntrSrc;  // Override the _gnt response above.
              end
            end
          end else begin
            // Do nothing if no clearing requested
            clear_index_en = 1'b1;
            clear_index_d  = clear_index_q + INTR_CLEAR_SOURCES_WIDTH'(1'b1);

            if (32'(clear_index_q) >= (NumIntClearSources - 1)) begin
              ctrl_state_d = DmaCfgValidate;
            end
          end
        end

        DmaWaitIntrSrcResponse: begin
          // Writes also get a resp valid, but no data.
          // Need to wait for this to not overrun TL-UL adapter
          if (intr_clear_tlul_rsp_valid) begin
            if (intr_clear_tlul_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d = DmaError;
            end else if (32'(clear_index_q) < (NumIntClearSources - 1)) begin
              clear_index_en = 1'b1;
              clear_index_d  = clear_index_q + INTR_CLEAR_SOURCES_WIDTH'(1'b1);
              ctrl_state_d   = DmaClearIntrSrc;
            end else begin
              ctrl_state_d = DmaCfgValidate;
            end
          end
        end

        DmaCfgValidate: begin
          // One-time configuration validation, performed once at the start of a (chunked)
          // transfer before any bus activity. All inputs are register values or the captured
          // `control_q`, which are locked for the duration of the transfer, so these checks
          // need not be (and no longer are) re-evaluated per transferred word.

          // Validate the `transfer_width` encoding (value 3 is invalid)
          unique case (reg2hw.transfer_width.q)
            DmaXfer1BperTxn, DmaXfer2BperTxn, DmaXfer4BperTxn: ;  // valid
            default: next_error[DmaSizeErr] = 1'b1;
          endcase

          // No empty transactions
          if ((reg2hw.chunk_data_size.q == '0) || (reg2hw.total_data_size.q == '0)) begin
            next_error[DmaSizeErr] = 1'b1;
          end

          // Legal-combination check on the captured control fields. Reject combinations that
          // would be a no-op, hash a constant, discard data without output, or pair the
          // hardware handshake with a missing read or write path.
          if ((!do_read && !do_write) ||  // no-op
              ((digest_sel != DigestNone) && !do_read) ||  // hash with no source data
              (!do_write && (digest_sel == DigestNone)) ||  // read-and-discard, no output
              (control_q.cfg_handshake_en && !do_read) ||  // handshake drains via reads
              (control_q.cfg_handshake_en && !do_write)) begin  // handshake completion via writes
            next_error[DmaOpcodeErr] = 1'b1;
          end

          // Inline hashing is only allowed for 32-bit transfer width
          if (use_inline_hashing && (reg2hw.transfer_width.q != DmaXfer4BperTxn)) begin
            next_error[DmaSizeErr] = 1'b1;
          end

          // Ensure that ASIDs have valid values, i.e., resolve to a configured port.
          // SEC_CM: ASID.INTERSIG.MUBI
          if (do_read && !src_asid_valid) begin
            next_error[DmaAsidErr] = 1'b1;
          end
          if (do_write && !dst_asid_valid) begin
            next_error[DmaAsidErr] = 1'b1;
          end

          // Check the validity of the restricted DMA-enabled memory range
          // Note: both the base and the limit addresses are inclusive
          if (control_q.enabled_memory_range_limit < control_q.enabled_memory_range_base) begin
            next_error[DmaBaseLimitErr] = 1'b1;
          end

          // In 4-byte transfers, source and destination address must be 4-byte aligned.
          // Source checks apply only when reading (for memset src_addr_lo is the fill pattern).
          if (do_read && reg2hw.transfer_width.q == DmaXfer4BperTxn && |reg2hw.src_addr_lo.q[1:0]) begin
            next_error[DmaSrcAddrErr] = 1'b1;
          end
          // Destination checks apply only when writing (for verify dst_addr_lo is unused).
          if (do_write && reg2hw.transfer_width.q == DmaXfer4BperTxn && |reg2hw.dst_addr_lo.q[1:0]) begin
            next_error[DmaDstAddrErr] = 1'b1;
          end

          // In 2-byte transfers, source and destination address must be 2-byte aligned
          if (do_read && reg2hw.transfer_width.q == DmaXfer2BperTxn && reg2hw.src_addr_lo.q[0]) begin
            next_error[DmaSrcAddrErr] = 1'b1;
          end
          if (do_write && reg2hw.transfer_width.q == DmaXfer2BperTxn &&
              reg2hw.dst_addr_lo.q[0]) begin
            next_error[DmaDstAddrErr] = 1'b1;
          end

          // Descriptor-driven memory-range protection: when exactly one endpoint is
          // range-checked, its address range must fall within the DMA enabled memory region.
          //
          // The descriptor-indexed checks below resolve `PortDesc`/`PortIs32` via
          // src/dst_port_idx, which default to port 0 on an invalid ASID. Gate each side on
          // its own ASID being valid so an invalid ASID raises only DmaAsidErr (above) and
          // not a spurious DmaSrc/DstAddrErr from the bogus default index.
          if (do_read && src_asid_valid) begin
            // Source is the range-checked endpoint (e.g. OT -> SoC copy).
            if (PortDesc[src_port_idx].range_check &&
                (!do_write || !PortDesc[dst_port_idx].range_check) &&
                // The limit is inclusive, so the last accessed byte is
                // `addr + src_range_span - 1`; it is in range iff that byte is <= limit.
                // `src_range_span` is the actual accessed extent: the transfer-word width for a
                // fixed address, else this chunk's real length (= min(total remaining,
                // chunk_data_size)). This avoids rejecting a shorter final chunk, or a fixed-address
                // FIFO word near the limit, that is genuinely within range.
                ((reg2hw.src_addr_lo.q > control_q.enabled_memory_range_limit) ||
                  (reg2hw.src_addr_lo.q < control_q.enabled_memory_range_base)   ||
                  ((DMA_ADDR_WIDTH'(reg2hw.src_addr_lo.q) +
                    DMA_ADDR_WIDTH'(src_range_span) - DMA_ADDR_WIDTH'(1)) >
                    DMA_ADDR_WIDTH'(control_q.enabled_memory_range_limit)))) begin
              next_error[DmaSrcAddrErr] = 1'b1;
            end

            // 32-bit source port: upper address bits must be zero (32-bit address space).
            if (PortIs32[src_port_idx] && (|reg2hw.src_addr_hi.q)) begin
              next_error[DmaSrcAddrErr] = 1'b1;
            end
          end

          if (do_write && dst_asid_valid) begin
            // Destination is the range-checked endpoint (e.g. SoC -> OT copy).
            if (PortDesc[dst_port_idx].range_check &&
                (!do_read || !PortDesc[src_port_idx].range_check) &&
                // Out-of-bound check. The limit is inclusive, so the last accessed byte is
                // `addr + dst_range_span - 1`; it is in range iff that byte is <= limit.
                // `dst_range_span` is the actual accessed extent (transfer-word width for a fixed
                // address, else this chunk's real length); see the source check above.
                ((reg2hw.dst_addr_lo.q > control_q.enabled_memory_range_limit) ||
                  (reg2hw.dst_addr_lo.q < control_q.enabled_memory_range_base) ||
                  ((DMA_ADDR_WIDTH'(reg2hw.dst_addr_lo.q) +
                    DMA_ADDR_WIDTH'(dst_range_span) - DMA_ADDR_WIDTH'(1)) >
                    DMA_ADDR_WIDTH'(control_q.enabled_memory_range_limit)))) begin
              next_error[DmaDstAddrErr] = 1'b1;
            end

            // 32-bit destination port: upper address bits must be zero (32-bit address space).
            if (PortIs32[dst_port_idx] && (|reg2hw.dst_addr_hi.q)) begin
              next_error[DmaDstAddrErr] = 1'b1;
            end
          end

          if (!control_q.range_valid) begin
            next_error[DmaRangeValidErr] = 1'b1;
          end

          // Reserved aes_op codepoint is an invalid opcode.
          if (!aes_session_q && reg2hw.control.aes_op.q == 2'd3) begin
            next_error[DmaOpcodeErr] = 1'b1;
          end

          // Inline AES legal-combination checks: full 16-byte blocks in every chunk.
          // AES needs a read+write stream, no inline hashing, 4-byte beats, 16-byte-multiple
          // sizes. Address increment and chunk wrap follow the normal DMA configuration.
          if (control_q.aes_en) begin
            if (!do_read || !do_write || (digest_sel != DigestNone)) begin
              next_error[DmaOpcodeErr] = 1'b1;
            end
            if (reg2hw.transfer_width.q != DmaXfer4BperTxn) begin
              next_error[DmaSizeErr] = 1'b1;
            end
            if (|reg2hw.total_data_size.q[3:0] || |reg2hw.chunk_data_size.q[3:0]) begin
              next_error[DmaSizeErr] = 1'b1;
            end
            if (aes_aad_blocks > 4'd2) begin  // only NumAadWords/4 = 2 AAD blocks are provided
              next_error[DmaSizeErr] = 1'b1;
            end
            // GCM length/phase tracking carries the 16-byte text-block count in a 13-bit field
            // (`aes_text_blocks` = total_data_size[16:4]). A larger GCM transfer would truncate the
            // block count, diverging the wrapper's GHASH length block / phase counter from the
            // gather/scatter FSM, so reject anything above 8191 blocks (0x1_FFF0 bytes). CTR has no
            // such field (the FSM tracks bytes directly), so it is left unconstrained here.
            if (control_q.aes_gcm && |reg2hw.total_data_size.q[31:17]) begin
              next_error[DmaSizeErr] = 1'b1;
            end
            if (aes_cfg_sideload && !keymgr_key_i.valid) begin  // never run with a default key
              next_error[DmaOpcodeErr] = 1'b1;
            end
          end

          // Decide whether the read-ahead burst datapath can be used: plain copy, no inline
          // hashing, no hardware handshake, a single chunk (chunk >= total), and both ends on
          // TL-UL ports (OT internal / SoC control). Otherwise use the serial datapath.
          fast_mode_d = do_read && do_write && !use_inline_hashing && !control_q.aes_en &&
                        !control_q.cfg_handshake_en &&
                        (reg2hw.chunk_data_size.q >= reg2hw.total_data_size.q) &&
                        src_asid_valid && dst_asid_valid;
          capture_fast_mode = 1'b1;

          if (|next_error) begin
            ctrl_state_d = DmaError;
          end else if (!dma_drained) begin
            // Do not start until responses from a prior transfer have drained.
            ctrl_state_d = DmaCfgValidate;
          end else if (control_q.aes_en) begin
            if (transfer_byte_q == '0) aes_start = 1'b1;
            capture_transfer_width = 1'b1;
            aes_word_cnt_d = 2'd0;
            aes_word_cnt_en = 1'b1;
            aes_rd_inflight_d = 1'b0;
            aes_wr_inflight_d = 1'b0;
            if (control_q.aes_gcm && (transfer_byte_q == '0) && (aes_aad_blocks != 4'd0)) begin
              aes_aad_blk_cnt_d  = 2'd0;
              aes_aad_blk_cnt_en = 1'b1;
              ctrl_state_d       = DmaAesGhashAad;
            end else begin
              ctrl_state_d = DmaAesGather;
            end
          end else if (fast_mode_d) begin
            rd_byte_d        = transfer_byte_q;
            capture_rd_byte  = 1'b1;
            rd_outstanding_d = '0;
            wr_outstanding_d = '0;
            ctrl_state_d     = (src_port_idx != dst_port_idx) ? DmaRunPipe : DmaReadBurst;
          end else begin
            // Start the inline hashing on the very first transfer (transfer_byte_q still 0).
            if ((transfer_byte_q == '0) && use_inline_hashing) begin
              sha2_hash_start = 1'b1;
            end
            ctrl_state_d = DmaAddrSetup;
          end
        end

        DmaAddrSetup: begin
          // First beat of a (chunked) transfer. The address/BE/width are computed
          // combinationally by p_addr_be_setup from the default setup counters (the current
          // registered counts); capture them and proceed to the read. Subsequent beats of a
          // plain copy fold this setup into the write-completion cycle (see below), removing
          // the dedicated per-word setup cycle.
          capture_transfer_width = 1'b1;
          capture_addr           = 1'b1;
          capture_be             = 1'b1;
          sha2_consumed_d        = 1'b0;
          ctrl_state_d           = do_read ? DmaSendRead : DmaSendWrite;
        end

        DmaSendRead, DmaWaitReadResponse: begin
          if (read_rsp_valid) begin
            if (read_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              capture_return_data = 1'b1;
              // We received data, feed it into the SHA2 engine
              if (use_inline_hashing) begin
                sha2_valid      = 1'b1;
                sha2_consumed_d = sha2_ready;
              end
              if (do_write) begin
                ctrl_state_d = DmaSendWrite;
              end else begin
                // Verify: the read itself commits the beat because there is no destination
                // write. Hashing is mandatory for this legal control combination.
                transfer_byte_d       = transfer_byte_q + beat_bytes;
                chunk_byte_d          = chunk_byte_q + beat_bytes;
                capture_transfer_byte = 1'b1;
                capture_chunk_byte    = 1'b1;

                if (!sha2_ready) begin
                  ctrl_state_d = DmaShaWait;
                end else if (transfer_byte_d >= reg2hw.total_data_size.q) begin
                  ctrl_state_d = DmaShaFinalize;
                end else if (chunk_byte_d >= reg2hw.chunk_data_size.q) begin
                  clear_go     = !control_q.cfg_handshake_en;
                  chunk_done   = !control_q.cfg_handshake_en;
                  ctrl_state_d = DmaIdle;
                end else begin
                  setup_transfer_byte    = transfer_byte_d;
                  setup_chunk_byte       = chunk_byte_d;
                  capture_transfer_width = 1'b1;
                  capture_addr           = 1'b1;
                  capture_be             = 1'b1;
                  sha2_consumed_d        = 1'b0;
                  ctrl_state_d           = DmaSendRead;
                end
              end
            end
          end else if (read_gnt) begin
            // Only Request handled
            ctrl_state_d = DmaWaitReadResponse;
          end
        end

        DmaSendWrite, DmaWaitWriteResponse: begin
          // If using inline hashing and data is not yet consumed, apply it
          if (use_inline_hashing && !sha2_consumed_q) begin
            sha2_valid = 1'b1;
            sha2_consumed_d = sha2_ready;
          end

          if (write_rsp_valid) begin
            if (write_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              // Advance by the number of bytes just transferred
              transfer_byte_d       = transfer_byte_q + beat_bytes;
              chunk_byte_d          = chunk_byte_q + beat_bytes;
              capture_transfer_byte = 1'b1;
              capture_chunk_byte    = 1'b1;

              // If we are doing inline hashing and the data was not consumed yet, wait until it is
              // consumed by the SHA engine and then continue.
              if (use_inline_hashing && !(sha2_ready || sha2_consumed_q)) begin
                ctrl_state_d = DmaShaWait;
              end else begin
                // Will there still be more to do _after_ this advance?
                if (transfer_byte_d >= reg2hw.total_data_size.q) begin
                  if (use_inline_hashing) begin
                    ctrl_state_d = DmaShaFinalize;
                  end else begin
                    clear_go     = 1'b1;
                    ctrl_state_d = DmaIdle;
                  end
                end else if (chunk_byte_d >= reg2hw.chunk_data_size.q) begin
                  // Conditionally clear the `go` bit when not being used in hardware handshake
                  // mode.
                  // In non-hardware handshake mode, finishing one chunk should raise the
                  // `chunk_done` IRQ and status bit, reset the `go` bit and await the next
                  // FW-controlled chunk.
                  clear_go     = !control_q.cfg_handshake_en;
                  chunk_done   = !control_q.cfg_handshake_en;
                  ctrl_state_d = DmaIdle;
                end else if (!use_inline_hashing) begin
                  // Plain copy: fold the next beat's address/BE setup into this cycle using
                  // the post-advance counts, and proceed straight to the read - removing the
                  // dedicated DmaAddrSetup cycle per word.
                  setup_transfer_byte    = transfer_byte_d;
                  setup_chunk_byte       = chunk_byte_d;
                  capture_transfer_width = 1'b1;
                  capture_addr           = 1'b1;
                  capture_be             = 1'b1;
                  sha2_consumed_d        = 1'b0;
                  ctrl_state_d           = do_read ? DmaSendRead : DmaSendWrite;
                end else begin
                  // Inline hashing: keep the dedicated setup cycle (SHA-bound path).
                  ctrl_state_d = DmaAddrSetup;
                end
              end
            end
          end else if (write_gnt) begin
            // Only Request handled
            ctrl_state_d = DmaWaitWriteResponse;
          end
        end

        // Read-ahead burst: issue back-to-back reads on the source port into the data FIFO.
        // Only reads are outstanding here, so every response is read data (no demux needed).
        DmaReadBurst: begin
          // Drive p_addr_be_setup for the beat currently being issued (single chunk).
          setup_transfer_byte    = rd_byte_q;
          setup_chunk_byte       = rd_byte_q;
          capture_transfer_width = 1'b1;  // keep transfer_width_q valid for the write phase

          // Issue another read while there are bytes left to read and the FIFO (buffered +
          // in-flight) is not full. Acceptance is qualified by read_gnt in the bus muxing.
          if ((rd_byte_q < reg2hw.total_data_size.q) &&
              ((int'(data_depth) + int'(rd_outstanding_q)) < int'(DMA_BURST_FIFO_DEPTH)) &&
              meta_wready) begin
            burst_rd_issue = 1'b1;
            if (read_gnt) begin
              meta_wvalid     = 1'b1;  // push this beat's metadata
              rd_byte_d       = rd_byte_q + TRANSFER_BYTES_WIDTH'(transfer_width_d);
              capture_rd_byte = 1'b1;
            end
          end

          // Read response: steer and push into the data FIFO, popping the metadata.
          if (read_rsp_valid) begin
            if (read_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              meta_rready = 1'b1;
              data_wvalid = 1'b1;
            end
          end

          // Outstanding-read update: +1 when a read is accepted, -1 when a response arrives.
          if ((burst_rd_issue & read_gnt) & ~(read_rsp_valid & ~read_rsp_error) &
              (rd_outstanding_q != BURST_CNT_W'(DMA_BURST_FIFO_DEPTH))) begin
            rd_outstanding_d = rd_outstanding_q + BURST_CNT_W'(1);
          end else if (~(burst_rd_issue & read_gnt) & (read_rsp_valid & ~read_rsp_error) &
                       (rd_outstanding_q != '0)) begin
            rd_outstanding_d = rd_outstanding_q - BURST_CNT_W'(1);
          end

          // Once all bytes are issued (or the FIFO filled) and every outstanding read has
          // returned, switch to draining the writes.
          if ((ctrl_state_d != DmaError) &&
              ((rd_byte_q >= reg2hw.total_data_size.q) ||
               ((int'(data_depth) + int'(rd_outstanding_q)) >= int'(DMA_BURST_FIFO_DEPTH))) &&
              (rd_outstanding_d == '0)) begin
            ctrl_state_d = DmaWriteBurst;
          end
        end

        // Read-ahead burst: drain the data FIFO as back-to-back writes on the destination port.
        DmaWriteBurst: begin
          if (data_rvalid) begin
            burst_wr_issue = 1'b1;
            if (write_gnt) begin
              data_rready = 1'b1;  // pop the entry just issued
            end
          end

          if (write_rsp_valid) begin
            if (write_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              transfer_byte_d       = transfer_byte_q + beat_bytes;
              chunk_byte_d          = chunk_byte_q + beat_bytes;
              capture_transfer_byte = 1'b1;
              capture_chunk_byte    = 1'b1;
            end
          end

          // Outstanding-write update: +1 when a write is accepted, -1 when an ack arrives.
          if ((burst_wr_issue & write_gnt) & ~(write_rsp_valid & ~write_rsp_error) &
              (wr_outstanding_q != BURST_CNT_W'(DMA_BURST_FIFO_DEPTH))) begin
            wr_outstanding_d = wr_outstanding_q + BURST_CNT_W'(1);
          end else if (~(burst_wr_issue & write_gnt) & (write_rsp_valid & ~write_rsp_error) &
                       (wr_outstanding_q != '0)) begin
            wr_outstanding_d = wr_outstanding_q - BURST_CNT_W'(1);
          end

          // Burst drained when the FIFO is empty and no writes remain outstanding.
          if ((ctrl_state_d != DmaError) && !data_rvalid && (wr_outstanding_d == '0)) begin
            if (transfer_byte_d >= reg2hw.total_data_size.q) begin
              clear_go     = 1'b1;
              ctrl_state_d = DmaIdle;
            end else begin
              // More to do: start the next read burst.
              rd_outstanding_d = '0;
              wr_outstanding_d = '0;
              ctrl_state_d     = DmaReadBurst;
            end
          end
        end

        // Cross-port read-ahead: reads (source port) and writes (destination port) run
        // concurrently. The ports are distinct, so read responses and write acknowledgements
        // arrive on separate response streams - no demux needed. Reads fill the data FIFO and
        // writes drain it in the same cycles, fully overlapping read and write latency.
        DmaRunPipe: begin
          setup_transfer_byte    = rd_byte_q;
          setup_chunk_byte       = rd_byte_q;
          capture_transfer_width = 1'b1;

          // Read side: issue while bytes remain and the FIFO (buffered + in-flight) has room.
          if ((rd_byte_q < reg2hw.total_data_size.q) &&
              ((int'(data_depth) + int'(rd_outstanding_q)) < int'(DMA_BURST_FIFO_DEPTH)) &&
              meta_wready) begin
            burst_rd_issue = 1'b1;
            if (read_gnt) begin
              meta_wvalid     = 1'b1;
              rd_byte_d       = rd_byte_q + TRANSFER_BYTES_WIDTH'(transfer_width_d);
              capture_rd_byte = 1'b1;
            end
          end
          if (read_rsp_valid) begin
            if (read_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              meta_rready = 1'b1;
              data_wvalid = 1'b1;
            end
          end
          if ((burst_rd_issue & read_gnt) & ~(read_rsp_valid & ~read_rsp_error) &
              (rd_outstanding_q != BURST_CNT_W'(DMA_BURST_FIFO_DEPTH))) begin
            rd_outstanding_d = rd_outstanding_q + BURST_CNT_W'(1);
          end else if (~(burst_rd_issue & read_gnt) & (read_rsp_valid & ~read_rsp_error) &
                       (rd_outstanding_q != '0)) begin
            rd_outstanding_d = rd_outstanding_q - BURST_CNT_W'(1);
          end

          // Write side: drain the FIFO concurrently on the destination port.
          if (data_rvalid) begin
            burst_wr_issue = 1'b1;
            if (write_gnt) begin
              data_rready = 1'b1;
            end
          end
          if (write_rsp_valid) begin
            if (write_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              transfer_byte_d       = transfer_byte_q + beat_bytes;
              chunk_byte_d          = chunk_byte_q + beat_bytes;
              capture_transfer_byte = 1'b1;
              capture_chunk_byte    = 1'b1;
            end
          end
          if ((burst_wr_issue & write_gnt) & ~(write_rsp_valid & ~write_rsp_error) &
              (wr_outstanding_q != BURST_CNT_W'(DMA_BURST_FIFO_DEPTH))) begin
            wr_outstanding_d = wr_outstanding_q + BURST_CNT_W'(1);
          end else if (~(burst_wr_issue & write_gnt) & (write_rsp_valid & ~write_rsp_error) &
                       (wr_outstanding_q != '0)) begin
            wr_outstanding_d = wr_outstanding_q - BURST_CNT_W'(1);
          end

          // Done when everything has been read into and drained out of the FIFO.
          if ((ctrl_state_d != DmaError) && !data_rvalid && (wr_outstanding_d == '0) &&
              (transfer_byte_d >= reg2hw.total_data_size.q)) begin
            clear_go     = 1'b1;
            ctrl_state_d = DmaIdle;
          end
        end

        DmaShaWait: begin
          // Still waiting for the SHA engine to consume the data
          sha2_valid = 1'b1;

          if (sha2_ready) begin
            // Byte count has already been updated for this transfer
            if (transfer_byte_q >= reg2hw.total_data_size.q) begin
              ctrl_state_d = DmaShaFinalize;
            end else if (chunk_byte_q >= reg2hw.chunk_data_size.q) begin
              // Conditionally clear the `go` bit when not being in hardware handshake mode.
              // In non-hardware handshake mode, finishing one chunk should raise the done IRQ
              // and done bit, and release the `go` bit for the next FW-controlled chunk.
              clear_go     = !control_q.cfg_handshake_en;
              chunk_done   = !control_q.cfg_handshake_en;
              ctrl_state_d = DmaIdle;
            end else begin
              ctrl_state_d = DmaAddrSetup;
            end
          end
        end

        DmaShaFinalize: begin
          if (sha2_hash_done_q) begin
            // Digest is ready, capture it to the CSRs
            sha2_digest_set = 1'b1;
            ctrl_state_d    = DmaIdle;
            clear_go        = 1'b1;
          end
        end

        // Inline AES-GCM: stream the AAD block(s) from the AAD CSRs into GHASH before the text.
        // Hold the current block valid until the wrapper accepts it, then advance; after the last
        // block, begin gathering the first text block.
        DmaAesGhashAad: begin
          aes_feeding_aad  = 1'b1;
          aes_blk_valid_in = 1'b1;
          if (aes_blk_ready_out) begin
            // Full-width terminate compare (zero-extend the 2-bit counter) so the feed count and the
            // wrapper's GHASH length block (built from the full aad_blocks) cannot diverge. The
            // <=2-block cap is enforced in DmaAddrSetup against NumAadWords.
            if ({2'b00, aes_aad_blk_cnt_q} == (aes_aad_blocks - 4'd1)) begin
              aes_aad_blk_cnt_d  = 2'd0;
              aes_aad_blk_cnt_en = 1'b1;
              aes_word_cnt_d     = 2'd0;
              aes_word_cnt_en    = 1'b1;
              ctrl_state_d       = DmaAesGather;
            end else begin
              aes_aad_blk_cnt_d  = aes_aad_blk_cnt_q + 2'd1;
              aes_aad_blk_cnt_en = 1'b1;
            end
          end
        end

        // Inline AES: gather a 16-byte block from 4 read beats (one outstanding read at a time),
        // honoring source increment; present the block to the engine on word 3.
        DmaAesGather: begin
          aes_rd_inflight_d = (aes_rd_inflight_q | (rd_issue && read_gnt)) & ~aes_read_rsp_qual;
          if (aes_read_rsp_qual) begin
            if (read_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              aes_gather_capture = 1'b1;
              if (aes_word_cnt_q != 2'd3) begin
                aes_word_cnt_d  = aes_word_cnt_q + 2'd1;
                aes_word_cnt_en = 1'b1;
              end else begin
                aes_word_cnt_d      = 2'd0;
                aes_word_cnt_en     = 1'b1;
                aes_blk_consumed_d  = 1'b0;
                aes_blk_consumed_en = 1'b1;
                ctrl_state_d        = DmaAesProcess;
              end
            end
          end
        end

        // Inline AES: present the gathered block until the engine accepts it, then wait for the
        // produced block and latch it into the scatter buffer.
        DmaAesProcess: begin
          aes_blk_valid_in = !aes_blk_consumed_q;
          if (aes_blk_valid_in && aes_blk_ready_out) begin
            aes_blk_consumed_d  = 1'b1;
            aes_blk_consumed_en = 1'b1;
          end
          if (aes_blk_valid_out) begin
            aes_scatter_capture = 1'b1;
            aes_word_cnt_d      = 2'd0;
            aes_word_cnt_en     = 1'b1;
            ctrl_state_d        = DmaAesScatter;
          end
        end

        // Inline AES: scatter the produced block as 4 write beats (one outstanding write at a time),
        // honoring destination increment and advancing byte counters by 4 each beat. After the
        // last beat, either gather the next block, finalize the tag (GCM), or complete (CTR).
        DmaAesScatter: begin
          aes_wr_inflight_d = (aes_wr_inflight_q | (wr_issue && write_gnt)) & ~aes_write_rsp_qual;
          if (aes_write_rsp_qual) begin
            if (write_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              transfer_byte_d       = transfer_byte_q + TRANSFER_BYTES_WIDTH'(4);
              chunk_byte_d          = chunk_byte_q + TRANSFER_BYTES_WIDTH'(4);
              capture_transfer_byte = 1'b1;
              capture_chunk_byte    = 1'b1;
              if (aes_word_cnt_q != 2'd3) begin
                aes_word_cnt_d  = aes_word_cnt_q + 2'd1;
                aes_word_cnt_en = 1'b1;
              end else begin
                aes_word_cnt_d  = 2'd0;
                aes_word_cnt_en = 1'b1;
                if (transfer_byte_d >= reg2hw.total_data_size.q) begin
                  if (control_q.aes_gcm) begin
                    // GCM: the engine still finalizes GHASH and produces the tag.
                    ctrl_state_d = DmaAesTag;
                  end else begin
                    // CTR: flush the engine and complete.
                    aes_clear    = 1'b1;
                    clear_go     = 1'b1;
                    ctrl_state_d = DmaIdle;
                  end
                end else if (chunk_byte_d >= reg2hw.chunk_data_size.q) begin
                  // Retain CTR/GHASH and configuration. Hardware handshake keeps GO/BUSY
                  // asserted and waits in Idle for the next enabled trigger.
                  clear_go = !control_q.cfg_handshake_en;
                  chunk_done = !control_q.cfg_handshake_en;
                  ctrl_state_d = DmaIdle;
                end else begin
                  // Next block within this chunk.
                  ctrl_state_d = DmaAesGather;
                end
              end
            end
          end
        end

        // Inline AES-GCM: wait for the tag. Encrypt publishes it (TAG_OUT + tag_valid); decrypt
        // accepts ONLY on the hardened compare (aes_tag_ok), else raises tag_failed + DmaAesTagErr
        // and suppresses `done`.
        //
        // DECRYPT QUARANTINE CONTRACT (release-of-unverified-plaintext): streaming AEAD decrypt
        // cannot defer the destination writes until the tag is known (a transfer may exceed any
        // feasible on-chip buffer), so the decrypted plaintext is already written to the destination
        // before the tag is checked. On mismatch `done` is never set (we go to DmaError; enforced by
        // AesTagFailNoDone_A / AesTagFailNoDoneStatus_A, so the done interrupt cannot fire) and
        // STATUS.tag_failed is raised. SW MUST therefore gate every consumer of the destination on
        // STATUS.tag_valid and wipe the buffer on tag_failed.
        //
        // TAPEOUT DECISION: this SW-quarantine contract is the accepted v1 behaviour. A hardware
        // destination-zeroize on tag error remains a tracked hardening item; it is NOT required
        // for v1 because (a) done/interrupt suppression is hardware-enforced above and (b) the
        // architectural contract requires consumers to wait for tag_valid before reading.
        DmaAesTag: begin
          if (aes_tag_valid) begin
            if (!aes_decrypt) begin
              aes_tag_valid_set = 1'b1;
              aes_clear         = 1'b1;
              clear_go          = 1'b1;
              ctrl_state_d      = DmaIdle;
            end else if (aes_tag_ok) begin
              aes_tag_valid_set = 1'b1;
              aes_clear         = 1'b1;
              clear_go          = 1'b1;
              ctrl_state_d      = DmaIdle;
            end else begin
              aes_tag_mismatch_set     = 1'b1;
              next_error[DmaAesTagErr] = 1'b1;
              ctrl_state_d             = DmaError;
            end
          end
        end

        // Wait here until the error is cleared
        DmaError: begin
          if (control_q.aes_en) aes_clear = 1'b1;
          if (!reg2hw.status.error.q && dma_drained) begin
            ctrl_state_d = DmaIdle;
            clear_go     = 1'b1;
          end
        end

        default: begin
          // Should not be reachable
          dma_state_error = 1'b1;
        end
      endcase
    end
  end

  // Combinational address / byte-enable / transfer-width setup for the beat selected by the
  // setup counters. Used both for the first beat of a chunk (DmaAddrSetup, setup_* = current
  // registered counts) and for the folded per-beat advance on the plain-copy path
  // (setup_* = post-advance counts), so the dedicated per-word setup cycle is removed.
  always_comb begin : p_addr_be_setup
    // Convert the transfer-width encoding to bytes per transaction (validity checked once in
    // DmaCfgValidate).
    unique case (reg2hw.transfer_width.q)
      DmaXfer1BperTxn: transfer_width_d = 3'b001;
      DmaXfer2BperTxn: transfer_width_d = 3'b010;
      DmaXfer4BperTxn: transfer_width_d = 3'b100;
      default:         transfer_width_d = 3'b000;
    endcase

    // Source/destination address for the beat selected by the setup counters, computed as an
    // absolute base+offset so it does not depend on the previous beat's registered address.
    // This makes the computation usable both by the serial datapath (which still captures the
    // result) and by the read-ahead burst datapath (which issues from the live position):
    //  - fixed-address mode: always the base address;
    //  - incrementing modes: base + offset within the current chunk. The architectural address
    //    registers are advanced at each chunk boundary, so using the cumulative transfer count
    //    here would advance twice on every chunk after the first.
    if (!do_read || (reg2hw.src_config.increment.q == AddrNoIncrement)) begin
      src_addr_d = {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q};
    end else begin
      src_addr_d = {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q} +
                   DMA_ADDR_WIDTH'(setup_chunk_byte);
    end

    if (!do_write || (reg2hw.dst_config.increment.q == AddrNoIncrement)) begin
      dst_addr_d = {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q};
    end else begin
      dst_addr_d = {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q} +
                   DMA_ADDR_WIDTH'(setup_chunk_byte);
    end

    unique case (transfer_width_d)
      3'b001: begin
        req_dst_be_d = top_pkg::TL_DBW'('b0001) << dst_addr_d[1:0];
        req_src_be_d = top_pkg::TL_DBW'('b0001) << src_addr_d[1:0];
      end
      3'b010: begin
        if (remaining_bytes >= TRANSFER_BYTES_WIDTH'(transfer_width_d)) begin
          req_dst_be_d = top_pkg::TL_DBW'('b0011) << dst_addr_d[1:0];
          req_src_be_d = top_pkg::TL_DBW'('b0011) << src_addr_d[1:0];
        end else begin
          req_dst_be_d = top_pkg::TL_DBW'('b0001) << dst_addr_d[1:0];
          req_src_be_d = top_pkg::TL_DBW'('b0001) << src_addr_d[1:0];
        end
      end
      3'b100: begin
        if (remaining_bytes >= TRANSFER_BYTES_WIDTH'(transfer_width_d)) begin
          req_dst_be_d = {top_pkg::TL_DBW{1'b1}};
        end else begin
          unique case (remaining_bytes)
            TRANSFER_BYTES_WIDTH'('h1): req_dst_be_d = top_pkg::TL_DBW'('b0001);
            TRANSFER_BYTES_WIDTH'('h2): req_dst_be_d = top_pkg::TL_DBW'('b0011);
            TRANSFER_BYTES_WIDTH'('h3): req_dst_be_d = top_pkg::TL_DBW'('b0111);
            default:                    req_dst_be_d = top_pkg::TL_DBW'('b1111);
          endcase
        end
        req_src_be_d = req_dst_be_d;  // for 4B, src strobes always equal dst
      end
      default: begin
        req_dst_be_d = top_pkg::TL_DBW'('b0000);
        req_src_be_d = top_pkg::TL_DBW'('b0000);
      end
    endcase
  end

  // Sub-word selection and replication across the bus width, such that it is available to the
  // destination for any address alignment.
  always_comb begin
    unique case (transfer_width_q)
      // 1B/txn - steer the selected byte to all byte lanes
      3'b001:
      unique casez (req_src_be_q)
        4'b1???: read_return_data_d = {4{dma_rsp_data[31:24]}};
        4'b01??: read_return_data_d = {4{dma_rsp_data[23:16]}};
        4'b001?: read_return_data_d = {4{dma_rsp_data[15:8]}};
        default: read_return_data_d = {4{dma_rsp_data[7:0]}};
      endcase
      // 2B/txn - select and duplicate the appropriate half-word
      // Note that for the final transaction of a transfer, there may be only a single strobe set.
      3'b010:
      read_return_data_d = {2{|req_src_be_q[1:0] ? dma_rsp_data[15:0] : dma_rsp_data[31:16]}};
      default: read_return_data_d = dma_rsp_data;
    endcase
  end


  prim_flop_en #(
      .Width(top_pkg::TL_DW)
  ) aff_read_return_data (
      .clk_i (gated_clk),
      .rst_ni(rst_ni),
      .en_i  (capture_return_data),
      .d_i   (read_return_data_d),
      .q_o   (read_return_data_q)
  );

  // ------------------------------------------------------------------------------------------
  // Read-ahead burst datapath: state flops, FIFOs and per-beat steering
  // ------------------------------------------------------------------------------------------
  prim_flop_en #(
      .Width(1)
  ) aff_fast_mode (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(capture_fast_mode),
      .d_i(fast_mode_d),
      .q_o(fast_mode_q)
  );
  prim_flop_en #(
      .Width(TRANSFER_BYTES_WIDTH)
  ) aff_rd_byte (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .en_i(capture_rd_byte),
      .d_i(rd_byte_d),
      .q_o(rd_byte_q)
  );
  prim_flop #(
      .Width(BURST_CNT_W)
  ) aff_rd_outstanding (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .d_i(rd_outstanding_d),
      .q_o(rd_outstanding_q)
  );
  prim_flop #(
      .Width(BURST_CNT_W)
  ) aff_wr_outstanding (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .d_i(wr_outstanding_d),
      .q_o(wr_outstanding_q)
  );

  // Per-port outstanding-transaction counters: +1 on an accepted request, -1 on a response.
  // They count reads, writes and interrupt-clear writes uniformly across the generic ports.
  always_comb begin
    port_outst_d = port_outst_q;
    for (int unsigned i = 0; i < NumPorts; i++) begin
      unique case ({
        port_req[i] & port_gnt[i], port_rvalid[i]
      })
        2'b10:
        if (&port_outst_q[i]) port_outst_d[i] = port_outst_q[i];
        else port_outst_d[i] = port_outst_q[i] + PORT_OUTST_W'(1);
        2'b01:
        if (port_outst_q[i] == '0) port_outst_d[i] = '0;
        else port_outst_d[i] = port_outst_q[i] - PORT_OUTST_W'(1);
        default: ;
      endcase
    end
  end
  prim_flop #(
      .Width(NumPorts * PORT_OUTST_W)
  ) aff_port_outst (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .d_i(port_outst_d),
      .q_o(port_outst_q)
  );
  // A new transfer may only begin once all TL-UL ports have no responses outstanding, so a
  // prior aborted/errored transfer's late responses cannot bleed into it.
  assign dma_drained = !(|port_outst_q);
  assign abort_complete = cfg_abort_en && dma_drained;

  // Outstanding-counter bounds assertions (must never underflow: a response implies a prior
  // accepted request still outstanding).
  for (genvar p = 0; p < NumPorts; p++) begin : gen_port_outst_assert
    `ASSERT(PortOutstNoUnderflow_A,
            port_rvalid[p] |-> ((port_outst_q[p] != '0) || (port_req[p] && port_gnt[p])), gated_clk,
            !rst_ni)
  end

  // The DMA-enabled-range membership check (DmaCfgValidate) bounds the access using
  // chunk_data_size; the burst path accesses total_data_size bytes. This is only safe because
  // fast mode requires chunk_data_size >= total_data_size. Assert that invariant locally so
  // the range-check safety is not merely emergent.
  `ASSERT(FastModeChunkGeTotal_A,
          fast_mode_q |-> (reg2hw.chunk_data_size.q >= reg2hw.total_data_size.q), gated_clk,
          !rst_ni)

  // Per-beat metadata pushed at read issue, popped at read response.
  assign meta_wdata = '{
          dst_addr: dst_addr_d,
          dst_be: req_dst_be_d,
          src_be: req_src_be_d,
          width: transfer_width_d
      };
  prim_fifo_sync #(
      .Width($bits(dma_burst_meta_t)),
      .Pass (1'b0),
      .Depth(DMA_BURST_FIFO_DEPTH)
  ) u_burst_meta_fifo (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .clr_i(cfg_abort_en | (ctrl_state_q == DmaError)),
      .wvalid_i(meta_wvalid),
      .wready_o(meta_wready),
      .wdata_i(meta_wdata),
      .rvalid_o(meta_rvalid),
      .rready_i(meta_rready),
      .rdata_o(meta_rdata),
      .full_o(),
      .depth_o(),
      .err_o(meta_fifo_err)
  );

  // Steer the read response according to the responding beat's metadata, then push into the
  // data FIFO together with the destination address / byte-enables / last flag.
  always_comb begin
    unique case (meta_rdata.width)
      3'b001:
      unique casez (meta_rdata.src_be)
        4'b1???: burst_steered_data = {4{dma_rsp_data[31:24]}};
        4'b01??: burst_steered_data = {4{dma_rsp_data[23:16]}};
        4'b001?: burst_steered_data = {4{dma_rsp_data[15:8]}};
        default: burst_steered_data = {4{dma_rsp_data[7:0]}};
      endcase
      3'b010:
      burst_steered_data = {2{|meta_rdata.src_be[1:0] ? dma_rsp_data[15:0] : dma_rsp_data[31:16]}};
      default: burst_steered_data = dma_rsp_data;
    endcase
  end
  assign data_wdata = '{
          data: burst_steered_data,
          dst_addr: meta_rdata.dst_addr,
          dst_be: meta_rdata.dst_be
      };
  prim_fifo_sync #(
      .Width($bits(dma_burst_data_t)),
      .Pass (1'b0),
      .Depth(DMA_BURST_FIFO_DEPTH)
  ) u_burst_data_fifo (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .clr_i(cfg_abort_en | (ctrl_state_q == DmaError)),
      .wvalid_i(data_wvalid),
      .wready_o(data_wready),
      .wdata_i(data_wdata),
      .rvalid_o(data_rvalid),
      .rready_i(data_rready),
      .rdata_o(data_rdata),
      .full_o(),
      .depth_o(data_depth),
      .err_o(data_fifo_err)
  );

  // Mux the data for the SHA2 engine. When capturing the data we
  // can use the data from the bus, otherwise the captured data from the flop
  //
  // Note: the SHA2 logic expects the `data` and `mask` fields to be populated from the MSBs down.
  // SHA2 consumes read data. Verify has no destination write, so use the source
  // byte-enable directly rather than a stale destination mask.
  assign sha2_data.data = {<<8{capture_return_data? read_return_data_d: read_return_data_q}};
  assign sha2_data.mask = {<<1{req_src_be_q}};

  // Interrupt logic
  prim_intr_hw #(
      .IntrT("Status")
  ) u_intr_dma_done (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .event_intr_i          (reg2hw.status.done.q),
      .reg2hw_intr_enable_q_i(reg2hw.intr_enable.dma_done.q),
      .reg2hw_intr_test_q_i  (reg2hw.intr_test.dma_done.q),
      .reg2hw_intr_test_qe_i (reg2hw.intr_test.dma_done.qe),
      .reg2hw_intr_state_q_i (reg2hw.intr_state.dma_done.q),
      .hw2reg_intr_state_de_o(hw2reg.intr_state.dma_done.de),
      .hw2reg_intr_state_d_o (hw2reg.intr_state.dma_done.d),
      .intr_o                (intr_dma_done_o)
  );

  prim_intr_hw #(
      .IntrT("Status")
  ) u_intr_chunk_dma_done (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .event_intr_i          (reg2hw.status.chunk_done.q),
      .reg2hw_intr_enable_q_i(reg2hw.intr_enable.dma_chunk_done.q),
      .reg2hw_intr_test_q_i  (reg2hw.intr_test.dma_chunk_done.q),
      .reg2hw_intr_test_qe_i (reg2hw.intr_test.dma_chunk_done.qe),
      .reg2hw_intr_state_q_i (reg2hw.intr_state.dma_chunk_done.q),
      .hw2reg_intr_state_de_o(hw2reg.intr_state.dma_chunk_done.de),
      .hw2reg_intr_state_d_o (hw2reg.intr_state.dma_chunk_done.d),
      .intr_o                (intr_dma_chunk_done_o)
  );

  prim_intr_hw #(
      .IntrT("Status")
  ) u_intr_error (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .event_intr_i          (reg2hw.status.error.q),
      .reg2hw_intr_enable_q_i(reg2hw.intr_enable.dma_error.q),
      .reg2hw_intr_test_q_i  (reg2hw.intr_test.dma_error.q),
      .reg2hw_intr_test_qe_i (reg2hw.intr_test.dma_error.qe),
      .reg2hw_intr_state_q_i (reg2hw.intr_state.dma_error.q),
      .hw2reg_intr_state_de_o(hw2reg.intr_state.dma_error.de),
      .hw2reg_intr_state_d_o (hw2reg.intr_state.dma_error.d),
      .intr_o                (intr_dma_error_o)
  );

  logic data_move_state;
  logic update_dst_addr_reg, update_src_addr_reg;

  assign data_move_state = (ctrl_state_q == DmaSendWrite)         ||
                           (ctrl_state_q == DmaWaitWriteResponse) ||
                           (ctrl_state_q == DmaWriteBurst)        ||
                           (ctrl_state_q == DmaRunPipe)           ||
                           (ctrl_state_q == DmaShaWait)           ||
                           (ctrl_state_q == DmaShaFinalize)       ||
                           (ctrl_state_q == DmaAesScatter)        ||
                           (ctrl_state_q == DmaAesTag);



  // Calculate the number of bytes remaining until the end of the current chunk.
  // Note that the total transfer size may be a non-integral multiple of the programmed chunk size,
  // so we must consider the `total_data_size` here too; this is important in determining the
  // correct write strobes for the final word of the transfer.
  // Bytes remaining for the beat currently being set up (selected by the setup counters).
  // These feed the byte-enable computation in p_addr_be_setup so the final, possibly partial,
  // word of a transfer/chunk gets the correct strobes - for both the first beat and the
  // folded per-beat advance.
  assign transfer_remaining_bytes = reg2hw.total_data_size.q - setup_transfer_byte;
  assign chunk_remaining_bytes = reg2hw.chunk_data_size.q - setup_chunk_byte;
  assign remaining_bytes = (transfer_remaining_bytes < chunk_remaining_bytes) ?
                            transfer_remaining_bytes : chunk_remaining_bytes;

  // Match the byte-enable clamp on the beat being committed. Use only registered counters here:
  // `setup_*` may already select the next beat in the same cycle, so feeding it back into the
  // completion counters would form a combinational loop.
  assign committed_remaining =
      ((reg2hw.total_data_size.q - transfer_byte_q) <
       (reg2hw.chunk_data_size.q - chunk_byte_q)) ?
      (reg2hw.total_data_size.q - transfer_byte_q) :
      (reg2hw.chunk_data_size.q - chunk_byte_q);
  assign beat_bytes = (committed_remaining < TRANSFER_BYTES_WIDTH'(transfer_width_q)) ?
                      committed_remaining : TRANSFER_BYTES_WIDTH'(transfer_width_q);

  // Range-check span per endpoint: a fixed (non-incrementing) address only ever accesses the single
  // transfer word [addr, addr+width-1]; an incrementing address spans the chunk
  // [addr, addr+remaining_bytes-1] (a wrapping chunk re-uses that span each chunk). Using the chunk
  // span for a fixed address would spuriously reject a legal FIFO word near the range limit.
  assign xfer_width_bytes = TRANSFER_BYTES_WIDTH'(1) << reg2hw.transfer_width.q;
  assign src_range_span =
      (reg2hw.src_config.increment.q == AddrNoIncrement) ? xfer_width_bytes : remaining_bytes;
  assign dst_range_span =
      (reg2hw.dst_config.increment.q == AddrNoIncrement) ? xfer_width_bytes : remaining_bytes;

  // Byte-enable for one beat: one-hot transfer width (bytes), beat address[1:0], and bytes
  // remaining (min of chunk and transfer). Shared by the first beat and the next-beat path.
  function automatic logic [top_pkg::TL_DBW-1:0] dma_compute_be(
      input logic [2:0]                      xfer_width,
      input logic [1:0]                      addr_lo,
      input logic [TRANSFER_BYTES_WIDTH-1:0] remaining);
    logic [top_pkg::TL_DBW-1:0] be;
    unique case (xfer_width)
      3'b001: begin
        be = top_pkg::TL_DBW'('b0001) << addr_lo;
      end
      3'b010: begin
        if (remaining >= TRANSFER_BYTES_WIDTH'(xfer_width)) begin
          be = top_pkg::TL_DBW'('b0011) << addr_lo;
        end else begin
          be = top_pkg::TL_DBW'('b0001) << addr_lo;
        end
      end
      3'b100: begin
        if (remaining >= TRANSFER_BYTES_WIDTH'(xfer_width)) begin
          be = {top_pkg::TL_DBW{1'b1}};
        end else begin
          unique case (remaining)
            TRANSFER_BYTES_WIDTH'('h1): be = top_pkg::TL_DBW'('b0001);
            TRANSFER_BYTES_WIDTH'('h2): be = top_pkg::TL_DBW'('b0011);
            TRANSFER_BYTES_WIDTH'('h3): be = top_pkg::TL_DBW'('b0111);
            default:                    be = top_pkg::TL_DBW'('b1111);
          endcase
        end
      end
      default: begin
        be = top_pkg::TL_DBW'('b0000);
      end
    endcase
    return be;
  endfunction

  always_comb begin
    // Because of using the primitives for interrupt handling, the hw2reg registers cannot be
    // collectively assigned a default value since that would create a second driver to the
    // interrupt registers.
    // Thus we must ensure that all registers are initialized manually to avoid creating latches.

    // Clear the `go` bit if we are in a single transfer and finished the DMA operation,
    // hardware handshake mode when we finished all transfers, or when aborting the transfer.
    hw2reg.control.go.de = clear_go || abort_complete;
    hw2reg.control.go.d = 1'b0;

    // Unlock the register set when not busy. IDLE is not the right indicator,
    // since multi-chunked transfers roundtrip via IDLE.
    hw2reg.cfg_regwen.d =
        prim_mubi_pkg::mubi4_bool_to_mubi(!(reg2hw.status.busy.q || aes_session_q));

    // Advance by the bytes actually moved in the completed chunk. This differs from the programmed
    // chunk size for a partial final chunk.
    new_dst_addr = {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q} +
                    DMA_ADDR_WIDTH'(chunk_byte_d);
    new_src_addr = {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q} +
                    DMA_ADDR_WIDTH'(chunk_byte_d);

    // If we are in multi-chunk mode, we need to update the register addresses since they are needed
    // for the next chunk. Do this only when going back to Idle and when we are incrementing the
    // address but not doing wrap-around.
    update_dst_addr_reg = 1'b0;
    update_src_addr_reg = 1'b0;
    if (data_move_state && (ctrl_state_d == DmaIdle)) begin
      // Memset (no read) keeps `src_addr_lo` as the fill pattern; writing back the chunk-advanced
      // source address would corrupt it, so suppress the source write-back.
      if (do_read &&
          reg2hw.src_config.increment.q == AddrIncrement &&
          reg2hw.src_config.wrap.q == AddrNoWrapChunk) begin
        update_src_addr_reg = 1'b1;
      end
      // Verify (no write) never advances a destination address, so suppress its write-back.
      if (do_write &&
          reg2hw.dst_config.increment.q == AddrIncrement &&
          reg2hw.dst_config.wrap.q == AddrNoWrapChunk) begin
        update_dst_addr_reg = 1'b1;
      end
    end

    hw2reg.dst_addr_hi.de = update_dst_addr_reg;
    hw2reg.dst_addr_hi.d = new_dst_addr[63:32];

    hw2reg.dst_addr_lo.de = update_dst_addr_reg;
    hw2reg.dst_addr_lo.d = new_dst_addr[31:0];

    hw2reg.src_addr_hi.de = update_src_addr_reg;
    hw2reg.src_addr_hi.d = new_src_addr[63:32];

    hw2reg.src_addr_lo.de = update_src_addr_reg;
    hw2reg.src_addr_lo.d = new_src_addr[31:0];

    hw2reg.control.initial_transfer.de = 1'b0;
    hw2reg.control.initial_transfer.d = 1'b0;
    // Clear the `initial transfer` flag when leaving the DmaIdle state the first time.
    if ((ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle) &&
        reg2hw.control.initial_transfer.q) begin
      hw2reg.control.initial_transfer.de = 1'b1;
    end

    // Assert busy write enable on
    // - transitions from IDLE out
    // - clearing the `go` bit (going back to idle)
    // - abort                 (going back to idle)
    hw2reg.status.busy.de = ((ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle)) ||
                            clear_go                                                 ||
                            abort_complete;
    // If transitioning from IDLE, set busy, otherwise clear it
    hw2reg.status.busy.d = ((ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle)) ? 1'b1 : 1'b0;

    // Status is cleared when leaving the IDLE state the first time, i.e., when busy is not yet set
    // A rejected attempt to replace a suspended AES session enters Error directly from Idle;
    // its error and error code must take priority over the start-of-chunk status clear.
    clear_status = (ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle) &&
                   (ctrl_state_d != DmaError) && !reg2hw.status.busy.q;
    // The SHA digest valid and the digest itself needs to incorporate the initial transfer flag as
    // busy is deasserted for every chunk in the middle of a multi-chunk memory-to-memory transfer
    clear_sha_status = (ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle) &&
                       reg2hw.control.initial_transfer.q;

    // Set the done bit only when finishing all chunks. Automatically clear the done bit when
    // starting a new transfer
    hw2reg.status.done.de = ((!cfg_abort_en) && data_move_state && clear_go && ~chunk_done) |
                            clear_status;
    hw2reg.status.done.d = clear_status ? 1'b0 : 1'b1;

    hw2reg.status.error.de = (ctrl_state_d == DmaError) | clear_status;
    hw2reg.status.error.d = clear_status ? 1'b0 : 1'b1;

    hw2reg.status.aborted.de = abort_complete | clear_status;
    hw2reg.status.aborted.d = clear_status ? 1'b0 : 1'b1;

    hw2reg.status.sha2_digest_valid.de = sha2_digest_set | clear_sha_status;
    hw2reg.status.sha2_digest_valid.d = sha2_digest_set;

    hw2reg.status.chunk_done.de = ((!cfg_abort_en) && chunk_done) | clear_status;
    hw2reg.status.chunk_done.d = clear_status ? 1'b0 : 1'b1;

    // Write digest to CSRs when needed. The digest is an 8-element 64-bit datatype. Depending on
    // the selected hashing algorithm, the digest is stored differently in the digest datatype:
    // SHA2-256: digest[0-7][31:0] store the 256-bit digest. The upper 32-bits of all digest
    //           elements are zero
    // SHA2-384: digest[0-5][63:0] store the 384-bit digest.
    // SHA2-512: digest[0-7][63:0] store the 512-bit digest.
    for (int i = 0; i < NR_SHA_DIGEST_ELEMENTS; i++) begin
      hw2reg.sha2_digest[i].de = sha2_digest_set | clear_sha_status;
      hw2reg.sha2_digest[i].d  = '0;
    end

    // Only mux the digest data when sha2_digest_set is set. Setting the digest happens during the
    // DmaFinalze state, where we need to use the stored and locked `digest_sel` value.
    // In case of clear_sha_status being asserted, the default value from hw2reg = '0; clears
    // the digest
    if (sha2_digest_set) begin
      for (int unsigned i = 0; i < NR_SHA_DIGEST_ELEMENTS / 2; i++) begin
        unique case (digest_sel)
          DigestSha256: begin
            hw2reg.sha2_digest[i].d =
                conv_endian32(sha2_digest[i][0+:32], control_q.cfg_digest_swap);
          end
          DigestSha384: begin
            if (i < 6) begin
              hw2reg.sha2_digest[i*2].d =
                  conv_endian32(sha2_digest[i][32+:32], control_q.cfg_digest_swap);
              hw2reg.sha2_digest[(i*2)+1].d =
                  conv_endian32(sha2_digest[i][0+:32], control_q.cfg_digest_swap);
            end
          end
          default: begin  // SHA2-512
            hw2reg.sha2_digest[i*2].d =
                conv_endian32(sha2_digest[i][32+:32], control_q.cfg_digest_swap);
            hw2reg.sha2_digest[(i*2)+1].d =
                conv_endian32(sha2_digest[i][0+:32], control_q.cfg_digest_swap);
          end
        endcase
      end
    end

    // Set the error code only when entering the error state
    set_error_code = (ctrl_state_q != DmaError) && (ctrl_state_d == DmaError);

    // Fiddle out error signals
    hw2reg.error_code.src_addr_error.de = set_error_code | clear_status;
    hw2reg.error_code.dst_addr_error.de = set_error_code | clear_status;
    hw2reg.error_code.opcode_error.de = set_error_code | clear_status;
    hw2reg.error_code.size_error.de = set_error_code | clear_status;
    hw2reg.error_code.bus_error.de = set_error_code | clear_status;
    hw2reg.error_code.base_limit_error.de = set_error_code | clear_status;
    hw2reg.error_code.range_valid_error.de = set_error_code | clear_status;
    hw2reg.error_code.asid_error.de = set_error_code | clear_status;

    hw2reg.error_code.src_addr_error.d = clear_status ? '0 : next_error[DmaSrcAddrErr];
    hw2reg.error_code.dst_addr_error.d = clear_status ? '0 : next_error[DmaDstAddrErr];
    hw2reg.error_code.opcode_error.d = clear_status ? '0 : next_error[DmaOpcodeErr];
    hw2reg.error_code.size_error.d = clear_status ? '0 : next_error[DmaSizeErr];
    hw2reg.error_code.bus_error.d = clear_status ? '0 : next_error[DmaBusErr];
    hw2reg.error_code.base_limit_error.d = clear_status ? '0 : next_error[DmaBaseLimitErr];
    hw2reg.error_code.range_valid_error.d = clear_status ? '0 : next_error[DmaRangeValidErr];
    hw2reg.error_code.asid_error.d = clear_status ? '0 : next_error[DmaAsidErr];

    // Clear the `control.abort` bit once we have handled the abort request
    hw2reg.control.abort.de = hw2reg.status.aborted.de;
    hw2reg.control.abort.d = 1'b0;

    // Clear the error code if the error flag is cleared (RW1C)
    if (reg2hw.status.error.qe & reg2hw.status.error.q) begin
      // Clear all errors
      hw2reg.error_code.src_addr_error.de    = 1'b1;
      hw2reg.error_code.dst_addr_error.de    = 1'b1;
      hw2reg.error_code.opcode_error.de      = 1'b1;
      hw2reg.error_code.size_error.de        = 1'b1;
      hw2reg.error_code.bus_error.de         = 1'b1;
      hw2reg.error_code.base_limit_error.de  = 1'b1;
      hw2reg.error_code.range_valid_error.de = 1'b1;
      hw2reg.error_code.asid_error.de        = 1'b1;

      hw2reg.error_code.src_addr_error.d     = 1'b0;
      hw2reg.error_code.dst_addr_error.d     = 1'b0;
      hw2reg.error_code.opcode_error.d       = 1'b0;
      hw2reg.error_code.size_error.d         = 1'b0;
      hw2reg.error_code.bus_error.d          = 1'b0;
      hw2reg.error_code.base_limit_error.d   = 1'b0;
      hw2reg.error_code.range_valid_error.d  = 1'b0;
      hw2reg.error_code.asid_error.d         = 1'b0;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Inline AES register interface
  //////////////////////////////////////////////////////////////////////////////
  // Drive the AES result registers from the sub-FSM. KEY_SHARE/IV/AAD/TAG_IN are reggen-stored and
  // captured by the wrapper at start; they are HW-wiped (SEC_CM KEY.SEC_WIPE / IV.CONFIG.SEC_WIPE)
  // when the operation ends, aborts, or errors, so no key/IV/tag residue is left in the CSR storage.
  // (v1 zeroizes; a pseudo-random wipe value is the production enhancement.)
  logic aes_err_clr;
  logic aes_wipe;
  logic aes_status_clear;
  assign aes_err_clr = reg2hw.status.error.qe & reg2hw.status.error.q;
  // An armed handshake transfer can wait indefinitely in Idle. Invalidate the previous
  // message's authentication result before the first trigger, not only when leaving Idle.
  assign aes_status_clear = clear_status ||
      ((ctrl_state_q == DmaIdle) && reg2hw.control.go.q &&
       reg2hw.control.initial_transfer.q && !reg2hw.status.busy.q && !aes_session_q);
  // SEC_CM: KEY.SEC_WIPE
  // Wipe the inline-AES key/IV/AAD/TAG_IN CSR copies on clear, abort or error (v1 zeroizes; a
  // pseudo-random wipe value is the production enhancement). The aes_core-internal key/IV/GHASH
  // state is wiped via the held key_iv_data_in_clear trigger (see dma_aes clr_hold).
  assign aes_wipe = aes_clear || cfg_abort_en || (ctrl_state_q == DmaError);
  always_comb begin
    // tag_valid / tag_failed: set by the tag state, cleared at the start of a new transfer.
    hw2reg.status.tag_valid.de = aes_tag_valid_set | aes_status_clear;
    hw2reg.status.tag_valid.d = aes_status_clear ? 1'b0 : 1'b1;
    hw2reg.status.tag_failed.de = aes_tag_mismatch_set | aes_status_clear;
    hw2reg.status.tag_failed.d = aes_status_clear ? 1'b0 : 1'b1;

    // Decrypt tag mismatch surfaced as a DMA error (cleared on start or the RW1C error clear).
    hw2reg.error_code.aes_tag_error.de = set_error_code | clear_status | aes_err_clr;
    hw2reg.error_code.aes_tag_error.d  = (clear_status | aes_err_clr) ? 1'b0
                                                                      : next_error[DmaAesTagErr];

    for (int unsigned i = 0; i < 8; i++) begin
      hw2reg.key_share0[i].de = aes_wipe;
      hw2reg.key_share0[i].d  = '0;
      hw2reg.key_share1[i].de = aes_wipe;
      hw2reg.key_share1[i].d  = '0;
    end
    for (int unsigned i = 0; i < NumAadWords; i++) begin
      hw2reg.aad[i].de = aes_wipe;
      hw2reg.aad[i].d  = '0;
    end
    for (int unsigned i = 0; i < 4; i++) begin
      hw2reg.iv[i].de     = aes_wipe;
      hw2reg.iv[i].d      = '0;
      hw2reg.tag_in[i].de = aes_wipe;
      hw2reg.tag_in[i].d  = '0;
      // TAG_OUT is hwext: HW continuously presents the wrapper-held computed tag (SW reads it gated
      // by STATUS.tag_valid).
      hw2reg.tag_out[i].d = aes_tag_out[i*32+:32];
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Unused signals
  //////////////////////////////////////////////////////////////////////////////
  logic unused_signals;
  assign unused_signals = ^{reg2hw.enabled_memory_range_base.qe,
                            reg2hw.enabled_memory_range_limit.qe,
                            reg2hw.range_regwen.q,
      // Read-ahead burst datapath: status bits not consumed (flow is
      // governed by the outstanding counters and data_depth) and the
      // word-aligned issue-address LSBs.
      meta_rvalid, data_wready, rd_issue_addr[1:0], wr_issue_addr[1:0]};

  // TAG_OUT is HW-driven (hwext); its reg2hw read-back path is unused by the DMA.
  logic unused_aes_signals;
  assign unused_aes_signals = ^{reg2hw.tag_out};

  //////////////////////////////////////////////////////////////////////////////
  // Assertions
  //////////////////////////////////////////////////////////////////////////////

  // All outputs should be known values after reset
  `ASSERT_KNOWN(AlertsKnown_A, alert_tx_o)
  `ASSERT_KNOWN_IF(RaclErrorOKnown_A, racl_error_o, racl_error_o.valid)
  `ASSERT_KNOWN(IntrDmaDoneKnown_A, intr_dma_done_o)
  `ASSERT_KNOWN(IntrDmaChunkDoneKnown_A, intr_dma_chunk_done_o)
  `ASSERT_KNOWN(IntrDmaErrorKnown_A, intr_dma_error_o)

  `ASSERT_KNOWN(TlDValidKnownO_A, tl_d_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_d_o.a_ready)

  // 32-bit host ports
  for (genvar i = 0; i < NumTlul32; i++) begin : gen_host_tl_known_a
    `ASSERT_KNOWN(HostTlAValidKnownO_A, host32_tl_h_o[i].a_valid)
    `ASSERT_KNOWN(HostTlDReadyKnownO_A, host32_tl_h_o[i].d_ready)
  end
  // 64-bit host ports
  for (genvar i = 0; i < NumTlul64; i++) begin : gen_host_wide_known_a
    `ASSERT_KNOWN(HostTlWideAValidKnownO_A, host64_h2d_o[i].a_valid)
    `ASSERT_KNOWN(HostTlWideDReadyKnownO_A, host64_h2d_o[i].d_ready)
  end

  // The pipelined fast path may request its distinct source and destination ports together.
  `ASSERT(MaxTwoPortReq_A, $countones(port_req) <= 2, gated_clk, !rst_ni)
  `ASSERT(TwoPortReqIsCrossPort_A, ($countones(port_req) == 2) |-> (src_port_idx != dst_port_idx),
          gated_clk, !rst_ni)

  // A request must only target a port whose ASID resolved to a valid index.
  `ASSERT(ReadReqValidIdx_A, rd_issue |-> src_asid_valid, gated_clk, !rst_ni)
  `ASSERT(WriteReqValidIdx_A, wr_issue |-> dst_asid_valid, gated_clk, !rst_ni)

  // Abort/error quiescence: no request may launch after abort, and software must not observe the
  // DMA as idle until every response to a previously accepted request has drained.
  `ASSERT(AbortNoBusReq_A, cfg_abort_en |-> (port_req == '0), gated_clk, !rst_ni)
  `ASSERT(AbortBusyHeld_A, (cfg_abort_en && !dma_drained) |-> reg2hw.status.busy.q,
          gated_clk, !rst_ni)
  `ASSERT(ErrorBusyHeld_A, ((ctrl_state_q == DmaError) && !dma_drained) |->
          reg2hw.status.busy.q, gated_clk, !rst_ni)
  `ASSERT(DrainBeforeIdle_A,
          ((ctrl_state_q != DmaIdle) && (ctrl_state_d == DmaIdle)) |-> !(|port_outst_d),
          gated_clk, !rst_ni)

  // Alert assertions for reg_we onehot check
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(RegWeOnehotCheck_A, u_dma_reg, alert_tx_o[0])

  // Handshake interrupt enable register must be expanded if there are more than 32 handshake
  // trigger wires
  `ASSERT_NEVER(LimitHandshakeTriggerWires_A, NumIntClearSources > 32)

  // The RTL code assumes the BE signal is 4-bit wide
  `ASSERT_NEVER(BeLengthMustBe4_A, top_pkg::TL_DBW != 4)

  // The DMA enabled memory should not be changed after lock
  `ASSERT_NEVER(NoDmaEnabledMemoryChangeAfterLock_A, prim_mubi_pkg::mubi4_test_false_loose(
                prim_mubi_pkg::mubi4_t'(reg2hw.range_regwen.q)
                ) && (reg2hw.enabled_memory_range_base.qe || reg2hw.enabled_memory_range_limit.qe))

  // Alert assertion for sparse FSM.
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(CtrlStateFsmCheck_A, aff_ctrl_state_q, alert_tx_o[0])

  // Inline AES sub-FSM SEC_CM assertions (mirrors aes.sv assertions for the aes_core FSMs).
  // The fatal alert index is AlertFatalFaultIdx = 0.
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(DmaAesFsmCheck_A, u_dma_aes.u_state_regs,
                                       alert_tx_o[AlertFatalFaultIdx])

  for (genvar i = 0; i < aes_pkg::Sp2VWidth; i++) begin : gen_aes_ctrl_fsm_sva
    if (aes_pkg::SP2V_LOGIC_HIGH[i] == 1'b1) begin : gen_p
      `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesControlFsmCheck_A,
                                           u_dma_aes.u_aes_core.u_aes_control.gen_fsm[i].gen_fsm_p.
              u_aes_control_fsm_i.u_aes_control_fsm.u_state_regs,
                                           alert_tx_o[AlertFatalFaultIdx])
      `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesCtrFsmCheck_A,
                                           u_dma_aes.u_aes_core.u_aes_ctr.gen_fsm[i].gen_fsm_p.
              u_aes_ctr_fsm_i.u_aes_ctr_fsm.u_state_regs,
                                           alert_tx_o[AlertFatalFaultIdx])
      `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesCipherControlFsmCheck_A,
                                           u_dma_aes.u_aes_core.u_aes_cipher_core.u_aes_cipher_control.gen_fsm[i].gen_fsm_p.
              u_aes_cipher_control_fsm_i.u_aes_cipher_control_fsm.u_state_regs,
                                           alert_tx_o[AlertFatalFaultIdx])
    end else begin : gen_n
      `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesControlFsmCheck_A,
                                           u_dma_aes.u_aes_core.u_aes_control.gen_fsm[i].gen_fsm_n.
              u_aes_control_fsm_i.u_aes_control_fsm.u_state_regs,
                                           alert_tx_o[AlertFatalFaultIdx])
      `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesCtrFsmCheck_A,
                                           u_dma_aes.u_aes_core.u_aes_ctr.gen_fsm[i].gen_fsm_n.
              u_aes_ctr_fsm_i.u_aes_ctr_fsm.u_state_regs,
                                           alert_tx_o[AlertFatalFaultIdx])
      `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesCipherControlFsmCheck_A,
                                           u_dma_aes.u_aes_core.u_aes_cipher_core.u_aes_cipher_control.gen_fsm[i].gen_fsm_n.
              u_aes_cipher_control_fsm_i.u_aes_cipher_control_fsm.u_state_regs,
                                           alert_tx_o[AlertFatalFaultIdx])
    end
  end

  // GHASH always exists (the inline AES always builds GCM), so its FSM check is unconditional.
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(AesGhashFsmCheck_A,
                                       u_dma_aes.u_aes_core.gen_ghash.u_aes_ghash.u_state_regs,
                                       alert_tx_o[AlertFatalFaultIdx])

  // GHASH masked-add / gf_mult1 muxes only exist when masking is enabled (`gen_masked_add` /
  // `gen_gf_mult1_mux` in aes_ghash); gate these SVA references on SecAesMasking so unmasked
  // builds still elaborate.
  if (SecAesMasking) begin : gen_ghash_masked_onehot_sva
    for (genvar s = 0; s < 2; s++) begin : gen_ghash_onehot_add_in_sva
      `ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(GhashAadOnehotCheck_A,
          u_dma_aes.u_aes_core.gen_ghash.u_aes_ghash.gen_masked_add.gen_add_in_muxes[s].
              u_prim_onehot_check_add_in_sel,
          alert_tx_o[AlertFatalFaultIdx])
    end
    `ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(GhashMultOnehotCheck_A,
        u_dma_aes.u_aes_core.gen_ghash.u_aes_ghash.gen_gf_mult1_mux.
            u_prim_onehot_check_gf_mult1_in_sel,
        alert_tx_o[AlertFatalFaultIdx])
  end

  // Inline AES decrypt tag-compare invariants (SEC_CM CTRL.CONSISTENCY): the tag is only accepted
  // when the redundant compare agrees, and a mismatch never lets the transfer complete.
  `ASSERT(AesDecryptTagAccept_A,
          (ctrl_state_q == DmaAesTag) && aes_decrypt && aes_tag_valid_set |-> aes_tag_ok)
  `ASSERT(AesDecryptTagReject_A,
          (ctrl_state_q == DmaAesTag) && aes_decrypt && aes_tag_mismatch_set |-> !aes_tag_ok)
  // A decrypt tag mismatch must move to the error state, never signal done.
  `ASSERT(AesTagFailNoDone_A, aes_tag_mismatch_set |-> (ctrl_state_d == DmaError))
  `ASSERT(AesSessionLocksConfig_A,
          aes_session_q |-> hw2reg.cfg_regwen.d == prim_mubi_pkg::MuBi4False)
  `ASSERT(
      AesFixedReadAddr_A,
      (ctrl_state_q == DmaAesGather) && (reg2hw.src_config.increment.q == AddrNoIncrement) |-> rd_issue_addr == {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q})
  `ASSERT(
      AesFixedWriteAddr_A,
      (ctrl_state_q == DmaAesScatter) && (reg2hw.dst_config.increment.q == AddrNoIncrement) |-> wr_issue_addr == {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q})
  `ASSERT(
      AesChunkPreservesSession_A,
      control_q.aes_en && chunk_done |-> !aes_clear && !aes_tag_valid_set && (chunk_byte_d[3:0] == 0) && (transfer_byte_d < reg2hw.total_data_size.q))
  `ASSERT(AesResumeDoesNotRestart_A, aes_session_q |-> !aes_start)
  `ASSERT(AesPauseNoTraffic_A,
          aes_session_q && (ctrl_state_q == DmaIdle) |-> !rd_issue && !wr_issue)
  `ASSERT(
      AesHandshakeWait_A,
      aes_session_q && control_q.cfg_handshake_en && (ctrl_state_q == DmaIdle) && !cfg_abort_en && !reg2hw.control.initial_transfer.q && !(|lsio_trigger) |-> ctrl_state_d == DmaIdle && !aes_start && !aes_clear)
  `ASSERT(
      AesHandshakeChunk_A,
      control_q.aes_en && control_q.cfg_handshake_en && (ctrl_state_q == DmaAesScatter) && (ctrl_state_d == DmaIdle) && !cfg_abort_en && (transfer_byte_d < reg2hw.total_data_size.q) |-> !clear_go && !chunk_done && !aes_clear)
  // Quarantine guarantee (release-of-unverified-plaintext, see DmaAesTag): on a decrypt tag
  // mismatch the DMA must never write a 1 into STATUS.done, so the done interrupt (which fires off
  // STATUS.done.q) cannot assert and SW has no "transfer complete" signal that could be mistaken
  // for "destination authenticated". The plaintext is still in the destination; SW MUST treat it
  // as poisoned until STATUS.tag_valid. This makes done-suppression an explicit, checkable
  // invariant rather than an emergent property of the clear_go path.
  `ASSERT(AesTagFailNoDoneStatus_A,
          aes_tag_mismatch_set |-> !(hw2reg.status.done.de && hw2reg.status.done.d))

  // Boundary-class count parameters must stay consistent with the `PortDesc` array.
  `ASSERT_INIT(NumTlul32Consistent_A, NumTlul32 == dma_count_class_local(dma_pkg::PortTlul32))
  `ASSERT_INIT(NumTlul64Consistent_A, NumTlul64 == dma_count_class_local(dma_pkg::PortTlul64))
  // A DMA with zero data ports is degenerate (PortDesc[NumPorts] requires NumPorts >= 1).
  `ASSERT_INIT(NumPortsNonZero_A, NumPorts >= 1)

  `ASSERT_INIT(NumPortsMax_A, NumPorts <= dma_pkg::MaxPorts)
  for (genvar p = 0; p < NumPorts; p++) begin : gen_asid_checks
    `ASSERT_INIT(AsidCodeValid_A, dma_pkg::dma_asid_code_valid(PortDesc[p].asid))
    `ASSERT_INIT(AsidUnique_A, dma_count_asid_local(PortDesc[p].asid) == 1)
    for (genvar q = 0; q < p; q++) begin : gen_distance
      `ASSERT_INIT(AsidDistance_A, $countones(PortDesc[p].asid ^ PortDesc[q].asid) >= 4)
    end
  end
  `ASSERT(ClearReqValidIdx_A, dma_clear_intr |-> clr_asid_valid)

  // The wide a_user must occupy exactly TL_AUW bits, like the stock tl_a_user_t.
  `ASSERT_INIT(DmaAUserWidth_A, $bits(dma_tlul_pkg::dma_tl_a_user_t) == top_pkg::TL_AUW)
endmodule
