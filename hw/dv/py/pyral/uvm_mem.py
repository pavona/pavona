# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Memory model scaffold."""

from __future__ import annotations

from typing import Optional

from .uvm_reg_item import uvm_reg_item
from .uvm_reg_model import UVM_PATH, UVM_PREDICT, UVM_STATUS


class uvm_mem:
    """Generic memory model with sparse mirrored state."""

    def __init__(self, name: str = "uvm_mem", size: int = 0, n_bits: int = 32):
        self.name = name
        self.size = size
        self.n_bits = n_bits
        self.parent: Optional[object] = None
        self.offsets: dict[object, int] = {}
        self.frontdoor = None
        self.backdoor = None
        self.access: str = "RW"
        self.desired: dict[int, int] = {}
        self.mirrored: dict[int, int] = {}
        self.reset_values: dict[int, int] = {}

    def configure(self, parent, hdl_path: str = "") -> None:
        del hdl_path
        self.parent = parent

    def get_name(self) -> str:
        return self.name

    def get_parent(self):
        return self.parent

    def add_map(self, reg_map, offset: int) -> None:
        self.offsets[reg_map] = offset

    def get_offset(self, reg_map=None) -> int:
        if reg_map is None:
            return next(iter(self.offsets.values()), 0)
        return self.offsets[reg_map]

    def get_size(self) -> int:
        return self.size

    def get_n_bits(self) -> int:
        return self.n_bits

    def get_n_bytes(self) -> int:
        return max((self.n_bits + 7) // 8, 1)

    def get_access(self) -> str:
        return self.access

    def get_address(self, index: int = 0, reg_map=None) -> int:
        if reg_map is None:
            reg_map = getattr(self.parent, "default_map", None)
        if reg_map is None:
            raise RuntimeError(
                f"{self.get_name()}: no register map is available")
        return int(getattr(
            reg_map, "base_addr",
            0)) + self.get_offset(reg_map) + (index * max(reg_map.n_bytes, 1))

    def set_frontdoor(self, frontdoor) -> None:
        self.frontdoor = frontdoor

    def set_backdoor(self, backdoor) -> None:
        self.backdoor = backdoor

    def set(self, index: int, value: int) -> None:
        self.desired[index] = value & self.get_mask()

    def get(self, index: int, default: int = 0) -> int:
        return self.desired.get(index, default) & self.get_mask()

    def get_mirrored_value(self, index: int, default: int = 0) -> int:
        return self.mirrored.get(index, default) & self.get_mask()

    def get_mask(self) -> int:
        return (1 << self.n_bits) - 1 if self.n_bits > 0 else 0

    def predict(self,
                index: int,
                value: int,
                kind: UVM_PREDICT = UVM_PREDICT.DIRECT) -> None:
        del kind
        masked = value & self.get_mask()
        self.desired[index] = masked
        self.mirrored[index] = masked

    def reset(self, kind: str = "HARD") -> None:
        del kind
        self.desired = {
            index: value & self.get_mask()
            for index, value in self.reset_values.items()
        }
        self.mirrored = dict(self.desired)

    async def read(self,
                   index: int,
                   reg_map=None,
                   path: UVM_PATH = UVM_PATH.DEFAULT,
                   parent=None,
                   extension=None):
        rw = self._create_item("READ", index, 0, reg_map, path, parent,
                               extension)
        await self._do_access(rw)
        value = rw.get_value()
        if rw.status == UVM_STATUS.IS_OK:
            self.predict(index, value, kind=UVM_PREDICT.READ)
        return rw.status, value

    async def write(
        self,
        index: int,
        value: int,
        reg_map=None,
        path: UVM_PATH = UVM_PATH.DEFAULT,
        parent=None,
        extension=None,
    ):
        rw = self._create_item("WRITE", index, value, reg_map, path, parent,
                               extension)
        await self._do_access(rw)
        if rw.status == UVM_STATUS.IS_OK:
            self.predict(index, value, kind=UVM_PREDICT.WRITE)
        return rw.status

    def _create_item(self, kind: str, index: int, value: int, reg_map,
                     path: UVM_PATH, parent, extension):
        resolved_map = reg_map or getattr(self.parent, "default_map", None)
        rw = uvm_reg_item(f"{self.get_name()}_{kind.lower()}")
        rw.element = self
        rw.element_kind = "MEM"
        rw.kind = kind
        rw.set_value(value & self.get_mask())
        rw.offset = self.get_offset(resolved_map)
        rw.map = resolved_map
        rw.local_map = resolved_map
        rw.path = path
        rw.parent = parent
        rw.extension = extension
        rw.n_bits = self.n_bits
        rw.bus_op.kind = kind
        rw.bus_op.addr = self.get_address(index, resolved_map)
        rw.bus_op.data = rw.get_value()
        rw.bus_op.n_bits = self.n_bits
        return rw

    async def _do_access(self, rw: uvm_reg_item) -> None:
        reg_map = rw.map
        actual_path = rw.path
        if actual_path == UVM_PATH.DEFAULT:
            actual_path = UVM_PATH.BACKDOOR if self.backdoor is not None else UVM_PATH.FRONTDOOR
        rw.path = actual_path
        if actual_path == UVM_PATH.BACKDOOR:
            backdoor = self.backdoor or getattr(reg_map, "backdoor", None)
            if backdoor is None:
                raise RuntimeError(
                    f"{self.get_name()}: no backdoor is configured")
            if rw.kind == "READ":
                await backdoor.read(rw)
            else:
                await backdoor.write(rw)
            return
        frontdoor = self.frontdoor or getattr(reg_map, "frontdoor", None)
        if frontdoor is None:
            raise RuntimeError(
                f"{self.get_name()}: no frontdoor is configured")
        await frontdoor.execute(rw, reg_map)
