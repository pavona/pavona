// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base sequence with random reset safety from which all other 'ac_range_check' test sequences
// can be derived.

// First declare ac_range_check_test_seq_parameters class (inherits dv_test_seq_parameters) that
// contains the control knobs that are required by the sequence.
// Instance of ac_range_check_base_test_seq_parameters is randomized at the beginning of sequence
// execution and held constant until the end.
//
// 'ac_range_check_base_config_parameters' contains all the other control knobs/parameters that any
// ac_range_check test sequence will require. An instance of this class can be used to generate
// constraint random data during the execution of the 'main_thread()'
// It also contains the "dut_cfg" class which itself contains all variables relating to DUT
// configuration.
//
// By default, TL transactions are random and can easily be overridden by derived sequences as
// required.


class ac_range_check_base_test_seq_parameters extends dv_test_seq_parameters;

  `uvm_object_utils(ac_range_check_base_test_seq_parameters)

  // The following parameters are inherited that allow controlling
  // random reset assertion
  // reset_testing   = DISABLE / ENABLE;
  // num_reset_loops = <integer_value>;
  // num_trans       = <integer_value>;  -- Controls how many transactions are triggered in each run
  //                                        of the main_thread()
  // do_dut_init     = 1                 -- Controls if DUT needs to be initialized just after
  //                                        release of reset and before main_thread() is invoked
  // do_dut_shutdown = 1                 -- Controls if 'dut_shutdown()' task has to be executed

  // If reset_testing == ENABLE, 'num_reset_loops > 0' -- Put a constraint in the derived sequence
  //                                                      to limit the number of runs.
  // If reset_testing == DISABLE,'num_reset_loops == 1'-- Ensure is at least equal to '1'

  // ---
  // The control knobs below are all the control knobs that are used by 'ac_range_check sequences'
  // that are randomized once in the test and held constant for the duration of test execution.
  //
  // Below we also add other fixed control knobs too.
  // Derived classes from this only need to add additional constraints to ensure a specific scenario
  // is generated.
  // ---

  // Various knobs to enable certain routines
  bit do_ac_range_check_init = 1;

  // A derived class can set the reset_enable constraint to only ENABLE or DISABLE and still will
  // not violate any constraints in this base class
  constraint reset_enable_c {
    reset_testing inside {DISABLE, ENABLE};
  }

  constraint reset_loops_c {
      if (reset_testing == ENABLE) num_reset_loops inside {[2:5]};
      if (reset_testing == DISABLE) num_reset_loops == 1;
  }

  function new(string name="");
    super.new(name);
  endfunction : new

endclass



class ac_range_check_base_config_parameters extends dv_config_parameters;

  `uvm_object_utils(ac_range_check_base_config_parameters)
  // ---
  // The control knobs below are all the control knobs that are used inside the 'main_thread()' of
  // 'ac_range_check sequences' via 'config_params'. These control knobs are expected to be
  // potentially randomized multiple times over the course of the execution of the test.
  //
  // Derived classes only need to add constraints
  // ---

  import ac_range_check_reg_pkg::*;

  // Configuration variables
  rand ac_range_check_dut_cfg dut_cfg;
  rand tl_main_vars_t tl_main_vars;
  rand int range_idx;

  rand bit zero_delays;
  rand protected bit [NUM_RANGES-1:0] config_range_mask;  // Which ranges should be constrained
  rand bit log_enable;
  rand bit [DenyCountWidth-1:0] deny_cnt_threshold;
  rand bit intr_enable;

  // Non-randomizable local variables
  bit fixed_log_enable;
  bit [DenyCountWidth-1:0] fixed_deny_cnt_threshold;
  bit fixed_intr_enable;

  // Control flags
  bit apply_log_enable_c;
  bit apply_deny_cnt_threshold_c;
  bit apply_intr_enable_c;

  function new(string name="");
    super.new(name);
    dut_cfg = ac_range_check_dut_cfg::type_id::create("dut_cfg");
  endfunction : new

  // Constraints
  constraint range_idx_c {
    range_idx inside {[0:NUM_RANGES-1]};
  }

  // Enable/allow the range 2/3 of the time, to get more granted accesses
  constraint range_attr_c {
    foreach (dut_cfg.range_base[i]) {
      dut_cfg.range_attr[i].execute_access dist {
        0 :/ 1,
        1 :/ 2
      };
      dut_cfg.range_attr[i].write_access dist {
        0 :/ 1,
        1 :/ 2
      };
      dut_cfg.range_attr[i].read_access dist {
        0 :/ 1,
        1 :/ 2
      };
      dut_cfg.range_attr[i].enable dist {
        0 :/ 1,
        1 :/ 2
      };
    }
  }

  constraint range_racl_policy_c {
    foreach (dut_cfg.range_racl_policy[i]) {
      soft dut_cfg.range_racl_policy[i].write_perm == 16'hFFFF;
      soft dut_cfg.range_racl_policy[i].read_perm  == 16'hFFFF;
    }
  }

  constraint tl_main_vars_addr_c {
    solve dut_cfg.range_base before tl_main_vars;
    solve dut_cfg.range_limit before tl_main_vars;
    solve range_idx before tl_main_vars;
    tl_main_vars.addr dist {
      // 98% more or less inside range, this will allow us to also test the range boundaries, as this
      // is usually where bug are found (+/-2*32-bit words -> -8 for the range_base and +4 for the
      // range_limit as range_limit is exclusive)
      [dut_cfg.range_base[range_idx]-8  : dut_cfg.range_limit[range_idx]+4] :/ 98,
      // 1% on the lowest part of the range
      [0                                : 9                               ] :/ 1,
      // 1% on the uppermost part of the range
      [2^NUM_RANGES-10                  : 2^NUM_RANGES-1                  ] :/ 1
    };
  }

  constraint tl_main_vars_mask_c {
    soft tl_main_vars.mask == 'hF;
  }

  // Enable deny_access 3/4 of the time for each range
  constraint log_denied_access_c {
    foreach (dut_cfg.range_base[i]) {
      dut_cfg.range_attr[i].log_denied_access dist {
        0 :/ 1,
        1 :/ 3
      };
    }
  }

  constraint range_c {
    solve config_range_mask before dut_cfg.range_base;
    solve dut_cfg.range_base before dut_cfg.range_limit;
    foreach (dut_cfg.range_limit[i]) {
      // Limit always greater than base
      dut_cfg.range_limit[i] > dut_cfg.range_base[i];
      if (config_range_mask[i]) {
        // Range size in 32-bit words, it shouldn't be too large and let it be 1 word size
        ((dut_cfg.range_limit[i] - dut_cfg.range_base[i]) >> 2) inside {[1:49]};
      }
    }
  }
