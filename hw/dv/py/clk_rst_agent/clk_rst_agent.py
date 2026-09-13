# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset agent."""

from typing import Optional

from dv_lib.dv_base_agent import dv_base_agent
from pyuvm import uvm_component

from .clk_rst_agent_cfg import clk_rst_agent_cfg
from .clk_rst_agent_cov import clk_rst_agent_cov
from .clk_rst_driver import clk_rst_driver
from .clk_rst_monitor import clk_rst_monitor
from .clk_rst_sequencer import clk_rst_sequencer


class clk_rst_agent(dv_base_agent[clk_rst_agent_cfg, clk_rst_driver,
                                  clk_rst_sequencer, clk_rst_monitor,
                                  clk_rst_agent_cov, ]):
    """Full clock/reset agent with monitor, sequencer, and driver."""

    DRIVER_T = clk_rst_driver
    SEQUENCER_T = clk_rst_sequencer
    MONITOR_T = clk_rst_monitor
    COV_T = clk_rst_agent_cov

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)

    def build_phase(self):
        super().build_phase()
        if self.sequencer is not None:
            self.sequencer.do_not_reset = True
