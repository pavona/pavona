# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Frontdoor scaffold."""

from __future__ import annotations

from .uvm_reg_item import uvm_reg_item


class uvm_reg_frontdoor:
    """Generic frontdoor access hook."""

    def __init__(self, name: str = "uvm_reg_frontdoor"):
        self.name = name

    async def execute(self, rw: uvm_reg_item, reg_map=None):
        del rw, reg_map
        raise NotImplementedError(
            "uvm_reg_frontdoor.execute() must be implemented")
