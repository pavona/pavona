# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset sequence item."""

from __future__ import annotations

from enum import IntEnum

import vsc
from dv_lib.dv_base_seq_item import dv_base_seq_item


class ClkRstItemType(IntEnum):
    """Mirror the SV item type enum."""

    RESET_ASSERTED = 0
    RESET_DEASSERTED = 1
    APPLY_RESET = 2
    DELAY = 3
    CONFIG_CLK_INTF = 4


@vsc.randobj
class clk_rst_item(dv_base_seq_item):
    """Shared item used by clk_rst_agent and delay_agent."""

    def __init__(self, name: str = "clk_rst_item") -> None:
        super().__init__(name)
        self.item_type: ClkRstItemType = ClkRstItemType.APPLY_RESET
        self.reset_time_steps = vsc.rand_uint32_t()
        self.delay_time_steps = vsc.rand_uint32_t()
        self.reset_time: float = 0.0

    def clone(self) -> "clk_rst_item":
        cloned = type(self)(self.get_name() + "_clone")
        cloned.item_type = ClkRstItemType(int(self.item_type))
        cloned.reset_time_steps = int(self.reset_time_steps)
        cloned.delay_time_steps = int(self.delay_time_steps)
        cloned.reset_time = float(self.reset_time)
        return cloned

    def convert2string(self) -> str:
        return (f"item_type={self.item_type.name} "
                f"reset_time_steps={int(self.reset_time_steps)} "
                f"delay_time_steps={int(self.delay_time_steps)} "
                f"reset_time={float(self.reset_time)}")
