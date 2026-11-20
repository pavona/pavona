// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// One fault epoch per interface and iteration, followed by a final healthy epoch.
// The interface count is set before randomization; execution progress stays in the sequence.
class cip_rst_safe_tl_intg_err_test_seq_parameters extends cip_rst_safe_csr_test_seq_parameters;
  `uvm_object_utils(cip_rst_safe_tl_intg_err_test_seq_parameters)

  uint num_ral_interfaces;

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == num_trans * num_ral_interfaces + 1;
  }

  constraint num_trans_c {
    num_trans == 10;
  }

  function new(string name = "");
    super.new(name);
    // Generic register checks start from reset values, without block functional programming.
    // All final checks also belong to main_thread(), not a post-start shutdown task.
    do_dut_shutdown = 1'b0;
  endfunction : new
endclass : cip_rst_safe_tl_intg_err_test_seq_parameters

// Select the fault, its location, and the repeated-alert target independently each epoch.
class cip_rst_safe_tl_intg_err_config_parameters extends cip_rst_safe_csr_config_parameters;
  `uvm_object_utils(cip_rst_safe_tl_intg_err_config_parameters)
  `uvm_object_new

  // Address-map input for the selected interface, supplied before each epoch's randomization.
  // This is not DUT state, and the constraint solver must not change the map.
  addr_range_t mem_ranges[$];

  rand tl_intg_err_e fault_kind;
  rand bit write;
  rand bit use_mem_addr;
  rand uint mem_index;
  rand bit [BUS_AW-1:0] addr;
  rand bit [BUS_DW-1:0] data;
  rand bit [BUS_DBW-1:0] mask;
  rand uint alert_handshakes;
  // Delay sequences count primary reference-clock cycles, not nanoseconds.
  rand uint fault_delay_clks;

  constraint fault_kind_c {
    fault_kind inside {TlIntgErrCmd, TlIntgErrData, TlIntgErrBoth};
  }

  constraint fault_address_c {
    if (mem_ranges.size() == 0) use_mem_addr == 0;
    if (use_mem_addr) {
      mem_index < mem_ranges.size();
      addr inside {[mem_ranges[mem_index].start_addr:mem_ranges[mem_index].end_addr]};
    } else {
      mem_index == 0;
    }
    // Choose the address category and window before the address. A large arbitrary-address
    // space or a large memory window must not dominate the category or window selection.
    solve use_mem_addr before mem_index;
    solve mem_index before addr;
  }

  constraint fault_mask_c {
    $countones(mask ^ {mask[BUS_DBW-2:0], 1'b0}) <= 2;
  }

  constraint alert_handshakes_c {
    alert_handshakes inside {[5:20]};
  }

  constraint fault_delay_clks_c {
    fault_delay_clks inside {[10:1000]};
  }

  constraint csr_access_abort_pct_c {
    // Fault and recovery checks need completed accesses. Adapter cancellation is covered by
    // the ordinary CSR tests, not by this directed fatal-alert recovery workload.
    csr_access_abort_pct == 0;
  }
endclass : cip_rst_safe_tl_intg_err_config_parameters

// Prove that corrupted TL requests cause an error response, sticky integrity status, and
// repeated fatal alerts while normal CSR traffic shares the interface. Acknowledgement alone
// is not recovery: only after these checks may the reset thread request a primary reset.
// The final epoch checks reset status and completes healthy CSR traffic without another reset.
//
// Alert evidence comes from a separate monitor FIFO, not pins, agent progress flags, or the
// scoreboard. The existing responder still acknowledges alerts. Missing observations prevent
// reset and leave the test subject to the normal phase timeout, rather than hiding the fault.
// This directed-reset workload must not be an ordinary stress-all child.
class cip_rst_safe_tl_intg_err_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rst_safe_csr_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T);
  `uvm_object_param_utils(cip_rst_safe_tl_intg_err_vseq #(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))
  `uvm_object_new

  protected string fault_ral_names[$];
  protected uint checked_faults;
  protected uint directed_resets;
  protected uint completed_recoveries;

  extern virtual task body();
  extern virtual task main_thread();
  extern virtual task reset_trigger_thread();
  extern virtual task post_start();
  extern virtual task issue_integrity_fault(string ral_name);
  extern virtual task check_integrity_status(bit fault_expected);
  extern virtual task check_repeated_alerts(uint count);
  extern virtual function void check_no_native_alerts();
endclass : cip_rst_safe_tl_intg_err_vseq

task cip_rst_safe_tl_intg_err_vseq::body();
  cip_rst_safe_tl_intg_err_test_seq_parameters intg_test_params;
  bit saved_tl_assert_en = 1'b1;

  if (test_params == null) begin
    test_params = cip_rst_safe_tl_intg_err_test_seq_parameters::type_id::create("test_params");
  end
  if (config_params == null) begin
    config_params = cip_rst_safe_tl_intg_err_config_parameters::type_id::create("config_params");
  end
  `downcast(intg_test_params, test_params)
  `DV_CHECK_EQ_FATAL(reset_ctrl_higher_seq, 0, "Integrity recovery owns its directed resets")
  `DV_CHECK_GT_FATAL(cfg.ral_models.size(), 0)
  `DV_CHECK_FATAL(p_sequencer.alert_observation_fifos.exists(cfg.tl_intg_alert_name),
                  "The integrity alert needs an independent monitor subscription")
  intg_test_params.num_ral_interfaces = cfg.ral_models.size();
  test_params.csr_test_type = "rw";

  fault_ral_names.delete();
  foreach (cfg.ral_models[i]) fault_ral_names.push_back(i);
  checked_faults = 0;
  directed_resets = 0;
  completed_recoveries = 0;

  // ALERT_TEST can produce the same native alert without an integrity fault. Keep that
  // software-triggered source in its own test so it cannot satisfy this test's alert count.
  foreach (all_csrs[i]) begin
    if (all_csrs[i].get_name() == "alert_test") begin
      csr_excl_item csr_excl = get_excl_item(all_csrs[i]);
      csr_excl.add_excl(all_csrs[i].get_full_name(), CsrExclWrite, CsrRwTest);
    end
  end

  // A background read can overlap the hardware status update, including on another interface.
  // Do not compare that read to a later RAL mirror. Check only these fields explicitly before
  // traffic and after both workers complete; all other CSR comparisons remain unchanged.
  foreach (cfg.tl_intg_alert_fields[field]) begin
    csr_excl_item csr_excl = get_excl_item(field);
    csr_excl.add_excl(field.get_full_name(), CsrExclCheck, CsrRwTest);
  end

  // Corruption can alter protocol fields as well as parity bits. Keep the legacy assertion
  // exception around the complete workload; monitored response and integrity checks stay on.
  void'(uvm_config_db#(bit)::get(null, "*", "tlul_assert_en", saved_tl_assert_en));
  uvm_config_db#(bit)::set(null, "*", "tlul_assert_en", 1'b0);
  super.body();
  uvm_config_db#(bit)::set(null, "*", "tlul_assert_en", saved_tl_assert_en);

  `DV_CHECK_EQ(checked_faults, test_params.num_trans * fault_ral_names.size())
  `DV_CHECK_EQ(directed_resets, checked_faults)
  `DV_CHECK_EQ(completed_recoveries, 1)
  `uvm_info(`gfn, $sformatf("TL integrity complete: faults=%0d resets=%0d recoveries=%0d",
                           checked_faults, directed_resets, completed_recoveries), UVM_LOW)
