// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_lock_range_with_rand_reset_test_seq_parameters
    extends ac_range_check_base_test_seq_parameters;
  `uvm_object_utils(ac_range_check_lock_range_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
    do_ac_range_check_init = 1'b0;
  endfunction : new
endclass : ac_range_check_lock_range_with_rand_reset_test_seq_parameters

class ac_range_check_lock_range_config_parameters
    extends ac_range_check_base_config_parameters;
  import ac_range_check_reg_pkg::*;
  `uvm_object_utils(ac_range_check_lock_range_config_parameters)

  rand bit [DataWidth-1:0] base[NUM_RANGES];
  rand bit [DataWidth-1:0] limit[NUM_RANGES];
  rand bit                 read_perm[NUM_RANGES];
  rand bit                 write_perm[NUM_RANGES];
  rand bit                 execute_perm[NUM_RANGES];

  rand bit [DataWidth-1:0] base_new[NUM_RANGES];
  rand bit [DataWidth-1:0] limit_new[NUM_RANGES];
  rand bit                 read_perm_new[NUM_RANGES];
  rand bit                 write_perm_new[NUM_RANGES];
  rand bit                 execute_perm_new[NUM_RANGES];

  rand bit [NUM_RANGES-1:0] lock_mask;
  rand bit [NUM_RANGES-1:0] enable;
  rand bit [NUM_RANGES-1:0] enable_new;
  rand bit [NUM_RANGES-1:0] log_denied_access;
  rand bit [NUM_RANGES-1:0] log_denied_access_new;
  rand int unsigned         reprogram_delay_clks;

  constraint addr_pairs_c {
    foreach (base[i]) {
      base[i][3:0]      == 0;
      limit[i][3:0]     == 0;
      base_new[i][3:0]  == 0;
      limit_new[i][3:0] == 0;

      (limit[i] - base[i]) inside {[32'h100:32'h200]};
      (limit_new[i] - base_new[i]) inside {[32'h100:32'h200]};
      base[i] < limit[i];
      base_new[i] < limit_new[i];

      if (i == (NUM_RANGES-1)) {
        enable[i]     == 1;
        lock_mask[i]  == 1;
        write_perm[i] == 1;
      }
    }
  }

  constraint mask_c {
    lock_mask  != 0;
    enable     != 0;
    enable_new != 0;
  }

  constraint reprogram_delay_clks_c {
    reprogram_delay_clks inside {[0:100]};
  }

  function new(string name = "");
    super.new(name);
  endfunction : new

  function void set_lock_fields_rand_mode(bit enable_rand);
    base.rand_mode(enable_rand);
    limit.rand_mode(enable_rand);
    read_perm.rand_mode(enable_rand);
    write_perm.rand_mode(enable_rand);
    execute_perm.rand_mode(enable_rand);
    base_new.rand_mode(enable_rand);
    limit_new.rand_mode(enable_rand);
    read_perm_new.rand_mode(enable_rand);
    write_perm_new.rand_mode(enable_rand);
    execute_perm_new.rand_mode(enable_rand);
    lock_mask.rand_mode(enable_rand);
    enable.rand_mode(enable_rand);
    enable_new.rand_mode(enable_rand);
    log_denied_access.rand_mode(enable_rand);
    log_denied_access_new.rand_mode(enable_rand);
    reprogram_delay_clks.rand_mode(enable_rand);
  endfunction : set_lock_fields_rand_mode
endclass : ac_range_check_lock_range_config_parameters

class ac_range_check_rst_safe_lock_range_with_rand_reset_vseq
    extends ac_range_check_rand_rst_safe_base_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_lock_range_with_rand_reset_vseq)

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task main_thread();
endclass : ac_range_check_rst_safe_lock_range_with_rand_reset_vseq

