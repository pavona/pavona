// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Trigger both sync and async fault, then check fatal alert is triggered and fault_status is
// updated correctly. Ported from hw/ip/keymgr/dv/env/seq_lib/keymgr_sync_async_fault_cross_vseq.sv.
class keymgr_dpe_sync_async_fault_cross_vseq extends keymgr_dpe_base_vseq;
  `uvm_object_utils(keymgr_dpe_sync_async_fault_cross_vseq)
  `uvm_object_new

  bit sync_fault_trig_first;
  bit async_fault_trig_first;

  task body();
    bit [TL_DW-1:0] act_fault_status;

    // Get past StWorkDpeReset so the DUT will issue KMAC requests when faults are triggered.
    repeat ($urandom_range(1, 4)) keymgr_dpe_operations(.advance_state(1));
    cfg.en_scb = 0;
    cfg.keymgr_dpe_vif.en_chk = 0;

    // Faults scramble the KMAC datapath; suppress assertions that fire as a consequence.
    // The list mirrors hw/ip/keymgr/dv/env/seq_lib/keymgr_custom_cm_vseq.sv.
    $assertoff(0, "tb.keymgr_dpe_kmac_intf");
    $assertoff(0, "tb.dut.u_ctrl.DataEn_A");
    $assertoff(0, "tb.dut.u_kmac_if.LastStrb_A");
    $assertoff(0, "tb.dut.KmacDataKnownO_A");
    $assertoff(0, "tb.dut.u_sideload_ctrl.KmacKeySource_a");

    fork
      trigger_sync_fault();
      trigger_async_fault();
    join

    wait_and_check_fatal_alert();

    csr_rd(.ptr(ral.fault_status), .value(act_fault_status));
    `DV_CHECK_EQ(act_fault_status[keymgr_pkg::FaultRegIntg], 1)

    // The KMAC sync fault only latches if a KMAC transaction was in flight when the
    // async fault arrived; with short keymgr_dpe ops the async path can win the race
    // and the FSM tears down before any KMAC error registers. Only sample the cross
    // covergroup when both fault types are actually observed -- otherwise the sampled
    // arrival order doesn't reflect what the DUT saw.
    if (cfg.en_cov &&
        (act_fault_status[keymgr_pkg::FaultKmacOp] ||
         act_fault_status[keymgr_pkg::FaultKmacOut])) begin
      cov.sync_async_fault_cross_cg.sample(sync_fault_trig_first, async_fault_trig_first);
    end
  endtask : body

  task trigger_sync_fault();
    bit is_adv_op = $urandom_range(0, 1);

    cfg.m_keymgr_dpe_kmac_agent_cfg.error_rsp_pct = 100;
    keymgr_dpe_operations(.advance_state(is_adv_op),
                          .num_gen_op(!is_adv_op),
                          .clr_output(0),
                          .wait_done(1));

    if (!async_fault_trig_first) sync_fault_trig_first = 1;
  endtask : trigger_sync_fault

  task trigger_async_fault();
    set_tl_assert_en(.enable(0));
    cfg.clk_rst_vif.wait_clks($urandom_range(0, 2000));
    issue_tl_access_w_intg_err(ral.get_name());
    set_tl_assert_en(.enable(1));

    if (!sync_fault_trig_first) async_fault_trig_first = 1;
  endtask : trigger_async_fault

  // Disable scb-driven check_en in this seq; the body does its own checks above.
  virtual function bit get_check_en();
    return 0;
  endfunction

  task post_start();
    expect_fatal_alerts = 1;
    super.post_start();
    cfg.en_scb = 1;
    cfg.keymgr_dpe_vif.en_chk = 1;
  endtask

endclass : keymgr_dpe_sync_async_fault_cross_vseq
