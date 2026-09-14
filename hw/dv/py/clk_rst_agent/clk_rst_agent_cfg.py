# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset agent configuration."""

from dv_lib.dv_base_agent_cfg import dv_base_agent_cfg


class clk_rst_agent_cfg(dv_base_agent_cfg):
    """No extra knobs yet; keep parity with the SV cfg shell."""

    def __init__(self) -> None:
        super().__init__()
