# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink environment configuration."""

from __future__ import annotations

from clk_rst_agent.clk_rst_agent_cfg import clk_rst_agent_cfg
from dv_lib.dv_base_env_cfg import dv_base_env_cfg
from dv_lib.dv_cocotb_utils import get_plusarg

from ...tl_agent_cfg import tl_agent_cfg
from ...tl_seq_item import SourceWidth


class tl_agent_env_cfg(dv_base_env_cfg):
    """Python port of SV ``tl_agent_env_cfg``."""

    def __init__(self, name: str = "cfg") -> None:
        super().__init__(name)
        self.host_agent_cfg: tl_agent_cfg | None = None
        self.device_agent_cfg: tl_agent_cfg | None = None
        self.tx_count: int | None = None

    def initialize(self, csr_base_addr: int = (1 << 32) - 1) -> None:
        del csr_base_addr
        # Mirror SV behavior: TL agent env has no RAL and does not call super.initialize().
        self.is_initialized = True
        self.ral_model_names = []

        self.clk_rst_cfg = clk_rst_agent_cfg()
        self.clk_rst_cfg.uvm_verbosity = self.uvm_verbosity

        self.delay_cfg = clk_rst_agent_cfg()
        self.delay_cfg.uvm_verbosity = self.uvm_verbosity

        self.host_agent_cfg = tl_agent_cfg()
        self.host_agent_cfg.uvm_verbosity = self.uvm_verbosity
        self.host_agent_cfg.max_outstanding_req = 1 << SourceWidth
        self.host_agent_cfg.if_mode = "Host"
        self.host_agent_cfg.device_can_rsp_on_same_cycle = True

        self.device_agent_cfg = tl_agent_cfg()
        self.device_agent_cfg.uvm_verbosity = self.uvm_verbosity
        self.device_agent_cfg.if_mode = "Device"
        self.device_agent_cfg.max_outstanding_req = 1 << SourceWidth
        self.device_agent_cfg.device_can_rsp_on_same_cycle = True

    def apply_runtime_args(self) -> None:
        tx_count_arg = get_plusarg("TX_COUNT")
        if not tx_count_arg:
            raise RuntimeError("TX_COUNT plusarg is required")
        try:
            self.tx_count = int(tx_count_arg, 0)
        except ValueError as err:
            raise RuntimeError(
                f"Invalid TX_COUNT plusarg value: {tx_count_arg!r}") from err
