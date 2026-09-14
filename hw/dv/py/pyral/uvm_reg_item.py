# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Register operation item types."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

try:
    from pyuvm import uvm_sequence_item
except ImportError:  # pragma: no cover - import fallback for local tooling

    class uvm_sequence_item:  # type: ignore[no-redef]

        def __init__(self, name: str = ""):
            self.name = name


from .uvm_reg_model import UVM_PATH, UVM_STATUS


@dataclass
class uvm_reg_bus_op:
    """Python mirror of the SV uvm_reg_bus_op descriptor."""

    kind: str = "READ"
    addr: int = 0
    data: int = 0
    n_bits: int = 0
    byte_en: int = 0
    status: UVM_STATUS = UVM_STATUS.IS_OK


class uvm_reg_item(uvm_sequence_item):
    """Lightweight register transaction descriptor."""

    def __init__(self, name: str = "uvm_reg_item"):
        super().__init__(name)
        self.element: Optional[Any] = None
        self.element_kind: str = ""
        self.kind: str = "READ"
        self.value: list[int] = []
        self.offset: int = 0
        self.map: Optional[Any] = None
        self.path: UVM_PATH = UVM_PATH.DEFAULT
        self.status: UVM_STATUS = UVM_STATUS.IS_OK
        self.local_map: Optional[Any] = None
        self.parent: Optional[Any] = None
        self.extension: Optional[Any] = None
        self.bd_kind: str = ""
        self.prior: int = -1
        self.byte_en: int = 0
        self.n_bits: int = 0
        self.fname: str = ""
        self.lineno: int = 0
        self.bus_op = uvm_reg_bus_op()

    def set_value(self, value: int) -> None:
        self.value = [value]

    def get_value(self, default: int = 0) -> int:
        return self.value[0] if self.value else default
