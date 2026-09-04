# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset driver."""

from dv_lib.dv_base_driver import dv_base_driver

from .clk_rst_agent_cfg import clk_rst_agent_cfg
from .clk_rst_item import ClkRstItemType, clk_rst_item


class clk_rst_driver(dv_base_driver[clk_rst_item, clk_rst_agent_cfg,
                                    clk_rst_item]):
    """Driver that delegates reset control to the reset domain."""

    async def run_phase(self):
        if self.reset_domain.is_driving_reset():
            await self.reset_domain.apply_reset()
        await self.get_and_drive()

    async def get_and_drive(self):
        while True:
            item = await self.get_next_item()
            if item.item_type == ClkRstItemType.APPLY_RESET:
                await self.reset_domain.apply_reset()
            elif item.item_type == ClkRstItemType.CONFIG_CLK_INTF:
                # Placeholder for future parity with any clk interface reconfiguration hook.
                pass
            else:
                self.uvm_report.fatal(
                    "CLK_RST_DRIVER", "only supports item_type in "
                    "{APPLY_RESET, CONFIG_CLK_INTF}")

            self.item_done()
