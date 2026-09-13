# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""DV-specific register map overlay."""

from __future__ import annotations

from pyral import uvm_reg_map


class dv_base_reg_map(uvm_reg_map):
    """Register map policy container for DV metadata."""

    def __init__(self, name: str = "dv_base_reg_map"):
        super().__init__(name=name)
        self.racl_support = False
        self.interface_name = ""

    def set_racl_support(self, enabled: bool) -> None:
        self.racl_support = enabled
        self.policy["racl_support"] = enabled

    def get_racl_support(self) -> bool:
        return self.racl_support

    def set_interface_name(self, interface_name: str) -> None:
        self.interface_name = interface_name
        self.policy["interface_name"] = interface_name
