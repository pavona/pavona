# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Delay driver."""

from __future__ import annotations

from typing import Set

import cocotb
from dv_lib.dv_base_driver import dv_base_driver
from pyuvm import UVM_LOW

from .clk_rst_agent_cfg import clk_rst_agent_cfg
from .clk_rst_item import ClkRstItemType, clk_rst_item


class delay_driver(dv_base_driver[clk_rst_item, clk_rst_agent_cfg,
                                  clk_rst_item]):
    """Driver that consumes clock cycles through the reset-domain vif."""

    def __init__(self, name: str, parent=None):
        super().__init__(name, parent)
        self._delay_tasks: Set[cocotb.Task] = set()

    async def get_and_drive(self):
        while True:
            item = await self.get_next_item()
            if item.item_type != ClkRstItemType.DELAY:
                self.item_done()
                self.uvm_report.fatal(
                    "DELAY_DRIVER",
                    f"unsupported item_type {item.item_type.name}")

            task_item = item.clone()
            task_item.set_id_info(item)
            task = cocotb.start_soon(self._run_delay(task_item))
            self._delay_tasks.add(task)
            self.item_done()

    def reset_interface_and_driver(self):
        for task in list(self._delay_tasks):
            if not task.done():
                task.cancel()
        self._delay_tasks.clear()

    async def _run_delay(self, item: clk_rst_item):
        if self.reset_domain is None:
            self.uvm_report.fatal("DELAY_DRIVER", "reset_domain is None")
        reset_domain = self.reset_domain
        self.uvm_report.info(
            "DELAY_DRIVER",
            f"Starting....Timesteps: {int(item.delay_time_steps)}",
            UVM_LOW,
        )
        await reset_domain.clk_rst_vif.wait_clks(int(item.delay_time_steps))

        rsp_item = clk_rst_item("rsp_item")
        rsp_item.item_type = item.item_type
        rsp_item.reset_time_steps = int(item.reset_time_steps)
        rsp_item.delay_time_steps = int(item.delay_time_steps)
        rsp_item.reset_time = float(item.reset_time)
        rsp_item.set_id_info(item)
        self.seq_item_port.put_response(rsp_item)
        self.uvm_report.info("DELAY_DRIVER", "....Completed", UVM_LOW)
