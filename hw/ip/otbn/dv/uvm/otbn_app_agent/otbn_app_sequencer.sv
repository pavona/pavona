// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otbn_app_sequencer extends dv_base_sequencer #(
  .ITEM_T (otbn_app_item),
  .CFG_T  (otbn_app_agent_cfg)
);
  `uvm_component_param_utils(otbn_app_sequencer)
  `uvm_component_new

endclass
