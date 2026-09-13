# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink RAL model scaffolds."""

from .tl_agent_reg_block import tl_agent_control_reg, tl_agent_reg_block

__all__ = [
    "tl_agent_control_reg",
    "tl_agent_reg_block",
]
