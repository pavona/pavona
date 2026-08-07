// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Focused reset test for the TL device path. It interrupts the driver during
// both response delay and asserted D-valid, resets a responder waiting for a
// request, and resets with an accepted request deliberately left in the
// monitor-fed FIFO. A final clean transfer proves post-reset restart.
class tl_rst_safe_device_reset_vseq extends dv_base_vseq #(
  .CFG_T              (tl_agent_env_cfg),
  .COV_T              (tl_agent_env_cov),
  .VIRTUAL_SEQUENCER_T(tl_rst_safe_agent_virtual_sequencer)
);

  localparam int unsigned DelayedRspMinClks = 50;
  localparam int unsigned DelayedRspMaxClks = 100;

  `uvm_object_utils(tl_rst_safe_device_reset_vseq)
  `uvm_object_new

  // Apply an in-test reset and synchronize to the first complete reference
  // clock after deassertion before starting the next reset epoch. Sequences
  // must use clock/reset events for synchronization, never # delays.
  protected virtual task apply_and_wait_for_reset();
    apply_reset();
    cfg.reset_domain.wait_reset_deassert();
    cfg.reset_domain.clk_rst_vif.wait_clks(1);
  endtask : apply_and_wait_for_reset

  // Randomize reset placement by a small number of reference-clock edges. This
  // is reset-injection timing only; functional stimulus and response decisions
  // remain transaction-level.
  protected virtual task wait_boundary_clks(int unsigned min_clks = 1, int unsigned max_clks = 5);
    cfg.reset_domain.clk_rst_vif.wait_clks($urandom_range(min_clks, max_clks));
  endtask : wait_boundary_clks

  virtual task body();
    tl_device_seq delayed_device_seq;
    tl_device_seq asserted_valid_device_seq;
    tl_device_seq blocked_device_seq;
    tl_device_seq clean_device_seq;
    tl_host_seq   interrupted_host_seq;
    tl_host_seq   asserted_valid_host_seq;
    tl_host_seq   queued_host_seq;
    tl_host_seq   clean_host_seq;
    tl_seq_item   observed_req;

    // Phase 1: make the device driver own a response for long enough that
    // reset deterministically destroys it before D-channel presentation.
    delayed_device_seq = tl_device_seq#()::type_id::create("delayed_device_seq");
    `DV_CHECK_RANDOMIZE_FATAL(delayed_device_seq)
    delayed_device_seq.min_rsp_delay = DelayedRspMinClks;
    delayed_device_seq.max_rsp_delay = DelayedRspMaxClks;
    fork
      delayed_device_seq.start(p_sequencer.device_seqr);
    join_none

    interrupted_host_seq = tl_host_seq#()::type_id::create("interrupted_host_seq");
    interrupted_host_seq.min_req_delay = 0;
    interrupted_host_seq.max_req_delay = 0;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(interrupted_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      interrupted_host_seq.start(p_sequencer.host_seqr);
    join_none

    p_sequencer.device_a_chan_fifo.get(observed_req);
    wait_boundary_clks(.min_clks(0), .max_clks(5));
    apply_and_wait_for_reset();
    interrupted_host_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    delayed_device_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "Reset left a request queued after interrupting the device response")

    // Phase 2: use an immediate response item while the host's configured
    // D-ready delay is long. Reset after the accepted A transaction and a few
    // reference clocks, while the driver is holding D-valid for D-ready.
    asserted_valid_device_seq = tl_device_seq#()::type_id::create("asserted_valid_device_seq");
    `DV_CHECK_RANDOMIZE_FATAL(asserted_valid_device_seq)
    asserted_valid_device_seq.min_rsp_delay = 0;
    asserted_valid_device_seq.max_rsp_delay = 0;
    fork
      asserted_valid_device_seq.start(p_sequencer.device_seqr);
    join_none

    asserted_valid_host_seq = tl_host_seq#()::type_id::create("asserted_valid_host_seq");
    asserted_valid_host_seq.min_req_delay = 0;
    asserted_valid_host_seq.max_req_delay = 0;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(asserted_valid_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      asserted_valid_host_seq.start(p_sequencer.host_seqr);
    join_none

    p_sequencer.device_a_chan_fifo.get(observed_req);
    wait_boundary_clks();
    apply_and_wait_for_reset();
    asserted_valid_host_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    asserted_valid_device_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "Reset left a request queued after interrupting asserted D-valid")

    // Phase 3: accept a request without a responder, then reset. This directly
    // checks that stop_sequences() flushes the monitor-fed request FIFO.
    queued_host_seq = tl_host_seq#()::type_id::create("queued_host_seq");
    queued_host_seq.min_req_delay = 0;
    queued_host_seq.max_req_delay = 0;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(queued_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      queued_host_seq.start(p_sequencer.host_seqr);
    join_none

    p_sequencer.device_a_chan_fifo.get(observed_req);
    wait_boundary_clks(.min_clks(0), .max_clks(5));
    apply_and_wait_for_reset();
    queued_host_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "Reset did not flush the unconsumed device request")

    // Phase 4: stop a responder that is blocked waiting for its next monitor
    // transaction. This proves an empty FIFO wait also terminates on reset.
    blocked_device_seq = tl_device_seq#()::type_id::create("blocked_device_seq");
    `DV_CHECK_RANDOMIZE_FATAL(blocked_device_seq)
    fork
      blocked_device_seq.start(p_sequencer.device_seqr);
    join_none
    wait_boundary_clks();
    apply_and_wait_for_reset();
    blocked_device_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "Reset left state while the responder was waiting for a request")

    // Phase 5: a fresh responder must see only a fresh request, and the clean
    // post-reset transaction must complete normally.
    clean_device_seq = tl_device_seq#()::type_id::create("clean_device_seq");
    `DV_CHECK_RANDOMIZE_FATAL(clean_device_seq)
    clean_device_seq.min_rsp_delay = 0;
    clean_device_seq.max_rsp_delay = 0;
    fork
      clean_device_seq.start(p_sequencer.device_seqr);
    join_none

    clean_host_seq = tl_host_seq#()::type_id::create("clean_host_seq");
    clean_host_seq.min_req_delay = 0;
    clean_host_seq.max_req_delay = 0;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(clean_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      clean_host_seq.start(p_sequencer.host_seqr);
    join_none

    clean_host_seq.wait_for_sequence_state(UVM_FINISHED);
    clean_device_seq.seq_stop();
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "Fresh responder left a device request unconsumed")
  endtask : body
endclass : tl_rst_safe_device_reset_vseq
