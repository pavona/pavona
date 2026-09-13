# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Migration-oriented TL agent register model scaffold."""

from __future__ import annotations

from pyral import uvm_reg, uvm_reg_block, uvm_reg_field


class tl_agent_control_reg(uvm_reg):
    """Minimal control register used to exercise the new RAL plumbing."""

    def __init__(self, name: str = "control"):
        super().__init__(name, n_bits=32)
        self.enable = uvm_reg_field("enable")
        self.mode = uvm_reg_field("mode")

    def build(self) -> None:
        self.enable.configure(self, size=1, lsb_pos=0, access="RW", reset=0)
        self.mode.configure(self, size=2, lsb_pos=1, access="RW", reset=0)
        self.add_field(self.enable)
        self.add_field(self.mode)


class tl_agent_reg_block(uvm_reg_block):
    """Simple block for early migration tests."""

    def __init__(self, name: str = "tl_agent_reg_block"):
        super().__init__(name)
        self.control = tl_agent_control_reg()

    def build(self, base_addr: int = 0) -> None:
        self.default_map = self.create_map("default_map", base_addr, 4)
        self.control.configure(self)
        self.control.build()
        self.add_reg(self.control)
        self.default_map.add_reg(self.control, 0x0, "RW")
        self.lock_model()
