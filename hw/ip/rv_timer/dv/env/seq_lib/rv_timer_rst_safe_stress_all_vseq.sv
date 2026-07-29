// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_stress_all_test_seq_parameters
    extends rv_timer_rst_safe_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans inside {[1:10]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_stress_all_test_seq_parameters

class rv_timer_rst_safe_stress_all_config_parameters
    extends cip_rst_safe_stress_all_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_config_parameters)

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_stress_all_config_parameters

class rv_timer_rst_safe_stress_all_vseq extends cip_rst_safe_stress_all_vseq #(
    .RAL_T               (rv_timer_reg_block),
    .CFG_T               (rv_timer_env_cfg),
    .COV_T               (rv_timer_env_cov),
    .VIRTUAL_SEQUENCER_T (rv_timer_rst_safe_virtual_sequencer),
    .TEST_PARAMS_T       (rv_timer_rst_safe_stress_all_test_seq_parameters),
    .CONFIG_PARAMS_T     (rv_timer_rst_safe_stress_all_config_parameters)
  );
  `uvm_object_utils(rv_timer_rst_safe_stress_all_vseq)

  extern function new(string name = "");
  extern virtual function void get_stress_seq_names(ref string seq_names[$]);
  extern virtual function void configure_stress_child(uvm_sequence selected_seq);
endclass : rv_timer_rst_safe_stress_all_vseq

function rv_timer_rst_safe_stress_all_vseq::new(string name = "");
  super.new(name);
endfunction : new

function void rv_timer_rst_safe_stress_all_vseq::get_stress_seq_names(
    ref string seq_names[$]);
  seq_names.push_back("rv_timer_rst_safe_smoke_vseq");
  seq_names.push_back("rv_timer_rst_safe_disabled_vseq");
  seq_names.push_back("rv_timer_rst_safe_common_vseq");
  seq_names.push_back("rv_timer_random_vseq");
  seq_names.push_back("rv_timer_rst_safe_min_vseq");
  seq_names.push_back("rv_timer_rst_safe_max_vseq");
endfunction : get_stress_seq_names

function void rv_timer_rst_safe_stress_all_vseq::configure_stress_child(
    uvm_sequence selected_seq);
  rv_timer_rand_rst_safe_base_vseq rst_safe_child;
  rv_timer_rst_safe_common_vseq    common_child;
  rv_timer_base_vseq               legacy_child;

  if ($cast(rst_safe_child, selected_seq)) begin
    rst_safe_child.do_apply_reset = 1'b0;
    rst_safe_child.reset_ctrl_higher_seq = 1'b1;

    if ($cast(common_child, selected_seq)) begin
      common_child.common_seq_type = "intr_test";
    end
  end else if ($cast(legacy_child, selected_seq)) begin
    legacy_child.do_apply_reset = 1'b0;
    cfg.m_tl_agent_cfg.a_valid_delay_min = 2;
    cfg.m_tl_agent_cfg.a_valid_delay_max = 10;
  end else begin
    `uvm_fatal(`gfn, $sformatf("Unsupported reset-safe stress-all child sequence %s",
                               selected_seq.get_type_name()))
  end
endfunction : configure_stress_child
