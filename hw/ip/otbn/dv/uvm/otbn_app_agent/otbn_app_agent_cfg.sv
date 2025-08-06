// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otbn_app_agent_cfg extends dv_base_agent_cfg;

  // interface handle used by driver, monitor & the sequencer, via cfg handle
  virtual otbn_app_intf vif;

  // Enable starting the device auto-response sequence by default if configured in Device mode.
  bit start_default_device_seq = 1;

  `uvm_object_utils_begin(otbn_app_agent_cfg)
    `uvm_field_int(start_default_device_seq, UVM_DEFAULT)
  `uvm_object_utils_end

  function new (string name = "otbn_app_agent_cfg");
    super.new(name);
  endfunction : new

endclass
