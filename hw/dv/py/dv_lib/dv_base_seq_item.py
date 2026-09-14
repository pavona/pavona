# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base sequence-item with deterministic seeded RNG."""

from pyuvm import uvm_sequence_item

from .dv_seeded_rng import ensure_seeded_rng


class dv_base_seq_item(uvm_sequence_item):
    """Base sequence-item class that provisions a deterministic RNG."""

    def __init__(self, name: str = "dv_base_seq_item") -> None:
        super().__init__(name)
        ensure_seeded_rng(self)
