// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ${module_instance_name}_mubi_cov_test_seq_parameters
    extends ${module_instance_name}_base_test_seq_parameters;
  `uvm_object_utils(${module_instance_name}_mubi_cov_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 16;
  }

  function new(string name = "");
    super.new(name);
    do_dut_init = 1'b0;
    do_${module_instance_name}_init = 1'b0;
  endfunction : new
endclass : ${module_instance_name}_mubi_cov_test_seq_parameters

// Drives every raw MuBi4 encoding through each attribute and regwen behavior.
class ${module_instance_name}_rst_safe_mubi_cov_vseq
    extends ${module_instance_name}_rst_safe_cov_base_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_mubi_cov_vseq)

  uvm_event reset_ready_ev;
  int unsigned epoch;

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task reset_trigger_thread();
  extern virtual task main_thread();
endclass : ${module_instance_name}_rst_safe_mubi_cov_vseq

function ${module_instance_name}_rst_safe_mubi_cov_vseq::new(string name = "");
  super.new(name);
  reset_ready_ev = new("reset_ready_ev");
endfunction : new

task ${module_instance_name}_rst_safe_mubi_cov_vseq::body();
  if (test_params == null) begin
    test_params = ${module_instance_name}_mubi_cov_test_seq_parameters::type_id::create(
        "test_params");
  end
  if (config_params == null) begin
    config_params = ${module_instance_name}_base_config_parameters::type_id::create(
        "config_params");
  end
  super.body();
endtask : body

task ${module_instance_name}_rst_safe_mubi_cov_vseq::reset_trigger_thread();
  reset_seq rst_seq;

  reset_ready_ev.wait_on();
  reset_ready_ev.reset();
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

task ${module_instance_name}_rst_safe_mubi_cov_vseq::main_thread();
  mubi4_t candidate = mubi4_t'(epoch[MuBi4Width-1:0]);

  initialize_directed_inputs();
  start_filtered_responder();
  ral.log_config.log_enable.set(1'b1);
  ral.log_config.log_clear.set(1'b1);
  csr_update(.csr(ral.log_config));

  for (int unsigned idx = 0; idx < NUM_RANGES; idx++) begin
    uvm_reg_data_t act_value;
    uvm_reg_data_t initial_base = range_base_addr(idx);
    uvm_reg_data_t replacement_base = initial_base + 32'h8000;
    mubi4_t expected_regwen = candidate;

    configure_fixed_range(idx);

    // ENABLE is decoded loosely: only the legal false encoding disables a range.
    write_range_attr_raw(idx, candidate, MuBi4True, MuBi4True, MuBi4True, MuBi4False);
    csr_rd(.ptr(ral.range_attr[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value,
                 pack_range_attr(idx, candidate, MuBi4True, MuBi4True, MuBi4True, MuBi4False))
    send_access(idx, Read);

    // R/W/X permissions are decoded strictly.
    write_range_attr_raw(idx, MuBi4True, candidate, MuBi4True, MuBi4True, MuBi4False);
    csr_rd(.ptr(ral.range_attr[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value,
                 pack_range_attr(idx, MuBi4True, candidate, MuBi4True, MuBi4True, MuBi4False))
    send_access(idx, Read);
    write_range_attr_raw(idx, MuBi4True, MuBi4True, candidate, MuBi4True, MuBi4False);
    csr_rd(.ptr(ral.range_attr[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value,
                 pack_range_attr(idx, MuBi4True, MuBi4True, candidate, MuBi4True, MuBi4False))
    send_access(idx, Write);
    write_range_attr_raw(idx, MuBi4True, MuBi4True, MuBi4True, candidate, MuBi4False);
    csr_rd(.ptr(ral.range_attr[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value,
                 pack_range_attr(idx, MuBi4True, MuBi4True, MuBi4True, candidate, MuBi4False))
    send_access(idx, Execute);

    // Logging is also decoded strictly.
    write_range_attr_raw(idx, MuBi4True, MuBi4False, MuBi4True, MuBi4True, candidate);
    csr_rd(.ptr(ral.range_attr[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value,
                 pack_range_attr(idx, MuBi4True, MuBi4False, MuBi4True, MuBi4True, candidate))
    send_access(idx, Read);

    // The first W0C write from reset retains the raw candidate encoding.
    // Only legal true is then decoded as writable; false and invalid values
    // lock the protected CSRs.
    csr_wr(.ptr(ral.range_base[idx]), .value(initial_base));
    csr_wr(.ptr(ral.range_regwen[idx]), .value(candidate));
    csr_rd(.ptr(ral.range_regwen[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value[MuBi4Width-1:0], expected_regwen,
                 $sformatf("range_regwen[%0d], candidate 0x%0h", idx, candidate))

    csr_wr(.ptr(ral.range_base[idx]), .value(replacement_base));
    csr_rd(.ptr(ral.range_base[idx]), .value(act_value));
    `DV_CHECK_EQ(act_value, candidate == MuBi4True ? replacement_base : initial_base,
                 $sformatf("protected range_base[%0d], candidate 0x%0h", idx, candidate))
  end

  epoch++;
  if (epoch < 16) begin
    reset_ready_ev.trigger();
    // The reset-safe base must kill this thread. Returning as reset asserts
    // is diagnosed as the main thread finishing before reset control.
    wait (1'b0);
  end
endtask : main_thread
