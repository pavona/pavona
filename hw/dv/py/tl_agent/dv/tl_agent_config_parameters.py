# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink per-reset-loop configuration parameters."""

from __future__ import annotations

import vsc
from dv_lib.dv_config_parameters import dv_config_parameters


@vsc.randobj
class tl_agent_config_parameters(dv_config_parameters):
    """TL-specific per-loop configuration controls."""

    def __init__(self, name: str = "tl_agent_config_parameters") -> None:
        super().__init__(name)
        self.out_of_order_rsp = vsc.rand_bit_t(1)
        self.host_min_req_cnt = vsc.rand_uint32_t()
        self.host_max_req_cnt = vsc.rand_uint32_t()
        self.rand_reset_delay = vsc.rand_uint32_t()

    @vsc.constraint
    def host_req_cnt_c(self):
        self.host_min_req_cnt in vsc.rangelist(vsc.rng(1, 200))
        self.host_max_req_cnt in vsc.rangelist(
            vsc.rng(self.host_min_req_cnt, 200))

    @vsc.constraint
    def rand_reset_delay_c(self):
        self.rand_reset_delay in vsc.rangelist(vsc.rng(50, 100))
        # self.rand_reset_delay.dist(
        #     vsc.weight(vsc.rng(1, 1000), 2),
        #     vsc.weight(vsc.rng(1001, 100_000), 7),
        #     vsc.weight(vsc.rng(100_001, 1_000_000), 1),
        # )
