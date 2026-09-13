# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Reset sequence."""

from dv_lib.dv_base_seq import dv_base_seq
from pyuvm import UVM_LOW

from ..clk_rst_agent_cfg import clk_rst_agent_cfg
from ..clk_rst_item import ClkRstItemType, clk_rst_item
from ..clk_rst_sequencer import clk_rst_sequencer


class reset_seq(dv_base_seq[clk_rst_sequencer, clk_rst_agent_cfg, clk_rst_item,
                            clk_rst_item]):
    """Trigger reset through the clock/reset agent."""

    def __init__(self, name: str = "reset_seq"):
        super().__init__(name)

    async def body(self):
        self.uvm_report.info("RESET_SEQ", "Starting body()", UVM_LOW)
        item = clk_rst_item(f"{self.get_name()}_item")
        item.item_type = ClkRstItemType.APPLY_RESET
        item.randomize()
        await self.start_item(item)
        await self.finish_item(item)
