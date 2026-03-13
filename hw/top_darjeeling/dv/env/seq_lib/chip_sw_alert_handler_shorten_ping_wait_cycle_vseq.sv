// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class chip_sw_alert_handler_shorten_ping_wait_cycle_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_alert_handler_shorten_ping_wait_cycle_vseq)

  `uvm_object_new

  virtual task pre_start();
    // The wait-time between two ping requests is a 16-bit value, coming from an LFSR.
    // In DV, the wait-time can be overridden by using ping_timer's wait_cyc_mask_i input,
    // which is a right-aligned mask.
    //
    // The minimum-allowed value,7, is chosen here to use only the least-significant 3 bits of
    // the LFSR output as the wait-time between two ping requests.
    void'(cfg.chip_vif.signal_probe_alert_handler_ping_timer_wait_cyc_mask_i(SignalProbeForce, 7));
    super.pre_start();
  endtask

endclass
