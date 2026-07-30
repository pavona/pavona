// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Closes logging and interrupt boundary behavior with a monotonic deny counter.
class ac_range_check_rst_safe_log_intr_cov_vseq
    extends ac_range_check_rst_safe_cov_base_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_log_intr_cov_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
  extern virtual task set_log_config(bit enable, bit clear, int unsigned threshold);
  extern virtual task read_log_state();
endclass : ac_range_check_rst_safe_log_intr_cov_vseq

function ac_range_check_rst_safe_log_intr_cov_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_log_intr_cov_vseq::set_log_config(
    bit enable, bit clear, int unsigned threshold);
  uvm_reg_data_t value = '0;

  value |= enable << ral.log_config.log_enable.get_lsb_pos();
  value |= clear << ral.log_config.log_clear.get_lsb_pos();
  value |= threshold << ral.log_config.deny_cnt_threshold.get_lsb_pos();
  csr_wr(.ptr(ral.log_config), .value(value));
endtask : set_log_config

task ac_range_check_rst_safe_log_intr_cov_vseq::read_log_state();
  uvm_reg_data_t value;

  csr_rd(.ptr(ral.log_status), .value(value));
  csr_rd(.ptr(ral.log_address), .value(value));
  csr_rd(.ptr(ral.intr_state), .value(value));
endtask : read_log_state

task ac_range_check_rst_safe_log_intr_cov_vseq::main_thread();
  int unsigned thresholds[] = '{1, 2, 3, 4, 5, 128, 250, 251, 252, 253, 254, 255};
  int unsigned deny_count = 0;

  initialize_directed_inputs();
  start_filtered_responder();

  // Index zero increments the counter. Index one generates an equivalent
  // denial with range logging disabled, allowing the counter to hold.
  configure_fixed_range(0, MuBi4True, MuBi4False, MuBi4False, MuBi4False, MuBi4True);
  configure_fixed_range(1, MuBi4True, MuBi4False, MuBi4False, MuBi4False, MuBi4False);
  configure_fixed_range(2);
  ral.intr_enable.set(1'b1);
  csr_update(.csr(ral.intr_enable));
  set_log_config(1'b1, 1'b1, thresholds[0]);

  foreach (thresholds[i]) begin
    set_log_config(1'b1, 1'b0, thresholds[i]);
    while (deny_count < thresholds[i]) begin
      send_access(0, Read);
      deny_count++;
    end
    // Sample equality without changing the counter, then cross the boundary.
    send_access(1, Read);
    read_log_state();
    if (thresholds[i] != 255) begin
      send_access(0, Read);
      deny_count++;
      read_log_state();
    end
  end

  // Exercise logging disabled with an empty log at every nonzero low
  // threshold. This makes the closure deterministic rather than relying on
  // random smoke to supply the other low-threshold cross bins.
  for (int unsigned threshold = 1; threshold <= 5; threshold++) begin
    set_log_config(1'b0, 1'b1, threshold);
    send_access(0, Read);
    read_log_state();
  end

  // Leave one checked granted transfer in the scoreboard accounting. The
  // logging matrix intentionally filters every other datapath request.
  send_access(2, Read);
endtask : main_thread
