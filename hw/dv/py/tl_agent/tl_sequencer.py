# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink sequencer with optional monitor-fed FIFOs."""

from typing import Optional

from dv_lib.dv_base_sequencer import dv_base_sequencer
from pyuvm import uvm_component

from .tl_agent_cfg import tl_agent_cfg
from .tl_seq_item import tl_seq_item

# dv_base_sequencer[ITEM_T, CFG_T, RSP_ITEM_T]
TL_ITEM_T = tl_seq_item
TL_CFG_T = tl_agent_cfg
TL_RSP_T = tl_seq_item


class tl_sequencer(dv_base_sequencer[TL_ITEM_T, TL_CFG_T, TL_RSP_T]):
    """TL sequencer with aliases for req/rsp analysis FIFOs."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.a_chan_req_fifo = None
        self.d_chan_rsp_fifo = None

    def build_phase(self):
        super().build_phase()
        # Monitor analysis ports require an export that implements write().
        # Use analysis FIFOs for monitor->sequencer channels.
        from pyuvm import uvm_tlm_analysis_fifo

        if hasattr(self.cfg, "has_req_fifo") and self.cfg.has_req_fifo:
            self.a_chan_req_fifo = uvm_tlm_analysis_fifo(
                "a_chan_req_fifo", self)
            self.req_analysis_fifo = self.a_chan_req_fifo
        else:
            self.a_chan_req_fifo = self.req_analysis_fifo

        if hasattr(self.cfg, "has_rsp_fifo") and self.cfg.has_rsp_fifo:
            self.d_chan_rsp_fifo = uvm_tlm_analysis_fifo(
                "d_chan_rsp_fifo", self)
            self.rsp_analysis_fifo = self.d_chan_rsp_fifo
        else:
            self.d_chan_rsp_fifo = self.rsp_analysis_fifo
