// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Config for the wide (64-bit) DMA host64 TileLink agent: a `tl_agent_cfg`
// specialization that swaps in the wide `dma_tl_if`.
class dma_tl_agent_cfg extends tl_agent_cfg;

  // Wide virtual interface (the parent's 32-bit `tl_if vif` is left unused).
  virtual dma_tl_if dma_vif;

  // When set, the monitor checks the inbound command integrity in `a_user.cmd_intg` against
  // `dma_tlul_pkg::dma_get_cmd_intg()` and `uvm_error`s on a mismatch. Runtime-controllable: a
  // command-integrity fault-injection (negative) test that intentionally corrupts `cmd_intg` must
  // clear this (e.g. via `dma_base_vseq::set_check_cmd_intg(0)`) to avoid a false monitor failure.
  // The monitor honors this knob at `dma_tl_monitor::check_a_channel`.
  bit check_cmd_intg = 1'b1;

  `uvm_object_utils_begin(dma_tl_agent_cfg)
    `uvm_field_int(check_cmd_intg, UVM_DEFAULT)
  `uvm_object_utils_end

  `uvm_object_new

endclass : dma_tl_agent_cfg
