# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink env cfg variant with a stub RAL model."""

from __future__ import annotations

from tl_agent.dv.env.tl_agent_env_cfg import tl_agent_env_cfg

from .ral_models import tl_agent_reg_block


class tl_agent_ral_env_cfg(tl_agent_env_cfg):
    """Extends the base TL env cfg with one migration RAL model."""

    def initialize(self, csr_base_addr: int = 0) -> None:
        super().initialize(csr_base_addr)
        if not hasattr(self, "clk_freqs_mhz"):
            self.clk_freqs_mhz = {}
        self.ral_model_names = [tl_agent_reg_block.__name__]
        self.create_ral_models(csr_base_addr)

    def create_ral_by_name(self, name: str):
        if name != tl_agent_reg_block.__name__:
            return None
        block = tl_agent_reg_block()
        self.pre_build_ral_settings(block)
        block.build()
        self.post_build_ral_settings(block)
        return block
