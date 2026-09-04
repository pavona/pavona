# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset sequencer types."""

from typing import Optional

from dv_lib.dv_base_sequencer import dv_base_sequencer
from pyuvm import uvm_component

from .clk_rst_agent_cfg import clk_rst_agent_cfg
from .clk_rst_item import clk_rst_item


class clk_rst_sequencer(dv_base_sequencer[clk_rst_item, clk_rst_agent_cfg,
                                          clk_rst_item]):
    """Sequencer for reset operations."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)


class delay_sequencer(dv_base_sequencer[clk_rst_item, clk_rst_agent_cfg,
                                        clk_rst_item]):
    """Sequencer for delay operations."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
