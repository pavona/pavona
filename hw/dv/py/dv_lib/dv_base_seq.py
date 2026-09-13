# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base sequence helpers."""

from typing import Generic, Optional, TypeVar

from pyuvm import resolve_uvm_verbosity, uvm_sequence_item

from .dv_base_agent_cfg import dv_base_agent_cfg
from .dv_base_sequence_core import dv_base_sequence_core
from .dv_base_sequencer import dv_base_sequencer
from .dv_seeded_rng import ensure_seeded_rng

REQ_T = TypeVar("REQ_T", bound=uvm_sequence_item)
RSP_T = TypeVar("RSP_T", bound=uvm_sequence_item)
CFG_T = TypeVar("CFG_T", bound=dv_base_agent_cfg)
SEQUENCER_T = TypeVar("SEQUENCER_T", bound=dv_base_sequencer)


class dv_base_seq(dv_base_sequence_core, Generic[SEQUENCER_T, CFG_T, REQ_T,
                                                 RSP_T]):
    """
    Base sequence that binds cfg from the active sequencer before execution.

    Generic order: SEQUENCER_T, CFG_T, REQ_T, RSP_T.
    Example: class my_seq(dv_base_seq[my_sequencer, my_cfg, my_req, my_rsp]): ...
    """

    def __init__(self, name: str = "dv_base_seq") -> None:
        super().__init__(name)
        self.cfg: Optional[CFG_T] = None
        ensure_seeded_rng(self)

    async def pre_body(self) -> None:
        await super().pre_body()
        self._bind_from_sequencer()

    def _bind_from_sequencer(self) -> None:
        sequencer = getattr(self, "sequencer", None)
        if sequencer is None or getattr(sequencer, "cfg", None) is None:
            self.uvm_report.fatal("DV_BASE_SEQ", "sequencer.cfg is required")
        self.cfg = sequencer.cfg
        self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                   self.cfg)
        self.set_report_verbosity(self.uvm_verbosity)

    async def body(self) -> None:
        self.uvm_report.fatal(
            "DV_BASE_SEQ",
            "override body() in sequences derived from dv_base_seq")
