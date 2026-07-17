// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset-safe variant of rv_timer_stress_all_vseq. Execute child sequences from main_thread() so the
// reset-safe base body owns reset orchestration.
class rv_timer_rst_safe_stress_all_test_seq_parameters
    extends rv_timer_rst_safe_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_test_seq_parameters)

  // The non-reset stress-all entry point uses the reset-safe environment and wrapper structure, but
  // leaves random reset testing disabled.
  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  // A single loop is sufficient when reset testing is disabled.
  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  // Avoid simulation running for too long.
  constraint num_trans_c {
    num_trans inside {[1:10]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_stress_all_test_seq_parameters

class rv_timer_rst_safe_stress_all_config_parameters extends rv_timer_rst_safe_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_config_parameters)

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_stress_all_config_parameters

class rv_timer_rst_safe_stress_all_vseq extends rv_timer_rand_rst_safe_base_vseq;
  `uvm_object_utils(rv_timer_rst_safe_stress_all_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
endclass : rv_timer_rst_safe_stress_all_vseq

function rv_timer_rst_safe_stress_all_vseq::new(string name = "");
  super.new(name);
  rv_timer_rst_safe_test_seq_parameters::type_id::set_type_override(
      rv_timer_rst_safe_stress_all_test_seq_parameters::get_type());
  rv_timer_rst_safe_config_parameters::type_id::set_type_override(
      rv_timer_rst_safe_stress_all_config_parameters::get_type());
endfunction : new

task rv_timer_rst_safe_stress_all_vseq::main_thread();
  // Initial reset-safe stress list. Add only reset-safe child sequences here; each child is started
  // under this wrapper so the outer reset-safe body owns reset control.
  string seq_names[] = {"rv_timer_rst_safe_smoke_vseq",
                        "rv_timer_rst_safe_disabled_vseq",
                        "rv_timer_rst_safe_common_vseq",
                        "rv_timer_random_vseq",
                        "rv_timer_min_vseq",
                        "rv_timer_max_vseq"};

  `uvm_info(`gfn, "Starting rv_timer_rst_safe_stress_all_vseq::main_thread()", UVM_LOW)

  for (int i = 1; i <= test_params.num_trans; i++) begin
    uvm_sequence                       seq;
    uint                               seq_idx = $urandom_range(0, seq_names.size - 1);
    bit                                legacy_random_child;
    int unsigned                       saved_a_valid_delay_min;
    int unsigned                       saved_a_valid_delay_max;

    if (i > 1) begin
      delay_seq del_seq;

      // rst_safe: separate child vseq launches with a delay-agent transaction. Blocking CSR calls
      // can return before the DUT-side TLUL assertion bookkeeping has advanced past the response
      // cycle, so a zero-gap child transition can re-enter TL immediately at the boundary.
      del_seq = delay_seq::type_id::create("stress_all_child_gap");
      del_seq.delay_time_steps = $urandom_range(1, 10);
      `uvm_info(`gfn, $sformatf("Waiting %0d delay steps before starting next child sequence",
                                del_seq.delay_time_steps), UVM_MEDIUM)
      del_seq.start(p_sequencer.delay_sequencer_h);
    end

    seq = create_seq_by_name(seq_names[seq_idx]);
    legacy_random_child = (seq_names[seq_idx] inside {"rv_timer_random_vseq",
                                                      "rv_timer_min_vseq",
                                                      "rv_timer_max_vseq"});

    if (legacy_random_child) begin
      rv_timer_base_vseq rv_timer_vseq;

      `downcast(rv_timer_vseq, seq)
      // rst_safe: reset ownership stays with this outer reset-safe stress sequence. The legacy
      // random child runs on the reset-safe virtual sequencer, but must not apply its own reset.
      rv_timer_vseq.do_apply_reset = 0;
      rv_timer_vseq.set_sequencer(p_sequencer);
      `DV_CHECK_RANDOMIZE_FATAL(rv_timer_vseq)

      // rst_safe: legacy random/min/max children use the old rv_timer_base_vseq helper stack. Add a
      // temporary TL host launch delay for this child so dense legacy CSR traffic is not issued on
      // adjacent bus opportunities while running under the reset-safe stress wrapper.
      saved_a_valid_delay_min = cfg.m_tl_agent_cfg.a_valid_delay_min;
      saved_a_valid_delay_max = cfg.m_tl_agent_cfg.a_valid_delay_max;
      cfg.m_tl_agent_cfg.a_valid_delay_min = 2;
      cfg.m_tl_agent_cfg.a_valid_delay_max = 10;
    end else begin
      rv_timer_rand_rst_safe_base_vseq rv_timer_vseq;

      `downcast(rv_timer_vseq, seq)
      // Reset ownership stays with this outer reset-safe stress sequence. Keep the child sequence's
      // local reset knob off so all reset control remains in this wrapper.
      rv_timer_vseq.do_apply_reset = 0;

      // Disable the child sequence's reset monitor/trigger threads. The stress-all wrapper is the
      // higher sequence that coordinates resets for the selected child.
      rv_timer_vseq.reset_ctrl_higher_seq = 1;

      rv_timer_vseq.set_sequencer(p_sequencer);
      `DV_CHECK_RANDOMIZE_FATAL(rv_timer_vseq)
      if (seq_names[seq_idx] == "rv_timer_rst_safe_common_vseq") begin
        // rst_safe: match legacy stress-all behavior by running the common wrapper as intr_test.
        rv_timer_vseq.common_seq_type = "intr_test";
      end
    end
    seq.start(p_sequencer);
    if (legacy_random_child) begin
      cfg.m_tl_agent_cfg.a_valid_delay_min = saved_a_valid_delay_min;
      cfg.m_tl_agent_cfg.a_valid_delay_max = saved_a_valid_delay_max;
    end
  end

  `uvm_info(`gfn, "Exiting main_thread()", UVM_LOW)
endtask : main_thread
