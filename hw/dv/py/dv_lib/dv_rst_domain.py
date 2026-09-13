# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Reset-domain wrapper around a clock/reset interface."""

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge
from interfaces.clk_rst_if import ClkRstIf


class dv_rst_domain:
    """Mirror the SV dv_rst_domain API for Python cocotb/pyuvm testbenches."""

    def __init__(
        self,
        clk_rst_vif: ClkRstIf,
        name: str = "dv_rst_domain",
    ) -> None:
        self.name = name
        self.clk_rst_vif = clk_rst_vif

    async def apply_reset(self) -> None:
        """Apply reset through the bound clock/reset interface."""
        cocotb.start_soon(self.clk_rst_vif.apply_reset())

    async def wait_reset_assert(self) -> None:
        """Wait for reset assertion; default domain supports async assert."""
        if int(self.clk_rst_vif.rst_n.value) == 0:
            return
        await FallingEdge(self.clk_rst_vif.rst_n)

    async def wait_reset_deassert(self) -> None:
        """Wait for reset deassertion; default domain uses synchronous release."""
        while True:
            await RisingEdge(self.clk_rst_vif.clk)
            if int(self.clk_rst_vif.rst_n.value) == 1:
                return

    def is_driving_reset(self) -> bool:
        """Return whether the interface is configured to drive reset."""
        return bool(self.clk_rst_vif.drive_rst_n)
