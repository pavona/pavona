// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Focused reset test for the TL Host path. It resets while the Host driver is
// delaying A-valid, while it is holding A-valid for A-ready, and after an A
// handshake while it is waiting for D. A final clean transfer proves restart.
class tl_rst_safe_host_reset_vseq extends dv_base_vseq #(
  .CFG_T              (tl_agent_env_cfg),
  .COV_T              (tl_agent_env_cov),
  .VIRTUAL_SEQUENCER_T(tl_rst_safe_agent_virtual_sequencer)
);

  localparam int unsigned DelayedAValidMinClks = 50;
  localparam int unsigned DelayedAValidMaxClks = 100;
  localparam int unsigned DelayedRspMinClks = 50;
  localparam int unsigned DelayedRspMaxClks = 100;

  `uvm_object_utils(tl_rst_safe_host_reset_vseq)
  `uvm_object_new

  // Apply an in-test reset and synchronize to the first complete reference
  // clock after deassertion before starting the next reset epoch. Sequences
  // must use clock/reset events for synchronization, never # delays.
  protected virtual task apply_and_wait_for_reset();
    apply_reset();
    cfg.reset_domain.wait_reset_deassert();
    cfg.reset_domain.clk_rst_vif.wait_clks(1);
  endtask : apply_and_wait_for_reset

  // The reset-safe Host driver starts its workers on clock boundaries. Waiting
  // at least four reference clocks ensures the requested Host state has been
  // entered; the randomized upper bound varies the reset placement.
  protected virtual task wait_for_host_state();
    cfg.reset_domain.clk_rst_vif.wait_clks($urandom_range(4, 8));
  endtask : wait_for_host_state

  virtual task body();
    tl_host_seq   delayed_a_valid_host_seq;
    tl_host_seq   held_a_valid_host_seq;
    tl_host_seq   waiting_for_d_host_seq;
    tl_host_seq   clean_host_seq;
    tl_device_seq delayed_device_seq;
    tl_device_seq clean_device_seq;
    tl_seq_item   observed_req;

    // Phase 1: the Host driver owns an item whose A-valid assertion is delayed.
    delayed_a_valid_host_seq = tl_host_seq#()::type_id::create("delayed_a_valid_host_seq");
    delayed_a_valid_host_seq.min_req_delay = DelayedAValidMinClks;
    delayed_a_valid_host_seq.max_req_delay = DelayedAValidMaxClks;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(delayed_a_valid_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      delayed_a_valid_host_seq.start(p_sequencer.host_seqr);
    join_none
    wait_for_host_state();
    apply_and_wait_for_reset();
    delayed_a_valid_host_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "A request was published during the delayed-A-valid reset phase")

    // Phase 2: A-valid is immediate, while build-time Device timing withholds
    // A-ready. Reset destroys the Host item before the A handshake.
    held_a_valid_host_seq = tl_host_seq#()::type_id::create("held_a_valid_host_seq");
    held_a_valid_host_seq.min_req_delay = 0;
    held_a_valid_host_seq.max_req_delay = 0;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(held_a_valid_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      held_a_valid_host_seq.start(p_sequencer.host_seqr);
    join_none
    wait_for_host_state();
    apply_and_wait_for_reset();
    held_a_valid_host_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "An unaccepted A request reached the Device responder FIFO")

    // Phase 3: allow the A handshake, but delay D long enough to reset while
    // the Host is waiting for the response to its accepted request.
    delayed_device_seq = tl_device_seq#()::type_id::create("delayed_device_seq");
    `DV_CHECK_RANDOMIZE_FATAL(delayed_device_seq)
    delayed_device_seq.min_rsp_delay = DelayedRspMinClks;
    delayed_device_seq.max_rsp_delay = DelayedRspMaxClks;
    fork
      delayed_device_seq.start(p_sequencer.device_seqr);
    join_none

    waiting_for_d_host_seq = tl_host_seq#()::type_id::create("waiting_for_d_host_seq");
    waiting_for_d_host_seq.min_req_delay = 0;
    waiting_for_d_host_seq.max_req_delay = 0;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(waiting_for_d_host_seq,
                                   req_cnt == 1;
                                   req_abort_after_a_valid_len == 0;)
    fork
      waiting_for_d_host_seq.start(p_sequencer.host_seqr);
    join_none

    p_sequencer.device_a_chan_fifo.get(observed_req);
    cfg.reset_domain.clk_rst_vif.wait_clks($urandom_range(0, 5));
    apply_and_wait_for_reset();
    waiting_for_d_host_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    delayed_device_seq.wait_for_sequence_state(UVM_STOPPED | UVM_FINISHED);
    `DV_CHECK_EQ(p_sequencer.device_seqr.a_chan_req_fifo.used(), 0,
                 "Reset left a request queued while the Host was waiting for D")

    // Phase 4: prove that both reset-safe agents restart and a fresh transfer
    // completes without stale Host or Device state.
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
                 "Fresh transfer left a Device request unconsumed")
  endtask : body
endclass : tl_rst_safe_host_reset_vseq
