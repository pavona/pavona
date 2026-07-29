// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_rst_safe_stress_all_test_seq_parameters
    extends ac_range_check_base_test_seq_parameters;
  `uvm_object_utils(ac_range_check_rst_safe_stress_all_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans inside {[3:6]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : ac_range_check_rst_safe_stress_all_test_seq_parameters

class ac_range_check_rst_safe_stress_all_vseq extends cip_rst_safe_stress_all_vseq #(
    .RAL_T               (ac_range_check_reg_block),
    .CFG_T               (ac_range_check_env_cfg),
    .COV_T               (ac_range_check_env_cov),
    .VIRTUAL_SEQUENCER_T (ac_range_check_virtual_sequencer),
    .TEST_PARAMS_T       (ac_range_check_rst_safe_stress_all_test_seq_parameters),
    .CONFIG_PARAMS_T     (cip_rst_safe_stress_all_config_parameters)
  );
  `uvm_object_utils(ac_range_check_rst_safe_stress_all_vseq)

  extern function new(string name = "");
  extern virtual function void get_stress_seq_names(ref string seq_names[$]);
  extern virtual function void configure_stress_child(uvm_sequence selected_seq);
endclass : ac_range_check_rst_safe_stress_all_vseq

function ac_range_check_rst_safe_stress_all_vseq::new(string name = "");
  super.new(name);
endfunction : new

function void ac_range_check_rst_safe_stress_all_vseq::get_stress_seq_names(
    ref string seq_names[$]);
  seq_names.push_back("ac_range_check_rst_safe_smoke_vseq");
  seq_names.push_back("ac_range_check_rst_safe_smoke_racl_vseq");
  seq_names.push_back("ac_range_check_bypass_vseq");
endfunction : get_stress_seq_names

function void ac_range_check_rst_safe_stress_all_vseq::configure_stress_child(
    uvm_sequence selected_seq);
  ac_range_check_rand_rst_safe_base_vseq rst_safe_child;
  ac_range_check_rst_safe_smoke_racl_vseq smoke_racl_child;
  ac_range_check_rst_safe_smoke_vseq      smoke_child;
  ac_range_check_bypass_vseq              bypass_child;

  if ($cast(rst_safe_child, selected_seq)) begin
    rst_safe_child.do_apply_reset        = 1'b0;
    rst_safe_child.reset_ctrl_higher_seq = 1'b1;
    rst_safe_child.test_params =
        ac_range_check_smoke_test_seq_parameters::type_id::create("test_params");

    if ($cast(smoke_racl_child, selected_seq)) begin
      rst_safe_child.config_params =
          ac_range_check_smoke_racl_config_parameters::type_id::create("config_params");
    end else if ($cast(smoke_child, selected_seq)) begin
      rst_safe_child.config_params =
          ac_range_check_smoke_config_parameters::type_id::create("config_params");
    end else begin
      `uvm_fatal(`gfn, $sformatf("Unsupported reset-safe stress-all child sequence %s",
                                 selected_seq.get_type_name()))
    end
  end else if ($cast(bypass_child, selected_seq)) begin
    bypass_child.do_apply_reset = 1'b0;
  end else begin
    `uvm_fatal(`gfn, $sformatf("Unsupported reset-safe stress-all child sequence %s",
                               selected_seq.get_type_name()))
  end
endfunction : configure_stress_child
