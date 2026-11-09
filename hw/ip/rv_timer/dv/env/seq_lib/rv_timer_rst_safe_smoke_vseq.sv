// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_smoke_test_seq_parameters extends rv_timer_rst_safe_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_smoke_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans inside {[1:6]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_smoke_test_seq_parameters

class rv_timer_rst_safe_smoke_config_parameters extends rv_timer_rst_safe_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_smoke_config_parameters)

  constraint en_timers_c {
    |en_timers == 1'b1;
  }

  constraint en_harts_c {
    |en_harts == 1'b1;
  }

  constraint prescale_c {
    solve en_harts before prescale;
    foreach (prescale[i]) {
      if (en_harts[i]) {
        if (smoke_test) prescale[i] == 1;
        else            prescale[i] inside {[0:max_prescale]};
      } else {
        prescale[i] == 0;
      }
    }
  }

  constraint step_c {
    solve en_harts before step;
    foreach (step[i]) {
      if (en_harts[i]) {
        if (smoke_test) step[i] == 1;
        else            step[i] inside {[1:max_step]};
      } else {
        step[i] == 0;
      }
    }
  }

  constraint ticks_c {
    solve prescale before ticks;
    foreach (ticks[i]) {
      if (en_harts[i]) {
        if (smoke_test) ticks[i] inside {[50:200]};
        else            ticks[i] * (prescale[i] + 1) <= max_clks_until_expiry;
      }
    }
  }

  constraint timer_exp_c {
    solve en_harts before compare_val;
    solve en_timers before compare_val;
    solve timer_val before compare_val;
    solve step before compare_val;
    solve ticks before compare_val;
    foreach (en_harts[i]) {
      foreach (en_timers[j]) {
        if (en_harts[i] && en_timers[j]) {
          compare_val[i][j] == timer_val[i] + step[i] * ticks[i];
        }
      }
    }
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_smoke_config_parameters

class rv_timer_rst_safe_smoke_vseq extends rv_timer_rand_rst_safe_base_vseq;
  `uvm_object_utils(rv_timer_rst_safe_smoke_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
  extern function automatic uint calculate_num_clks(int hart = 0, int timer = 0);
  extern task cfg_all_timers();
endclass : rv_timer_rst_safe_smoke_vseq

function rv_timer_rst_safe_smoke_vseq::new(string name = "");
  super.new(name);
  rv_timer_rst_safe_test_seq_parameters::type_id::set_type_override(
      rv_timer_rst_safe_smoke_test_seq_parameters::get_type());
  rv_timer_rst_safe_config_parameters::type_id::set_type_override(
      rv_timer_rst_safe_smoke_config_parameters::get_type());
endfunction : new

task rv_timer_rst_safe_smoke_vseq::main_thread();
  delay_seq del_seq;

  `uvm_info(`gfn, "Starting rv_timer_rst_safe_smoke_vseq::main_thread()", UVM_LOW)

  for (int trans = 1; trans <= test_params.num_trans; trans++) begin
    int unsigned intr_timeout_ns;

    `uvm_info(`gfn, $sformatf("Running test iteration %0d/%0d",
                              trans, test_params.num_trans), UVM_LOW)
    config_params.smoke_test = cfg.smoke_test;
    config_params.max_prescale = max_prescale;
    config_params.max_step = max_step;
    `DV_CHECK_RANDOMIZE_FATAL(config_params)

    // This task runs timers and waits until they raise an interrupt. This timeout gives an upper
    // bound on how long to wait.
    intr_timeout_ns = delay * 2 + (config_params.max_clks_until_expiry *
                                   (cfg.clk_rst_vif.clk_period_ps / 1000.0));

    // Disable timers first.
    csr_wr(.ptr(ral.ctrl[0]), .value(ral.ctrl[0].get_reset()), .blocking(1));

    // Configure the timers and harts based on rand fields.
    cfg_all_timers();

    // Now enable timers.
    for (int i = 0; i < NUM_HARTS; i++) begin
      for (int j = 0; j < NUM_TIMERS; j++) begin
        cfg_timer(.hart(i), .timer(j), .enable(config_params.en_timers[j]));
      end
    end

    for (int i = 0; i < NUM_HARTS; i++) begin
      automatic int a_i = i;
      fork
        if (config_params.en_harts[a_i]) begin
          int unsigned actual_timeout_ns;

          `DV_CHECK_MEMBER_RANDOMIZE_FATAL(delay)

          actual_timeout_ns = 100 + delay + intr_timeout_ns;
          intr_state_spinwait(.hart(a_i), .exp_data(config_params.en_timers),
                              .spinwait_delay_ns(delay), .timeout_ns(actual_timeout_ns));
        end
      join_none
    end
    wait fork;

    // Disable timers.
    csr_wr(.ptr(ral.ctrl[0]), .value(ral.ctrl[0].get_reset()), .blocking(1));

    // Write one to clear the interrupt status.
    for (int i = 0; i < NUM_HARTS; i++) begin
      for (int j = 0; j < NUM_TIMERS; j++) begin
        if (config_params.en_harts[i] && config_params.en_timers[j]) begin
          clear_intr_state(.hart(i), .timer(j));
        end
      end
    end
  end

  del_seq = delay_seq::type_id::create("del_seq:main_thread");
  `DV_CHECK_RANDOMIZE_FATAL(del_seq)
  del_seq.start(p_sequencer.delay_sequencer_h);
  if ($test$plusargs("rv_timer_rst_safe_seq_debug")) begin
    `uvm_info(`gfn, $sformatf(
                    "RV_TIMER_RST_SAFE_SEQ_DEBUG main_thread exit: outstanding_csr_accesses=%0d",
                    csr_utils_pkg::outstanding_accesses), UVM_LOW)
  end
  `uvm_info(`gfn, "Exiting main_thread()", UVM_LOW)
endtask : main_thread

function automatic uint rv_timer_rst_safe_smoke_vseq::calculate_num_clks(int hart = 0,
                                                                         int timer = 0);
  uint64 mtime_dif = config_params.compare_val[hart][timer] - config_params.timer_val[hart];

  calculate_num_clks = ((mtime_dif / config_params.step[hart]) +
                        ((mtime_dif % config_params.step[hart]) != 0)) *
                       (config_params.prescale[hart] + 1) + 1;
endfunction : calculate_num_clks

task rv_timer_rst_safe_smoke_vseq::cfg_all_timers();
  for (int i = 0; i < NUM_HARTS; i++) begin
    cfg_hart(.hart(i), .prescale(config_params.prescale[i]),
             .step(config_params.step[i]));
    set_timer_val(.hart(i), .val(config_params.timer_val[i]));
    for (int j = 0; j < NUM_TIMERS; j++) begin
      set_compare_val(.hart(i), .timer(j), .val(config_params.compare_val[i][j]));
      cfg_interrupt(.hart(i), .timer(j), .enable(config_params.en_interrupt[i][j]));
    end
  end
endtask : cfg_all_timers
