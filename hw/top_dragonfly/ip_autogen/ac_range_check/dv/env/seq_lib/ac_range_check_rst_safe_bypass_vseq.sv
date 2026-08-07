// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// High-level goal
// ---------------
// - Exercise the AC_RANGE_CHECK bypass feature.
// - Confirm that asserting the RANGE_CHECK_OVERWRITE interface puts the module in bypass mode and
//   makes it transparent to all TLUL transactions on the unfiltered interface.
// - Run live TLUL traffic while bypass is enabled to catch functional issues.
//
// Test flow
// ---------
// 1. Assert RANGE_CHECK_OVERWRITE before starting the inherited reset-safe smoke traffic.
// 2. Run the smoke sequence with randomized range and logging configuration. In bypass mode, those
//    range permissions must not prevent the unfiltered TLUL transactions from passing through.
// 3. Deassert RANGE_CHECK_OVERWRITE during shutdown so a later sequence does not inherit bypass.
//
// DV implementation note
// ----------------------
// AC_RANGE_CHECK can enter bypass only when the RANGE_CHECK_OVERWRITE pins carry a true MuBi value.
// These pins are represented by the TB miscellaneous interface and are currently driven through
// cfg.misc_vif; they are not controlled through a DUT CSR.

class ac_range_check_rst_safe_bypass_vseq
    extends ac_range_check_rst_safe_smoke_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_bypass_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
  extern virtual task dut_shutdown();
endclass : ac_range_check_rst_safe_bypass_vseq

function ac_range_check_rst_safe_bypass_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_bypass_vseq::main_thread();
  // Enable bypass before the inherited smoke sequence starts live TLUL traffic.
  cfg.misc_vif.set_range_check_overwrite(1'b1);
  super.main_thread();
endtask : main_thread

task ac_range_check_rst_safe_bypass_vseq::dut_shutdown();
  // RANGE_CHECK_OVERWRITE is a TB-driven input, so restore it explicitly after the test.
  cfg.misc_vif.set_range_check_overwrite(1'b0);
  super.dut_shutdown();
endtask : dut_shutdown
