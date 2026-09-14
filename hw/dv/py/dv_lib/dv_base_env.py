# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base pyUVM environment."""

from __future__ import annotations

from typing import Generic, Optional, Type, TypeVar

from pyuvm import UVM_LOW, resolve_uvm_verbosity, uvm_component, uvm_env

from .dv_base_env_cfg import dv_base_env_cfg
from .dv_base_env_cov import dv_base_env_cov
from .dv_base_scoreboard import dv_base_scoreboard
from .dv_base_virtual_sequencer import dv_base_virtual_sequencer

CFG_T = TypeVar("CFG_T", bound=dv_base_env_cfg)
VIRTUAL_SEQUENCER_T = TypeVar("VIRTUAL_SEQUENCER_T", bound=uvm_component)
SCOREBOARD_T = TypeVar("SCOREBOARD_T", bound=uvm_component)
COV_T = TypeVar("COV_T", bound=uvm_component)


class dv_base_env(
        uvm_env,
        Generic[CFG_T, VIRTUAL_SEQUENCER_T, SCOREBOARD_T, COV_T],
):
    """
    Python port of SV ``dv_base_env``.

    The environment:
    - resolves ``cfg`` from ``ConfigDB``
    - instantiates optional coverage, a virtual sequencer, and a scoreboard
    """

    VIRTUAL_SEQUENCER_CLS: Type[uvm_component] = dv_base_virtual_sequencer
    SCOREBOARD_CLS: Type[uvm_component] = dv_base_scoreboard
    COV_CLS: Type[uvm_component] = dv_base_env_cov

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None
        self.virtual_sequencer: Optional[VIRTUAL_SEQUENCER_T] = None
        self.scoreboard: Optional[SCOREBOARD_T] = None
        self.cov: Optional[COV_T] = None
        self.uvm_verbosity: int = int(getattr(parent, "uvm_verbosity",
                                              UVM_LOW))
        self.set_report_verbosity(self.uvm_verbosity)

    def build_phase(self):
        super().build_phase()

        if self.cfg is None:
            self.uvm_report.fatal(
                "DV_BASE_ENV", """cfg is not set. Resolve this before
                                      procceeding""")
        self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                   self.cfg)
        self.set_report_verbosity(self.uvm_verbosity)

        if self.cfg.en_cov:
            cov = self.COV_CLS("cov", self)
            self.cov = cov

        if self.cfg.is_active:
            virtual_sequencer = self.VIRTUAL_SEQUENCER_CLS(
                "virtual_sequencer", self)
            setattr(virtual_sequencer, "cfg", self.cfg)
            setattr(virtual_sequencer, "cov", self.cov)
            if hasattr(virtual_sequencer, "is_virtual_sequencer"):
                setattr(virtual_sequencer, "is_virtual_sequencer", True)
            self.virtual_sequencer = virtual_sequencer

        self.scoreboard = self.SCOREBOARD_CLS("scoreboard", self)
        self.scoreboard.cfg = self.cfg
        self.scoreboard.cov = self.cov
