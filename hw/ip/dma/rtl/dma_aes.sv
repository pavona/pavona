// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Inline AES wrapper for the DMA.
//
// Embeds the hardened `aes_core` (cipher + CTR + GHASH, masked, DOM S-box) behind a 128-bit
// streaming interface. It drives aes_core's reg2hw/hw2reg in *auto-operation* (no TL register
// block), replicates the EDN arbiter + `prim_sync_reqack_data` CDC from aes.sv:79-199, and runs a
// small sparse-encoded sequencer (config -> key -> iv -> per-block run).
//
// GCM (mode_i == AES_GCM): drive GHASH through GCM_INIT -> [GCM_AAD] -> GCM_TEXT -> GCM_TAG via
// CTRL_GCM_SHADOWED (two-write commit, like CTRL_SHADOWED), sequenced by `gcm_phase_q` and the
// DmaAesStGcmCfg (commit a phase) / DmaAesStGcmRun (run it) states. v1: full 16-byte blocks only.
//   - AAD: the producer streams AAD blocks first, then text blocks, in order on blk_data_i; the
//     `aad_blocks_i` / `text_blocks_i` counts split the stream (AAD absorbed with no output read,
//     text read out on blk_data_o), so no side-band signal is needed.
//   - Length block: built internally from the counts as {len_aad_bits, len_text_bits} (NIST bit
//     order, byte-reversed into the data_in layout; see gcm_len_block), fed during GCM_TAG.
//
// Correctness invariants (do not change without re-reviewing aes_core):
//   - The CTR counter is INTERNAL (iv_q); `iv_i` is loaded exactly ONCE at config (iv[*].qe pulsed
//     once), never re-pulsed - the counter self-advances. hw2reg.iv is a read-back mirror only.
//   - CTRL_SHADOWED / CTRL_GCM_SHADOWED are prim_subreg_shadow: pulse the qe TWICE with identical
//     .q to commit; a single pulse leaves the config staged and AES never starts.
//
// Countermeasure reductions vs. aes.sv: no TL register block, so aes_core's shadow-storage /
// shadow-update / TL-integrity error inputs are tied to 0 and rst_shadowed_ni is tied to rst_ni.
// Revisit when a full DMA TL register block drives them.
//
// Design notes:
//   - GCM phase routing skips empty AAD/TEXT phases (AAD-only/GMAC/zero-text); it never enters a
//     zero-block phase.
//   - clear_i in DmaAesStGcmCfg fully resets the GCM sub-state.
//   - The key/iv/data clear trigger is HELD (clr_hold) until aes_core acknowledges it, so a clear_i
//     arriving while the cipher is busy still wipes the key/IV/GHASH state (the FSM consumes the
//     trigger only once it returns to idle). clr_hold also drops any captured output block so an
//     aborted mid-block transfer leaves no stale data / deadlock for the next transfer.
//   - A clear_i between a commit's two writes is handled by re-arming the shadow phase at start_i
//     (shadow_phase_clr); see DmaAesStIdle.
//   - GCM_INIT completion is taken from aes_core's gcm_init_done_o, the same signal the AES IP uses
//     to gate the GCM_INIT -> next-phase transition.
//   - Full 16-byte blocks only; dma.sv must reject non-block-multiple AES transfers.