endtask : body

task cip_rst_safe_tl_intg_err_vseq::main_thread();
  cip_rst_safe_tl_intg_err_config_parameters intg_config_params;
  string ral_name;
  `downcast(intg_config_params, config_params)
  disable_coverage_sample_for_csr_test();
  alerts_ready();
  check_integrity_status(1'b0);
  check_no_native_alerts();

  // The base decrements the epoch budget before main_thread(). Zero is the final healthy
  // pass; a separate checked-fault count proves that earlier epochs did not skip their work.
  if (test_params.num_reset_loops == 0) begin
    run_csr_vseq(.csr_test_type("rw"));
    check_integrity_status(1'b0);
    check_no_native_alerts();
    completed_recoveries++;
    `uvm_info(`gfn, "TL integrity recovery: healthy CSR pass and reset status checked", UVM_LOW)
    return;
  end

  ral_name = fault_ral_names[checked_faults % fault_ral_names.size()];
  // Solve the fault choices together before either worker starts. The fault worker only
  // consumes them; it must not randomize shared configuration while CSR traffic is running.
  intg_config_params.mem_ranges = cfg.ral_models[ral_name].mem_ranges;
  `DV_CHECK_RANDOMIZE_FATAL(intg_config_params)
  `uvm_info(`gfn, $sformatf("TL integrity episode %0d/%0d: interface=%s",
                           checked_faults + 1, test_params.num_trans * fault_ral_names.size(),
                           ral_name), UVM_LOW)

  fork
    run_csr_vseq(.csr_test_type("rw"), .ral_name(ral_name));
    begin
      issue_integrity_fault(ral_name);
      check_repeated_alerts(intg_config_params.alert_handshakes);
    end
  join

  // Neither the corrupt request nor background CSR traffic remains pending here. Compare
  // against the configured fault value directly, without sequence-to-scoreboard prediction.
  check_integrity_status(1'b1);
  checked_faults++;
  `uvm_info(`gfn, "TL integrity episode checked; requesting recovery reset", UVM_LOW)
  reset_ready_ev.trigger();
  // Keep this epoch under the reset owner's termination boundary.
  wait (1'b0);
endtask : main_thread

task cip_rst_safe_tl_intg_err_vseq::issue_integrity_fault(string ral_name);
  cip_rst_safe_tl_intg_err_config_parameters intg_config_params;
  cip_tl_host_single_seq tl_seq;
  delay_seq del_seq;
  `downcast(intg_config_params, config_params)

  del_seq = delay_seq::type_id::create("del_seq");
  del_seq.delay_time_steps = intg_config_params.fault_delay_clks;
  del_seq.start(p_sequencer.delay_sequencer_h, this);
  check_no_native_alerts();

  tl_seq = cip_tl_host_single_seq::type_id::create("tl_seq");
  tl_seq.tl_intg_err_type = intg_config_params.fault_kind;
  if (cfg.zero_delays) tl_seq.max_req_delay = 0;
  // Initialize the leaf's single-request and protocol defaults, then supply the fault inputs.
  // The TL leaf still constructs the request and applies the selected integrity corruption.
  `DV_CHECK_RANDOMIZE_FATAL(tl_seq)
  tl_seq.addr = intg_config_params.addr;
  tl_seq.write = intg_config_params.write;
  tl_seq.data = intg_config_params.data;
  tl_seq.mask = intg_config_params.mask;
  `uvm_info(`gfn, $sformatf(
      "TL integrity injection: interface=%s kind=%s write=%0b addr=0x%0h mask=0x%0h alerts=%0d",
      ral_name, intg_config_params.fault_kind.name(), intg_config_params.write,
      intg_config_params.addr, intg_config_params.mask, intg_config_params.alert_handshakes),
      UVM_LOW)
  tl_seq.start(p_sequencer.tl_sequencer_hs[ral_name], this);

  // The helper used by legacy skips d_error checks for corrupt requests. Require an actual
  // completed error response here as well as the independent common scoreboard checks.
  `DV_CHECK_EQ_FATAL(tl_seq.rsp.rsp_completed, 1, "Integrity request did not complete")
  `DV_CHECK_EQ_FATAL(tl_seq.rsp.d_error, 1, "Integrity request did not return an error")
  `uvm_info(`gfn, "TL integrity error response checked", UVM_LOW)
