# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Configuration parameters for random-reset-safe virtual sequences."""

import vsc

from .dv_base_seq_item import dv_base_seq_item


@vsc.randobj
class dv_config_parameters(dv_base_seq_item):
    """Placeholder config-parameter object matching the SV base class shape."""

    def __init__(self, name: str = "dv_config_parameters") -> None:
        super().__init__(name)

    def constraint_mode(self, enabled: int) -> None:
        """Compatibility shim for existing call sites."""
        del enabled