endclass





class ac_range_check_rand_rst_safe_base_vseq extends cip_rand_rst_safe_base_vseq #(
    .RAL_T               (ac_range_check_reg_block),
    .CFG_T               (ac_range_check_env_cfg),
    .COV_T               (ac_range_check_env_cov),
    .VIRTUAL_SEQUENCER_T (ac_range_check_virtual_sequencer),
    .TEST_PARAMS_T       (ac_range_check_base_test_seq_parameters),
    .CONFIG_PARAMS_T     (ac_range_check_base_config_parameters)
  );
  `uvm_object_utils(ac_range_check_rand_rst_safe_base_vseq)

  // Moving of all sequence control parameters to two separate parameter classes helps with random
  // stability issues that were observed during coverage closure for ac_range_check block

  // This vseq inherits two params object instances that are created instanced in
  // 'dv_rand_rst_safe_base_seq' namely:
  // - TEST_PARAMS_T   test_params;
  // - CONFIG_PARAMS_T config_params;


  // Standard SV/UVM methods
  extern function new(string name="");

  // DV Base class specific tasks/methods
  extern virtual task reset_trigger_thread();
  extern virtual task main_thread();
  extern virtual function void handle_reset_assertion ();


  // Class specific methods
  extern virtual task dut_init();
  extern virtual task ac_range_check_init();
  extern virtual task cfg_range_base();
  extern virtual task cfg_range_limit();
  extern virtual task cfg_range_attr();
  extern virtual task cfg_range_racl_policy();
  extern virtual task send_single_tl_unfilt_tr(bit zero_delays = 0);
  extern virtual task tl_filt_device_auto_resp(int min_rsp_delay = 0, int max_rsp_delay = 80,
    int rsp_abort_pct = 25, int d_error_pct = 0, int d_chan_intg_err_pct = 0);
  extern virtual task configure_range(int unsigned idx = 0, bit [DataWidth-1:0] base = 0,
    bit [DataWidth-1:0] limit = 0, bit read_perm = 0, bit write_perm = 0, bit execute_perm = 0,
    bit en = 0, bit log_denied_access = 0);
endclass : ac_range_check_rand_rst_safe_base_vseq


function ac_range_check_rand_rst_safe_base_vseq::new(string name="");
  super.new(name);

  // Derived test sequences will need to set the appropriate type override in the 'new()' method
  // before calling 'super.body()'.
  //
  // 'test_params' & 'config_params' instance is created in when 'body()' task of the
  // dv_rand_rst_safe_base_seq is executed. i.e 'super.body()' is called in the derived sequence.
  //
  // <TEST_PARAMS_T>::type_id::set_type_override(<OVERRIDE_TEST_PARAMS_T>::get_type());
  // <CONFIG_PARAMS_T>::type_id::set_type_override(<OVERRIDE_CONFIG_PARAMS_T>::get_type());
endfunction : new


task ac_range_check_rand_rst_safe_base_vseq::reset_trigger_thread();
  // Any TB that implements the reset safety will need the below lines implemented in the derived
  // sequence. DV Lib does not have access to reset_seq at compile and hence the example is provided
  // such that derived TB base_vseq can implement
  reset_seq  rst_seq;

  `uvm_info (get_name(), "Triggering Reset", UVM_MEDIUM)

  // Execute the reset sequence on the clk reset sequencer
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread


task ac_range_check_rand_rst_safe_base_vseq::main_thread();
  // This is the task for main execution focus of the virtual sequence i.e. the transaction
  // generator.
  // For 'ac_range_check' this will need to be implemented in any of the sequences deriving from
  // this base sequence. An example is 'ac_range_check_rst_safe_smoke_sequence'
  `uvm_fatal (get_name(), "Derived sequence needs to provide an implementation")
endtask : main_thread

function void ac_range_check_rand_rst_safe_base_vseq::handle_reset_assertion ();
  // This function is to make sure all state elements in the sequence and env are brought to the
  // default state as what would be when the sequence was initially started / at the point reset is
  // asserted
  super.handle_reset_assertion();
endfunction : handle_reset_assertion


task ac_range_check_rand_rst_safe_base_vseq::dut_init();

  // TODO: misc_vif needs to be moved into a separate agent
  // and have appropriate sequences to drive the interface
  // Initialize some of DUT inputs
  cfg.misc_vif.set_range_check_overwrite(0);
  cfg.misc_vif.init_racl_policies();

  if (test_params.do_ac_range_check_init) begin
    ac_range_check_init();
  end

  // Spawns off a thread to auto-respond to incoming TL accesses on the Filtered host interface.
  // Note: the fork is required as the called sequence will loop indefinitely.
  fork
    tl_filt_device_auto_resp();
  join_none
endtask : dut_init


task ac_range_check_rand_rst_safe_base_vseq::ac_range_check_init();
  // This fork will ensure that configuration takes place in "disorder", as the TL register
  // sequencer will have to deal with parallel requests (and random delays).
  fork
    cfg_range_base();
    cfg_range_limit();
    cfg_range_attr();
    cfg_range_racl_policy();
  join
  // TODO lastly, randomly lock the configuration with RANGE_REGWEN
endtask : ac_range_check_init


// Only update registers whose value does not match the new one (usage of set+update instead write)
task ac_range_check_rand_rst_safe_base_vseq::cfg_range_base();
  foreach (config_params.dut_cfg.range_base[i]) begin
    ral.range_base[i].set(config_params.dut_cfg.range_base[i]);
    csr_update(.csr(ral.range_base[i]));
  end
endtask : cfg_range_base


task ac_range_check_rand_rst_safe_base_vseq::cfg_range_limit();
  foreach (config_params.dut_cfg.range_limit[i]) begin
    ral.range_limit[i].set(config_params.dut_cfg.range_limit[i]);
    csr_update(.csr(ral.range_limit[i]));
  end
endtask : cfg_range_limit


task ac_range_check_rand_rst_safe_base_vseq::cfg_range_attr();
  foreach (config_params.dut_cfg.range_attr[i]) begin
    ral.range_attr[i].log_denied_access.set(mubi4_bool_to_mubi(
                                            config_params.dut_cfg.range_attr[i].log_denied_access));
    ral.range_attr[i].execute_access.set(mubi4_bool_to_mubi(
                                            config_params.dut_cfg.range_attr[i].execute_access));
    ral.range_attr[i].write_access.set(mubi4_bool_to_mubi(
                                            config_params.dut_cfg.range_attr[i].write_access));
    ral.range_attr[i].read_access.set(mubi4_bool_to_mubi(
                                            config_params.dut_cfg.range_attr[i].read_access));
    ral.range_attr[i].enable.set(mubi4_bool_to_mubi(
                                            config_params.dut_cfg.range_attr[i].enable));
    csr_update(.csr(ral.range_attr[i]));
  end
endtask : cfg_range_attr


task ac_range_check_rand_rst_safe_base_vseq::cfg_range_racl_policy();
  foreach (config_params.dut_cfg.range_racl_policy[i]) begin
    ral.range_racl_policy_shadowed[i].set(config_params.dut_cfg.range_racl_policy[i]);
    // Shadowed register: the 2 writes are automatically managed by the csr_utils_pkg
    csr_update(.csr(ral.range_racl_policy_shadowed[i]));
  end
endtask : cfg_range_racl_policy


task ac_range_check_rand_rst_safe_base_vseq::send_single_tl_unfilt_tr(bit zero_delays = 0);
  cip_tl_host_single_seq tl_unfilt_host_seq;
  `uvm_create_on(tl_unfilt_host_seq, p_sequencer.tl_unfilt_sqr)
  if (zero_delays) begin
    tl_unfilt_host_seq.min_req_delay = 0;
    tl_unfilt_host_seq.max_req_delay = 0;
  end

  `DV_CHECK_RANDOMIZE_WITH_FATAL(tl_unfilt_host_seq,
                              instr_type == mubi4_bool_to_mubi(config_params.tl_main_vars.instr_type);
                              write      == config_params.tl_main_vars.write;
                              addr       == config_params.tl_main_vars.addr;
                              mask       == config_params.tl_main_vars.mask;
                              data       == config_params.tl_main_vars.data;
                              racl_role  == config_params.tl_main_vars.role;)

  //csr_utils_pkg::increment_outstanding_access();
  `uvm_info(`gfn, "Starting tl_unfilt_host_seq", UVM_MEDIUM)
  `DV_SPINWAIT(`uvm_send(tl_unfilt_host_seq), "Timed out when sending fetch request")
  //csr_utils_pkg::decrement_outstanding_access();
endtask : send_single_tl_unfilt_tr


task ac_range_check_rand_rst_safe_base_vseq::tl_filt_device_auto_resp(int min_rsp_delay       = 0,
                                                        int max_rsp_delay       = 80,
                                                        int rsp_abort_pct       = 25,
                                                        int d_error_pct         = 0,
                                                        int d_chan_intg_err_pct = 0);
  cip_tl_device_seq tl_filt_device_seq;
  tl_filt_device_seq = cip_tl_device_seq::type_id::create("tl_filt_device_seq");
  tl_filt_device_seq.min_rsp_delay       = min_rsp_delay;
  tl_filt_device_seq.max_rsp_delay       = max_rsp_delay;
  tl_filt_device_seq.rsp_abort_pct       = rsp_abort_pct;
  tl_filt_device_seq.d_error_pct         = d_error_pct;
  tl_filt_device_seq.d_chan_intg_err_pct = d_chan_intg_err_pct;
  `DV_CHECK_RANDOMIZE_FATAL(tl_filt_device_seq)
  `uvm_info(`gfn, "Starting tl_filt_device_seq", UVM_MEDIUM)
  tl_filt_device_seq.start(p_sequencer.tl_filt_sqr);
endtask : tl_filt_device_auto_resp


task ac_range_check_rand_rst_safe_base_vseq::configure_range(int unsigned idx = 0,
  bit [DataWidth-1:0] base = 0, bit [DataWidth-1:0] limit = 0, bit read_perm = 0,
  bit write_perm = 0, bit execute_perm = 0, bit en = 0, bit log_denied_access = 0);

  `uvm_info(`gfn, $sformatf("Configuring range index: %0d", idx), UVM_MEDIUM)
  `uvm_info(`gfn, $sformatf("Base: 0%0h Limit:0%0h", base, limit), UVM_MEDIUM)

  // RANGE_BASE_x
  ral.range_base[idx].set(base);
  csr_update(.csr(ral.range_base[idx]));

  // RANGE_LIMIT_x
  ral.range_limit[idx].set(limit);
  csr_update(.csr(ral.range_limit[idx]));

  // Needed by the parent sequence to generate TLUL transaction with appropriate addresses.
  // Randomization is disabled on the base and limit so as to allow this sequence to do the
  // appropriate lock range testing
  config_params.dut_cfg.range_base[idx] = base;
  config_params.dut_cfg.range_base[idx].rand_mode(0);

  config_params.dut_cfg.range_limit[idx] = limit;
  config_params.dut_cfg.range_limit[idx].rand_mode(0);

  // RANGE_ATTR_x broken down into fields
  ral.range_attr[idx].log_denied_access.set(mubi4_bool_to_mubi(log_denied_access));
  ral.range_attr[idx].execute_access.set   (mubi4_bool_to_mubi(execute_perm));
  ral.range_attr[idx].write_access.set     (mubi4_bool_to_mubi(write_perm));
  ral.range_attr[idx].read_access.set      (mubi4_bool_to_mubi(read_perm));
  ral.range_attr[idx].enable.set           (mubi4_bool_to_mubi(en));
  csr_update(.csr(ral.range_attr[idx]));

  // Disable RACL side effects for simplicity.
  ral.range_racl_policy_shadowed[idx].set(32'hFFFF_FFFF);
  csr_update(.csr(ral.range_racl_policy_shadowed[idx]));

endtask : configure_range