endtask : issue_integrity_fault

task cip_rst_safe_tl_intg_err_vseq::check_integrity_status(bit fault_expected);
  foreach (cfg.tl_intg_alert_fields[field]) begin
    uvm_reg_data_t expected_value;
    expected_value = fault_expected ? cfg.tl_intg_alert_fields[field] : field.get_reset();
    // Explicit expected values avoid using a mirror changed by the read itself or a different
    // interface. Frontdoor checking remains active even when the block scoreboard is disabled.
    csr_rd_check(.ptr(field), .check(UVM_CHECK), .blocking(1), .compare_value(expected_value));
    `uvm_info(`gfn, $sformatf("TL integrity status checked: %s expected=0x%0h",
                             field.get_full_name(), expected_value), UVM_LOW)
  end
endtask : check_integrity_status

task cip_rst_safe_tl_intg_err_vseq::check_repeated_alerts(uint count);
  bit handshake_started = 1'b0;
  uint completed = 0;
  `uvm_info(`gfn, $sformatf("Waiting for %0d completed native alerts on %s",
                           count, cfg.tl_intg_alert_name), UVM_LOW)
  while (completed < count) begin
    alert_esc_seq_item item;
    p_sequencer.alert_observation_fifos[cfg.tl_intg_alert_name].get(item);
    // A ping response is not evidence of reporting the injected integrity fault.
    if (item.alert_esc_type == AlertEscPingTrans) continue;
    `DV_CHECK_EQ_FATAL(item.alert_esc_type, AlertEscSigTrans)
    `DV_CHECK_EQ_FATAL(item.ping_timeout, 0)
    case (item.alert_handshake_sta)
      AlertReceived: begin
        `DV_CHECK_EQ_FATAL(handshake_started, 0, "Repeated start before alert completion")
        handshake_started = 1'b1;
      end
      AlertAckComplete: begin
        `DV_CHECK_EQ_FATAL(handshake_started, 1, "Alert completion without a start")
        handshake_started = 1'b0;
        completed++;
        `uvm_info(`gfn, $sformatf("TL integrity alert completion %0d/%0d", completed, count),
                  UVM_MEDIUM)
      end
      default: begin
        `DV_CHECK_FATAL(0, "Unexpected native alert monitor observation")
      end
    endcase
  end
  `uvm_info(`gfn, $sformatf("TL integrity repeated alerts checked: %0d", completed), UVM_LOW)
endtask : check_repeated_alerts

function void cip_rst_safe_tl_intg_err_vseq::check_no_native_alerts();
  alert_esc_seq_item item;
  // Check, do not silently flush, observations outside the fault episode. Only reset may
  // discard an unfinished fatal-alert handshake. Pings are independent healthy traffic.
  while (p_sequencer.alert_observation_fifos[cfg.tl_intg_alert_name].try_get(item)) begin
    `DV_CHECK_EQ_FATAL(item.alert_esc_type, AlertEscPingTrans,
                      "Unexpected native alert outside the integrity fault episode")
  end
endfunction : check_no_native_alerts

task cip_rst_safe_tl_intg_err_vseq::reset_trigger_thread();
  reset_seq rst_seq;
  reset_ready_ev.wait_on();
  reset_ready_ev.reset();
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h, this);
  wait (in_reset);
  directed_resets++;
endtask : reset_trigger_thread

task cip_rst_safe_tl_intg_err_vseq::post_start();
  // Recovery checks run inside main_thread(). Do not invoke the legacy signal-level alert
  // waits, interrupt writes, or shutdown hook after the reset-owned workload has finished.
endtask : post_start
