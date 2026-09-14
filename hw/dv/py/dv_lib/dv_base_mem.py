# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""DV-specific memory overlay."""

from __future__ import annotations

from pyral import normalize_access, uvm_mem


class dv_base_mem(uvm_mem):
    """Memory policy differences layered on top of pyral."""

    def __init__(
        self,
        name: str = "dv_base_mem",
        size: int = 0,
        n_bits: int = 32,
        access: str = "RW",
        has_coverage: int = 0,
    ):
        del has_coverage
        super().__init__(name=name, size=size, n_bits=n_bits)
        self.access = normalize_access(access)
        if self.access not in {"RW", "RO", "WO"}:
            raise ValueError(f"Memory can only be RW, RO or WO (saw {access})")
        self.mem_partial_write_support = False
        self.write_to_ro_mem_ok = False
        self.read_to_wo_mem_ok = False
        self.data_intg_passthru = False

    def set_mem_partial_write_support(self, enable: bool) -> None:
        self.mem_partial_write_support = enable

    def get_mem_partial_write_support(self) -> bool:
        return self.mem_partial_write_support

    def set_data_intg_passthru(self, enable: bool) -> None:
        self.data_intg_passthru = enable

    def get_data_intg_passthru(self) -> bool:
        return self.data_intg_passthru

    def set_write_to_ro_mem_ok(self, ok: bool) -> None:
        self.write_to_ro_mem_ok = ok

    def get_write_to_ro_mem_ok(self) -> bool:
        return self.write_to_ro_mem_ok

    def set_read_to_wo_mem_ok(self, ok: bool) -> None:
        self.read_to_wo_mem_ok = ok

    def get_read_to_wo_mem_ok(self) -> bool:
        return self.read_to_wo_mem_ok
