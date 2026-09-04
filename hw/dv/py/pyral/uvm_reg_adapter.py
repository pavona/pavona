# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base adapter API between register ops and bus items."""

from __future__ import annotations

from .uvm_reg_item import uvm_reg_bus_op


class uvm_reg_adapter:
    """Minimal SV-compatible adapter surface."""

    def __init__(self, name: str = "uvm_reg_adapter"):
        self.name = name
        self.supports_byte_enable = False
        self.provides_responses = False

    def reg2bus(self, rw: uvm_reg_bus_op):
        raise NotImplementedError(
            f"{type(self).__name__}.reg2bus() is not implemented")

    def bus2reg(self, bus_item, rw: uvm_reg_bus_op) -> None:
        raise NotImplementedError(
            f"{type(self).__name__}.bus2reg() is not implemented")
