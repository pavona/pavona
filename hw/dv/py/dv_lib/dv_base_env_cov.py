# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
Base environment coverage component. Mirrors SV dv_base_env_cov: holds cfg.
Subclass to add environment-specific coverage when covergroups are defined.
"""

from typing import Generic, Optional, TypeVar

from pyuvm import uvm_component

from .dv_base_env_cfg import dv_base_env_cfg

# Configuration type for the environment (typically dv_base_env_cfg or subclass).
CFG_T = TypeVar("CFG_T", bound=dv_base_env_cfg)


class dv_base_env_cov(uvm_component, Generic[CFG_T]):
    """
    Base environment coverage component.

    Holds a reference to the environment config (cfg). Created by the environment
    when cfg.en_cov is True; parent sets cov.cfg = cfg. Subclass to add
    environment-specific coverage.
    """

    def __init__(self,
                 name: str,
                 parent: Optional[uvm_component] = None) -> None:
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None
