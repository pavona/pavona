# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Configuration for TileLink agent."""

import random
from typing import Any, List, Optional

from dv_lib.dv_base_agent_cfg import dv_base_agent_cfg
from interfaces.tl_widths import get_tl_widths


class tl_agent_cfg(dv_base_agent_cfg):
    """TileLink agent configuration. vif is the TlIf (or compatible) interface."""

    def __init__(self) -> None:
        super().__init__()
        widths = get_tl_widths()
        self.vif: Optional[Any] = None
        self.max_outstanding_req: int = 16
        self.valid_a_source_width: int = widths.tl_aiw
        self.a_source_pend_q: List[int] = []
        # Agent mode hint used by host/device wrappers.
        self.if_mode: str = "Host"

        # Host A-channel valid drop controls.
        self.allow_a_valid_drop_wo_a_ready: bool = True
        self.use_seq_item_a_valid_len: bool = False
        self.a_valid_len_min: int = 1
        self.a_valid_len_max: int = 10

        # Device D-channel valid drop controls.
        self.use_seq_item_d_valid_len: bool = False
        self.allow_d_valid_drop_wo_d_ready: bool = False
        self.d_valid_len_min: int = 1
        self.d_valid_len_max: int = 10

        # Host A-channel valid delay.
        self.use_seq_item_a_valid_delay: bool = False
        self.a_valid_delay_min: int = 0
        self.a_valid_delay_max: int = 10

        # Host D-ready delay.
        self.d_ready_delay_min: int = 0
        self.d_ready_delay_max: int = 10

        # Device A-ready delay.
        self.a_ready_delay_min: int = 0
        self.a_ready_delay_max: int = 10

        # Device D-valid delay.
        self.use_seq_item_d_valid_delay: bool = False
        self.d_valid_delay_min: int = 0
        self.d_valid_delay_max: int = 10

        # If False, force d_ready high while a_valid is asserted.
        self.host_can_stall_rsp_when_a_valid_high: bool = False

        # Invalidate options (X vs zero/randomized struct emulation).
        self.invalidate_a_x: bool = False
        self.invalidate_d_x: bool = False

        # Optional sequencer FIFOs.
        self.has_req_fifo: bool = False
        self.has_rsp_fifo: bool = False

    def add_to_a_source_pend_q(self, a_source: int) -> None:
        source = int(a_source)
        if source not in self.a_source_pend_q:
            self.a_source_pend_q.append(source)

    def remove_from_a_source_pend_q(self, a_source: int) -> None:
        source = int(a_source)
        if source in self.a_source_pend_q:
            self.a_source_pend_q.remove(source)

    def randomize_a_source_in_req(self, req) -> None:
        max_source = 1 << int(self.valid_a_source_width)
        candidates = [
            src for src in range(max_source) if src not in self.a_source_pend_q
        ]
        if not candidates:
            raise RuntimeError("No available a_source values remain")
        req.a_source = random.choice(candidates)
        self.add_to_a_source_pend_q(req.a_source)
