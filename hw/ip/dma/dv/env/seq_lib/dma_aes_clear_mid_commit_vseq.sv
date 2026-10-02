// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed regression for the inline-AES shadow-register commit-phase desync on abort/clear. The
// aes_core CTRL_SHADOWED / CTRL_GCM_SHADOWED registers commit on a two-write
// protocol; the wrapper mirrors the hardware commit phase in its open-loop `cfg_phase_q`. A
// `clear_i` (DMA abort) landing between the two accepted writes resets the wrapper's mirror but NOT
// the hardware `prim_subreg_shadow.phase_q` (clear only wipes key/iv/data; rst_shadowed_ni resets
// the shadow DATA, not the phase). The next transfer's first write would then be mis-read as the
// second (commit) write -> a spurious recov_ctrl_update_err and/or a configuration that never
// actually commits (the engine runs with the stale prior config). The fix pulses the shadow read
// strobe (shadow_phase_clr) at start_i to force the hardware phase back to 0 in lockstep with
// cfg_phase_q.
//
// The natural window is a single cycle between the two writes and is not cycle-addressable from the
// CSR abort path (the abort takes several cycles to propagate). To exercise the residual
// deterministically this sequence:
//   1. Runs and aborts an in-flight AES transfer (exercises the real abort/clear path), then
//   2. Uses uvm_hdl_deposit to place the aes_core shadow-phase flops into the exact post-abort
//      desynced state (phase == 1 while the wrapper is idle with cfg_phase_q == 0), confirms via
//      uvm_hdl_read that the scenario is established (so the test can never pass vacuously), then
//   3. Launches a fresh transfer whose config differs from the prior one. The scoreboard (AES
//      predictor + unexpected-alert check) then proves the fix: the recovery transfer must produce
//      the correct ciphertext (config committed) AND raise no recov_fault (no spurious update err).
//      Without the fix the recovery either mismatches (stale config) or fires recov_fault.
// Both the CTRL_SHADOWED (CTR + GCM share it) and CTRL_GCM_SHADOWED (every GCM phase commit) shadow
// registers are desynced and recovered.
class dma_aes_clear_mid_commit_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_aes_clear_mid_commit_vseq)
  `uvm_object_new

  localparam bit [63:0] SrcAddr   = 64'h0000_1000;
  localparam bit [63:0] DstAddr   = 64'h0000_2000;
  localparam bit [31:0] RangeBase = 32'h0000_0000;
  localparam bit [31:0] RangeLim  = 32'h0000_FFFF;

  // Whitebox hierarchy of the aes_core shadow-phase flops. KEEP IN SYNC with the instance names in
  // hw/ip/aes/rtl/aes_core.sv, aes_ctrl_reg_shadowed.sv, aes_ctrl_gcm_reg_shadowed.sv and
  // hw/ip/prim/rtl/prim_subreg_shadow.sv (the `phase_q` flop).
  localparam string AesCorePath = "tb.dut.u_dma_aes.u_aes_core";

  rand int unsigned num_iters;
  constraint num_iters_c { num_iters inside {[3:5]}; }

  // ---- whitebox shadow-phase helpers ------------------------------------------------------------
  function void get_phase_paths(ref string ctrl_paths[$], ref string gcm_paths[$]);
    string cs = {AesCorePath, ".u_ctrl_reg_shadowed."};
    string gs = {AesCorePath, ".u_ctrl_gcm_reg_shadowed.gen_ctrl_gcm_reg_shadowed."};
    ctrl_paths = '{};
    gcm_paths  = '{};
    // CTRL_SHADOWED: one prim_subreg_shadow per field.
    ctrl_paths.push_back({cs, "u_ctrl_reg_shadowed_operation.phase_q"});
    ctrl_paths.push_back({cs, "u_ctrl_reg_shadowed_mode.phase_q"});
    ctrl_paths.push_back({cs, "u_ctrl_reg_shadowed_key_len.phase_q"});
    ctrl_paths.push_back({cs, "u_ctrl_reg_shadowed_sideload.phase_q"});
    ctrl_paths.push_back({cs, "u_ctrl_reg_shadowed_prng_reseed_rate.phase_q"});
    ctrl_paths.push_back({cs, "u_ctrl_reg_shadowed_manual_operation.phase_q"});
    // CTRL_GCM_SHADOWED: phase + num_valid_bytes.
    gcm_paths.push_back({gs, "u_ctrl_gcm_reg_shadowed_phase.phase_q"});
    gcm_paths.push_back({gs, "u_ctrl_gcm_reg_shadowed_num_valid_bytes.phase_q"});
  endfunction

  // Drive every shadow commit-phase flop to `val`, emulating "first write accepted, clear landed
  // before the second" (val=1) - the exact state a clear-mid-commit leaves behind.
  function void deposit_shadow_phase(bit val);
    string cps[$], gps[$];
    get_phase_paths(cps, gps);
    foreach (cps[i]) `DV_CHECK_FATAL(uvm_hdl_deposit(cps[i], val), {"deposit failed: ", cps[i]})
    foreach (gps[i]) `DV_CHECK_FATAL(uvm_hdl_deposit(gps[i], val), {"deposit failed: ", gps[i]})
  endfunction

  // Returns 1 only if EVERY shadow commit-phase flop is in phase 1 (all desynced) - we deposit 1
  // into all of them, so anything less means the setup did not take.
  function bit all_shadow_phase_set();
    string cps[$], gps[$];
    logic v;
    bit   all = 1'b1;
    get_phase_paths(cps, gps);
    foreach (cps[i]) begin `DV_CHECK_FATAL(uvm_hdl_read(cps[i], v), {"read failed: ", cps[i]}) all &= v; end
    foreach (gps[i]) begin `DV_CHECK_FATAL(uvm_hdl_read(gps[i], v), {"read failed: ", gps[i]}) all &= v; end
    return all;
  endfunction

  // ---- transfer helpers -------------------------------------------------------------------------
  task clear_status();
    csr_wr(ral.status, 32'h0000_002E); // RW1C done/aborted/error/chunk_done
    csr_wr(ral.intr_state, (1 << IntrDmaDone) | (1 << IntrDmaChunkDone) | (1 << IntrDmaError));
  endtask

  // Randomize a fresh AES-encrypt config (so it differs from any previously committed config),
  // publish it into `cfg` for the scoreboard predictor, preload memory and program the CSRs. Does
  // NOT assert `go` - the caller decides when to start (and may inject the desync first).
  task setup_encrypt(bit gcm, int n_blocks, int aad_blocks);
    dma_seq_item c = dma_seq_item::type_id::create("c");
    bit [7:0] pt_b[];

    // Fresh random key/IV/AAD: a recovery transfer that reuses the prior config would mask the bug
    // (matching shadow value -> no update error), so always reconfigure with new material.
    foreach (cfg.aes_key0[w]) cfg.aes_key0[w] = $urandom;
    foreach (cfg.aes_key1[w]) cfg.aes_key1[w] = $urandom;
    foreach (cfg.aes_iv[w])   cfg.aes_iv[w]   = $urandom;
    if (gcm) cfg.aes_iv[3] = 32'h0; // GCM: core initializes the counter word internally
    foreach (cfg.aes_aad[w])  cfg.aes_aad[w]  = $urandom;
    cfg.aes_key_len     = (1 << $urandom_range(0, 2)); // one-hot AES-128/192/256
    cfg.aes_sideload    = 1'b0;
    cfg.aes_reseed_rate = (1 << $urandom_range(0, 2));
    cfg.aes_aad_blocks  = aad_blocks[3:0];
    cfg.aes_mode_gcm    = gcm;
    cfg.aes_decrypt     = 1'b0;

    pt_b = new[n_blocks*16];
    foreach (pt_b[b]) pt_b[b] = $urandom;
    cfg.src_data = pt_b; // scoreboard predicts the ciphertext from this

    foreach (pt_b[b]) cfg.mems[OtInternalAddr].write_byte(SrcAddr + b, pt_b[b]);
    for (int i = 0; i < n_blocks*16; i++) cfg.mems[OtInternalAddr].write_byte(DstAddr + i, 8'hA5);

    c.src_asid = OtInternalAddr; c.dst_asid = OtInternalAddr;
    c.src_addr = SrcAddr; c.dst_addr = DstAddr;
    c.src_addr_inc = 1'b1; c.dst_addr_inc = 1'b1;
    c.src_chunk_wrap = 1'b0; c.dst_chunk_wrap = 1'b0;
    c.handshake = 1'b0;
    c.total_data_size = n_blocks*16; c.chunk_data_size = n_blocks*16;
    c.per_transfer_width = DmaXfer4BperTxn;

    clear_status();
    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(OtInternalAddr, OtInternalAddr);
    set_total_size(n_blocks*16); set_chunk_data_size(n_blocks*16);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
    program_aes_config(cfg.aes_key0, cfg.aes_key1, cfg.aes_iv, cfg.aes_aad,
                       cfg.aes_aad_blocks, cfg.aes_key_len, cfg.aes_sideload, cfg.aes_reseed_rate);
    start_device(c);
  endtask

  task go_encrypt(bit gcm);
    set_control(gcm ? OpcAesGcmEnc : OpcAesCtrEnc,
                .initial_transfer(1'b1), .handshake(1'b0), .go(1'b1));
  endtask

  // Wait for a terminal state after an abort and re-arm for the next transfer.
  task recover_terminal();
    bit [31:0] st, regwen;
    `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[1] || st[2] || st[3]));,
                 "clear-mid-commit: aborted transfer did not reach a terminal state")
    abort_pending = 1'b0;
    clear_aborted();
    clear_status();
    `DV_SPINWAIT(begin
      do begin csr_rd(ral.cfg_regwen, regwen); end while (regwen != prim_mubi_pkg::MuBi4True);
    end, "clear-mid-commit: CFG_REGWEN did not unlock after abort")
    stop_device();
  endtask

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting inline-AES clear-mid-commit regression", UVM_LOW)
    init_model();
    cfg.ref_model = 1'b1;

    for (int mode = 0; mode < 2; mode++) begin
      bit gcm = mode[0];
      for (int i = 0; i < num_iters; i++) begin
        int n_blocks   = $urandom_range(2, 4);
        int aad_blocks = gcm ? $urandom_range(0, 2) : 0;
        status_t status;

        // ---- 1) realistic abort of an in-flight transfer (exercise the real clear path) ----
        cfg.aes_scb_predict = 1'b0; // aborted transfer leaves a partial destination; do not predict
        setup_encrypt(gcm, n_blocks, aad_blocks);
        go_encrypt(gcm);
        cfg.clk_rst_vif.wait_clks($urandom_range(1, 40));
        abort();
        recover_terminal();

        // ---- 2) deterministically establish the mid-commit desync the abort may leave behind ----
        // Place the shadow commit phase into "first write accepted, second pending" while idle.
        deposit_shadow_phase(1'b1);
        `DV_CHECK(all_shadow_phase_set(),
                  "clear-mid-commit: failed to establish the shadow-phase desync on every flop (test would be vacuous)")

        // ---- 3) recovery transfer: the fix must re-arm the shadow phase at start_i ----
        // Scoreboard predicts the ciphertext (config must have committed) and flags any unexpected
        // recov_fault (no spurious update error). No set_exp_alert: a recov_fault here is a failure.
        cfg.aes_scb_predict = 1'b1;
        status = '0;
        setup_encrypt(gcm, n_blocks, aad_blocks);
        go_encrypt(gcm);
        poll_status(.intr_driven(1'b0), .status(status));
        stop_device();
        `DV_CHECK_EQ(status[StatusError], 1'b0,
                     $sformatf("clear-mid-commit %s iter %0d: recovery transfer errored",
                               gcm ? "GCM" : "CTR", i))
        `DV_CHECK_EQ(status[StatusDone], 1'b1,
                     $sformatf("clear-mid-commit %s iter %0d: recovery transfer did not complete",
                               gcm ? "GCM" : "CTR", i))
        clear_status();
      end
    end

    // Largest legal GCM transfer: 8191 16-byte text blocks (0x1_FFF0 bytes). Exercises the abort
    // path on a maximal transfer and covers the GCM block-count upper boundary
    // (cp_gcm_blocks.max_valid), sampled when the accepted config reaches DmaAddrSetup. Abort soon
    // after start so the 128KiB transfer does not complete. Both endpoints are OT-internal, so the
    // single-endpoint range check is skipped despite the large size.
    cfg.aes_scb_predict = 1'b0;
    setup_encrypt(.gcm(1'b1), .n_blocks(8191), .aad_blocks(0));
    go_encrypt(1'b1);
    cfg.clk_rst_vif.wait_clks($urandom_range(1, 40));
    abort();
    recover_terminal();

    `uvm_info(`gfn, "DMA: Completed inline-AES clear-mid-commit regression", UVM_LOW)
  endtask : body
endclass
