# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Base RAL sequence scaffold."""

from __future__ import annotations

try:
    from pyuvm import uvm_sequence
except ImportError:  # pragma: no cover - import fallback for local tooling

    class uvm_sequence:  # type: ignore[no-redef]

        def __init__(self, name: str = ""):
            self.name = name


class uvm_reg_sequence(uvm_sequence):
    """Placeholder for register-aware pyUVM sequences."""

    def __init__(self, name: str = "uvm_reg_sequence"):
        super().__init__(name)
