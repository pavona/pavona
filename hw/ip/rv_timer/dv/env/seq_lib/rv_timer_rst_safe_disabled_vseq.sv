// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset-safe variant of rv_timer_disabled_vseq. This sequence keeps the disabled-timer behavior
// inside main_thread(), so the reset-safe base sequence owns reset timing and thread termination.
class rv_timer_rst_safe_disabled_test_seq_parameters
    extends rv_timer_rst_safe_smoke_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_disabled_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == DISABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 1;
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_disabled_test_seq_parameters

class rv_timer_rst_safe_disabled_vseq extends rv_timer_rst_safe_smoke_vseq;
  `uvm_object_utils(rv_timer_rst_safe_disabled_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
endclass : rv_timer_rst_safe_disabled_vseq

function rv_timer_rst_safe_disabled_vseq::new(string name = "");
  super.new(name);
  rv_timer_rst_safe_test_seq_parameters::type_id::set_type_override(
      rv_timer_rst_safe_disabled_test_seq_parameters::get_type());
endfunction : new

task rv_timer_rst_safe_disabled_vseq::main_thread();
  `uvm_info(`gfn, "Starting rv_timer_rst_safe_disabled_vseq::main_thread()", UVM_LOW)

  for (int trans = 1; trans <= test_params.num_trans; trans++) begin
    bit stop_reading;

    `uvm_info(`gfn, $sformatf("Running test iteration %0d/%0d",
                              trans, test_params.num_trans), UVM_LOW)

    config_params.smoke_test = cfg.smoke_test;
    config_params.max_prescale = max_prescale;
    config_params.max_step = max_step;
    `DV_CHECK_RANDOMIZE_FATAL(config_params)

    // Disable timers, then program harts, compare values, and interrupt enables. Unlike the smoke
    // sequence, timers intentionally remain disabled for the duration of this iteration.
    csr_wr(.ptr(ral.ctrl[0]), .value(ral.ctrl[0].get_reset()), .blocking(1));
    cfg_all_timers();

    fork
      begin
        for (int i = 0; i < NUM_HARTS; i++) begin
          for (int j = 0; j < NUM_TIMERS; j++) begin
            automatic int a_i = i;
            automatic int a_j = j;
            fork
              begin
                delay_seq del_seq;
                int intr_pin_idx = a_i * NUM_TIMERS + a_j;
                int delay_time_steps = (config_params.step[a_i] == 0) ? 100 :
                    calculate_num_clks(.hart(a_i), .timer(a_j));

                del_seq = delay_seq::type_id::create($sformatf("disabled_intr_delay_%0d_%0d",
                                                               a_i, a_j));
                del_seq.delay_time_steps = delay_time_steps;
                del_seq.start(p_sequencer.delay_sequencer_h);
                `DV_CHECK_CASE_EQ(cfg.intr_vif.sample_pin(.idx(intr_pin_idx)), 1'b0)
              end
            join_none
          end
        end
        wait fork;
        stop_reading = 1'b1;
      end
      begin
        uint64 read_data;

        // Read interrupt status and timer value registers while the disabled timers are expected to
        // remain inactive. The CSR reads also feed the scoreboard checks.
        forever begin
          delay_seq del_seq;

          `DV_CHECK_MEMBER_RANDOMIZE_FATAL(delay)
          del_seq = delay_seq::type_id::create("disabled_poll_delay");
          del_seq.delay_time_steps = delay;
          del_seq.start(p_sequencer.delay_sequencer_h);

          for (int i = 0; i < NUM_HARTS; i++) begin
            read_intr_status_reg(.hart(i), .status_val(read_data));
            read_timer_val_reg(.hart(i), .mtime_val(read_data));
          end
          if (stop_reading) break;
        end

        // Final read after the no-interrupt wait completes.
        for (int i = 0; i < NUM_HARTS; i++) begin
          read_intr_status_reg(.hart(i), .status_val(read_data));
          read_timer_val_reg(.hart(i), .mtime_val(read_data));
        end
      end
    join
  end

  `uvm_info(`gfn, "Exiting main_thread()", UVM_LOW)
endtask : main_thread
