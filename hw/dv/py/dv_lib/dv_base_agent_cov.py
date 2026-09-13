# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base agent coverage component."""

from typing import Generic, Optional, TypeVar

from pyuvm import uvm_component

from .dv_base_agent_cfg import dv_base_agent_cfg

CFG_T = TypeVar("CFG_T", bound=dv_base_agent_cfg)


class dv_base_agent_cov(uvm_component, Generic[CFG_T]):
    """Base agent coverage shell. Subclasses attach agent-specific coverage."""

    def __init__(self,
                 name: str,
                 parent: Optional[uvm_component] = None) -> None:
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None
