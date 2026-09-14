# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink environment virtual sequencer."""

from __future__ import annotations

from typing import Optional

from clk_rst_agent.clk_rst_sequencer import clk_rst_sequencer, delay_sequencer
from dv_lib.dv_base_virtual_sequencer import dv_base_virtual_sequencer
from pyuvm import uvm_component

from ...tl_sequencer import tl_sequencer
from .tl_agent_env_cfg import tl_agent_env_cfg
from .tl_agent_env_cov import tl_agent_env_cov


class tl_agent_virtual_sequencer(dv_base_virtual_sequencer[tl_agent_env_cfg,
                                                           tl_agent_env_cov]):
    """Python port of SV ``tl_agent_virtual_sequencer``."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.host_seqr: Optional[tl_sequencer] = None
        self.device_seqr: Optional[tl_sequencer] = None
        self.clk_rst_sequencer_h: Optional[clk_rst_sequencer] = None
        self.delay_sequencer_h: Optional[delay_sequencer] = None

    def handle_reset_assertion(self) -> None:
        return
