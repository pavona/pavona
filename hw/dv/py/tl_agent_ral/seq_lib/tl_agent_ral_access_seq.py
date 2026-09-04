# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Single-request TL access sequence used by the RAL frontdoor."""

from __future__ import annotations

from dv_lib.dv_base_seq import dv_base_seq
from pyuvm import UVM_MEDIUM
from tl_agent.tl_agent_cfg import tl_agent_cfg
from tl_agent.tl_seq_item import (AccessAck, AccessAckData, Get, PutFullData,
                                  PutPartialData, tl_seq_item)
from tl_agent.tl_sequencer import tl_sequencer


class tl_agent_ral_access_seq(dv_base_seq[tl_sequencer, tl_agent_cfg,
                                          tl_seq_item, tl_seq_item]):
    """Issue one explicit TL transaction and wait for its response."""

    def __init__(self, name: str = "tl_agent_ral_access_seq"):
        super().__init__(name)
        self.write: bool = False
        self.addr: int = 0
        self.mask: int = 0xF
        self.data: int = 0
        self.size: int = 2
        self.source: int = 0
        self.rsp: tl_seq_item | None = None

    async def body(self):
        req = tl_seq_item(f"{self.get_name()}_req")
        await self.start_item(req)
        req.a_addr = int(self.addr)
        req.a_mask = int(self.mask)
        req.a_data = int(self.data)
        req.a_size = int(self.size)
        req.a_source = int(self.source)
        req.a_param = 0
        req.a_user = 0
        req.a_opcode = Get if not self.write else (
            PutFullData if req.a_mask == 0xF else PutPartialData)
        self.uvm_report.info(
            "TL_AGENT_RAL_ACCESS_SEQ",
            f"send addr=0x{req.a_addr:x} data=0x{req.a_data:x} "
            f"mask=0x{req.a_mask:x} opcode={req.a_opcode}",
            UVM_MEDIUM,
        )
        await self.finish_item(req)

        self.rsp = await self.get_response()
        self.uvm_report.info(
            "TL_AGENT_RAL_ACCESS_SEQ",
            f"got rsp opcode={self.rsp.d_opcode} data=0x{int(self.rsp.d_data):x} "
            f"err={int(bool(self.rsp.d_error))}",
            UVM_MEDIUM,
        )
        if not self.write and self.rsp.d_opcode != AccessAckData:
            self.uvm_report.fatal("TL_AGENT_RAL_ACCESS_SEQ",
                                  "expected AccessAckData for read response")
        if self.write and self.rsp.d_opcode != AccessAck:
            self.uvm_report.fatal("TL_AGENT_RAL_ACCESS_SEQ",
                                  "expected AccessAck for write response")
