// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class cip_rand_rst_safe_base_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer,
  type TEST_PARAMS_T       = dv_test_seq_parameters,
  type CONFIG_PARAMS_T     = dv_config_parameters
) extends dv_rand_rst_safe_base_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T,
                                       TEST_PARAMS_T, CONFIG_PARAMS_T);
  `uvm_object_new

  // knobs to disable post_start clear interrupt routine
  bit do_clear_all_interrupts = 1'b1;

  bit expect_fatal_alerts = 1'b0;

  // knob to enable/disable running csr_vseq with passthru_mem_tl_intg_err
  bit en_csr_vseq_w_passthru_mem_intg = 1;

  // knob to enable/disable running csr_vseq with tl_intg_err
  bit en_csr_vseq_w_tl_intg = 1;

  // csr queues
  dv_base_reg all_csrs[$];
  dv_base_reg intr_state_csrs[$];

  // user can set the name of common seq to run directly without using $value$plusargs
  string common_seq_type;

  // The reset-safe stress wrapper uses this delay in its reset trigger thread.
  // Keep it separate from functional stimulus, which the reset owner terminates on reset.
  rand uint rand_reset_delay;
  constraint rand_reset_delay_c {
    rand_reset_delay dist {
      [1 : 1000]              :/ 1,
      [1001 : 100_000]        :/ 2,
      [100_001 : 1_000_000]   :/ 6,
      [1_000_001 : 5_000_000] :/ 1
    };
  }

  // Retain this control and its shadow-test policy until those workloads are migrated.
  // The dedicated CSR sequence uses its own config_params.csr_access_abort_pct.
  rand uint csr_access_abort_pct;
  constraint csr_access_abort_pct_c {
    csr_access_abort_pct dist {
      0        :/ 50,
      [1 : 99] :/ 40,
      100      :/ 10
    };
  }

  `uvm_object_param_utils_begin(cip_rand_rst_safe_base_vseq#(
      RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))
    `uvm_field_string(common_seq_type, UVM_DEFAULT)
  `uvm_object_utils_end

  // TODO: Add dedicated reset-safe sequences for pass-through memory integrity,
  // shadow-register errors, and security fault injection.

  function void pre_randomize();
    super.pre_randomize();
    // Disable csr_access_abort because shadow_reg sequence requires all shadow registers'
    // read/write to be executed into design without aborting.
    if (common_seq_type inside {"shadow_reg_errors", "shadow_reg_errors_with_csr_rw"}) begin
      csr_access_abort_pct.rand_mode(0);
    end
  endfunction

  task pre_start();
    if (common_seq_type == "") void'($value$plusargs("run_%0s", common_seq_type));
    csr_utils_pkg::max_outstanding_accesses = 1 << BUS_AIW;
    super.pre_start();
    extract_common_csrs();
  endtask

  task post_start();
    super.post_start();

    if (expect_fatal_alerts) begin
      // Fatal alert is triggered in this seq. Wait 10_000ns so the background check
      // `check_fatal_alert_nonblocking` has enough time to execute before we call dut_init. If
      // there is a reset in the meantime, stop waiting.
      `DV_SPINWAIT_EXIT(#10_000ns;,
                        wait(!cfg.clk_rst_vif.rst_n);)

      // If we are not in reset, ask the dut to re-initialise itself. This will issue a reset if
      // the sequence has do_apply_reset=1. If not, the reset will be applied in an upper vseq.
      if (cfg.clk_rst_vif.rst_n) dut_init();
    end else begin
      if (cfg.clk_rst_vif.rst_n) check_no_fatal_alerts();
    end

    // Some fatal alerts might trigger interrupt as well, so only check interrupt after fatal alert
    // is cleared.
    void'($value$plusargs("do_clear_all_interrupts=%0b", do_clear_all_interrupts));
    if (do_clear_all_interrupts) clear_all_interrupts();
  endtask

  // tl_access task: does a single BUS_DW-bit write or read transaction to the specified address
  // note that this task does not update ral model; optionally also checks for error response
  // The `size` and `addr[1:0]` are randomized based on the given `mask`, and this is also applied
  // to mem access. If it doesn't support partial access, use mask = '1.
  virtual task tl_access(input bit [BUS_AW-1:0]  addr,
                         input bit               write,
                         inout bit [BUS_DW-1:0]  data,
                         input uint              tl_access_timeout_ns = cfg.tl_access_timeout_ns,
                         input bit [BUS_DBW-1:0] mask = '1,
                         input bit               check_rsp = 1'b1,
                         input bit               exp_err_rsp = 1'b0,
                         input bit [BUS_DW-1:0]  exp_data = 0,
                         input bit [BUS_DW-1:0]  compare_mask = '1,
                         input bit               check_exp_data = 1'b0,
                         input bit               blocking = csr_utils_pkg::default_csr_blocking,
                         input mubi4_t           instr_type = MuBi4False,
                         tl_sequencer            tl_sequencer_h = p_sequencer.tl_sequencer_h,
                         input tl_intg_err_e     tl_intg_err_type = TlIntgErrNone);

    bit completed, saw_err;
    tl_access_w_abort(addr, write, data, completed, saw_err, tl_access_timeout_ns, mask, check_rsp,
                      exp_err_rsp, exp_data, compare_mask, check_exp_data, blocking, instr_type,
                      tl_sequencer_h, tl_intg_err_type);
  endtask

  // this tl_access can input req_abort_pct (percentage to enable req abort) and output status for
  // seq to update predicted value
  virtual task tl_access_w_abort(
      input bit [BUS_AW-1:0]  addr,
      input bit               write,
      inout bit [BUS_DW-1:0]  data,
      output bit              completed,
      output bit              saw_err,
      input uint              tl_access_timeout_ns = cfg.tl_access_timeout_ns,
      input bit [BUS_DBW-1:0] mask = '1,
      input bit               check_rsp = 1'b1,
      input bit               exp_err_rsp = 1'b0,
      input bit [BUS_DW-1:0]  exp_data = 0,
      input bit [BUS_DW-1:0]  compare_mask = '1,
      input bit               check_exp_data = 1'b0,
      input bit               blocking = csr_utils_pkg::default_csr_blocking,
      input                   mubi4_t instr_type = MuBi4False,
      tl_sequencer            tl_sequencer_h = p_sequencer.tl_sequencer_h,
      input                   tl_intg_err_e tl_intg_err_type = TlIntgErrNone,
      input int               req_abort_pct = 0);

    cip_tl_seq_item rsp;

    if (blocking) begin
      tl_access_sub(addr, write, data, completed, saw_err, rsp, tl_access_timeout_ns, mask,
                    check_rsp, exp_err_rsp, exp_data, compare_mask, check_exp_data, req_abort_pct,
                    instr_type, tl_sequencer_h, tl_intg_err_type);
    end else begin
      fork
        tl_access_sub(addr, write, data, completed, saw_err, rsp, tl_access_timeout_ns, mask,
                      check_rsp, exp_err_rsp, exp_data, compare_mask, check_exp_data,
                      req_abort_pct, instr_type, tl_sequencer_h, tl_intg_err_type);
      join_none
      // Add #0 to ensure that this thread starts executing before any subsequent call
      #0;
    end
  endtask

  virtual task tl_access_sub(
      input bit [BUS_AW-1:0]  addr,
      input bit               write,
      inout bit [BUS_DW-1:0]  data,
      output bit              completed,
      output bit              saw_err,
      output                  cip_tl_seq_item rsp,
      input                   uint tl_access_timeout_ns = cfg.tl_access_timeout_ns,
      input bit [BUS_DBW-1:0] mask = '1,
      input bit               check_rsp = 1'b1,
      input bit               exp_err_rsp = 1'b0,
      input bit [BUS_DW-1:0]  exp_data = 0,
      input bit [BUS_DW-1:0]  compare_mask = '1,
      input bit               check_exp_data = 1'b0,
      input int               req_abort_pct = 0,
      input                   mubi4_t instr_type = MuBi4False,
      tl_sequencer            tl_sequencer_h = p_sequencer.tl_sequencer_h,
      input                   tl_intg_err_e tl_intg_err_type = TlIntgErrNone);

    cip_tl_host_single_seq tl_seq;
    `uvm_create_on(tl_seq, tl_sequencer_h)
    tl_seq.tl_intg_err_type = tl_intg_err_type;
    if (cfg.zero_delays) begin
      tl_seq.min_req_delay = 0;
      tl_seq.max_req_delay = 0;
    end
    tl_seq.req_abort_pct = req_abort_pct;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(tl_seq,
        addr        == local::addr;
        write       == local::write;
        mask        == local::mask;
        data        == local::data;
        instr_type  == local::instr_type;)

    fork begin : isolation_fork
      fork
        `uvm_send_pri(tl_seq, 100)
        begin
          // Wait until the sequence actually gets allocated to the sequencer. If a vast number of
          // TL operations have been enqueued in parallel, this might take a while. Since we're
          // using tl_host_single_seq, we expect to send exactly one item and the sequence's
          // reqs_started counter will become 1 when that item starts on the relevant bus.
          wait(tl_seq.reqs_started);

          // Now wait a bounded time to check that the bus hasn't locked up for some reason.
          #(tl_access_timeout_ns * 1ns);
        end
      join_any
      disable fork;
    end join

    rsp = tl_seq.rsp;

    if (!write) begin
      data = rsp.d_data;
      if (check_exp_data && !cfg.under_reset) begin
        bit [BUS_DW-1:0] masked_data = data & compare_mask;
        exp_data &= compare_mask;
        `DV_CHECK_EQ(masked_data, exp_data, $sformatf("addr 0x%0h read out mismatch", addr))
      end
    end
    if (check_rsp && !cfg.under_reset && tl_intg_err_type == TlIntgErrNone) begin
      `DV_CHECK_EQ(rsp.d_error, exp_err_rsp,
                   $sformatf("unexpected error response for addr: 0x%x", rsp.a_addr))
    end

    // Expose whether the transaction ran and whether it generated an error. Note that we
    // probably only want to do a RAL update if it ran and caused no error.
    completed = rsp.rsp_completed;
    saw_err = rsp.d_error;
  endtask

  // CIP spec indicates all comportable IPs will have the same standardized interrupt csrs. We can
  // leverage that to create a common set of tasks that all IP environments can reuse. The
  // following are descriptions of some of the args:

  // interrupts: bit vector indicating which interrupts to process
  // scope: for top level, specify which ip / sub module's interrupt to clear

  // common task
  local function dv_base_reg get_interrupt_csr(string csr_name,
                                               dv_base_reg_block scope = null);
    // check within scope first, if supplied
    if (scope != null) begin
      get_interrupt_csr = scope.get_dv_base_reg_by_name(csr_name);
    end else begin
      get_interrupt_csr = ral.get_dv_base_reg_by_name(csr_name);
    end
  endfunction

  local function void extract_common_csrs();
    foreach (cfg.ral_models[i]) begin
      dv_base_reg regs[$];
      cfg.ral_models[i].get_dv_base_regs(regs);
      foreach (regs[i]) all_csrs.push_back(regs[i]);
    end
    foreach (all_csrs[i]) begin
      string csr_name = all_csrs[i].get_name();
      if (!uvm_re_match("intr_state*", csr_name)) begin
        intr_state_csrs.push_back(get_interrupt_csr(csr_name));
      end
    end
  endfunction

  // task to enable multiple interrupts
  // enable: if set, then selected interrupts are enabled, else disabled
  // see description above for other args
  virtual task cfg_interrupts(bit [BUS_DW-1:0] interrupts,
                              bit enable = 1'b1,
                              dv_base_reg_block scope = null);

    uvm_reg          csr;
    bit [BUS_DW-1:0] data;

    csr = get_interrupt_csr("intr_enable", scope);
    data = csr.get_mirrored_value();
    if (enable) data |= interrupts;
    else        data &= ~interrupts;
    csr.set(data);
    csr_update(.csr(csr));
  endtask

  // generic task to check if given interrupt bits & status are set
  // check_set: check if interrupts are set (1) or unset (0)
  // clear: bit vector indicating which interrupt bit to clear
  // see description above for other args
  virtual task check_interrupts(bit [BUS_DW-1:0] interrupts,
                                bit check_set,
                                dv_base_reg_block scope = null,
                                bit [BUS_DW-1:0] clear = '1);
    uvm_reg          csr_intr_state, csr_intr_enable;
    bit [BUS_DW-1:0] act_pins;
    bit [BUS_DW-1:0] exp_pins;
    bit [BUS_DW-1:0] exp_intr_state;

    if (cfg.under_reset) return;

    act_pins = cfg.intr_vif.sample() & interrupts;
    if (check_set) begin
      csr_intr_enable = get_interrupt_csr("intr_enable", scope);
      exp_pins = interrupts & csr_intr_enable.get_mirrored_value();
      exp_intr_state = interrupts;
    end else begin
      exp_pins = '0;
      exp_intr_state = ~interrupts;
    end
    `DV_CHECK_EQ(act_pins, exp_pins)
    csr_intr_state = get_interrupt_csr("intr_state", scope);
    csr_rd_check(.ptr(csr_intr_state), .compare_value(exp_intr_state), .compare_mask(interrupts));

    if (check_set && |(interrupts & clear)) begin
      csr_wr(.ptr(csr_intr_state), .value(interrupts & clear));
    end
  endtask

  // some coverage sampling should be disabled when it's a CSR test
  virtual function void disable_coverage_sample_for_csr_test();
    `uvm_info(`gfn, "mubi reg coverage sampling is disabled as this is a CSR test", UVM_HIGH)
    foreach (all_csrs[i]) begin
      dv_base_reg_field fields[$];

      all_csrs[i].get_dv_base_reg_fields(fields);
      // assign null to all mubi_cov object, so that coverage sampling is skipped
      foreach (fields[j]) fields[j].mubi_cov = null;
    end
  endfunction

  // Retain common workloads that do not yet have a complete replacement. CSR and memory
  // workloads use dedicated reset-safe sequences so their workers and history belong to each
  // invocation, not to the shared base or this dispatcher.
  virtual task run_common_vseq_wrapper(int num_times = 1);
    if (common_seq_type == "") void'($value$plusargs("run_%0s", common_seq_type));

    disable_coverage_sample_for_csr_test();

    // check which test type
    case (common_seq_type)
      "intr_test":                     run_intr_test_vseq(num_times);
      "alert_test":                    run_alert_test_vseq(num_times);

      // Reset ownership belongs to the dedicated reset-safe sequences.
      "stress_all_with_rand_reset", "csr_mem_rw_with_rand_reset": begin
        `DV_CHECK_FATAL(0, "Legacy reset wrapper removed; use the reset-safe sequence reset flow")
      end
      default: begin
        `DV_CHECK_FATAL(0, $sformatf(
            "Unsupported common workload '%s'; select its dedicated reset-safe sequence",
            common_seq_type))
      end
    endcase
  endtask

  // generic task to check interrupt test reg functionality
  virtual task run_intr_test_vseq(int num_times = 1);
    import dv_utils_pkg::interrupt_t;
    dv_base_reg intr_csrs[$];
    dv_base_reg intr_test_csrs[$];

    foreach (all_csrs[i]) begin
      string csr_name = all_csrs[i].get_name();
      if (!uvm_re_match("intr_test*", csr_name) ||
          !uvm_re_match("intr_enable*", csr_name) ||
          !uvm_re_match("intr_state*", csr_name)) begin
        intr_csrs.push_back(get_interrupt_csr(csr_name));
      end
      if (!uvm_re_match("intr_test*", csr_name)) begin
        intr_test_csrs.push_back(get_interrupt_csr(csr_name));
      end
    end

    // Checking the intr_test register works only makes sense if there is at least one interrupt
    // register. We shouldn't call this sequence for blocks that don't have one, so let's fail
    // understandably if we have done so by accident.
    `DV_CHECK(intr_csrs.size() > 0, "Called intr_test vseq without any interrupt register.")

    num_times = num_times * intr_csrs.size();
    for (int trans = 1; trans <= num_times; trans++) begin
      bit [BUS_DW-1:0] num_used_bits;
      bit [BUS_DW-1:0] intr_enable_val[$];
      `uvm_info(`gfn, $sformatf("Running intr test iteration %0d/%0d", trans, num_times), UVM_LOW)

      // Random Write to all intr related registers
      intr_csrs.shuffle();
      foreach (intr_csrs[i]) begin
        uvm_reg_data_t data = $urandom();
        `uvm_info(`gfn, $sformatf("Write %s: 0x%0h", intr_csrs[i].`gfn, data), UVM_MEDIUM)
        csr_wr(.ptr(intr_csrs[i]), .value(data));
        if (cfg.under_reset) break;
      end

      // Read all intr related csr and check interrupt pins
      intr_csrs.shuffle();
      foreach (intr_csrs[i]) begin
        uvm_reg_data_t exp_val = `gmv(intr_csrs[i]);
        uvm_reg_data_t act_val;

        interrupt_t irq_ro_mask = '0;

        // Status type interrupts have RO fields in intr_state, so mask those bits off here as they
        // can't be generically predicted for all IPs.
        if (!uvm_re_match("intr_state*", intr_csrs[i].get_name())) begin
          irq_ro_mask = intr_csrs[i].get_ro_mask();
        end

        exp_val &= ~irq_ro_mask;

        csr_rd(.ptr(intr_csrs[i]), .value(act_val));
        act_val &= ~irq_ro_mask;

        if (cfg.under_reset) break;
        `uvm_info(`gfn, $sformatf("Read %s: 0x%0h", intr_csrs[i].get_full_name(), act_val),
                  UVM_MEDIUM)
        if (intr_csrs[i].get_predicted_mask() == 0) begin
          `DV_CHECK_EQ(exp_val, act_val, {"when reading the intr CSR ",
                                          intr_csrs[i].get_full_name()})

          // if it's intr_state, also check the interrupt pin value
          if (!uvm_re_match("intr_state*", intr_csrs[i].get_name())) begin
            interrupt_t exp_intr_pin = intr_csrs[i].get_intr_pins_exp_value();
            interrupt_t act_intr_pin = cfg.intr_vif.sample();
            act_intr_pin &= interrupt_t'((1 << cfg.num_interrupts) - 1);
            `DV_CHECK_CASE_EQ(exp_intr_pin, act_intr_pin)
          end // if (!uvm_re_match
        end
      end // foreach (intr_csrs[i])
    end
    // Write 0 to intr_test to clean up status interrupts, otherwise, status interrupts may remain
    // active. And writing any value to a status interrupt CSR (intr_state) can't clear its value.
    foreach (intr_test_csrs[i]) begin
      csr_wr(.ptr(intr_test_csrs[i]), .value(0));
    end
  endtask

  // Task to clear register intr status bits
  virtual task clear_interrupt_reg(dv_base_reg register, bit [BUS_DW-1:0] ro_mask);
    bit [BUS_DW-1:0] data;
    // Status type interrupts are read-only and cannot be cleared by writing 1 to them.
    // Instead, the underlying condition needs to be resolved (e.g. drain a FIFO that is full).
    // Therefore, we use the RO bitmask to mask the writes / reads below.
    csr_rd(.ptr(register), .value(data));
    if ((data & ~ro_mask) != 0) begin
      `uvm_info(`gtn, $sformatf("Clearing status bits in %0s", register.get_name()),
                UVM_HIGH)
      csr_wr(.ptr(register), .value(data & ~ro_mask));
      csr_rd(.ptr(register), .value(data));
      if (!cfg.under_reset) `DV_CHECK_EQ(data & ~ro_mask, 0)
    end
  endtask

  // Task to clear register intr status bits
  virtual task clear_all_interrupts();
    import dv_utils_pkg::interrupt_t;
    interrupt_t irq_ro_mask = '0;
    if (cfg.num_interrupts == 0) return;

    // Iterate over all interrupt registers (typically there is only one).
    foreach (intr_state_csrs[i]) begin
      irq_ro_mask[i*BUS_DW +: BUS_DW] = BUS_DW'(intr_state_csrs[i].get_ro_mask());
      clear_interrupt_reg(intr_state_csrs[i], irq_ro_mask[i*BUS_DW +: BUS_DW]);
      if (cfg.under_reset) break;
    end

    if (!cfg.under_reset) begin
      // Status type interrupts may remain asserted, hence we have to mask them away.
      interrupt_t all_interrupts = interrupt_t'((1 << cfg.num_interrupts) - 1);
      interrupt_t clearable_mask = all_interrupts & ~irq_ro_mask;
      `DV_CHECK_EQ(cfg.intr_vif.sample() & clearable_mask, '0)
    end
  endtask

  // Watch the interface for the alert called alert_name and check that either it doesn't fire or
  // that it is currently firing, but gets cleared and doesn't re-assert itself.
  //
  // This task is safe to kill (on reset).
  local task check_not_fatal_alert(string alert_name, alert_esc_agent_cfg alert_cfg);
    // The maximum number of cycles that an alert handshake should take.
    // - 20 cycles includes ack response and ack stable time.
    // - 10 is the max difference between alert clock and dut clock.
    int max_alert_handshake_cycles = 20 * 10;

    // The amount of time to watch to check a new alert doesn't appear. This is chosen to be at
    // least the length of a single handshake.
    int check_cycles = $urandom_range(max_alert_handshake_cycles, max_alert_handshake_cycles * 3);

    // Take a snapshot of the number of pings that has been seen for the alert in question. If we
    // see a ping while we're waiting, we want to stop immediately since we won't be able to
    // decipher the resulting alert.
    int unsigned ping_count = alert_cfg.ping_count;

    // The alert may have been triggered already. Assuming it is not fatal, wait long enough
    // for any such alert to be acknowledged and cleared. This would normally be a known
    // number of cycles, but asynchronous alerts make it a bit trickier. Look at the interface
    // itself and wait for any ack to complete.
    cfg.clk_rst_vif.wait_clks(max_alert_handshake_cycles);
    `DV_SPINWAIT(alert_cfg.vif.wait_ack_complete();)

    // Now wait for a while to make sure that the alert is not triggered.
    fork begin : isolation_fork
      fork
        begin
          cfg.clk_rst_vif.wait_clks(check_cycles);
        end
        wait(alert_cfg.vif.alert_tx_final.alert_p && !alert_cfg.vif.alert_tx_final.alert_n);
      join_any
      disable fork;
    end join

    // If there's alert visible through alert_tx_final, we must have stopped early. This must mean
    // that an unexpected alert was generated.
    if (alert_cfg.vif.alert_tx_final.alert_p && !alert_cfg.vif.alert_tx_final.alert_n) begin
      // If ping_count has changed, the alert was probably due to the ping and we should
      // ignore it (but print a debug message). If ping_count is unchanged, the alert fired
      // when we didn't expect it to.
      if (alert_cfg.ping_count == ping_count)
        `uvm_error("Alert %0s fired unexpectedly.", alert_name)
      else
        `uvm_info(`gfn,
                  $sformatf("Unexpected alert %0s, but this may have a ping response.",
                            alert_name),
                  UVM_DEBUG)
    end
  endtask

  // Watch the interface for each alert and check that it does not fire as a fatal alert (using
  // check_not_fatal_alert)
  //
  // If a reset is asserted, this task completes immediately.
  virtual task check_no_fatal_alerts();
    fork begin : isolation_fork
      fork
        wait(cfg.under_reset);

        fork begin : isolation_fork
          foreach(cfg.m_alert_agent_cfgs[alert_name]) begin
            fork
              check_not_fatal_alert(alert_name, cfg.m_alert_agent_cfgs[alert_name]);
            join_none
          end
          wait fork;
        end join
      join_any
      disable fork;
    end join
  endtask

  virtual task run_alert_test_vseq(int num_times = 1);
    int num_alerts = cfg.list_of_alerts.size();
    dv_base_reg alert_test_csr = ral.get_dv_base_reg_by_name("alert_test");
    `DV_CHECK_FATAL(num_alerts > 0, "Please declare `list_of_alerts` under cfg!")

    for (int trans = 1; trans <= num_times; trans++) begin
      `uvm_info(`gfn, $sformatf("Running alert test iteration %0d/%0d", trans, num_times), UVM_LOW)

      repeat ($urandom_range(num_alerts, num_alerts * 10)) begin
        bit [BUS_DW-1:0] alert_req = $urandom_range(0, (1'b1 << num_alerts) - 1);
        // Write random value to alert_test register.
        csr_wr(.ptr(alert_test_csr), .value(alert_req));
        `uvm_info(`gfn, $sformatf("Write alert_test with val %0h", alert_req), UVM_HIGH)
        for (int i = 0; i < num_alerts; i++) begin
          string alert_name = cfg.list_of_alerts[i];

          // If the field has already been written, check if the corresponding alert fires
          // correctly and check if writing to this alert_test field again won't corrupt the
          // current alert mechanism.
          if (alert_req[i]) begin
            // if previous alert_handler just finish, there is a max of two clock_cycle
            // pause in between
            wait_alert_trigger(alert_name, .max_wait_cycle(4));

            // write alert_test during alert handshake will be ignored
            if ($urandom_range(1, 10) == 10) begin
              csr_wr(.ptr(alert_test_csr), .value(1'b1 << i));
              `uvm_info(`gfn, "Write alert_test again during alert handshake", UVM_HIGH)
            end

            // drive alert response sequence
            drive_alert_rsp_and_check_handshake(alert_name, i);

         // If the field has not been written, check if the corresponding alert does not fire.
         // Randomly decide to write this field and check if the alert fires.
         end else begin
           cfg.clk_rst_vif.wait_clks($urandom_range(0, 3));
           `DV_CHECK_EQ(cfg.m_alert_agent_cfgs[alert_name].vif.get_alert(), 0,
                        $sformatf("alert_test did not set alert:%0s", alert_name))

            // write alert_test field when there is ongoing alert handshake
            if ($urandom_range(1, 10) == 10) begin
              `uvm_info(`gfn,
                        $sformatf("Write alert_test with val %0h during alert_handshake",
                        1'b1 << i), UVM_HIGH)
              csr_wr(.ptr(alert_test_csr), .value(1'b1 << i));
              `DV_SPINWAIT_EXIT(while (!cfg.m_alert_agent_cfgs[alert_name].vif.get_alert())
                                cfg.clk_rst_vif.wait_clks(1);,
                                cfg.clk_rst_vif.wait_clks(2);,
                                $sformatf("expect alert_%0d:%0s to fire",
                                          i, alert_name))
              drive_alert_rsp_and_check_handshake(alert_name, i);
            end
          end
        end // end for loop

        // check no alert triggers continuously
        foreach (cfg.list_of_alerts[i]) begin
          `DV_CHECK_EQ(cfg.m_alert_agent_cfgs[cfg.list_of_alerts[i]].vif.get_alert(), 0,
                       $sformatf("expect alert:%0s to stay low", cfg.list_of_alerts[i]))
        end
      end // end repeat
    end
  endtask

  // Blocks if there's a ping in-flight
  task wait_until_ping_is_finished(alert_esc_agent_cfg alert_agent_cfg);

    if (alert_agent_cfg.vif.in_ping_st()) begin
      // There's a 2-cycles sampling delay in the monitor, so if the VIF has already seen the ping.
      // Wait for it. Otherwise there may be scenarios where the `active_ping` is not yet set
      // in the monitor due to the 2-cycle delay. Which causes issues predicting the value in
      // `fatal_alert_cause`
      wait (alert_agent_cfg.active_ping == 1);
    end
    wait (alert_agent_cfg.active_ping == 0);
  endtask // wait_until_ping_is_finished


  // if alerts are triggered continuously, there are 6 cycles gap between 2 alerts. 2-3 cycles for
  // clock domain crossing, 2 for pauses, 1 for idle state.
  // So use 7 cycle for default max_wait_cycle.
  virtual task wait_alert_trigger(string alert_name, int max_wait_cycle = 7,
                                 bit wait_complete = 0);

    // wait until ping finishes before the dv_spinwait in case
    // m_alert_agent_cfgs[alert_name].vif.is_alert_handshaking() is true due to a ping
    wait_until_ping_is_finished(cfg.m_alert_agent_cfgs[alert_name]);
    `DV_SPINWAIT_EXIT(while (!cfg.m_alert_agent_cfgs[alert_name].vif.is_alert_handshaking()) begin
                        cfg.clk_rst_vif.wait_clks(1);
                        wait_until_ping_is_finished(cfg.m_alert_agent_cfgs[alert_name]);
                      end,
                      // another thread to wait for given cycles. If timeout, report an error.
                      cfg.clk_rst_vif.wait_clks(max_wait_cycle);
                      `uvm_error(`gfn, $sformatf("expect alert:%0s to fire", alert_name)))
    if (wait_complete) begin
      `DV_SPINWAIT(cfg.m_alert_agent_cfgs[alert_name].vif.wait_ack_complete();,
                   $sformatf("timeout wait for alert handshake:%0s", alert_name))
    end
  endtask

  virtual task drive_alert_rsp_and_check_handshake(string alert_name, int alert_index);
    alert_receiver_alert_rsp_seq ack_seq =
        alert_receiver_alert_rsp_seq::type_id::create("ack_seq");
    `DV_CHECK_RANDOMIZE_FATAL(ack_seq);
    ack_seq.start(p_sequencer.alert_esc_sequencer_h[alert_name]);

    `DV_SPINWAIT(cfg.m_alert_agent_cfgs[alert_name].vif.wait_ack_complete();,
                 $sformatf("timeout wait for alert_%0d handshake:%0s", alert_index, alert_name))

    if (cfg.m_alert_agent_cfgs[alert_name].is_async) cfg.clk_rst_vif.wait_clks(2);
  endtask

  virtual task check_fatal_alert_nonblocking(string alert_name);
    fork
      `DV_SPINWAIT_EXIT(
          forever begin
            // 1 extra cycle to make sure no race condition
            // Plus 2 extra cycles due to alert sampling delay of 2 cycles at the VIF
            for (int i = 0; i <  (alert_esc_agent_pkg::ALERT_B2B_DELAY + 1 + 2); i++) begin
              if (cfg.m_alert_agent_cfgs[alert_name].active_ping) begin
                wait (cfg.m_alert_agent_cfgs[alert_name].active_ping==0);
                i = 0; // restart the delay, since alert may take longer now ping is happening
              end
              cfg.clk_rst_vif.wait_n_clks(1);
              if (cfg.m_alert_agent_cfgs[alert_name].vif.get_alert() == 1) break;
            end
            `DV_CHECK_EQ(cfg.m_alert_agent_cfgs[alert_name].vif.get_alert(), 1,
                         $sformatf("fatal error %0s does not trigger!", alert_name))
            cfg.m_alert_agent_cfgs[alert_name].vif.wait_ack_complete();
          end,
          wait(cfg.under_reset);)
    join_none
  endtask

  // enable/disable tl_assert
  virtual function void set_tl_assert_en(bit enable, string path = "*");
    uvm_config_db#(bit)::set(null, path, "tlul_assert_en", enable);
  endfunction

endclass
