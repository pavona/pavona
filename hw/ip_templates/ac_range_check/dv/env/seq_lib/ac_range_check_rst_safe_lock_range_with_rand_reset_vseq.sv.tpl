// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// High-level goal
// ---------------
// - Exercise the AC_RANGE_CHECK range-locking feature under live traffic and random reset.
// - Confirm that clearing RANGE_REGWEN for a range makes later writes to that range ineffective,
//   while unlocked ranges continue to accept reprogramming.
// - Confirm that reset removes the locks and that a restarted operation has no stale sequence or
//   DUT state from the interrupted pass.
//
// Test flow for every main-thread pass
// ------------------------------------
// 1. Configure every range with an initial set of values.
// 2. Lock a randomized nonempty subset by clearing the corresponding RANGE_REGWEN fields.
// 3. Run live unfiltered TLUL traffic while attempting to reprogram every range after a randomized
//    delay. Locked ranges receive direct CSR writes; unlocked ranges use normal configuration.
// 4. Read every range back so the scoreboard checks that locked values stayed unchanged and
//    unlocked values changed. Send one guaranteed-granted transaction required by the existing DV
//    end-of-test check.
//
// Reset may terminate any of these steps. The common reset-safe lifecycle discards that pass and
// starts main_thread() again after reset. The final pass must complete all four steps.

class ${module_instance_name}_lock_range_with_rand_reset_test_seq_parameters
    extends ${module_instance_name}_base_test_seq_parameters;
  `uvm_object_utils(${module_instance_name}_lock_range_with_rand_reset_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops inside {[2:4]};
  }

  function new(string name = "");
    super.new(name);
    do_${module_instance_name}_init = 1'b0;
  endfunction : new
endclass : ${module_instance_name}_lock_range_with_rand_reset_test_seq_parameters

class ${module_instance_name}_lock_range_config_parameters
    extends ${module_instance_name}_base_config_parameters;
  import ${module_instance_name}_reg_pkg::*;
  `uvm_object_utils(${module_instance_name}_lock_range_config_parameters)

  // Initial values programmed before locking.
  rand bit [DataWidth-1:0] base[NUM_RANGES];
  rand bit [DataWidth-1:0] limit[NUM_RANGES];
  rand bit                 read_perm[NUM_RANGES];
  rand bit                 write_perm[NUM_RANGES];
  rand bit                 execute_perm[NUM_RANGES];

  // Second values used for the reprogramming attempt.
  rand bit [DataWidth-1:0] base_new[NUM_RANGES];
  rand bit [DataWidth-1:0] limit_new[NUM_RANGES];
  rand bit                 read_perm_new[NUM_RANGES];
  rand bit                 write_perm_new[NUM_RANGES];
  rand bit                 execute_perm_new[NUM_RANGES];

  // Per-range lock, enable, and logging choices for the initial and replacement configurations.
  rand bit [NUM_RANGES-1:0] lock_mask;
  rand bit [NUM_RANGES-1:0] enable;
  rand bit [NUM_RANGES-1:0] enable_new;
  rand bit [NUM_RANGES-1:0] log_denied_access;
  rand bit [NUM_RANGES-1:0] log_denied_access_new;
  // Delay in clock cycles before the reprogramming attempt begins.
  rand int unsigned         reprogram_delay_clks;

  constraint addr_pairs_c {
    foreach (base[i]) {
      // Use aligned, forward ranges of bounded size for both configurations.
      base[i][3:0]      == 0;
      limit[i][3:0]     == 0;
      base_new[i][3:0]  == 0;
      limit_new[i][3:0] == 0;

      (limit[i] - base[i]) inside {[32'h100:32'h200]};
      (limit_new[i] - base_new[i]) inside {[32'h100:32'h200]};
      base[i] < limit[i];
      base_new[i] < limit_new[i];

      if (i == (NUM_RANGES-1)) {
        // The final range supplies a guaranteed-granted write required by the existing DV
        // end-of-test check. Locking it also guarantees every test exercises a locked range.
        enable[i]     == 1;
        lock_mask[i]  == 1;
        write_perm[i] == 1;
      }
    }
  }

  constraint mask_c {
    // Exercise at least one locked range and at least one enabled range in both configurations.
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
    // A reset restarts main_thread() with the same config object. Toggle all lock-test fields
    // together so each restarted pass can select a fresh, then stable, configuration.
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
endclass : ${module_instance_name}_lock_range_config_parameters

class ${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq
    extends ${module_instance_name}_rand_rst_safe_base_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq)

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task main_thread();
endclass : ${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq

function ${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq::new(
    string name = "");
  super.new(name);
endfunction : new

task ${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq::body();
  if (test_params == null) begin
    test_params =
        ${module_instance_name}_lock_range_with_rand_reset_test_seq_parameters::type_id::create(
            "test_params");
  end
  if (config_params == null) begin
    config_params =
        ${module_instance_name}_lock_range_config_parameters::type_id::create(
            "config_params");
  end
  super.body();
endtask : body

task ${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq::main_thread();
  ${module_instance_name}_lock_range_config_parameters lock_cfg;
  bit reprogram_done = 1'b0;

  if (!$cast(lock_cfg, config_params)) begin
    `uvm_fatal(`gfn, $sformatf("Unexpected lock-range configuration type %s",
                               config_params.get_type_name()))
  end

  `uvm_info(`gfn, "Starting reset-safe lock-range stimulus", UVM_LOW)

  // A random-reset restart reuses the parameter object, so explicitly re-enable the lock fields
  // before choosing the configuration for this pass.
  lock_cfg.set_lock_fields_rand_mode(1'b1);
  `DV_CHECK_RANDOMIZE_FATAL(lock_cfg)
  lock_cfg.set_lock_fields_rand_mode(1'b0);

  // Step 1: Program every range with its initial values.
  foreach (lock_cfg.base[i]) begin
    configure_range(i, lock_cfg.base[i], lock_cfg.limit[i], lock_cfg.read_perm[i],
                    lock_cfg.write_perm[i], lock_cfg.execute_perm[i], lock_cfg.enable[i],
                    lock_cfg.log_denied_access[i]);
  end

  // Step 2: Lock the selected ranges and retain the original coverage sampling behavior.
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

  // Step 3: Keep traffic active while the delayed reprogramming attempt executes. delay_seq owns
  // the timed wait so reset can terminate the complete main_thread() hierarchy cleanly.
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

          // RAL also knows that this range is locked, so field set/update calls would preserve the
          // old mirror and would not put the attempted replacement value on TL. Assemble the
          // complete attribute word and use direct csr_wr() calls to prove the DUT ignores writes
          // to the locked base, limit, and attribute registers.
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

  // Step 4: Read back every range. Normal CSR checking proves locked ranges retained the initial
  // values and unlocked ranges accepted the replacement values.
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
      // Satisfy the existing scoreboard requirement that the test observes at least one granted
      // transaction. The final range was constrained to make this write legal.
      lock_cfg.tl_main_vars.addr = lock_cfg.base[i];
      lock_cfg.tl_main_vars.write = 1'b1;
      send_single_tl_unfilt_tr(1'b0);
    end
  end
endtask : main_thread
