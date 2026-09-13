# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Unified TileLink agent wrapper (SV `tl_agent` compatibility)."""

from typing import Optional

from pyuvm import UVM_LOW, resolve_uvm_verbosity, uvm_agent, uvm_component

from .tl_agent_cfg import tl_agent_cfg
from .tl_device_agent import tl_device_agent
from .tl_host_agent import tl_host_agent


class tl_agent(uvm_agent):
    """Create host or device TL agent based on `cfg.if_mode`."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[tl_agent_cfg] = None
        self.impl = None
        self.uvm_verbosity: int = int(getattr(parent, "uvm_verbosity",
                                              UVM_LOW))
        self.set_report_verbosity(self.uvm_verbosity)

    def build_phase(self):
        super().build_phase()

        if self.cfg is None:
            self.uvm_report.fatal("TL_AGENT", "cfg is None")
        self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                   self.cfg)
        self.set_report_verbosity(self.uvm_verbosity)

        mode = str(getattr(self.cfg, "if_mode", "Host")).lower()
        impl_cls = tl_device_agent if mode == "device" else tl_host_agent

        # Child agent consumes cfg/vif through the same keys as normal agents.
        self.impl = impl_cls("impl", self)
        self.impl.cfg = self.cfg

    def connect_phase(self):
        super().connect_phase()
        if self.impl is None:
            self.uvm_report.fatal("TL_AGENT", "impl agent was not created")
        if self.cfg.vif is None:
            self.uvm_report.fatal("TL_AGENT", "cfg.vif is None")

    @property
    def monitor(self):
        return None if self.impl is None else getattr(self.impl, "monitor",
                                                      None)

    @property
    def sequencer(self):
        return None if self.impl is None else getattr(self.impl, "sequencer",
                                                      None)

    @property
    def driver(self):
        return None if self.impl is None else getattr(self.impl, "driver",
                                                      None)

    @property
    def cov(self):
        return None if self.impl is None else getattr(self.impl, "cov", None)
