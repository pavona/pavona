# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink test-sequence parameters."""

from __future__ import annotations

import vsc
from dv_lib.dv_test_seq_parameters import EnableType, dv_test_seq_parameters


@vsc.randobj
class tl_agent_test_seq_parameters(dv_test_seq_parameters):
    """TL-specific once-per-test randomized controls."""

    def __init__(self, name: str = "tl_agent_test_seq_parameters") -> None:
        super().__init__(name)
        self.do_dut_init = True
        self.do_dut_shutdown = True

    @vsc.constraint
    def reset_loops_c(self):
        with vsc.if_then(self.reset_testing == int(EnableType.ENABLE)):
            self.num_reset_loops in vsc.rangelist(vsc.rng(2, 5))

    @vsc.constraint
    def reset_testing_default_c(self):
        vsc.soft(self.reset_testing == int(EnableType.DISABLE))
