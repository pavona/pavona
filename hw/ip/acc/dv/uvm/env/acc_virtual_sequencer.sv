// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_virtual_sequencer extends cip_base_virtual_sequencer #(
    .CFG_T(acc_env_cfg),
    .COV_T(acc_env_cov)
  );
  `uvm_component_utils(acc_virtual_sequencer)
  `uvm_component_new

  key_sideload_sequencer#(keymgr_pkg::acc_key_req_t) key_sideload_sequencer_h;
  acc_app_sequencer acc_app_sequencer_h;

endclass
