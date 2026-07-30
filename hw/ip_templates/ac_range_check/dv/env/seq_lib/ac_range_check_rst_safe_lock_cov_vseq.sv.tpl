// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ${module_instance_name}_lock_cov_test_seq_parameters
    extends ${module_instance_name}_base_test_seq_parameters;
  `uvm_object_utils(${module_instance_name}_lock_cov_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 2;
  }

  function new(string name = "");
    super.new(name);
    do_dut_init = 1'b0;
    do_${module_instance_name}_init = 1'b0;
  endfunction : new
endclass : ${module_instance_name}_lock_cov_test_seq_parameters

// Closes the range enable/logging/lock crosses and proves locked writes are ignored.
class ${module_instance_name}_rst_safe_lock_cov_vseq
    extends ${module_instance_name}_rst_safe_cov_base_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_lock_cov_vseq)

  uvm_event reset_ready_ev;
  int unsigned epoch;

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task reset_trigger_thread();
  extern virtual task main_thread();
  extern virtual task check_range_state(int unsigned idx,
                                        uvm_reg_data_t exp_attr,
                                        mubi4_t exp_regwen,
                                        uvm_reg_data_t exp_base,
                                        uvm_reg_data_t exp_limit,
                                        uvm_reg_data_t exp_policy);
endclass : ${module_instance_name}_rst_safe_lock_cov_vseq

function ${module_instance_name}_rst_safe_lock_cov_vseq::new(string name = "");
  super.new(name);
  reset_ready_ev = new("reset_ready_ev");
endfunction : new

task ${module_instance_name}_rst_safe_lock_cov_vseq::body();
  if (test_params == null) begin
    test_params = ${module_instance_name}_lock_cov_test_seq_parameters::type_id::create(
        "test_params");
  end
  if (config_params == null) begin
    config_params = ${module_instance_name}_base_config_parameters::type_id::create(
        "config_params");
  end
  super.body();
endtask : body

task ${module_instance_name}_rst_safe_lock_cov_vseq::reset_trigger_thread();
  reset_seq rst_seq;

  reset_ready_ev.wait_on();
  reset_ready_ev.reset();
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

task ${module_instance_name}_rst_safe_lock_cov_vseq::check_range_state(
    int unsigned idx,
    uvm_reg_data_t exp_attr,
    mubi4_t exp_regwen,
    uvm_reg_data_t exp_base,
    uvm_reg_data_t exp_limit,
    uvm_reg_data_t exp_policy);
  uvm_reg_data_t act_attr;
  uvm_reg_data_t act_regwen;
  uvm_reg_data_t act_base;
  uvm_reg_data_t act_limit;
  uvm_reg_data_t act_policy;

  csr_rd(.ptr(ral.range_attr[idx]), .value(act_attr));
  csr_rd(.ptr(ral.range_regwen[idx]), .value(act_regwen));
  csr_rd(.ptr(ral.range_base[idx]), .value(act_base));
  csr_rd(.ptr(ral.range_limit[idx]), .value(act_limit));
  csr_rd(.ptr(ral.range_racl_policy_shadowed[idx]), .value(act_policy));
  `DV_CHECK_EQ(act_attr, exp_attr, $sformatf("range_attr[%0d]", idx))
  `DV_CHECK_EQ(act_regwen[MuBi4Width-1:0], exp_regwen,
               $sformatf("range_regwen[%0d]", idx))
  `DV_CHECK_EQ(act_base, exp_base, $sformatf("range_base[%0d]", idx))
  `DV_CHECK_EQ(act_limit, exp_limit, $sformatf("range_limit[%0d]", idx))
  `DV_CHECK_EQ(act_policy, exp_policy, $sformatf("range_racl_policy[%0d]", idx))
endtask : check_range_state

task ${module_instance_name}_rst_safe_lock_cov_vseq::main_thread();
  mubi4_t initial_enable = MuBi4False;
  mubi4_t initial_log = MuBi4False;
  mubi4_t reprogram_enable = MuBi4True;
  mubi4_t reprogram_log = MuBi4True;
  mubi4_t attempted_enable = (epoch == 0) ? MuBi4False : MuBi4True;
  mubi4_t attempted_log = (epoch == 0) ? MuBi4False : MuBi4True;

  initialize_directed_inputs();
  start_filtered_responder();

  for (int unsigned idx = 0; idx < NUM_RANGES; idx++) begin
    uvm_reg_data_t expected_attr;

    configure_fixed_range(idx, initial_enable, MuBi4True, MuBi4True, MuBi4True, initial_log);
    expected_attr = pack_range_attr(idx, initial_enable, MuBi4True, MuBi4True, MuBi4True,
                                   initial_log);
    check_range_state(idx, expected_attr, MuBi4True, range_base_addr(idx),
                      range_limit_addr(idx), 32'hffff_ffff);
    if (cfg.en_cov) begin
      cov.sample_range_lock_cg(idx, initial_enable == MuBi4True, 1'b0);
      cov.sample_lock_logging_cg(idx, initial_log == MuBi4True, 1'b0);
    end

    if (epoch == 0) begin
      write_range_attr_raw(idx, reprogram_enable, MuBi4True, MuBi4True, MuBi4True,
                           reprogram_log);
      expected_attr = pack_range_attr(idx, reprogram_enable, MuBi4True, MuBi4True, MuBi4True,
                                     reprogram_log);
      check_range_state(idx, expected_attr, MuBi4True, range_base_addr(idx),
                        range_limit_addr(idx), 32'hffff_ffff);
      if (cfg.en_cov) begin
        cov.sample_range_lock_cg(idx, 1'b1, 1'b0);
        cov.sample_lock_logging_cg(idx, 1'b1, 1'b0);
      end
    end else if (idx == 0) begin
      // The final lock matrix otherwise contains only disabled ranges. Issue
      // one checked granted transfer, then restore the disabled state before
      // locking and sampling it.
      write_range_attr_raw(idx, MuBi4True, MuBi4True, MuBi4True, MuBi4True, MuBi4False);
      send_access(idx, Read);
      write_range_attr_raw(idx, initial_enable, MuBi4True, MuBi4True, MuBi4True, initial_log);
    end

    csr_wr(.ptr(ral.range_regwen[idx]), .value(MuBi4False));
    csr_wr(.ptr(ral.range_base[idx]), .value(range_base_addr(idx) + 32'h8000));
    csr_wr(.ptr(ral.range_limit[idx]), .value(range_limit_addr(idx) + 32'h8000));
    write_range_attr_raw(idx, attempted_enable, MuBi4False, MuBi4False, MuBi4False,
                         attempted_log);
    write_racl_policy(idx, 16'h0000, 16'h0000);
    check_range_state(idx, expected_attr, MuBi4False, range_base_addr(idx),
                      range_limit_addr(idx), 32'hffff_ffff);
    if (cfg.en_cov) begin
      cov.sample_range_lock_cg(idx, epoch == 0, 1'b1);
      cov.sample_lock_logging_cg(idx, epoch == 0, 1'b1);
    end
  end

  epoch++;
  if (epoch == 1) begin
    reset_ready_ev.trigger();
    // The reset-safe base must kill this thread. Returning as reset asserts
    // is diagnosed as the main thread finishing before reset control.
    wait (1'b0);
  end
endtask : main_thread
