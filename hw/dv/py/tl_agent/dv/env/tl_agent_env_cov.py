# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink environment coverage component."""

from dv_lib.dv_base_env_cov import dv_base_env_cov

from .tl_agent_env_cfg import tl_agent_env_cfg


class tl_agent_env_cov(dv_base_env_cov[tl_agent_env_cfg]):
    """Alias of ``dv_base_env_cov`` for TL env typing/parity with SV."""
