// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class soc_dbg_ctrl_misc_agent_cfg extends dv_base_agent_cfg;
  virtual soc_dbg_ctrl_misc_io_if vif;

  `uvm_object_utils(soc_dbg_ctrl_misc_agent_cfg)
  `uvm_object_new
endclass : soc_dbg_ctrl_misc_agent_cfg
