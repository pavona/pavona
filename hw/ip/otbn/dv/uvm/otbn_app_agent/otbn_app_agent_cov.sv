// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otbn_app_agent_cov extends dv_base_agent_cov #(otbn_app_agent_cfg);
  `uvm_component_utils(otbn_app_agent_cov)

  // covergroups

  function new(string name, uvm_component parent);
    super.new(name, parent);
    // instantiate all covergroups here
  endfunction : new

endclass
