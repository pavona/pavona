# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Delay agent."""

from typing import Optional

import cocotb
from pyuvm import uvm_agent, uvm_component

from .clk_rst_agent_cfg import clk_rst_agent_cfg
from .clk_rst_sequencer import delay_sequencer
from .delay_driver import delay_driver


class delay_agent(uvm_agent):
    """Cut-down agent: sequencer + optional driver, no monitor or coverage."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[clk_rst_agent_cfg] = None
        self.driver: Optional[delay_driver] = None
        self.sequencer: Optional[delay_sequencer] = None
        self._agent_reset_monitor_task: Optional[cocotb.Task] = None

    def build_phase(self):
        super().build_phase()

        if self.cfg is None:
            self.uvm_report.fatal(
                "DELAY_AGENT", "cfg == None. Resolve this before proceeding")

        if self.cfg.active_or_passive in ("UVM_ACTIVE", "ACTIVE"):
            self.sequencer = delay_sequencer("sequencer", self)
            self.sequencer.cfg = self.cfg

            if self.cfg.has_driver:
                self.driver = delay_driver("driver", self)
                self.driver.cfg = self.cfg

    def connect_phase(self):
        super().connect_phase()
        if self.driver is not None and self.sequencer is not None:
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)

        if self.cfg.vif is None:
            self.uvm_report.fatal("DELAY_AGENT",
                                  "vif is None is cfg. Enshure it is set")
        if self.cfg.reset_domain is None:
            self.uvm_report.fatal("DELAY_AGENT",
                                  "vif is None is cfg. Enshure it is set")
        self.driver.vif = self.cfg.vif
        self.driver.reset_domain = self.cfg.reset_domain

    async def run_phase(self):
        if self.cfg is None or self.cfg.reset_domain is None:
            self.uvm_report.fatal("DELAY_AGENT",
                                  "cfg.reset_domain is required")

        await self.cfg.reset_domain.wait_reset_assert()
        await self.cfg.reset_domain.wait_reset_deassert()
        self._agent_reset_monitor_task = cocotb.start_soon(
            self._agent_reset_thread())

    async def _agent_reset_thread(self):
        assert self.cfg is not None
        while True:
            await self.cfg.reset_domain.wait_reset_assert()
            self.sequencer.stop_sequences()
            await self.cfg.reset_domain.wait_reset_deassert()
