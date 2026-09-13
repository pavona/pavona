# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base TileLink host sequence helpers."""

from typing import Optional

from dv_lib.dv_base_seq import dv_base_seq
from pyuvm import uvm_sequence_item

from ..tl_agent_cfg import tl_agent_cfg
from ..tl_seq_item import SourceWidth, tl_seq_item
from ..tl_sequencer import tl_sequencer


class tl_host_base_seq(dv_base_seq[tl_sequencer, tl_agent_cfg, tl_seq_item,
                                   tl_seq_item]):
    """Provide late a_source assignment and response bookkeeping."""

    def __init__(self, name: str = "tl_host_base_seq"):
        super().__init__(name)
        self.cfg: Optional[tl_agent_cfg] = None
        self.override_a_source_val: bool = False
        self.overridden_a_source_val: int = 0

    def get_cfg(self,
                item: Optional[uvm_sequence_item] = None) -> tl_agent_cfg:
        if self.cfg is not None:
            return self.cfg
        sequencer = getattr(
            self, "sequencer",
            None) or (item.get_sequencer() if item is not None else None)
        if sequencer is None or getattr(sequencer, "cfg", None) is None:
            self.uvm_report.fatal("TL_HOST_BASE_SEQ",
                                  "tl_host_base_seq requires sequencer.cfg")
        self.cfg = sequencer.cfg
        return self.cfg

    async def finish_item(self,
                          item: uvm_sequence_item,
                          set_priority: int = -1):
        req = item
        cfg = self.get_cfg(req)
        if self.override_a_source_val:
            req.a_source = int(self.overridden_a_source_val) & (
                (1 << SourceWidth) - 1)
            cfg.add_to_a_source_pend_q(req.a_source)
        else:
            cfg.randomize_a_source_in_req(req)
        await super().finish_item(item)

    async def get_base_response(self, transaction_id: Optional[int] = None):
        if transaction_id is None:
            sequencer = getattr(self, "sequencer", None)
            if sequencer is None:
                self.uvm_report.fatal(
                    "TL_HOST_BASE_SEQ",
                    "tl_host_base_seq requires an active sequencer")
            rsp = await sequencer.get_response(None)
        else:
            rsp = await self.get_response(transaction_id=transaction_id)
        cfg = self.get_cfg(rsp)
        cfg.remove_from_a_source_pend_q(rsp.d_source)
        return rsp
