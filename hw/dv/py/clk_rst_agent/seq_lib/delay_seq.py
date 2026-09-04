# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Delay sequence."""

from dv_lib.dv_base_seq import dv_base_seq
from pyuvm import UVM_LOW

from ..clk_rst_agent_cfg import clk_rst_agent_cfg
from ..clk_rst_item import ClkRstItemType, clk_rst_item
from ..clk_rst_sequencer import delay_sequencer


class delay_seq(dv_base_seq[delay_sequencer, clk_rst_agent_cfg, clk_rst_item,
                            clk_rst_item]):
    """Consume a programmable number of clock cycles."""

    def __init__(self,
                 name: str = "delay_seq",
                 delay_time_steps: int | None = None):
        super().__init__(name)
        self.delay_time_steps = None if delay_time_steps is None else int(
            delay_time_steps)

    async def body(self):
        self.uvm_report.info("DELAY_SEQ", "Starting body()", UVM_LOW)

        item = clk_rst_item(f"{self.get_name()}_item")
        item.item_type = ClkRstItemType.DELAY
        delay_time_steps = self.delay_time_steps
        if delay_time_steps is None:
            item.randomize()
        else:
            item.delay_time_steps = int(delay_time_steps)
        await self.start_item(item)
        await self.finish_item(item)
        self.uvm_report.info("DELAY_SEQ", "Driver started counting clk edges",
                             UVM_LOW)

        self.rsp = await self.get_response()
        self.uvm_report.info("DELAY_SEQ", "Completed body()", UVM_LOW)
