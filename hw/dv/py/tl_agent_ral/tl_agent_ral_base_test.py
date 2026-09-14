# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink base test variant with initial RAL scaffolding."""

from __future__ import annotations

from typing import Optional

from pyuvm import uvm_component
from tl_agent.dv.tests.tl_agent_base_test import tl_agent_base_test

from .tl_agent_ral_env_cfg import tl_agent_ral_env_cfg


class tl_agent_ral_base_test(tl_agent_base_test):
    """Uses a TL env cfg that builds a stub register model."""

    CFG_CLS = tl_agent_ral_env_cfg

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
