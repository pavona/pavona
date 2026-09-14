# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base pyUVM virtual sequencer."""

from typing import Generic, Optional, TypeVar

from pyuvm import uvm_component

from .dv_base_env_cfg import dv_base_env_cfg
from .dv_base_env_cov import dv_base_env_cov
from .dv_base_sequencer import dv_base_sequencer

CFG_T = TypeVar("CFG_T", bound=dv_base_env_cfg)
COV_T = TypeVar("COV_T", bound=dv_base_env_cov)


class dv_base_virtual_sequencer(
        dv_base_sequencer,
        Generic[CFG_T, COV_T],
):
    """
    Python port of SV ``dv_base_virtual_sequencer``.

    This sequencer is marked as virtual and does not participate in the reset-driven
    sequence stopping performed by agents.
    """

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None
        self.cov: Optional[COV_T] = None
        self.do_not_reset = True
        self.is_virtual_sequencer = True

    def handle_reset_assertion(self) -> None:
        self.uvm_report.fatal(
            "DV_BASE_VIRTUAL_SEQUENCER",
            "handle_reset_assertion() needs implementation in derived class")
