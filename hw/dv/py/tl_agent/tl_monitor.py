# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
TileLink interface monitor. Python translation of tl_monitor.sv (derived from dv_base_monitor).
"""

from typing import Any, Dict, Optional

import cocotb
from cocotb.triggers import Event, RisingEdge
from dv_lib.dv_base_monitor import dv_base_monitor
from pyuvm import UVM_DEBUG, uvm_analysis_port

from .tl_agent_cfg import tl_agent_cfg
from .tl_agent_cov import tl_agent_cov
from .tl_seq_item import TlSeqItemChannel, tl_seq_item

# dv_base_monitor[ITEM_T, REQ_ITEM_T, RSP_ITEM_T, CFG_T, COV_T]
TL_ITEM_T = tl_seq_item
TL_REQ_T = tl_seq_item
TL_RSP_T = tl_seq_item
TL_CFG_T = tl_agent_cfg
TL_COV_T = tl_agent_cov


class tl_monitor(dv_base_monitor[TL_ITEM_T, TL_REQ_T, TL_RSP_T, TL_CFG_T,
                                 TL_COV_T, ]):
    """TileLink monitor: samples A/D channels on clock edge, tracks pending requests."""

    def __init__(self, name: str, parent: Optional[Any] = None):
        super().__init__(name, parent)
        self.pending_a_req: Dict[int, tl_seq_item] = {}
        self.agent_name: str = name
        self._a_task = None
        self._d_task = None
        # Base monitor has analysis_port and notify() to write to that port
        # and run callbacks.
        # TL-specific ports below for A/D channel subscribers (e.g. scoreboard).
        self.a_chan_port: Optional[uvm_analysis_port] = None
        self.d_chan_port: Optional[uvm_analysis_port] = None

    def build_phase(self) -> None:
        super().build_phase()
        self.vif = self.cfg.vif
        if self.vif is None:
            self.uvm_report.fatal("TL_MONITOR",
                                  "cfg.vif must be set before build_phase")
        self.a_chan_port = uvm_analysis_port("a_chan_port", self)
        self.d_chan_port = uvm_analysis_port("d_chan_port", self)

    def reset_monitor(self) -> None:
        """Clear pending state when reset is asserted (called by base)."""
        self._sample_pending_req_on_reset()
        self.pending_a_req.clear()
        if self.cfg and hasattr(self.cfg, "a_source_pend_q"):
            self.cfg.a_source_pend_q.clear()

    async def collect_trans(self) -> None:
        """Spawn channel collector tasks and keep them alive until cancelled by base class."""
        a_task = cocotb.start_soon(self.check_a_channel())
        d_task = cocotb.start_soon(self.check_d_channel())

        stopper = Event()
        try:
            await stopper.wait()
        finally:
            for t in (a_task, d_task):
                if t is not None and not t.done():
                    t.cancel()

    async def check_a_channel(self) -> None:
        """A-channel collector loop."""
        while True:
            await RisingEdge(self.vif.clk)
            a_valid = int(self.vif.a_valid.value
                          ) if self.vif.a_valid.value is not None else 0
            a_ready = int(self.vif.a_ready.value
                          ) if self.vif.a_ready.value is not None else 0

            # TL transactions are only accepted on a completed handshake.
            # Sampling only when a_valid && a_ready avoids capturing transient
            # drive values that were not actually transferred.
            if not (a_valid and a_ready):
                continue

            req = tl_seq_item("req")
            req.channel = TlSeqItemChannel.A_CHANNEL
            req.a_addr = int(self.vif.a_address.value)
            req.a_opcode = int(self.vif.a_opcode.value)
            req.a_size = int(self.vif.a_size.value)
            req.a_param = int(self.vif.a_param.value)
            req.a_data = int(self.vif.a_data.value)
            req.a_mask = int(self.vif.a_mask.value)
            req.a_source = int(self.vif.a_source.value)
            req.a_user = int(self.vif.a_user.value)

            self.uvm_report.info(
                "TL_MONITOR",
                f"[{self.agent_name}][a_chan] : {req.convert2string()}",
                UVM_DEBUG,
            )

            self.sample_outstanding_cov(req)

            cloned = req.clone()
            if (cloned.a_source >> self.cfg.valid_a_source_width) != 0:
                self.uvm_report.fatal(
                    "TL_MONITOR",
                    f"a_source 0x{cloned.a_source:x} exceeds valid_a_source_width"
                )
            if cloned.a_source in self.pending_a_req:
                self.uvm_report.fatal(
                    "TL_MONITOR", f"duplicate a_source 0x{cloned.a_source:x}")
            self.pending_a_req[int(cloned.a_source)] = cloned

            max_out = getattr(self.cfg, "max_outstanding_req", 0)
            rst_n = getattr(self.vif, "rst_n", None)
            if max_out > 0 and rst_n is not None and int(rst_n.value) == 1:
                if len(self.pending_a_req) > max_out:
                    self.uvm_report.error(
                        "TL_MONITOR", f"pending a_req exceeds limit {max_out}")
                if (self.cfg.en_cov and self.cov is not None and
                        self.cov.m_max_outstanding_cg is not None):
                    self.cov.m_max_outstanding_cg.sample(
                        len(self.pending_a_req))

            self.a_chan_port.write(req)
            self.notify(req)

    async def check_d_channel(self) -> None:
        """D-channel collector loop."""
        while True:
            await RisingEdge(self.vif.clk)
            d_valid = int(self.vif.d_valid.value
                          ) if self.vif.d_valid.value is not None else 0
            d_ready = int(self.vif.d_ready.value
                          ) if self.vif.d_ready.value is not None else 0

            # A D-channel response is only transferred on a completed handshake.
            # Sampling only when d_valid && d_ready prevents consuming response
            # field values from cycles where no transfer occurred.
            if not (d_valid and d_ready):
                continue

            d_source = int(self.vif.d_source.value)
            if d_source not in self.pending_a_req:
                self.uvm_report.info(
                    "TL_MONITOR",
                    f"Ignoring TL response with no matching request "
                    f"(d_source 0x{d_source:x})",
                    UVM_DEBUG,
                )
                continue

            rsp = self.pending_a_req.pop(d_source)
            rsp.channel = TlSeqItemChannel.D_CHANNEL
            rsp.d_opcode = int(self.vif.d_opcode.value)
            rsp.d_data = int(self.vif.d_data.value)
            rsp.d_source = d_source
            rsp.d_param = int(self.vif.d_param.value)
            rsp.d_error = bool(
                int(self.vif.d_error.value
                    )) if self.vif.d_error.value is not None else False
            rsp.d_sink = int(self.vif.d_sink.value)
            rsp.d_size = int(self.vif.d_size.value)
            rsp.d_user = int(self.vif.d_user.value)

            self.uvm_report.info(
                "TL_MONITOR",
                f"[{self.agent_name}][d_chan] : {rsp.convert2string()}",
                UVM_DEBUG,
            )

            if self.cfg.en_cov and self.cov is not None:
                self.cov.sample(rsp)

            self.d_chan_port.write(rsp)
            self.notify(rsp)

    def report_phase(self) -> None:
        super().report_phase()
        if self.pending_a_req:
            self.uvm_report.error(
                "TL_MONITOR",
                f"{len(self.pending_a_req)} items left at end of sim")
            for src, item in self.pending_a_req.items():
                self.uvm_report.info(
                    "TL_MONITOR",
                    f"pending_a_req[{src}] = {item.convert2string()}",
                    UVM_DEBUG,
                )

    def _sample_pending_req_on_reset(self) -> None:
        if not self.cfg or not self.cfg.en_cov or self.cov is None:
            return
        if self.cov.m_pending_req_on_rst_cg is not None:
            self.cov.m_pending_req_on_rst_cg.sample(
                int(bool(self.pending_a_req)))

    def sample_outstanding_cov(self, item: tl_seq_item) -> None:
        if not self.cfg or not self.cfg.en_cov or self.cov is None:
            return

        same_addr_outstanding = any(
            int(pending_item.a_addr) == int(item.a_addr)
            for pending_item in self.pending_a_req.values())

        toggle_cg = self.cov.m_outstanding_item_w_same_addr_cov_obj
        if toggle_cg is not None:
            toggle_cg.sample(int(same_addr_outstanding))
