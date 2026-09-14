# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset monitor."""

from dv_lib.dv_base_monitor import dv_base_monitor

from .clk_rst_agent_cfg import clk_rst_agent_cfg
from .clk_rst_agent_cov import clk_rst_agent_cov
from .clk_rst_item import ClkRstItemType, clk_rst_item


class clk_rst_monitor(dv_base_monitor[clk_rst_item, clk_rst_item, clk_rst_item,
                                      clk_rst_agent_cfg, clk_rst_agent_cov]):
    """Publish reset assert/deassert events detected on the bound reset domain."""

    def __init__(self, name, parent=None):
        super().__init__(name, parent)
        self._last_rst_n: int | None = None

    async def run_phase(self):
        if self.reset_domain is None:
            self.uvm_report.fatal("CLK_RST_MONITOR", "reset_domain is None")
        await self.collect_trans()

    async def collect_trans(self):
        self._last_rst_n = int(self.reset_domain.clk_rst_vif.rst_n.value)
        while True:
            await self.reset_domain.clk_rst_vif.clk.value_change
            rst_n = int(self.reset_domain.clk_rst_vif.rst_n.value)

            if self._last_rst_n != rst_n:
                item = clk_rst_item(f"{self.get_name()}_item")
                item.item_type = (ClkRstItemType.RESET_ASSERTED if rst_n == 0
                                  else ClkRstItemType.RESET_DEASSERTED)
                self.notify(item)
            self._last_rst_n = rst_n
