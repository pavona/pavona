// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_cfg_update_on_fly_test_seq_parameters
    extends rv_timer_rst_safe_smoke_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_cfg_update_on_fly_test_seq_parameters)

  constraint num_trans_c {
    num_trans inside {[1:4]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_cfg_update_on_fly_test_seq_parameters

class rv_timer_rst_safe_cfg_update_on_fly_config_parameters
    extends rv_timer_rst_safe_smoke_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_cfg_update_on_fly_config_parameters)

  rand bit upd_cfg_in_end;

  uint64 min_clks_until_expiry = 100;

  constraint ticks_c {
    solve prescale before ticks;
    foreach (ticks[i]) {
      if (en_harts[i]) {
        (ticks[i] * (prescale[i] + 1)) <= max_clks_until_expiry;
        (ticks[i] * (prescale[i] + 1)) >= min_clks_until_expiry;
      }
    }
  }

  function new(string name = "");
    super.new(name);
    max_clks_until_expiry = 10_000;
  endfunction : new
endclass : rv_timer_rst_safe_cfg_update_on_fly_config_parameters

class rv_timer_rst_safe_cfg_update_control_parameters extends dv_config_parameters;
  `uvm_object_utils(rv_timer_rst_safe_cfg_update_control_parameters)

  bit          upd_cfg_in_end;
  int unsigned min_wait_clks;
  int unsigned max_wait_clks;
  uint         max_step;
  uint         max_prescale;

  rand int unsigned num_updates;
  rand int unsigned wait_clks;
  rand int unsigned poll_delay_ns;
  rand bit          update_hart_cfg;
  rand bit          update_step;
  rand uint         new_step;
  rand uint         new_prescale;
  rand bit          compare_add;
  rand uint         compare_step_multiplier;
  rand uint         compare_divisor;
  rand bit          timer_add;
  rand uint         timer_step_multiplier;
  rand uint         timer_divisor;
  rand bit          clear_while_enabled;
  rand bit          clear_by_intr_state;
  rand bit [TL_DW-1:0] clear_compare_value;

  constraint update_count_c {
    if (upd_cfg_in_end) num_updates inside {[4:8]};
    else                num_updates == 1;
  }

  constraint wait_clks_c {
    if (upd_cfg_in_end) wait_clks == 0;
    else                wait_clks inside {[min_wait_clks:max_wait_clks]};
  }

  constraint update_hart_cfg_c {
    if (upd_cfg_in_end) update_hart_cfg == 1'b0;
  }

  constraint hart_cfg_values_c {
    new_step inside {[1:max_step]};
    new_prescale inside {[0:max_prescale]};
  }

  constraint compare_update_c {
    if (upd_cfg_in_end) compare_add == 1'b1;
    compare_step_multiplier inside {[30:300]};
    compare_divisor inside {[4:20]};
  }

  constraint timer_update_c {
    if (!upd_cfg_in_end) timer_add == 1'b1;
    timer_step_multiplier inside {[30:300]};
    timer_divisor inside {[4:20]};
  }

  constraint poll_delay_c {
    poll_delay_ns inside {[1:10_000]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_cfg_update_control_parameters

class rv_timer_rst_safe_cfg_update_on_fly_vseq extends rv_timer_rst_safe_smoke_vseq;
  `uvm_object_utils(rv_timer_rst_safe_cfg_update_on_fly_vseq)

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task main_thread();
  extern local task wait_delay_clks(int unsigned clks, string name);
  extern local task status_read_for_clks(int hart, int clks, int unsigned poll_delay_ns);
  extern local task clear_intr_state_with_control(
      int hart, int timer, rv_timer_rst_safe_cfg_update_control_parameters update_params);
endclass : rv_timer_rst_safe_cfg_update_on_fly_vseq

function rv_timer_rst_safe_cfg_update_on_fly_vseq::new(string name = "");
  super.new(name);
endfunction : new

task rv_timer_rst_safe_cfg_update_on_fly_vseq::body();
  if (test_params == null) begin
    test_params =
        rv_timer_rst_safe_cfg_update_on_fly_test_seq_parameters::type_id::create(
            "test_params");
  end
  if (config_params == null) begin
    config_params =
        rv_timer_rst_safe_cfg_update_on_fly_config_parameters::type_id::create(
            "config_params");
  end
  super.body();
endtask : body

task rv_timer_rst_safe_cfg_update_on_fly_vseq::main_thread();
  rv_timer_rst_safe_cfg_update_on_fly_config_parameters cfg_update_params;
  rv_timer_rst_safe_cfg_update_control_parameters update_params;

  `DV_CHECK_FATAL($cast(cfg_update_params, config_params))
  update_params =
      rv_timer_rst_safe_cfg_update_control_parameters::type_id::create("update_params");
  update_params.max_step = max_step;
  update_params.max_prescale = max_prescale;

  `uvm_info(`gfn, "Starting rv_timer_rst_safe_cfg_update_on_fly_vseq::main_thread()", UVM_LOW)

  for (int trans = 1; trans <= test_params.num_trans; trans++) begin
    `uvm_info(`gfn, $sformatf("Running test iteration %0d/%0d",
                              trans, test_params.num_trans), UVM_LOW)

    // Disable all timers before configuring the timer selected by the nested loops.
    csr_wr(.ptr(ral.ctrl[0]), .value(ral.ctrl[0].get_reset()), .blocking(1));

    for (int hart = 0; hart < NUM_HARTS; hart++) begin
      for (int timer = 0; timer < NUM_TIMERS; timer++) begin
        int          num_clks;
        int unsigned num_updates;
        uint         read_data;
        bit          timer_at_min_max_val;

        cfg_update_params.smoke_test = cfg.smoke_test;
        cfg_update_params.max_prescale = max_prescale;
        cfg_update_params.max_step = max_step;
        `DV_CHECK_RANDOMIZE_FATAL(cfg_update_params)

        cfg_all_timers();
        cfg_timer(.hart(hart), .timer(timer), .enable(1'b1));

        update_params.upd_cfg_in_end = cfg_update_params.upd_cfg_in_end;
        update_params.min_wait_clks = 0;
        update_params.max_wait_clks = 0;
        `DV_CHECK_RANDOMIZE_FATAL(update_params)
        num_updates = update_params.num_updates;

        for (int update = 0; update < num_updates; update++) begin
          int current_num_clks = calculate_num_clks(hart, timer);

          if (cfg_update_params.upd_cfg_in_end) begin
            num_clks = current_num_clks -
                       (cfg_update_params.prescale[hart] + 1) - 8 - 2;
            if (num_clks < 0) num_clks = 0;
            update_params.min_wait_clks = 0;
            update_params.max_wait_clks = 0;
          end else begin
            update_params.min_wait_clks = current_num_clks / 10;
            update_params.max_wait_clks = current_num_clks / 2;
          end
          `DV_CHECK_RANDOMIZE_FATAL(update_params)
          if (!cfg_update_params.upd_cfg_in_end) num_clks = update_params.wait_clks;

          status_read_for_clks(.hart(hart), .clks(num_clks),
                               .poll_delay_ns(update_params.poll_delay_ns));

          if (update_params.update_hart_cfg) begin
            if (update_params.update_step) begin
              `uvm_info(`gfn, "Updating timer step value", UVM_LOW)
              cfg_update_params.step[hart] = update_params.new_step;
            end else begin
              `uvm_info(`gfn, "Updating timer prescale value", UVM_LOW)
              cfg_update_params.prescale[hart] = update_params.new_prescale;
            end
            cfg_timer(.hart(hart), .timer(timer), .enable(1'b0));
            cfg_hart(.hart(hart), .prescale(cfg_update_params.prescale[hart]),
                     .step(cfg_update_params.step[hart]));
            cfg_timer(.hart(hart), .timer(timer), .enable(1'b1));
          end

          // Avoid overflow or underflow when applying the largest possible update.
          if ((cfg_update_params.compare_val[hart][timer] >= 64'hFFFFFFFFFFFED52B) |
              (cfg_update_params.timer_val[hart] <= 64'h12AD4)) begin
            timer_at_min_max_val = 1'b1;
            break;
          end else begin
            uint64 mtime_diff;

            `uvm_info(`gfn, "Updating timer and compare reg", UVM_LOW)
            mtime_diff = cfg_update_params.compare_val[hart][timer] -
                         cfg_update_params.timer_val[hart];
            if (update_params.compare_add) begin
              cfg_update_params.compare_val[hart][timer] +=
                  cfg_update_params.step[hart] * update_params.compare_step_multiplier;
            end else begin
              cfg_update_params.compare_val[hart][timer] -=
                  mtime_diff / update_params.compare_divisor;
            end
            set_compare_val(.hart(hart), .timer(timer),
                            .val(cfg_update_params.compare_val[hart][timer]));

            mtime_diff = cfg_update_params.compare_val[hart][timer] -
                         cfg_update_params.timer_val[hart];
            if (update_params.timer_add) begin
              cfg_update_params.timer_val[hart] += mtime_diff / update_params.timer_divisor;
            end else begin
              cfg_update_params.timer_val[hart] -=
                  cfg_update_params.step[hart] * update_params.timer_step_multiplier;
            end
            set_timer_val(.hart(hart), .val(cfg_update_params.timer_val[hart]));
          end

          read_timer_val_reg(.hart(hart), .mtime_val(cfg_update_params.timer_val[hart]));
        end

        read_intr_status_reg(.hart(hart), .status_val(read_data));
        `DV_CHECK_EQ(read_data, 0)

        if (!(cfg_update_params.upd_cfg_in_end && timer_at_min_max_val)) begin
          num_clks = calculate_num_clks(hart, timer) -
                     (cfg_update_params.prescale[hart] + 4);
          if (num_clks < 0) num_clks = 0;
          `DV_CHECK_RANDOMIZE_FATAL(update_params)
          status_read_for_clks(.hart(hart), .clks(num_clks),
                               .poll_delay_ns(update_params.poll_delay_ns));
        end

        wait_delay_clks(.clks(cfg_update_params.prescale[hart] + 5),
                        .name("timer_expiry_delay"));

        `uvm_info(`gfn, "Timer expired last read", UVM_LOW)
        read_intr_status_reg(.hart(hart), .status_val(read_data));
        `DV_CHECK_EQ_FATAL(read_data, (1 << timer))

        `DV_CHECK_RANDOMIZE_FATAL(update_params)
        if (update_params.clear_while_enabled) begin
          clear_intr_state_with_control(.hart(hart), .timer(timer),
                                        .update_params(update_params));
        end

        cfg_timer(.hart(hart), .timer(timer), .enable(1'b0));
        `DV_CHECK_RANDOMIZE_FATAL(update_params)
        clear_intr_state_with_control(.hart(hart), .timer(timer),
                                      .update_params(update_params));
      end
    end
  end

  `uvm_info(`gfn, "Exiting rv_timer_rst_safe_cfg_update_on_fly_vseq::main_thread()", UVM_LOW)
endtask : main_thread

task rv_timer_rst_safe_cfg_update_on_fly_vseq::wait_delay_clks(int unsigned clks,
                                                               string name);
  delay_seq del_seq;

  if (clks == 0) return;
  del_seq = delay_seq::type_id::create(name);
  del_seq.delay_time_steps = clks;
  del_seq.start(p_sequencer.delay_sequencer_h);
endtask : wait_delay_clks

task rv_timer_rst_safe_cfg_update_on_fly_vseq::status_read_for_clks(
    int hart, int clks, int unsigned poll_delay_ns);
  bit          stop_reading;
  int unsigned poll_delay_clks;

  if (clks <= 0) return;
  poll_delay_clks = ((poll_delay_ns * 1000) + cfg.clk_rst_vif.clk_period_ps - 1) /
                    cfg.clk_rst_vif.clk_period_ps;
  if (poll_delay_clks == 0) poll_delay_clks = 1;

  fork
    begin
      wait_delay_clks(.clks(clks), .name("status_read_window"));
      stop_reading = 1'b1;
    end
    begin
      while (!stop_reading) begin
        uint read_data;

        read_intr_status_reg(.hart(hart), .status_val(read_data));
        wait_delay_clks(.clks(poll_delay_clks), .name("status_read_poll_delay"));
      end
    end
  join
endtask : status_read_for_clks

task rv_timer_rst_safe_cfg_update_on_fly_vseq::clear_intr_state_with_control(
    int hart, int timer, rv_timer_rst_safe_cfg_update_control_parameters update_params);
  uvm_reg         intr_state_rg;
  bit [TL_DW-1:0] status;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  `DV_CHECK_LT_FATAL(timer, NUM_TIMERS)
  intr_state_rg = ral.get_reg_by_name($sformatf("intr_state%0d", hart));
  `DV_CHECK_NE_FATAL(intr_state_rg, null)

  if (update_params.clear_by_intr_state) begin
    csr_wr(.ptr(intr_state_rg), .value(1 << timer), .blocking(1));
  end else begin
    set_compare_val(.hart(hart), .timer(timer), .val(update_params.clear_compare_value));
    wait_delay_clks(.clks(1), .name("clear_intr_delay"));
  end
  csr_rd(.ptr(intr_state_rg), .value(status), .blocking(1));
endtask : clear_intr_state_with_control
