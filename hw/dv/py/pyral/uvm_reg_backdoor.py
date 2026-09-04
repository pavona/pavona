# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Backdoor scaffold."""

from __future__ import annotations

from .uvm_reg_item import uvm_reg_item


class uvm_reg_backdoor:
    """Generic backdoor access hook."""

    def __init__(self, name: str = "uvm_reg_backdoor"):
        self.name = name

    async def read(self, rw: uvm_reg_item):
        del rw
        raise NotImplementedError(
            "uvm_reg_backdoor.read() must be implemented")

    async def write(self, rw: uvm_reg_item):
        del rw
        raise NotImplementedError(
            "uvm_reg_backdoor.write() must be implemented")