`include "prim_assert.sv"

module dma_aes
  import aes_pkg::*;
  import aes_reg_pkg::*;
#(
  parameter bit          SecMasking   = 1,
  parameter sbox_impl_e  SecSBoxImpl  = SBoxImplDom,
  parameter bit          SecAllowForcingMasks = 0,
  parameter bit          AES192Enable = 1,
  parameter int unsigned EntropyWidth = edn_pkg::ENDPOINT_BUS_WIDTH,
  // Secure netlist constants for the clearing/masking PRNGs (threaded into aes_core).
  parameter clearing_lfsr_seed_t RndCnstClearingLfsrSeed  = RndCnstClearingLfsrSeedDefault,
  parameter clearing_lfsr_perm_t RndCnstClearingLfsrPerm  = RndCnstClearingLfsrPermDefault,
  parameter clearing_lfsr_perm_t RndCnstClearingSharePerm = RndCnstClearingSharePermDefault,
  parameter masking_lfsr_seed_t  RndCnstMaskingLfsrSeed   = RndCnstMaskingLfsrSeedDefault,
  parameter masking_lfsr_perm_t  RndCnstMaskingLfsrPerm   = RndCnstMaskingLfsrPermDefault
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,

  // EDN (entropy) clock domain.
  input  logic                    clk_edn_i,
  input  logic                    rst_edn_ni,

  // Configuration inputs (sampled at start_i).
  input  aes_mode_e               mode_i,        // AES_CTR / AES_GCM
  input  ciph_op_e                op_i,          // CIPH_FWD (enc) / CIPH_INV (dec)
  input  key_len_e                key_len_i,     // one-hot AES_128/192/256
  input  logic                    sideload_i,    // use keymgr sideload key
  input  prs_rate_e               reseed_rate_i, // PRNG reseed rate

  // SW key/iv inputs.
  input  logic [7:0][31:0]        key_share0_i,
  input  logic [7:0][31:0]        key_share1_i,
  input  logic [3:0][31:0]        iv_i,

  // Key manager sideload key.
  input  keymgr_pkg::hw_key_req_t keymgr_key_i,

  // 128-bit block streaming interface.
  input  logic [127:0]            blk_data_i,
  input  logic                    blk_valid_i,
  output logic                    blk_ready_o,
  output logic [127:0]            blk_data_o,
  output logic                    blk_valid_o,
  input  logic                    blk_ready_i,

  // GCM interface.
  // gcm_phase_i / num_valid_bytes_i are retained for interface compatibility but are NOT used to
  // drive the datapath: the wrapper sequences the GCM phases itself (see gcm_phase_q) and always
  // uses 16 valid bytes (full blocks only in v1). aad_blocks_i / text_blocks_i tell the wrapper how
  // to split the incoming blk_data_i stream (AAD blocks first, then text blocks) and are used to
  // build the GHASH length block for the tag.
  input  gcm_phase_e              gcm_phase_i,
  input  logic [4:0]              num_valid_bytes_i,
  input  logic [12:0]            aad_blocks_i,   // number of 16-byte AAD blocks (0..)
  input  logic [12:0]            text_blocks_i,  // number of 16-byte text blocks
  output logic [127:0]            tag_o,
  output logic                    tag_valid_o,

  // Control / status.
  input  logic                    start_i,   // pulse to (re)configure key/iv and begin a transfer
  input  logic                    clear_i,   // pulse to clear key/iv/data registers

  // EDN request/response.
  output edn_pkg::edn_req_t       edn_o,
  input  edn_pkg::edn_rsp_t       edn_i,

  // Alerts.
  output logic                    alert_recov_o,
  output logic                    alert_fatal_o,

  // Life cycle escalation.
  input  lc_ctrl_pkg::lc_tx_t     lc_escalate_en_i
);

  // gcm_phase_i / num_valid_bytes_i are intentionally not used to drive the datapath (the wrapper
  // sequences the phases itself). Keep them tied off into an unused signal to avoid lint warnings.
  logic unused_gcm_inputs;
  assign unused_gcm_inputs = ^{gcm_phase_i, num_valid_bytes_i};

  ///////////////////////////////
  // EDN arbiter + clk_edn CDC //
  ///////////////////////////////
  // Mirrors aes.sv:79-199. Clearing + masking PRNGs share one EDN endpoint (clearing has priority);
  // a hold register keeps a dropped request asserted until acked. clk_i<->clk_edn_i crossing uses
  // prim_sync_reqack_data (NOT prim_edn_req).
  logic                      edn_req_int;
  logic                      edn_req_hold_d, edn_req_hold_q;
  logic                      edn_req;
  logic                      edn_ack;
  logic   [EntropyWidth-1:0] edn_data;
  logic                      unused_edn_fips;
  logic                      entropy_clearing_req, entropy_masking_req;
  logic                      entropy_clearing_ack, entropy_masking_ack;

  assign edn_req_int          = entropy_clearing_req | entropy_masking_req;
  assign entropy_clearing_ack =  entropy_clearing_req & edn_ack;
  assign entropy_masking_ack  = ~entropy_clearing_req & entropy_masking_req & edn_ack;

  assign edn_req        = edn_req_int | edn_req_hold_q;
  assign edn_req_hold_d = (edn_req_hold_q | edn_req) & ~edn_ack;
  always_ff @(posedge clk_i or negedge rst_ni) begin : edn_req_reg
    if (!rst_ni) begin
      edn_req_hold_q <= '0;
    end else begin
      edn_req_hold_q <= edn_req_hold_d;
    end
  end

  prim_sync_reqack_data #(
    .Width(EntropyWidth),
    .DataSrc2Dst(1'b0),
    .DataReg(1'b0)
  ) u_prim_sync_reqack_data (
    .clk_src_i  ( clk_i         ),
    .rst_src_ni ( rst_ni        ),
    .clk_dst_i  ( clk_edn_i     ),
    .rst_dst_ni ( rst_edn_ni    ),
    .req_chk_i  ( 1'b1          ),
    .src_req_i  ( edn_req       ),
    .src_ack_o  ( edn_ack       ),
    .dst_req_o  ( edn_o.edn_req ),
    .dst_ack_i  ( edn_i.edn_ack ),
    .data_i     ( edn_i.edn_bus ),
    .data_o     ( edn_data      )
  );
  assign unused_edn_fips = edn_i.edn_fips;

  /////////////////////////////
  // aes_core CSR adapter FSM //
  /////////////////////////////
  // Sparse-encoded sub-FSM. Encodings generated at commit 30f4e91242 via:
  //   util/design/sparse-fsm-encode.py --language=sv --seed 4172254853 -d 3 -m 8 -n 7
  // Minimum Hamming distance 3. The two GCM states (DmaAesStGcmCfg / DmaAesStGcmRun) drive the
  // GCM phase sequence; the CTR path uses DmaAesStRun unchanged.
  localparam int unsigned DmaAesStateWidth = 7;
  typedef enum logic [DmaAesStateWidth-1:0] {
    DmaAesStIdle   = 7'b1110001,
    DmaAesStCfg    = 7'b1100111,
    DmaAesStKey    = 7'b0101100,
    DmaAesStIv     = 7'b0011110,
    DmaAesStRun    = 7'b0010011,
    DmaAesStErr    = 7'b1011101,
    DmaAesStGcmCfg = 7'b0000101,
    DmaAesStGcmRun = 7'b1000000
  } dma_aes_state_e;
  dma_aes_state_e state_d, state_q;

  // GCM phase tracker. Selects which phase DmaAesStGcmCfg commits and what DmaAesStGcmRun does.
  // Only the four streaming phases are used (INIT/AAD/TEXT/TAG); SAVE/RESTORE are out of scope.
  gcm_phase_e gcm_phase_d, gcm_phase_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : gcm_phase_reg
    if (!rst_ni) begin
      gcm_phase_q <= GCM_INIT;
    end else begin
      gcm_phase_q <= gcm_phase_d;
    end
  end

  // Block counter for the current GCM phase (counts AAD or text blocks fed/processed).
  logic [12:0] gcm_blk_cnt_q;
  logic        gcm_blk_cnt_en;
  logic        gcm_blk_cnt_clr;
  always_ff @(posedge clk_i or negedge rst_ni) begin : gcm_blk_cnt_reg
    if (!rst_ni) begin
      gcm_blk_cnt_q <= 13'd0;
    end else if (gcm_blk_cnt_clr) begin
      gcm_blk_cnt_q <= 13'd0;
    end else if (gcm_blk_cnt_en) begin
      gcm_blk_cnt_q <= gcm_blk_cnt_q + 13'd1;
    end
  end

  // Captured authentication tag.
  logic [127:0] tag_q;
  logic         tag_valid_q;
  logic         tag_capture;
  // Pulsed on start to invalidate a stale tag_valid_o latched by a previous GCM transfer - else the
  // consumer (dma.sv DmaAesTag) could sample the old tag before this transfer's GCM_TAG runs.
  logic         tag_clear;

  // GCM_TEXT inter-block gate. Each text block must be cipher+GHASH processed and its output
  // captured before the next is fed; unlike CTR, GCM cannot pipeline (it would desync GHASH/counter).
  // Set when a block is fully fed, cleared when its output is captured; no feed while set.
  logic gcm_txt_await_d, gcm_txt_await_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : gcm_txt_await_reg
    if (!rst_ni) begin
      gcm_txt_await_q <= 1'b0;
    end else begin
      gcm_txt_await_q <= gcm_txt_await_d;
    end
  end

  // GCM_AAD absorb tracker. AAD produces no output_valid (aes_control_fsm returns to CTRL_IDLE
  // without data_out_we), so block-absorbed is detected via a busy->idle EDGE on the registered
  // aes_idle mirror - not its level, which is stale-HIGH for one cycle after start_gcm_aad drops
  // idle. Arm gcm_aad_busy_seen only once idle has actually gone LOW (GHASH absorbing); a later
  // idle-HIGH then clears the await and advances.
  logic gcm_aad_busy_seen_d, gcm_aad_busy_seen_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : gcm_aad_busy_seen_reg
    if (!rst_ni) begin
      gcm_aad_busy_seen_q <= 1'b0;
    end else begin
      gcm_aad_busy_seen_q <= gcm_aad_busy_seen_d;
    end
  end

  // GCM_INIT completes when aes_core asserts gcm_init_done_o (H=E(0) and S=E(J0) ready) - the same
  // signal the AES IP uses to gate the GCM_INIT -> next-phase transition.
  logic aes_gcm_init_done;

  // Fatal alert sources: aes_core's own fatal alert plus a sparse-FSM error in this wrapper.
  // SEC_CM: AES.FSM.SPARSE - an undefined sub-FSM state (e.g. due to fault injection) drops to the
  // default arm, which raises `fsm_err`. This is latched (fatal alerts are sticky until reset) and
  // OR'd into alert_fatal_o; the ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT below verifies the binding.
  logic aes_alert_fatal;
  logic fsm_err;
  logic fsm_err_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : fsm_err_reg
    if (!rst_ni) begin
      fsm_err_q <= 1'b0;
    end else begin
      fsm_err_q <= fsm_err_q | fsm_err;
    end
  end
  assign alert_fatal_o = aes_alert_fatal | fsm_err_q;

  // Two-write shadow commit phase tracker. In DmaAesStCfg we pulse the qe twice (phase 0 stages,
  // phase 1 commits).
  logic cfg_phase_d, cfg_phase_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : cfg_phase_reg
    if (!rst_ni) begin
      cfg_phase_q <= 1'b0;
    end else begin
      cfg_phase_q <= cfg_phase_d;
    end
  end

  // hw2reg status signals from aes_core.
  aes_reg2hw_t aes_reg2hw;
  aes_hw2reg_t aes_hw2reg;

  // aes_core drives status as (d, de) pairs. With no register block, hold each bit here and update
  // it only when its `de` strobe fires (what aes_reg_top would do).
  logic aes_input_ready;
  logic aes_output_valid;
  logic aes_idle;
  always_ff @(posedge clk_i or negedge rst_ni) begin : status_reg
    if (!rst_ni) begin
      aes_input_ready  <= 1'b0;
      aes_output_valid <= 1'b0;
      aes_idle         <= 1'b1;
    end else begin
      if (aes_hw2reg.status.input_ready.de)  aes_input_ready  <= aes_hw2reg.status.input_ready.d;
      if (aes_hw2reg.status.output_valid.de) aes_output_valid <= aes_hw2reg.status.output_valid.d;
      if (aes_hw2reg.status.idle.de)         aes_idle         <= aes_hw2reg.status.idle.d;
    end
  end

  // Per-FSM control strobes.
  logic       ctrl_qe;        // pulse all ctrl_shadowed.*.qe
  logic       ctrl_gcm_qe;    // pulse ctrl_gcm_shadowed.{phase,num_valid_bytes}.qe (two-write)
  logic       key_qe;         // pulse all key_share*.qe
  logic       iv_qe;          // pulse all iv[*].qe
  logic [3:0] data_in_qe;     // per-word data_in[*].qe (driven one word per cycle)
  logic       data_in_is_len; // when set, data_in is driven from the GCM length block
  logic       clear_pulse;    // one-shot clear request from the FSM (abort/error/reconfigure)
  logic       shadow_phase_clr; // pulse ctrl_shadowed/ctrl_gcm_shadowed .re; resets commit phase
  // Held clear. `clear_pulse` is a one-shot, but aes_control_fsm only consumes the
  // key_iv_data_in_clear trigger once it is back in CTRL_IDLE and then runs a multi-cycle clear
  // sequence that re-checks the trigger; aes_reg_top normally holds the trigger bit until the FSM
  // writes it back. Mirror that here: latch the request and hold the trigger asserted (`clr_hold`)
  // until aes_core acknowledges it (`clr_ack`, the trigger write-back strobe). Without this, a
  // clear_i (DMA abort) arriving while the cipher is busy is silently dropped and the key/IV/GHASH
  // state is never wiped (SEC_WIPE failure).
  logic       clr_pending_d, clr_pending_q;
  logic       clr_ack;
  logic       clr_hold;

  // GCM length block: {len_aad_bits[63:0], len_text_bits[63:0]} in NIST GCM ordering, byte-reversed
  // into the AES data_in register layout (same transform the AES DV uses: {<<8{conc}}). Each block
  // is 128 bits = 16 bytes; lengths are expressed in bits.
  logic [63:0]  gcm_len_aad_bits;
  logic [63:0]  gcm_len_text_bits;
  logic [127:0] gcm_len_conc;
  logic [127:0] gcm_len_block;
  assign gcm_len_aad_bits  = {{(64-13-7){1'b0}}, aad_blocks_i,  7'd0}; // blocks * 128
  assign gcm_len_text_bits = {{(64-13-7){1'b0}}, text_blocks_i, 7'd0}; // blocks * 128
  assign gcm_len_conc      = {gcm_len_aad_bits, gcm_len_text_bits};
  // Byte-reverse the 16 bytes (matches aes_base_vseq.sv: len_aad_data = {<<8{len_aad_data_conc}}).
  for (genvar b = 0; b < 16; b++) begin : gen_len_byte_rev
    assign gcm_len_block[b*8 +: 8] = gcm_len_conc[(15-b)*8 +: 8];
  end

  // Captured output block.
  logic [127:0] blk_data_q;
  logic         blk_valid_q;
  logic         blk_capture;
  logic         out_pending_q;

  // data_in feed counter. The aes_core control FSM clears its data_in_new tracker if all four
  // data_in.qe pulse in the SAME cycle (aes_control_fsm.sv:1013). We therefore feed the four
  // 32-bit input words ONE PER CYCLE so data_in_new accumulates and the cipher auto-starts.
  logic [1:0] data_in_cnt_q;
  logic       data_in_cnt_en;
  logic       data_in_cnt_clr;
  always_ff @(posedge clk_i or negedge rst_ni) begin : data_in_cnt_reg
    if (!rst_ni) begin
      data_in_cnt_q <= 2'd0;
    end else if (data_in_cnt_clr) begin
      data_in_cnt_q <= 2'd0;
    end else if (data_in_cnt_en) begin
      data_in_cnt_q <= data_in_cnt_q + 2'd1;
    end
  end

  // Unmask / collect the 128-bit data_out from aes_core's data_out registers (the final ciphertext
  // for CTR is provided directly on data_out[*].d).
  logic [127:0] aes_data_out;
  for (genvar i = 0; i < 4; i++) begin : gen_data_out
    assign aes_data_out[i*32 +: 32] = aes_hw2reg.data_out[i].d;
  end

  always_comb begin : dma_aes_fsm
    state_d     = state_q;
    cfg_phase_d = cfg_phase_q;
    gcm_phase_d = gcm_phase_q;

    ctrl_qe        = 1'b0;
    ctrl_gcm_qe    = 1'b0;
    key_qe         = 1'b0;
    iv_qe          = 1'b0;
    data_in_qe     = 4'b0;
    data_in_is_len = 1'b0;
    clear_pulse    = 1'b0;
    shadow_phase_clr = 1'b0;
    data_in_cnt_en = 1'b0;
    data_in_cnt_clr = 1'b0;
    gcm_blk_cnt_en  = 1'b0;
    gcm_blk_cnt_clr = 1'b0;
    gcm_txt_await_d = gcm_txt_await_q;
    gcm_aad_busy_seen_d = gcm_aad_busy_seen_q;
    fsm_err        = 1'b0;

    blk_ready_o = 1'b0;
    blk_capture = 1'b0;
    tag_capture = 1'b0;
    tag_clear   = 1'b0;

    unique case (state_q)
      // Wait for a transfer to be started.
      DmaAesStIdle: begin
        cfg_phase_d = 1'b0;
        if (start_i) begin
          // Invalidate any tag latched by a previous transfer so a stale tag_valid_o cannot be
          // misread by the consumer before this transfer's GCM_TAG phase has produced a fresh tag.
          tag_clear = 1'b1;
          // Re-arm the aes_core shadow commit phase before the first commit write. A clear_i that
          // landed between the two writes of a PRIOR aborted commit leaves the HW
          // prim_subreg_shadow.phase_q at 1 (clear_pulse only wipes key/iv/data; rst_shadowed_ni
          // resets the shadow data, not the phase), so the next first write would be mis-read as the
          // commit write -> spurious recov_ctrl_update_err / never-committed config. A shadow read
          // forces phase_q back to 0; safe here because idle asserts no qe (no write-vs-read race).
          shadow_phase_clr = 1'b1;
          state_d   = DmaAesStCfg;
        end
      end

      // Two-write shadow commit: pulse ctrl_shadowed.*.qe twice with identical .q, gated on idle
      // (aes_control_fsm gates ctrl_we_o on !start_core && !start_ghash) so a write after a busy
      // clear/reconfigure is not silently dropped (e.g. CTR->GCM keeping the stale CTR mode).
      // For GCM, commit GCM_INIT FIRST: its gcm_clear wipes the IV "new" tracker, so key/IV must be
      // (re)written after this commit - hence INIT-then-key/IV.
      DmaAesStCfg: begin
        // Also gate on !clr_hold so a new transfer cannot commit config while a prior abort's clear
        // is still draining (the clear keeps the core busy, so aes_idle is usually already low, but
        // this closes the one-cycle idle-mirror race where the config write could be dropped).
        if (aes_idle && !clr_hold) begin
          ctrl_qe     = 1'b1;
          cfg_phase_d = ~cfg_phase_q;
          if (cfg_phase_q) begin
            if (mode_i == AES_GCM) begin
              gcm_phase_d     = GCM_INIT;
              cfg_phase_d     = 1'b0; // arm two-write tracker for the GCM_INIT commit
              gcm_blk_cnt_clr = 1'b1;
              state_d         = DmaAesStGcmCfg;
            end else begin
              state_d = DmaAesStKey;
            end
          end
        end
        if (clear_i) begin
          // An abort during config returns to idle and re-arms the commit tracker.
          clear_pulse = 1'b1;
          cfg_phase_d = 1'b0;
          state_d     = DmaAesStIdle;
        end
      end

      // Load SW key shares once (non-shadowed single-write subregs). For sideload, the key comes
      // from keymgr_key_i and aes_core consumes it when sideload is set; no qe pulse is needed.
      DmaAesStKey: begin
        // A DMA abort during key load must wipe and return to idle, like the other states; else the
        // key/IV/GHASH state is left un-cleared and the wrapper runs on while the DMA goes idle.
        if (clear_i) begin
          clear_pulse = 1'b1;
          state_d     = DmaAesStIdle;
        end else begin
          key_qe  = ~sideload_i;
          state_d = DmaAesStIv;
        end
      end

      // Load IV exactly ONCE, never re-pulsed. The key write triggers a reseed (and, for decrypt,
      // start-key generation) that makes the core busy, and iv_we is ignored while busy
      // (aes_control_fsm gates it on !start_core). So wait for idle before pulsing iv_qe (as the AES
      // DV does), else the IV "new" tracker never sets and GCM INIT never sees iv_ready.
      DmaAesStIv: begin
        if (clear_i) begin
          // Abort during IV load: wipe and return to idle (see DmaAesStKey).
          clear_pulse = 1'b1;
          state_d     = DmaAesStIdle;
        end else if (aes_idle) begin
          iv_qe = 1'b1;
          if (mode_i == AES_GCM) begin
            // GCM_INIT phase is already committed; IV is now loaded (after the INIT commit's
            // gcm_clear) so iv_ready stays set and INIT auto-runs (it does not depend on data_in).
            state_d = DmaAesStGcmRun;
          end else begin
            state_d = DmaAesStRun;
          end
        end
      end

      // Per-block auto-operation: feed the four input words one per cycle so data_in_new
      // accumulates, then wait for output_valid and capture the result.
      DmaAesStRun: begin
        // Feed one input word per cycle while the core is ready and we have a pending input block
        // that has not yet been fully loaded, and no unconsumed output is held.
        if (blk_valid_i && aes_input_ready && !out_pending_q && !blk_valid_q) begin
          data_in_qe[data_in_cnt_q] = 1'b1;
          data_in_cnt_en            = 1'b1;
          if (data_in_cnt_q == 2'd3) begin
            // Last word of this block consumed from the producer.
            blk_ready_o     = 1'b1;
            data_in_cnt_clr = 1'b1;
            data_in_cnt_en  = 1'b0;
          end
        end
        // Capture the produced block exactly once on the rising edge of output_valid.
        if (aes_output_valid && !out_pending_q) begin
          blk_capture = 1'b1;
        end
        if (clear_i) begin
          clear_pulse     = 1'b1;
          data_in_cnt_clr = 1'b1;
          state_d         = DmaAesStIdle;
        end
      end

      // Two-write shadow commit of CTRL_GCM_SHADOWED for the phase in gcm_phase_q. Writes are gated
      // on idle so both are accepted (aes_control_fsm gates the GCM control write on !start_core &&
      // !start_ghash). A gap between the two is harmless (no read clears the shadow phase); a
      // dropped write would desync cfg_phase from the HW shadow phase.
      DmaAesStGcmCfg: begin
        if (aes_idle) begin
          ctrl_gcm_qe = 1'b1;
          cfg_phase_d = ~cfg_phase_q;
          if (cfg_phase_q) begin
            // After committing GCM_INIT we still need to (re)load key + IV; for the other phases the
            // key/IV are already present so run the phase directly.
            state_d = (gcm_phase_q == GCM_INIT) ? DmaAesStKey : DmaAesStGcmRun;
          end
        end
        if (clear_i) begin
          // Fully reset the GCM sub-state (not just the FSM state) so no residue -
          // await / busy-seen / block & word counters / commit phase - corrupts the next transfer.
          clear_pulse         = 1'b1;
          data_in_cnt_clr     = 1'b1;
          gcm_blk_cnt_clr     = 1'b1;
          gcm_txt_await_d     = 1'b0;
          gcm_aad_busy_seen_d = 1'b0;
          cfg_phase_d         = 1'b0;
          state_d             = DmaAesStIdle;
        end
      end

      // Run the currently-committed GCM phase.
      DmaAesStGcmRun: begin
        cfg_phase_d = 1'b0; // arm the two-write tracker for the next phase commit
        unique case (gcm_phase_q)
          // GCM_INIT: HW reseeds the masking PRNG and encrypts H = E(0) and S = E(J0). Advance once
          // aes_core asserts gcm_init_done - the deterministic completion signal (gated on entropy
          // internally), so no idle/timeout heuristic is needed.
          GCM_INIT: begin
            if (aes_gcm_init_done) begin
              gcm_blk_cnt_clr = 1'b1;
              // Pick the next phase by what is actually present - AAD if any, else TEXT
              // if any, else straight to TAG (AAD-only / GMAC / zero-text). Never enter a phase with
              // zero blocks: GCM_TEXT with text_blocks_i==0 would never advance and would underflow
              // the (text_blocks_i - 1) "last block" test below.
              gcm_phase_d = (aad_blocks_i  != 13'd0) ? GCM_AAD  :
                            (text_blocks_i != 13'd0) ? GCM_TEXT : GCM_TAG;
              state_d     = DmaAesStGcmCfg;
            end
          end

          // GCM_AAD: feed AAD blocks into GHASH only (no output read), one block at a time. Per block:
          // fully fed -> set await, clear busy_seen; idle falls -> busy_seen (absorbing); idle rises
          // -> block absorbed, clear await and feed the next (see the gcm_aad_busy_seen note above).
          GCM_AAD: begin
            if (blk_valid_i && aes_input_ready && !gcm_txt_await_q) begin
              data_in_qe[data_in_cnt_q] = 1'b1;
              data_in_cnt_en            = 1'b1;
              if (data_in_cnt_q == 2'd3) begin
                blk_ready_o         = 1'b1;
                data_in_cnt_clr     = 1'b1;
                data_in_cnt_en      = 1'b0;
                gcm_txt_await_d     = 1'b1;
                gcm_aad_busy_seen_d = 1'b0; // start watching for the busy->idle edge of this block
                gcm_blk_cnt_en      = 1'b1;
              end
            end
            // Arm the absorb-complete detector only after idle has genuinely dropped LOW (GHASH is
            // actively absorbing this block). Until then the registered idle mirror may be stale.
            if (gcm_txt_await_q && !gcm_aad_busy_seen_q && !aes_idle) begin
              gcm_aad_busy_seen_d = 1'b1;
            end
            // Block absorbed: idle went LOW (busy_seen) and has now returned HIGH. Either feed the
            // next AAD block (await clears) or, if this was the last block, advance to GCM_TEXT.
            if (gcm_txt_await_q && gcm_aad_busy_seen_q && aes_idle) begin
              gcm_txt_await_d     = 1'b0;
              gcm_aad_busy_seen_d = 1'b0;
              if (gcm_blk_cnt_q == aad_blocks_i) begin
                // All AAD blocks absorbed (counter already incremented on the last feed): advance.
                // Skip TEXT when there are no text blocks (AAD-only / GMAC).
                gcm_blk_cnt_clr = 1'b1;
                gcm_phase_d     = (text_blocks_i != 13'd0) ? GCM_TEXT : GCM_TAG;
                state_d         = DmaAesStGcmCfg;
              end
            end
          end

          // GCM_TEXT: feed text blocks, read ciphertext/plaintext out. Feed only when not awaiting
          // a previous block's output (gcm_txt_await_q), so each block is fully processed before
          // the next is presented.
          GCM_TEXT: begin
            if (blk_valid_i && aes_input_ready && !out_pending_q && !blk_valid_q &&
                !gcm_txt_await_q) begin
              data_in_qe[data_in_cnt_q] = 1'b1;
              data_in_cnt_en            = 1'b1;
              if (data_in_cnt_q == 2'd3) begin
                blk_ready_o     = 1'b1;
                data_in_cnt_clr = 1'b1;
                data_in_cnt_en  = 1'b0;
                gcm_txt_await_d = 1'b1; // block fully fed; wait for its output before next feed
              end
            end
            if (aes_output_valid && !out_pending_q) begin
              blk_capture     = 1'b1;
              gcm_txt_await_d = 1'b0; // output captured; next block may be fed
              gcm_blk_cnt_en  = 1'b1;
              if (gcm_blk_cnt_q == (text_blocks_i - 13'd1)) begin
                // Last text block produced: stop counting and wait (below) for the GHASH to settle
                // (idle) before committing the GCM_TAG phase. Setting await here parks the feeder.
                gcm_blk_cnt_clr = 1'b1;
                gcm_blk_cnt_en  = 1'b0;
                gcm_txt_await_d = 1'b1; // mark "all text done, awaiting idle for TAG commit"
              end
            end
            // Once all text blocks are done (await set, counter cleared) and the core is idle, the
            // last block's GHASH has settled: commit the GCM_TAG phase.
            if (gcm_txt_await_q && (gcm_blk_cnt_q == 13'd0) && aes_idle && !out_pending_q &&
                !blk_valid_q) begin
              gcm_txt_await_d = 1'b0;
              gcm_phase_d     = GCM_TAG;
              state_d         = DmaAesStGcmCfg;
            end
          end

          // GCM_TAG: feed the internally-built length block, then capture the tag.
          GCM_TAG: begin
            data_in_is_len = 1'b1;
            // gcm_txt_await_q (0 on entry to GCM_TAG) is reused as a "length block fully fed" guard.
            // Without it the registered aes_input_ready mirror, which lags by one cycle, would let
            // the feeder re-pulse data_in_qe[0] after the 4th word is fed.
            if (aes_input_ready && !out_pending_q && !tag_valid_q && !gcm_txt_await_q) begin
              data_in_qe[data_in_cnt_q] = 1'b1;
              data_in_cnt_en            = 1'b1;
              if (data_in_cnt_q == 2'd3) begin
                data_in_cnt_clr = 1'b1;
                data_in_cnt_en  = 1'b0;
                gcm_txt_await_d = 1'b1; // all four length words fed; stop feeding
              end
            end
            if (aes_output_valid && !out_pending_q) begin
              // The tag is provided on data_out; capture it and signal completion.
              tag_capture     = 1'b1;
              gcm_txt_await_d = 1'b0;
              state_d         = DmaAesStIdle;
            end
          end

          default: begin
            // Unexpected phase (e.g. SAVE/RESTORE which we do not drive): treat as a fault.
            state_d = DmaAesStErr;
            fsm_err = 1'b1;
          end
        endcase
        if (clear_i) begin
          clear_pulse         = 1'b1;
          data_in_cnt_clr     = 1'b1;
          gcm_blk_cnt_clr     = 1'b1;
          gcm_txt_await_d     = 1'b0;
          gcm_aad_busy_seen_d = 1'b0;
          state_d             = DmaAesStIdle;
        end
      end

      DmaAesStErr: begin
        clear_pulse = 1'b1;
      end

      // Undefined state (e.g. fault injection into state_q): raise a fatal alert and drop to the
      // terminal error state.
      // SEC_CM: AES.FSM.SPARSE
      default: begin
        state_d = DmaAesStErr;
        fsm_err = 1'b1;
      end
    endcase

    // A fatal alert is terminal (aes_core latches it; recovery needs reset).
    if (alert_fatal_o && (state_q != DmaAesStErr)) begin
      state_d = DmaAesStErr;
    end
  end

  // SEC_CM: AES.FSM.SPARSE - the alert trigger assertion is handled by dma.sv's
  // CtrlStateFsmCheck_A and the aes_alert_fatal wiring; disable the prim_sparse_fsm_flop's
  // built-in EnableAlertTriggerSVA check to avoid cross-module assign issues in VCS.
  `PRIM_FLOP_SPARSE_FSM(u_state_regs, state_d, state_q, dma_aes_state_e, DmaAesStIdle,
                         clk_i, rst_ni, 0)

  // Hold the key/iv/data clear trigger until aes_core writes it back (acknowledges consuming it).
  assign clr_ack       = aes_hw2reg.trigger.key_iv_data_in_clear.de;
  assign clr_pending_d = clear_pulse | (clr_pending_q & ~clr_ack);
  always_ff @(posedge clk_i or negedge rst_ni) begin : clr_pending_reg
    if (!rst_ni) begin
      clr_pending_q <= 1'b0;
    end else begin
      clr_pending_q <= clr_pending_d;
    end
  end
  assign clr_hold = clear_pulse | clr_pending_q;

  // Output block capture / handshake.
  always_ff @(posedge clk_i or negedge rst_ni) begin : blk_out_reg
    if (!rst_ni) begin
      blk_data_q    <= '0;
      blk_valid_q   <= 1'b0;
      out_pending_q <= 1'b0;
    end else begin
      if (clr_hold) begin
        // Abort/clear takes precedence over a same-cycle capture: drop any held output block so a
        // stale ciphertext/plaintext is neither replayed into the next transfer (which would
        // deadlock the feed gate on !blk_valid_q/!out_pending_q) nor left visible on blk_data_o.
        blk_data_q    <= '0;
        blk_valid_q   <= 1'b0;
        out_pending_q <= 1'b0;
      end else if (blk_capture) begin
        blk_data_q    <= aes_data_out;
        blk_valid_q   <= 1'b1;
        out_pending_q <= 1'b1;
      end else if (blk_valid_q && blk_ready_i) begin
        blk_valid_q   <= 1'b0;
        out_pending_q <= 1'b0;
      end
    end
  end
  assign blk_data_o  = blk_data_q;
  assign blk_valid_o = blk_valid_q;

  // Authentication tag capture (GCM_TAG). Latched once and held until reset/clear; the consumer
  // (dma.sv, or the TB) compares it against the expected/received tag.
  always_ff @(posedge clk_i or negedge rst_ni) begin : tag_reg
    if (!rst_ni) begin
      tag_q       <= '0;
      tag_valid_q <= 1'b0;
    end else if (tag_capture) begin
      tag_q       <= aes_data_out;
      tag_valid_q <= 1'b1;
    end else if (clr_hold || tag_clear) begin
      tag_valid_q <= 1'b0;
    end
  end
  assign tag_o       = tag_q;
  assign tag_valid_o = tag_valid_q;

  ///////////////////////////////
  // reg2hw / hw2reg adapter    //
  ///////////////////////////////
  always_comb begin : reg2hw_adapter
    aes_reg2hw = '0;

    // -- CTRL_SHADOWED (two-write commit; .re resets the commit phase) --
    aes_reg2hw.ctrl_shadowed.operation.q        = op_i;
    aes_reg2hw.ctrl_shadowed.operation.qe       = ctrl_qe;
    aes_reg2hw.ctrl_shadowed.operation.re       = shadow_phase_clr;
    aes_reg2hw.ctrl_shadowed.mode.q             = mode_i;
    aes_reg2hw.ctrl_shadowed.mode.qe            = ctrl_qe;
    aes_reg2hw.ctrl_shadowed.mode.re            = shadow_phase_clr;
    aes_reg2hw.ctrl_shadowed.key_len.q          = key_len_i;
    aes_reg2hw.ctrl_shadowed.key_len.qe         = ctrl_qe;
    aes_reg2hw.ctrl_shadowed.key_len.re         = shadow_phase_clr;
    aes_reg2hw.ctrl_shadowed.sideload.q         = sideload_i;
    aes_reg2hw.ctrl_shadowed.sideload.qe        = ctrl_qe;
    aes_reg2hw.ctrl_shadowed.sideload.re        = shadow_phase_clr;
    aes_reg2hw.ctrl_shadowed.prng_reseed_rate.q = reseed_rate_i;
    aes_reg2hw.ctrl_shadowed.prng_reseed_rate.qe = ctrl_qe;
    aes_reg2hw.ctrl_shadowed.prng_reseed_rate.re = shadow_phase_clr;
    aes_reg2hw.ctrl_shadowed.manual_operation.q  = 1'b0; // auto-operation
    aes_reg2hw.ctrl_shadowed.manual_operation.qe = ctrl_qe;
    aes_reg2hw.ctrl_shadowed.manual_operation.re = shadow_phase_clr;

    // -- CTRL_GCM_SHADOWED (two-write commit; phase comes from the wrapper's gcm_phase_q;
    //    .re resets the commit phase) --
    aes_reg2hw.ctrl_gcm_shadowed.phase.q            = gcm_phase_q;
    aes_reg2hw.ctrl_gcm_shadowed.phase.qe           = ctrl_gcm_qe;
    aes_reg2hw.ctrl_gcm_shadowed.phase.re           = shadow_phase_clr;
    // Full 16-byte blocks only. A non-block-multiple message would produce a
    // confidently-wrong authentication tag (the GHASH length block is built from whole-block counts
    // in gcm_len_*_bits). This is a hard contract: dma.sv MUST reject non-16-byte-multiple AES
    // transfers in its legal-combination check (DmaSizeErr) until partial-block support is added.
    aes_reg2hw.ctrl_gcm_shadowed.num_valid_bytes.q  = 5'd16;
    aes_reg2hw.ctrl_gcm_shadowed.num_valid_bytes.qe = ctrl_gcm_qe;
    aes_reg2hw.ctrl_gcm_shadowed.num_valid_bytes.re = shadow_phase_clr;

    // -- KEY_SHARE0/1 (single-write subregs, pulse once) --
    for (int i = 0; i < 8; i++) begin
      aes_reg2hw.key_share0[i].q  = key_share0_i[i];
      aes_reg2hw.key_share0[i].qe = key_qe;
      aes_reg2hw.key_share1[i].q  = key_share1_i[i];
      aes_reg2hw.key_share1[i].qe = key_qe;
    end

    // -- IV (load once) --
    for (int i = 0; i < 4; i++) begin
      aes_reg2hw.iv[i].q  = iv_i[i];
      aes_reg2hw.iv[i].qe = iv_qe;
    end

    // -- DATA_IN (one word per cycle; see the data_in feed counter note above). During GCM_TAG the
    //    input is the internally-built length block instead of the streamed block. --
    for (int i = 0; i < 4; i++) begin
      aes_reg2hw.data_in[i].q  = data_in_is_len ? gcm_len_block[i*32 +: 32]
                                                : blk_data_i[i*32 +: 32];
      aes_reg2hw.data_in[i].qe = data_in_qe[i];
    end

    // -- DATA_OUT read strobe (read when we capture a block or the tag) --
    for (int i = 0; i < 4; i++) begin
      aes_reg2hw.data_out[i].q  = '0;
      aes_reg2hw.data_out[i].re = blk_capture | tag_capture;
    end

    // -- TRIGGER -- (held until aes_core acknowledges the clear, see clr_hold)
    aes_reg2hw.trigger.start.q                = 1'b0; // auto-operation, never used
    aes_reg2hw.trigger.key_iv_data_in_clear.q = clr_hold;
    aes_reg2hw.trigger.data_out_clear.q       = clr_hold;
    aes_reg2hw.trigger.prng_reseed.q          = 1'b0;

    // -- STATUS (output_lost feedback, SW read-back path) --
    aes_reg2hw.status.output_lost.q = 1'b0;
    aes_reg2hw.status.idle.q        = aes_idle;

    // -- CTRL_AUX_SHADOWED --
    aes_reg2hw.ctrl_aux_shadowed.key_touch_forces_reseed.q = 1'b1;
    aes_reg2hw.ctrl_aux_shadowed.force_masks.q             = SecAllowForcingMasks;

    // -- ALERT_TEST --
    aes_reg2hw.alert_test.fatal_fault.q          = 1'b0;
    aes_reg2hw.alert_test.fatal_fault.qe         = 1'b0;
    aes_reg2hw.alert_test.recov_ctrl_update_err.q  = 1'b0;
    aes_reg2hw.alert_test.recov_ctrl_update_err.qe = 1'b0;
  end

  //////////////
  // aes_core //
  //////////////
  // SEC_CM: LC_ESCALATE_EN.INTERSIG.MUBI - synchronize the life cycle escalation input (mirrors
  // aes.sv:115-122; aes_core does not synchronize it internally).
  lc_ctrl_pkg::lc_tx_t lc_escalate_en;
  prim_lc_sync #(
    .NumCopies (1)
  ) u_prim_lc_sync (
    .clk_i,
    .rst_ni,
    .lc_en_i ( lc_escalate_en_i ),
    .lc_en_o ( {lc_escalate_en} )
  );

  aes_core #(
    .AES192Enable         ( AES192Enable         ),
    // The inline AES datapath always builds GCM (the DMA's AAD/tag flow depends on GHASH).
    .AESGCMEnable         ( 1'b1                 ),
    .SecMasking           ( SecMasking           ),
    .SecSBoxImpl          ( SecSBoxImpl          ),
    .SecAllowForcingMasks ( SecAllowForcingMasks ),
    .EntropyWidth         ( EntropyWidth         ),
    .RndCnstClearingLfsrSeed  ( RndCnstClearingLfsrSeed  ),
    .RndCnstClearingLfsrPerm  ( RndCnstClearingLfsrPerm  ),
    .RndCnstClearingSharePerm ( RndCnstClearingSharePerm ),
    .RndCnstMaskingLfsrSeed   ( RndCnstMaskingLfsrSeed   ),
    .RndCnstMaskingLfsrPerm   ( RndCnstMaskingLfsrPerm   )
  ) u_aes_core (
    .clk_i,
    .rst_ni,
    // Countermeasure reduction: no separate shadow reset in this wrapper.
    .rst_shadowed_ni        ( rst_ni               ),

    .entropy_clearing_req_o ( entropy_clearing_req ),
    .entropy_clearing_ack_i ( entropy_clearing_ack ),
    .entropy_clearing_i     ( edn_data             ),
    .entropy_masking_req_o  ( entropy_masking_req  ),
    .entropy_masking_ack_i  ( entropy_masking_ack  ),
    .entropy_masking_i      ( edn_data             ),

    .keymgr_key_i           ( keymgr_key_i         ),

    .lc_escalate_en_i       ( lc_escalate_en       ),

    // Countermeasure reduction: no TL register block to detect these errors; tied off.
    .shadowed_storage_err_i ( 1'b0                 ),
    .shadowed_update_err_i  ( 1'b0                 ),
    .intg_err_alert_i       ( 1'b0                 ),
    .alert_recov_o          ( alert_recov_o        ),
    .alert_fatal_o          ( aes_alert_fatal      ),

    .gcm_init_done_o        ( aes_gcm_init_done    ),

    .reg2hw                 ( aes_reg2hw           ),
    .hw2reg                 ( aes_hw2reg           )
  );

  ////////////////
  // Assertions //
  ////////////////
  `ASSERT_KNOWN(EdnReqKnown_A, edn_o.edn_req)
  `ASSERT_KNOWN(BlkValidKnown_A, blk_valid_o)
  `ASSERT_KNOWN(AlertRecovKnown_A, alert_recov_o)
  `ASSERT_KNOWN(AlertFatalKnown_A, alert_fatal_o)

  // Liveness: a running GCM_INIT must always make progress - advance on gcm_init_done, abort to
  // idle, or fault to err - so a stuck init (done never asserting) fails here, not hangs silently.
  `ASSERT(GcmInitProgress_A,
          (state_q == DmaAesStGcmRun && gcm_phase_q == GCM_INIT) |->
              s_eventually (state_q != DmaAesStGcmRun || gcm_phase_q != GCM_INIT))

  // SEC_CM: AES.FSM.SPARSE - the alert trigger assertion is handled by dma.sv's
  // CtrlStateFsmCheck_A and the aes_alert_fatal wiring; disable the prim_sparse_fsm_flop's
  // built-in EnableAlertTriggerSVA check to avoid cross-module assign issues in VCS.

endmodule
