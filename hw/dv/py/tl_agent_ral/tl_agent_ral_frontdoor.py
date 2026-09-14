# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Frontdoor helpers for issuing register accesses over the TL host agent."""

from __future__ import annotations

import logging
from typing import Tuple

from cocotb.triggers import with_timeout
from pyral import UVM_PREDICT, uvm_reg
from pyuvm import UVM_MEDIUM, uvm_reporter
from tl_agent.tl_reg_adapter import tl_reg_adapter, tl_reg_bus_op
from tl_agent.tl_seq_item import MaskWidth

from .seq_lib.tl_agent_ral_access_seq import tl_agent_ral_access_seq


class tl_agent_ral_frontdoor:
    """Execute simple register accesses via the TL host sequencer."""

    def __init__(self, host_seqr, adapter: tl_reg_adapter | None = None):
        self.host_seqr = host_seqr
        self.adapter = adapter or tl_reg_adapter()
        self.report_id = type(self).__name__
        logger = getattr(self.host_seqr, "logger", None) or logging.getLogger(
            type(self).__name__)
        verbosity = int(getattr(self.host_seqr, "uvm_verbosity", UVM_MEDIUM))
        self.uvm_report = uvm_reporter(logger, verbosity)

    async def write_reg(self, reg: uvm_reg, value: int, reg_map=None) -> str:
        rw = tl_reg_bus_op(
            kind="WRITE",
            addr=reg.get_address(reg_map),
            data=value,
            byte_en=(1 << MaskWidth) - 1,
        )
        self.uvm_report.info(
            self.report_id,
            f"write_reg start reg={reg.get_name()} addr=0x{rw.addr:x} data=0x{int(value):x}",
            UVM_MEDIUM,
        )
        rsp, rw = await self._access(rw)
        if bool(getattr(rsp, "d_error", False)):
            rw.status = "NOT_OK"
        if rw.status == "IS_OK":
            reg.predict(value, UVM_PREDICT.WRITE)
        self.uvm_report.info(
            self.report_id,
            f"write_reg done reg={reg.get_name()} status={rw.status}",
            UVM_MEDIUM,
        )
        return rw.status

    async def read_reg(self, reg: uvm_reg, reg_map=None) -> Tuple[str, int]:
        rw = tl_reg_bus_op(
            kind="READ",
            addr=reg.get_address(reg_map),
            data=0,
            byte_en=(1 << MaskWidth) - 1,
        )
        self.uvm_report.info(
            self.report_id,
            f"read_reg start reg={reg.get_name()} addr=0x{rw.addr:x}",
            UVM_MEDIUM,
        )
        rsp, rw = await self._access(rw)
        if bool(getattr(rsp, "d_error", False)):
            rw.status = "NOT_OK"
        if rw.status == "IS_OK":
            reg.predict(rw.data, UVM_PREDICT.READ)
        self.uvm_report.info(
            self.report_id,
            f"read_reg done reg={reg.get_name()} status={rw.status} data=0x{int(rw.data):x}",
            UVM_MEDIUM,
        )
        return rw.status, int(rw.data)

    async def _access(self, rw: tl_reg_bus_op):
        bus_req = self.adapter.reg2bus(rw)
        seq = tl_agent_ral_access_seq("tl_agent_ral_frontdoor_seq")
        seq.write = str(rw.kind).upper() == "WRITE"
        seq.addr = int(bus_req.a_addr)
        seq.mask = int(bus_req.a_mask)
        seq.data = int(getattr(bus_req, "a_data", 0))
        self.uvm_report.info(
            self.report_id,
            f"_access launch kind={rw.kind} addr=0x{int(seq.addr):x} "
            f"mask=0x{int(seq.mask):x} data=0x{int(seq.data):x}",
            UVM_MEDIUM,
        )
        await with_timeout(seq.start(self.host_seqr), 20, "us")
        rsp = seq.rsp
        if rsp is None:
            self.uvm_report.fatal(self.report_id,
                                  "host sequence did not return a response")
        self.adapter.bus2reg(rsp, rw)
        self.uvm_report.info(
            self.report_id,
            f"_access rsp kind={rw.kind} d_error={int(bool(getattr(rsp, 'd_error', False)))} "
            f"data=0x{int(rw.data):x} status={rw.status}",
            UVM_MEDIUM,
        )
        return rsp, rw