function ac_range_check_rst_safe_lock_range_with_rand_reset_vseq::new(
    string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_lock_range_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params =
        ac_range_check_lock_range_with_rand_reset_test_seq_parameters::type_id::create(
            "test_params");
  end
  if (config_params == null) begin
    config_params =
        ac_range_check_lock_range_config_parameters::type_id::create(
            "config_params");
  end
  super.body();
endtask : body

task ac_range_check_rst_safe_lock_range_with_rand_reset_vseq::main_thread();
  ac_range_check_lock_range_config_parameters lock_cfg;
  bit reprogram_done = 1'b0;

  if (!$cast(lock_cfg, config_params)) begin
    `uvm_fatal(`gfn, $sformatf("Unexpected lock-range configuration type %s",
                               config_params.get_type_name()))
  end

  `uvm_info(`gfn, "Starting reset-safe lock-range stimulus", UVM_LOW)

  // A random-reset restart reuses the parameter object, so explicitly re-enable
  // the lock fields before choosing the configuration for this pass.
  lock_cfg.set_lock_fields_rand_mode(1'b1);
  `DV_CHECK_RANDOMIZE_FATAL(lock_cfg)
  lock_cfg.set_lock_fields_rand_mode(1'b0);

  foreach (lock_cfg.base[i]) begin
    configure_range(i, lock_cfg.base[i], lock_cfg.limit[i], lock_cfg.read_perm[i],
                    lock_cfg.write_perm[i], lock_cfg.execute_perm[i], lock_cfg.enable[i],
                    lock_cfg.log_denied_access[i]);
  end

  foreach (lock_cfg.lock_mask[i]) begin
    if (lock_cfg.lock_mask[i]) begin
      `uvm_info(`gfn, $sformatf("Range index %0d locked", i), UVM_MEDIUM)
      ral.range_regwen[i].set(32'h0);
      csr_update(.csr(ral.range_regwen[i]));
    end else begin
      `uvm_info(`gfn, $sformatf("Range index %0d unlocked", i), UVM_MEDIUM)
    end

    // TODO(#27352): Move this sampling to the scoreboard after its
    // range_regwen write handling has been corrected.
    if (cfg.en_cov) begin
      cov.sample_range_lock_cg(i, lock_cfg.enable[i], lock_cfg.lock_mask[i]);
      cov.sample_lock_logging_cg(i, lock_cfg.log_denied_access[i],
                                 lock_cfg.lock_mask[i]);
    end
  end

  fork
    begin : traffic_thread
      while (!reprogram_done) begin
        `DV_CHECK_RANDOMIZE_FATAL(lock_cfg)
        send_single_tl_unfilt_tr(1'b0);
      end
    end

    begin : reprogram_thread
      delay_seq del_seq;

      del_seq = delay_seq::type_id::create("del_seq");
      del_seq.delay_time_steps = lock_cfg.reprogram_delay_clks;
      del_seq.start(p_sequencer.delay_sequencer_h);

      foreach (lock_cfg.base_new[i]) begin
        `uvm_info(`gfn, $sformatf("Attempting to reprogram range index %0d", i), UVM_MEDIUM)
        if (lock_cfg.lock_mask[i]) begin
          int unsigned lsb;
          bit [MuBi4Width-1:0] mubi4_execute;
          bit [MuBi4Width-1:0] mubi4_write;
          bit [MuBi4Width-1:0] mubi4_read;
          bit [MuBi4Width-1:0] mubi4_enable;
          bit [MuBi4Width-1:0] mubi4_log_denied;
          bit [DataWidth-1:0]  mubi4_attr;

          mubi4_execute = mubi4_bool_to_mubi(lock_cfg.execute_perm_new[i]);
          mubi4_write = mubi4_bool_to_mubi(lock_cfg.write_perm_new[i]);
          mubi4_read = mubi4_bool_to_mubi(lock_cfg.read_perm_new[i]);
          mubi4_enable = mubi4_bool_to_mubi(lock_cfg.enable_new[i]);
          mubi4_log_denied = mubi4_bool_to_mubi(lock_cfg.log_denied_access_new[i]);

          mubi4_attr = 0;
          lsb = ral.range_attr[i].log_denied_access.get_lsb_pos();
          mubi4_attr |= mubi4_log_denied << lsb;
          lsb = ral.range_attr[i].execute_access.get_lsb_pos();
          mubi4_attr |= mubi4_execute << lsb;
          lsb = ral.range_attr[i].write_access.get_lsb_pos();
          mubi4_attr |= mubi4_write << lsb;
          lsb = ral.range_attr[i].read_access.get_lsb_pos();
          mubi4_attr |= mubi4_read << lsb;
          lsb = ral.range_attr[i].enable.get_lsb_pos();
          mubi4_attr |= mubi4_enable << lsb;

          csr_wr(.ptr(ral.range_base[i]), .value(lock_cfg.base_new[i]));
          csr_wr(.ptr(ral.range_limit[i]), .value(lock_cfg.limit_new[i]));
          csr_wr(.ptr(ral.range_attr[i]), .value(mubi4_attr));
        end else begin
          configure_range(i, lock_cfg.base_new[i], lock_cfg.limit_new[i],
                          lock_cfg.read_perm_new[i], lock_cfg.write_perm_new[i],
                          lock_cfg.execute_perm_new[i], lock_cfg.enable_new[i],
                          lock_cfg.log_denied_access_new[i]);
        end
      end
      reprogram_done = 1'b1;
    end
  join

  foreach (lock_cfg.base[i]) begin
    uvm_reg_data_t act_base;
    uvm_reg_data_t act_limit;
    uvm_reg_data_t act_attr;

    csr_rd(.ptr(ral.range_base[i]), .value(act_base));
    csr_rd(.ptr(ral.range_limit[i]), .value(act_limit));
    csr_rd(.ptr(ral.range_attr[i]), .value(act_attr));

    `uvm_info(`gfn,
              $sformatf("Range %0d readback: base=0x%0h limit=0x%0h attr=0x%0h",
                        i, act_base, act_limit, act_attr),
              UVM_MEDIUM)

    if (i == (NUM_RANGES-1)) begin
      lock_cfg.tl_main_vars.addr = lock_cfg.base[i];
      lock_cfg.tl_main_vars.write = 1'b1;
      send_single_tl_unfilt_tr(1'b0);
    end
  end
endtask : main_thread
