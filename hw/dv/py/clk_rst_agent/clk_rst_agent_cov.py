# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Clock/reset coverage placeholder."""

from dv_lib.dv_base_agent_cov import dv_base_agent_cov

from .clk_rst_agent_cfg import clk_rst_agent_cfg


class clk_rst_agent_cov(dv_base_agent_cov[clk_rst_agent_cfg]):
    """Coverage hook for parity with the SV package."""

    pass
