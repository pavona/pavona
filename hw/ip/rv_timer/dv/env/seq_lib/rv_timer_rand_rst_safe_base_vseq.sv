// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class rv_timer_rst_safe_test_seq_parameters extends dv_test_seq_parameters;
  `uvm_object_utils(rv_timer_rst_safe_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing inside {DISABLE, ENABLE};
  }

  constraint reset_loops_c {
    if (reset_testing == ENABLE) num_reset_loops inside {[2:5]};
    if (reset_testing == DISABLE) num_reset_loops == 1;
  }

  constraint num_trans_c {
    num_trans inside {[1:3]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : rv_timer_rst_safe_test_seq_parameters

class rv_timer_rst_safe_config_parameters extends dv_config_parameters;
  rand bit [NUM_TIMERS-1:0] en_timers;
  rand bit [NUM_HARTS-1:0]  en_harts;

  rand uint64 timer_val[NUM_HARTS];
  rand uint64 compare_val[NUM_HARTS][NUM_TIMERS];
  rand bit    en_interrupt[NUM_HARTS][NUM_TIMERS];

  rand uint prescale[NUM_HARTS];
  rand uint step[NUM_HARTS];
  rand uint ticks[NUM_HARTS];

  bit    smoke_test;
  uint64 max_clks_until_expiry = 5_000;
  uint   max_prescale;
  uint   max_step;

  `uvm_object_utils(rv_timer_rst_safe_config_parameters)

  function new(string name = "");
    super.new(name);
  endfunction
endclass : rv_timer_rst_safe_config_parameters

