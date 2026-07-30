// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Shared deterministic setup for the reset-safe coverage-closure sequences.
class ac_range_check_cov_test_seq_parameters
    extends ac_range_check_base_test_seq_parameters;
  `uvm_object_utils(ac_range_check_cov_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  function new(string name = "");
    super.new(name);
    do_dut_init = 1'b0;
    do_ac_range_check_init = 1'b0;
  endfunction : new
endclass : ac_range_check_cov_test_seq_parameters

class ac_range_check_rst_safe_cov_base_vseq
    extends ac_range_check_rand_rst_safe_base_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_cov_base_vseq)

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task initialize_directed_inputs();
  extern virtual task start_filtered_responder(int d_error_pct = 0);
  extern virtual task configure_fixed_range(int unsigned idx,
                                            mubi4_t enable = MuBi4True,
                                            mubi4_t read_access = MuBi4True,
                                            mubi4_t write_access = MuBi4True,
                                            mubi4_t execute_access = MuBi4True,
                                            mubi4_t log_denied_access = MuBi4False);
  extern virtual task write_range_attr_raw(int unsigned idx,
                                           mubi4_t enable,
                                           mubi4_t read_access,
                                           mubi4_t write_access,
                                           mubi4_t execute_access,
                                           mubi4_t log_denied_access);
  extern virtual task write_racl_policy(int unsigned idx,
                                        bit [15:0] read_perm,
                                        bit [15:0] write_perm);
  extern virtual task send_access(int unsigned idx,
                                  access_type_e access_type,
                                  int unsigned role = 0);
  extern virtual function uvm_reg_data_t pack_range_attr(
      int unsigned idx,
      mubi4_t enable,
      mubi4_t read_access,
      mubi4_t write_access,
      mubi4_t execute_access,
      mubi4_t log_denied_access);
  extern virtual function bit [DataWidth-1:0] range_base_addr(int unsigned idx);
  extern virtual function bit [DataWidth-1:0] range_limit_addr(int unsigned idx);
endclass : ac_range_check_rst_safe_cov_base_vseq

function ac_range_check_rst_safe_cov_base_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_cov_base_vseq::body();
  if (test_params == null) begin
    test_params = ac_range_check_cov_test_seq_parameters::type_id::create(
        "test_params");
  end
  if (config_params == null) begin
    config_params = ac_range_check_base_config_parameters::type_id::create(
        "config_params");
  end
  super.body();
endtask : body

task ac_range_check_rst_safe_cov_base_vseq::initialize_directed_inputs();
  cfg.misc_vif.set_range_check_overwrite(1'b0);
  cfg.misc_vif.init_racl_policies();
endtask : initialize_directed_inputs

task ac_range_check_rst_safe_cov_base_vseq::start_filtered_responder(
    int d_error_pct = 0);
  fork
    tl_filt_device_auto_resp(.min_rsp_delay(0),
                             .max_rsp_delay(0),
                             .rsp_abort_pct(0),
                             .d_error_pct(d_error_pct));
  join_none
endtask : start_filtered_responder

function bit [DataWidth-1:0]
    ac_range_check_rst_safe_cov_base_vseq::range_base_addr(int unsigned idx);
  return 32'h1000 + (idx * 32'h100);
endfunction : range_base_addr

function bit [DataWidth-1:0]
    ac_range_check_rst_safe_cov_base_vseq::range_limit_addr(int unsigned idx);
  return range_base_addr(idx) + 32'h100;
endfunction : range_limit_addr

task ac_range_check_rst_safe_cov_base_vseq::write_range_attr_raw(
    int unsigned idx,
    mubi4_t enable,
    mubi4_t read_access,
    mubi4_t write_access,
    mubi4_t execute_access,
    mubi4_t log_denied_access);
  uvm_reg_data_t attr_value =
      pack_range_attr(idx, enable, read_access, write_access, execute_access, log_denied_access);
  csr_wr(.ptr(ral.range_attr[idx]), .value(attr_value));
endtask : write_range_attr_raw

function uvm_reg_data_t ac_range_check_rst_safe_cov_base_vseq::pack_range_attr(
    int unsigned idx,
    mubi4_t enable,
    mubi4_t read_access,
    mubi4_t write_access,
    mubi4_t execute_access,
    mubi4_t log_denied_access);
  uvm_reg_data_t attr_value = '0;

  attr_value |= uvm_reg_data_t'(enable) << ral.range_attr[idx].enable.get_lsb_pos();
  attr_value |= uvm_reg_data_t'(read_access) << ral.range_attr[idx].read_access.get_lsb_pos();
  attr_value |= uvm_reg_data_t'(write_access) << ral.range_attr[idx].write_access.get_lsb_pos();
  attr_value |= uvm_reg_data_t'(execute_access) <<
                ral.range_attr[idx].execute_access.get_lsb_pos();
  attr_value |= uvm_reg_data_t'(log_denied_access) <<
                ral.range_attr[idx].log_denied_access.get_lsb_pos();
  return attr_value;
endfunction : pack_range_attr

task ac_range_check_rst_safe_cov_base_vseq::write_racl_policy(
    int unsigned idx,
    bit [15:0] read_perm,
    bit [15:0] write_perm);
  uvm_reg_data_t policy_value = {write_perm, read_perm};
  csr_wr(.ptr(ral.range_racl_policy_shadowed[idx]), .value(policy_value));
  csr_wr(.ptr(ral.range_racl_policy_shadowed[idx]), .value(policy_value));
endtask : write_racl_policy

task ac_range_check_rst_safe_cov_base_vseq::configure_fixed_range(
    int unsigned idx,
    mubi4_t enable,
    mubi4_t read_access,
    mubi4_t write_access,
    mubi4_t execute_access,
    mubi4_t log_denied_access);
  csr_wr(.ptr(ral.range_base[idx]), .value(range_base_addr(idx)));
  csr_wr(.ptr(ral.range_limit[idx]), .value(range_limit_addr(idx)));
  write_range_attr_raw(idx, enable, read_access, write_access, execute_access,
                       log_denied_access);
  write_racl_policy(idx, 16'hffff, 16'hffff);
endtask : configure_fixed_range

task ac_range_check_rst_safe_cov_base_vseq::send_access(
    int unsigned idx,
    access_type_e access_type,
    int unsigned role = 0);
  config_params.tl_main_vars.addr = range_base_addr(idx);
  config_params.tl_main_vars.mask = '1;
  config_params.tl_main_vars.data = 32'hc001_cafe ^ idx ^ role;
  config_params.tl_main_vars.role = role;
  config_params.tl_main_vars.write = (access_type == Write);
  config_params.tl_main_vars.instr_type = (access_type == Execute);
  send_single_tl_unfilt_tr(1'b1);
endtask : send_access
