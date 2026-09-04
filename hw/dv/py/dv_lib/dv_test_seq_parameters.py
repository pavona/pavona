# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Test-sequence parameters for random-reset-safe virtual sequences."""
from enum import IntEnum

import vsc

from .dv_base_seq_item import dv_base_seq_item


class EnableType(IntEnum):
    """Enable/disable knob matching the SV enum shape."""

    DISABLE = 0
    ENABLE = 1


@vsc.randobj
class dv_test_seq_parameters(dv_base_seq_item):
    """Mirror the SV reset-test control object with Python defaults."""

    def __init__(self, name: str = "dv_test_seq_parameters") -> None:
        super().__init__(name)
        self.reset_testing = vsc.rand_bit_t(1)
        self.num_reset_loops = vsc.rand_uint32_t()
        self.num_trans = vsc.rand_uint32_t()
        self.do_dut_init: bool = True
        self.do_dut_shutdown: bool = True

    @vsc.constraint
    def num_trans_c(self):
        self.num_trans in vsc.rangelist(vsc.rng(1, 20))

    @vsc.constraint
    def reset_loops_enabled_c(self):
        with vsc.if_then(self.reset_testing == int(EnableType.ENABLE)):
            self.num_reset_loops > 0

    @vsc.constraint
    def reset_loops_default_c(self):
        with vsc.implies(self.reset_testing == int(EnableType.DISABLE)):
            vsc.soft(self.num_reset_loops == 1)

    @vsc.constraint
    def reset_testing_default_c(self):
        vsc.soft(self.reset_testing == int(EnableType.DISABLE))

    def constraint_mode(self, enabled: int) -> None:
        """Compatibility shim for existing call sites."""
        del enabled