class rv_timer_rand_rst_safe_base_vseq extends cip_rand_rst_safe_base_vseq #(
    .RAL_T               (rv_timer_reg_block),
    .CFG_T               (rv_timer_env_cfg),
    .COV_T               (rv_timer_env_cov),
    .VIRTUAL_SEQUENCER_T (rv_timer_rst_safe_virtual_sequencer),
    .TEST_PARAMS_T       (rv_timer_rst_safe_test_seq_parameters),
    .CONFIG_PARAMS_T     (rv_timer_rst_safe_config_parameters)
  );
  `uvm_object_utils(rv_timer_rand_rst_safe_base_vseq)

  // random delay between consecutive transactions
  rand uint delay;

  constraint delay_c {
    delay dist {
      0                   :/ 1,
      [1      :100]       :/ 1,
      [101    :10_000]    :/ 8,
      [10_001 :1_000_000] :/ 1
    };
  }

  bit [TL_DW-1:0] max_prescale;
  bit [TL_DW-1:0] max_step;

  constraint rand_reset_delay_c {
    rand_reset_delay dist {
      [1 : 1000]              :/ 2,
      [1001 : 100_000]        :/ 7,
      [100_001 : 1_000_000]   :/ 1
    };
  }

  extern function new(string name = "");
  extern function void pre_randomize();
  extern virtual task post_start();
  extern virtual task reset_trigger_thread();
  extern virtual task main_thread();
  extern virtual function void handle_reset_assertion();
  extern virtual task dut_init();
  extern virtual task cfg_timer(int hart = 0, int timer = 0, bit enable = 1'b1);
  extern virtual task cfg_hart(int hart = 0, int prescale = 1, int step = 1);
  extern virtual task set_timer_val(int hart = 0, bit [63:0] val);
  extern virtual task set_compare_val(int hart = 0, int timer = 0, bit [63:0] val);
  extern virtual task cfg_interrupt(int hart = 0, int timer = 0, bit enable = 1'b1);
  extern virtual task clear_intr_state(int hart = 0, int timer = 0);
  extern virtual task intr_state_spinwait(input int  hart              = 0,
                                          input uint exp_data          = 0,
                                          input uint spinwait_delay_ns = 0,
                                          input uint timeout_ns        = 10_000_000);
  extern virtual task read_intr_status_reg(input int hart = 0, output uint status_val);
  extern virtual task read_timer_val_reg(input int hart = 0, output uint64 mtime_val);
endclass : rv_timer_rand_rst_safe_base_vseq

function rv_timer_rand_rst_safe_base_vseq::new(string name = "");
  super.new(name);
endfunction : new

function void rv_timer_rand_rst_safe_base_vseq::pre_randomize();
  super.pre_randomize();
  if (p_sequencer != null) begin
    max_prescale = (1 << p_sequencer.cfg.ral.cfg0.prescale.get_n_bits()) - 1;
    max_step = (1 << p_sequencer.cfg.ral.cfg0.step.get_n_bits()) - 1;
  end
endfunction : pre_randomize

task rv_timer_rand_rst_safe_base_vseq::post_start();
  // rst_safe: keep RV timer CSR traffic inside main_thread(), where reset kills are controlled.
  do_clear_all_interrupts = 1'b0;
  super.post_start();
endtask : post_start

task rv_timer_rand_rst_safe_base_vseq::reset_trigger_thread();
  reset_seq rst_seq;
  delay_seq del_seq;

  del_seq = delay_seq::type_id::create("del_seq:reset_trigger");
  del_seq.delay_time_steps = rand_reset_delay;
  del_seq.start(p_sequencer.delay_sequencer_h);

  `uvm_info(`gfn, "Triggering reset", UVM_MEDIUM)
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

task rv_timer_rand_rst_safe_base_vseq::main_thread();
  `uvm_fatal(`gfn, "Derived reset-safe sequence must implement main_thread()")
endtask : main_thread

function void rv_timer_rand_rst_safe_base_vseq::handle_reset_assertion();
  `uvm_info(`gfn, "Reset Assertion - Elements that need to be reset at a seq level", UVM_LOW)
  super.handle_reset_assertion();
endfunction : handle_reset_assertion

task rv_timer_rand_rst_safe_base_vseq::dut_init();
endtask : dut_init

task rv_timer_rand_rst_safe_base_vseq::cfg_timer(int hart = 0, int timer = 0,
                                                 bit enable = 1'b1);
  uvm_reg       ctrl_rg;
  uvm_reg_field active_fld;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  `DV_CHECK_LT_FATAL(timer, NUM_TIMERS)
  ctrl_rg = ral.get_reg_by_name($sformatf("ctrl"));
  `DV_CHECK_NE_FATAL(ctrl_rg, null)
  active_fld = ctrl_rg.get_field_by_name($sformatf("active_%0d", timer));
  `DV_CHECK_NE_FATAL(active_fld, null)
  active_fld.set(enable);
  csr_update(.csr(ctrl_rg), .blocking(1));
endtask : cfg_timer

task rv_timer_rand_rst_safe_base_vseq::cfg_hart(int hart = 0, int prescale = 1, int step = 1);
  uvm_reg hart_cfg_rg;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  `DV_CHECK_LE_FATAL(prescale, max_prescale)
  `DV_CHECK_LE_FATAL(step, max_step)
  hart_cfg_rg = ral.get_reg_by_name($sformatf("cfg%0d", hart));
  `DV_CHECK_NE_FATAL(hart_cfg_rg, null)
  hart_cfg_rg.get_field_by_name("prescale").set(prescale);
  hart_cfg_rg.get_field_by_name("step").set(step);
  csr_update(.csr(hart_cfg_rg), .blocking(1));
endtask : cfg_hart

task rv_timer_rand_rst_safe_base_vseq::set_timer_val(int hart = 0, bit [63:0] val);
  uvm_reg timer_val_l_rg;
  uvm_reg timer_val_u_rg;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  timer_val_l_rg = ral.get_reg_by_name($sformatf("timer_v_lower%0d", hart));
  timer_val_u_rg = ral.get_reg_by_name($sformatf("timer_v_upper%0d", hart));
  `DV_CHECK_NE_FATAL(timer_val_l_rg, null)
  `DV_CHECK_NE_FATAL(timer_val_u_rg, null)
  timer_val_l_rg.set(val[31:0]);
  timer_val_u_rg.set(val[63:32]);
  csr_update(.csr(timer_val_l_rg), .blocking(1));
  csr_update(.csr(timer_val_u_rg), .blocking(1));
endtask : set_timer_val

task rv_timer_rand_rst_safe_base_vseq::set_compare_val(int hart = 0, int timer = 0,
                                                       bit [63:0] val);
  uvm_reg compare_val_l_rg;
  uvm_reg compare_val_u_rg;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  `DV_CHECK_LT_FATAL(timer, NUM_TIMERS)
  compare_val_l_rg = ral.get_reg_by_name($sformatf("compare_lower%0d_%0d", hart, timer));
  compare_val_u_rg = ral.get_reg_by_name($sformatf("compare_upper%0d_%0d", hart, timer));
  `DV_CHECK_NE_FATAL(compare_val_l_rg, null)
  `DV_CHECK_NE_FATAL(compare_val_u_rg, null)
  compare_val_l_rg.set(val[31:0]);
  compare_val_u_rg.set(val[63:32]);
  csr_update(.csr(compare_val_l_rg), .blocking(1));
  csr_update(.csr(compare_val_u_rg), .blocking(1));
endtask : set_compare_val

task rv_timer_rand_rst_safe_base_vseq::cfg_interrupt(int hart = 0, int timer = 0,
                                                     bit enable = 1'b1);
  uvm_reg       intr_en_rg;
  uvm_reg_field timer_intr_en_fld;
  int           intr_pin_idx = hart * NUM_TIMERS + timer;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  `DV_CHECK_LT_FATAL(timer, NUM_TIMERS)
  intr_en_rg = ral.get_reg_by_name($sformatf("intr_enable%0d", hart));
  `DV_CHECK_NE_FATAL(intr_en_rg, null)
  timer_intr_en_fld = intr_en_rg.get_field_by_name($sformatf("ie_%0d", timer));
  `DV_CHECK_NE_FATAL(timer_intr_en_fld, null)
  timer_intr_en_fld.set(enable);
  csr_update(.csr(intr_en_rg), .blocking(1));
  if (!enable && !cfg.under_reset) begin
    `DV_CHECK_EQ(cfg.intr_vif.sample_pin(.idx(intr_pin_idx)), 1'b0)
  end
endtask : cfg_interrupt

task rv_timer_rand_rst_safe_base_vseq::clear_intr_state(int hart = 0, int timer = 0);
  uvm_reg         intr_state_rg;
  bit [TL_DW-1:0] status;
  bit [TL_DW-1:0] wr_value;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  `DV_CHECK_LT_FATAL(timer, NUM_TIMERS)
  intr_state_rg = ral.get_reg_by_name($sformatf("intr_state%0d", hart));
  `DV_CHECK_NE_FATAL(intr_state_rg, null)

  if ($urandom_range(0, 1)) begin
    wr_value = 1 << timer;
    csr_wr(.ptr(intr_state_rg), .value(wr_value), .blocking(1));
  end else begin
    wr_value = $urandom();
    set_compare_val(hart, timer, wr_value);
    cfg.clk_rst_vif.wait_clks_or_rst(1);
  end
  csr_rd(.ptr(intr_state_rg), .value(status), .blocking(1));
endtask : clear_intr_state

task rv_timer_rand_rst_safe_base_vseq::intr_state_spinwait(
                                                       input int  hart              = 0,
                                                       input uint exp_data          = 0,
                                                       input uint spinwait_delay_ns = 0,
                                                       input uint timeout_ns        = 10_000_000);
  bit [TL_DW-1:0] read_data;
  uint            spinwait_delay_clks;
  uvm_reg intr_state_rg;

  intr_state_rg = ral.get_reg_by_name($sformatf("intr_state%0d", hart));
  `DV_CHECK_NE_FATAL(intr_state_rg, null)

  if (spinwait_delay_ns != 0) begin
    spinwait_delay_clks = ((spinwait_delay_ns * 1000) + cfg.clk_rst_vif.clk_period_ps - 1) /
                          cfg.clk_rst_vif.clk_period_ps;
  end
  if (spinwait_delay_clks < 2) spinwait_delay_clks = 2;

  fork
    begin : isolation_fork
      fork
        while (1) begin
          delay_seq del_seq;

          csr_rd(.ptr(intr_state_rg), .value(read_data), .blocking(1));
          if (read_data == exp_data) break;

          del_seq = delay_seq::type_id::create("del_seq:intr_state_spinwait");
          del_seq.delay_time_steps = spinwait_delay_clks;
          del_seq.start(p_sequencer.delay_sequencer_h);
        end
        begin
          `DV_WAIT_TIMEOUT(timeout_ns, "intr_state_spinwait",
                           $sformatf("timeout %0s (addr=0x%0h) == 0x%0h",
                           intr_state_rg.get_full_name(), intr_state_rg.get_address(), exp_data))
        end
      join_any
      disable fork;
    end : isolation_fork
  join
endtask : intr_state_spinwait

task rv_timer_rand_rst_safe_base_vseq::read_intr_status_reg(input int hart = 0,
                                                            output uint status_val);
  uvm_reg intr_state_rg;

  intr_state_rg = ral.get_reg_by_name($sformatf("intr_state%0d", hart));
  `DV_CHECK_NE_FATAL(intr_state_rg, null)
  csr_rd(.ptr(intr_state_rg), .value(status_val), .blocking(1));
endtask : read_intr_status_reg

task rv_timer_rand_rst_safe_base_vseq::read_timer_val_reg(input int hart = 0,
                                                          output uint64 mtime_val);
  bit [TL_DW-1:0] data;
  uvm_reg timer_val_l_rg;
  uvm_reg timer_val_u_rg;

  `DV_CHECK_LT_FATAL(hart, NUM_HARTS)
  timer_val_l_rg = ral.get_reg_by_name($sformatf("timer_v_lower%0d", hart));
  timer_val_u_rg = ral.get_reg_by_name($sformatf("timer_v_upper%0d", hart));
  `DV_CHECK_NE_FATAL(timer_val_l_rg, null)
  `DV_CHECK_NE_FATAL(timer_val_u_rg, null)

  csr_rd(.ptr(timer_val_u_rg), .value(data), .blocking(1));
  mtime_val[63:32] = data;
  csr_rd(.ptr(timer_val_l_rg), .value(data), .blocking(1));
  mtime_val[31:0] = data;
endtask : read_timer_val_reg
