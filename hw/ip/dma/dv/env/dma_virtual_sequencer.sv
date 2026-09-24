// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dma_virtual_sequencer extends cip_base_virtual_sequencer #(
  .CFG_T(dma_env_cfg),
  .COV_T(dma_env_cov)
);

  // Device sequencer handles keyed by GLOBAL port index `p`, one per present host port. 32-bit
  // ports use `tl_sequencer`, 64-bit ports use `dma_tl_sequencer`. Keyed by `p` (not ASID) so two
  // ports may share an ASID without overwriting each other's sequencer handle.
  tl_sequencer     tl32_sequencer_h[int];
  dma_tl_sequencer tl64_sequencer_h[int];

`uvm_component_utils(dma_virtual_sequencer)
`uvm_component_new

endclass
