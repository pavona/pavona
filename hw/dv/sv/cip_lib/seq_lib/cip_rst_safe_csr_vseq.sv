// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test-wide controls for the common CSR workload. The CSR leaf is selected with the existing
// +csr_<test> argument; the same register algorithms are used with and without random reset.
class cip_rst_safe_csr_test_seq_parameters extends dv_test_seq_parameters;
  `uvm_object_utils(cip_rst_safe_csr_test_seq_parameters)

  // Select the workload before the base randomizes these controls. Hardware-reset testing
  // needs a preparation epoch followed by a reset-value check, not a timed interruption.
  string csr_test_type;

  // Keep assertions enabled unless random register preparation needs the legacy exception.
  bit enable_asserts_in_hw_reset_rand_wr = 1'b1;

  constraint reset_enable_c {
    if (csr_test_type == "hw_reset") reset_testing == ENABLE;
    else                             reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    if (csr_test_type == "hw_reset") num_reset_loops == 2;
    else                             num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans == 1;
  }

  function new(string name = "");
    super.new(name);

    // CSR testing must not inherit a block's normal functional register programming. The
    // workload runs from main_thread(), under the existing reset termination boundary.
    do_dut_init = 1'b0;
  endfunction : new
endclass : cip_rst_safe_csr_test_seq_parameters

// Random choices for access generation and reset timing, separate from the test-wide workload.
class cip_rst_safe_csr_config_parameters extends dv_config_parameters;
  `uvm_object_utils(cip_rst_safe_csr_config_parameters)

  // Preserve the existing CSR adapter-abort distribution. Shadowed registers disable aborts
  // for the workload because the two writes must both reach the DUT.
  rand uint csr_access_abort_pct;

  // Primary reset-domain clock cycles before reset, consumed by the delay sequence.
  rand uint reset_delay;

  // Each repetition can issue a read, a write, both, or neither to the same register.
  // Keep the choices here so a derived configuration can constrain the access pattern.
  rand uint same_csr_repetitions;
  rand bit same_csr_do_read;
  rand bit same_csr_do_write;
  rand uvm_reg_data_t same_csr_wdata;

  constraint csr_access_abort_pct_c {
    csr_access_abort_pct dist {
      0 :/ 50,
      [1:99] :/ 40,
      100 :/ 10
    };
  }

  constraint reset_delay_c {
    // Short CSR passes can finish within a thousand primary clocks. Target their early traffic
    // with a shorter random delay; the final epoch still completes a full pass without reset.
    // Timing alone does not guarantee active traffic or an outstanding request at reset.
    reset_delay inside {[1:500]};
  }

  constraint same_csr_repetitions_c {
    same_csr_repetitions inside {[2:20]};
  }

  `uvm_object_new
endclass : cip_rst_safe_csr_config_parameters

// Verify software-visible register behavior without the block's functional initialization.
// The mapped tests select one objective through +csr_<test>:
// - rw: Check register and field readback against their declared access policies.
// - bit_bash: Check individual register bits for unintended changes to other bits.
// - aliasing: Check that a register write does not change another register unexpectedly.
// - same_csr_outstanding: Check ordered read/write results with accesses pending to one register.
// - hw_reset: Prepare register storage, apply reset, and check the declared reset values.
// - mem_walk: Use the UVM frontdoor walk to check each eligible RW memory and address map.
// Register and field exclusions limit each test to behavior that the generic checks can verify.
// Memory walk retains the UVM memory exclusions and compares readback in its existing leaf.
//
// CSR leaf sequences use the environment's RAL frontdoors and configured checking ownership.
// The same-register test uses raw TL because RAL serializes accesses to one register.
// Hardware-reset preparation can also use eligible backdoor writes before the deliberate reset.
// Other mapped tests complete without an injected reset unless a derived reset policy enables it.
//
// All workload operations run below main_thread(), under the inherited reset execution mechanism.
// A block specialization supplies only its types and factory name, not another CSR algorithm.
// Shared TL access and register discovery remain in the CIP base.
class cip_rst_safe_csr_vseq #(
  type RAL_T               = dv_base_reg_block,
  type CFG_T               = cip_base_env_cfg,
  type COV_T               = cip_base_env_cov,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends cip_rand_rst_safe_base_vseq #(
    .RAL_T(RAL_T),
    .CFG_T(CFG_T),
    .COV_T(COV_T),
    .VIRTUAL_SEQUENCER_T(VIRTUAL_SEQUENCER_T),
    .TEST_PARAMS_T(cip_rst_safe_csr_test_seq_parameters),
    .CONFIG_PARAMS_T(cip_rst_safe_csr_config_parameters)
  );
  `uvm_object_param_utils(cip_rst_safe_csr_vseq #(RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T))

  // This event only coordinates the two sequence threads. It carries no DUT or checker state.
  protected uvm_event reset_ready_ev;

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task main_thread();
  extern virtual task reset_trigger_thread();
  extern virtual task run_same_csr_outstanding_vseq(int num_times);
  extern virtual task run_csr_vseq_wrapper(int num_times = 1,
                                         dv_base_reg_block models[$] = {});
  extern virtual task run_csr_vseq(string csr_test_type,
                                 int num_test_csrs = 0,
                                 bit do_rand_wr_and_reset = 1,
                                 dv_base_reg_block models[$] = {},
                                 string ral_name = "");
  extern virtual task run_csr_vseq_base(string csr_test_type,
                                      int num_test_csrs = 0,
                                      bit do_rand_wr_and_reset = 1,
                                      dv_base_reg_block models[$] = {},
                                      string ral_name = "");
endclass : cip_rst_safe_csr_vseq

function cip_rst_safe_csr_vseq::new(string name = "");
  super.new(name);
  reset_ready_ev = new("reset_ready_ev");

  // Do not issue interrupt-clearing CSR accesses after the reset-owned workload has ended.
  do_clear_all_interrupts = 1'b0;
endfunction : new

task cip_rst_safe_csr_vseq::body();
  if (test_params == null) begin
    test_params = cip_rst_safe_csr_test_seq_parameters::type_id::create("test_params");
  end
  if (config_params == null) begin
    config_params = cip_rst_safe_csr_config_parameters::type_id::create("config_params");
  end

  // The base randomizes test_params in body(). Select the workload first so its reset policy
  // is constrained correctly, and retain that selection across reset epochs.
  if (test_params.csr_test_type == "") begin
    void'($value$plusargs("csr_%0s", test_params.csr_test_type));
  end

  // Member-only randomization still checks every enabled constraint on this object. Establish
  // valid values for all controls before the base starts the reset and CSR workers; otherwise
  // a control left at zero can prevent an unrelated member from being randomized.
  `DV_CHECK_RANDOMIZE_FATAL(config_params)

  reset_ready_ev.reset();
  super.body();
endtask : body

task cip_rst_safe_csr_vseq::main_thread();
  // Retain the coverage policy of the existing common CSR wrapper. The leaf sequence and the
  // configured checker retain responsibility for the register access-policy checks.
  disable_coverage_sample_for_csr_test();

  // RAL serializes accesses to one register. This workload uses raw TL requests so several
  // accesses to that register can be pending together, with the same reset owner as CSR leaves.
  if (test_params.csr_test_type == "same_csr_outstanding") begin
    run_same_csr_outstanding_vseq(test_params.num_trans);
    return;
  end

  // The base decrements num_reset_loops before starting each epoch. Zero identifies the final
  // check after reset; no separate epoch counter or reset-state transfer is needed.
  if (test_params.csr_test_type == "hw_reset" && test_params.num_reset_loops == 0 &&
      !test_params.enable_asserts_in_hw_reset_rand_wr) begin
    `DV_ASSERT_CTRL_REQ("dut_assert_en", 1'b1)
  end
  run_csr_vseq_wrapper(test_params.num_trans);

  if (test_params.csr_test_type == "hw_reset" && test_params.num_reset_loops > 0) begin
    // The leaf waits for preparation writes to finish so reset tests programmed register state.
    // This is a test precondition, not a graceful DUT shutdown or a reset-safety requirement.
    `uvm_info(`gfn, "CSR hardware reset: writes complete; ready for reset", UVM_LOW)
    reset_ready_ev.trigger();

    // The base owns termination of this epoch. Returning here would race reset completion.
    wait (1'b0);
  end
endtask : main_thread

task cip_rst_safe_csr_vseq::reset_trigger_thread();
  delay_seq del_seq;
  reset_seq rst_seq;

  if (test_params.csr_test_type == "hw_reset") begin
    // A hardware-reset check must start from programmed state. The latched event also covers
    // preparation completing before this thread reaches the wait.
    reset_ready_ev.wait_on();
    reset_ready_ev.reset();
    `uvm_info(`gfn, "CSR hardware reset: applying reset after completed writes", UVM_LOW)
  end else begin
    // Randomize only reset timing here. The concurrent CSR worker owns the access-abort choice.
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(reset_delay, config_params)
    del_seq = delay_seq::type_id::create("del_seq");
    del_seq.delay_time_steps = config_params.reset_delay;
    del_seq.start(p_sequencer.delay_sequencer_h);
  end

  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

task cip_rst_safe_csr_vseq::run_same_csr_outstanding_vseq(int num_times);
  csr_test_type_e csr_test_type = CsrRwTest;

  for (int trans = 1; trans <= num_times; trans++) begin
    uint num_reads = 0;
    uint num_writes = 0;

    `uvm_info(`gfn, $sformatf("Running same CSR outstanding test iteration %0d/%0d",
                             trans, num_times), UVM_LOW)

    // Reset belongs to the enclosing sequence lifecycle, not to the register-access loop.
    foreach (cfg.ral_models[ral_name]) begin
      dv_base_reg csrs[$];
      cfg.ral_models[ral_name].get_dv_base_regs(csrs);
      csrs.shuffle();

      foreach (csrs[i]) begin
        uvm_reg_data_t exp_data = csrs[i].get_mirrored_value();
        uvm_reg_data_t rd_data, wr_data, rd_mask, wr_mask;
        csr_excl_item csr_excl = get_excl_item(csrs[i]);

        rd_mask = get_mask_excl_fields(csrs[i], CsrExclWriteCheck, csr_test_type);
        wr_mask = get_mask_excl_fields(csrs[i], CsrExclWrite, csr_test_type);
        `DV_CHECK_MEMBER_RANDOMIZE_FATAL(same_csr_repetitions, config_params)

        repeat (config_params.same_csr_repetitions) begin
          `DV_CHECK_MEMBER_RANDOMIZE_FATAL(same_csr_do_read, config_params)
          `DV_CHECK_MEMBER_RANDOMIZE_FATAL(same_csr_do_write, config_params)

          // Capture each read's expectation before later writes change the mirror. The raw TL
          // helper compares that snapshot when the corresponding response returns.
          if (config_params.same_csr_do_read &&
              !csr_excl.is_excl(csrs[i], CsrExclWriteCheck, csr_test_type)) begin
            tl_access(.addr(csrs[i].get_address()), .write(0), .data(rd_data),
                      .check_exp_data(1), .exp_data(exp_data), .compare_mask(rd_mask),
                      .blocking(0), .tl_sequencer_h(p_sequencer.tl_sequencer_hs[ral_name]));
            num_reads++;
          end

          if (config_params.same_csr_do_write &&
              !csr_excl.is_excl(csrs[i], CsrExclWrite, csr_test_type)) begin
            int num_write = csrs[i].get_is_shadowed() ? 2 : 1;

            `DV_CHECK_MEMBER_RANDOMIZE_FATAL(same_csr_wdata, config_params)
            wr_data = config_params.same_csr_wdata & wr_mask;
            // Raw TL bypasses the RAL frontdoor. Keep the existing sequence-owned prediction
            // and both writes of a shadow pair so later reads have the correct expectation.
            repeat (num_write) begin
              tl_access(.addr(csrs[i].get_address()), .write(1), .data(wr_data), .blocking(0),
                        .tl_sequencer_h(p_sequencer.tl_sequencer_hs[ral_name]));
              void'(csrs[i].predict(.value(wr_data), .kind(UVM_PREDICT_WRITE)));
              num_writes++;
            end
            exp_data = csrs[i].get_mirrored_value();
          end
        end

        // These nonblocking raw TL accesses do not use the CSR utility's outstanding counter.
        // Wait for this worker's access children before changing registers or returning. Reset
        // kills this main-thread hierarchy directly; it does not wait for this normal completion.
        wait fork;

        // Raw TL also bypasses the RAL write callback that locks protected fields.
        if (csrs[i].is_wen_reg()) csrs[i].lock_lockable_flds(`gmv(csrs[i]), UVM_PREDICT_WRITE);
      end
    end

    `uvm_info(`gfn, $sformatf(
        "Same CSR outstanding iteration %0d/%0d complete: reads=%0d writes=%0d",
        trans, num_times, num_reads, num_writes), UVM_LOW)
  end
endtask : run_same_csr_outstanding_vseq

task cip_rst_safe_csr_vseq::run_csr_vseq_wrapper(int num_times = 1,
                                               dv_base_reg_block models[$] = {});
  if (models.size() == 0) begin
    `DV_CHECK_GE_FATAL(cfg.ral_models.size(), 1)
  end

  for (int i = 1; i <= num_times; i++) begin
    `uvm_info(`gfn, $sformatf("Running csr %0s vseq iteration %0d/%0d.",
                             test_params.csr_test_type, i, num_times), UVM_LOW)
    run_csr_vseq(.csr_test_type(test_params.csr_test_type), .models(models));
  end
endtask : run_csr_vseq_wrapper

task cip_rst_safe_csr_vseq::run_csr_vseq(string csr_test_type,
                                       int num_test_csrs = 0,
                                       bit do_rand_wr_and_reset = 1,
                                       dv_base_reg_block models[$] = {},
                                       string ral_name = "");
  bit has_shadow_reg;
  dv_base_reg regs[$];

  // A cancelled half of a shadow-register write pair can itself create an update error. Keep
  // the existing policy of disabling adapter aborts when a supplied environment has such CSRs.
  foreach (cfg.ral_models[i]) cfg.ral_models[i].get_dv_base_regs(regs);
  foreach (regs[i]) begin
    if (regs[i].get_is_shadowed()) begin
      has_shadow_reg = 1;
      break;
    end
  end
  if (!has_shadow_reg && config_params.csr_access_abort_pct.rand_mode()) begin
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(csr_access_abort_pct, config_params)
  end else begin
    config_params.csr_access_abort_pct = 0;
  end
  foreach (cfg.m_tl_agent_cfgs[i]) begin
    cfg.m_tl_agent_cfgs[i].csr_access_abort_pct_in_adapter = config_params.csr_access_abort_pct;
  end

  // An intentional adapter abort returns UVM_NOT_OK. Preserve the existing status-check policy
  // during extraction; changes to this shared utility policy require a separate review.
  if (config_params.csr_access_abort_pct > 0) begin
    csr_utils_pkg::default_csr_check = UVM_NO_CHECK;
  end else begin
    csr_utils_pkg::default_csr_check = UVM_CHECK;
  end
  run_csr_vseq_base(csr_test_type, num_test_csrs, do_rand_wr_and_reset, models, ral_name);
endtask : run_csr_vseq

task cip_rst_safe_csr_vseq::run_csr_vseq_base(string csr_test_type,
                                            int num_test_csrs = 0,
                                            bit do_rand_wr_and_reset = 1,
                                            dv_base_reg_block models[$] = {},
                                            string ral_name = "");
  csr_base_seq m_csr_seq;

  `DV_CHECK_GE_FATAL(cfg.ral_models.size(), 1)
  if (models.size() == 0) begin
    if (ral_name != "") begin
      `DV_CHECK_FATAL(cfg.ral_models.exists(ral_name))
      models.push_back(cfg.ral_models[ral_name]);
    end else begin
      foreach (cfg.ral_models[i]) models.push_back(cfg.ral_models[i]);
    end
  end

  // Reuse the existing CSR algorithms and factory selection. No register algorithm belongs in
  // this wrapper, and the selected leaf retains the environment's configured frontdoor.
  case (csr_test_type)
    "hw_reset": csr_base_seq::type_id::set_type_override(csr_hw_reset_seq::get_type());
    "rw": csr_base_seq::type_id::set_type_override(csr_rw_seq::get_type());
    "bit_bash": csr_base_seq::type_id::set_type_override(csr_bit_bash_seq::get_type());
    "aliasing": csr_base_seq::type_id::set_type_override(csr_aliasing_seq::get_type());
    "mem_walk": csr_base_seq::type_id::set_type_override(csr_mem_walk_seq::get_type());
    default: begin
      `DV_CHECK_FATAL(0, $sformatf("Invalid CSR test selection: +csr_%0s", csr_test_type))
    end
  endcase

  foreach (models[i]) begin
    csr_excl_item csr_excl = csr_utils_pkg::get_excl_item(models[i]);
    if (csr_excl != null) csr_excl.print_exclusions();
    if (csr_test_type == "mem_walk") begin
      uvm_mem memories[$];
      models[i].get_memories(memories);
      // A shared test can also run on a CSR-only block. State that no memory traffic will occur,
      // without bypassing the leaf or treating successful completion as memory verification.
      if (memories.size() == 0) begin
        `uvm_info(`gfn, $sformatf("Memory walk: %s has no mapped memories; no memory accesses",
                                 models[i].get_full_name()), UVM_LOW)
      end
    end
  end

  // Prepare state only in the nonfinal hardware-reset epoch. The main thread announces
  // completion to the reset thread; this helper never applies reset or checks before reset.
  if (csr_test_type == "hw_reset" && do_rand_wr_and_reset && test_params.num_reset_loops > 0) begin
    csr_write_seq m_csr_write_seq;

    `uvm_info(`gfn, "CSR hardware reset: preparing registers before reset", UVM_LOW)
    if (!test_params.enable_asserts_in_hw_reset_rand_wr) begin
      `DV_ASSERT_CTRL_REQ("dut_assert_en", 1'b0)
    end
    m_csr_write_seq = csr_write_seq::type_id::create("m_csr_write_seq");
    m_csr_write_seq.models = models;
    m_csr_write_seq.external_checker = cfg.en_scb;

    // Preserve legacy preparation of eligible register storage through frontdoor and backdoor
    // writes. The leaf retains its HDL-path checks, exclusions, and access-completion wait.
    m_csr_write_seq.en_rand_backdoor_write = 1'b1;
    m_csr_write_seq.start(null);
    return;
  end

  if (csr_test_type == "hw_reset") begin
    `uvm_info(`gfn, "CSR hardware reset: checking register reset values", UVM_LOW)
  end
  m_csr_seq = csr_base_seq::type_id::create("m_csr_seq");
  m_csr_seq.models = models;
  m_csr_seq.external_checker = cfg.en_scb;
  m_csr_seq.num_test_csrs = num_test_csrs;
  m_csr_seq.start(null);
  if (csr_test_type == "hw_reset") begin
    `uvm_info(`gfn, "CSR hardware reset: reset-value checks complete", UVM_LOW)
  end
endtask : run_csr_vseq_base
