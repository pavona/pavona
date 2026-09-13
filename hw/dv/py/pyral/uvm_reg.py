# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Register model."""

from __future__ import annotations

import asyncio
from collections import OrderedDict
from typing import Optional

from .uvm_reg_field import uvm_reg_field
from .uvm_reg_item import uvm_reg_item
from .uvm_reg_model import UVM_PATH, UVM_PREDICT, UVM_STATUS


class uvm_reg:
    """Generic register container with access normalization."""

    def __init__(self,
                 name: str = "uvm_reg",
                 n_bits: int = 32,
                 has_coverage: int = 0):
        del has_coverage
        self.name = name
        self.n_bits = n_bits
        self.parent: Optional[object] = None
        self.fields: "OrderedDict[str, uvm_reg_field]" = OrderedDict()
        self.offsets: dict[object, int] = {}
        self.desired: int = 0
        self.mirrored: int = 0
        self.reset_value: int = 0
        self.frontdoor = None
        self.backdoor = None
        self._access_lock = asyncio.Lock()
        self._last_rw: Optional[uvm_reg_item] = None

    def configure(self, parent, hdl_path: str = "") -> None:
        del hdl_path
        self.parent = parent

    def add_field(self, field: uvm_reg_field) -> None:
        self.fields[field.get_name()] = field
        self._sync_from_fields()

    def add_map(self, reg_map, offset: int) -> None:
        self.offsets[reg_map] = offset

    def get_name(self) -> str:
        return self.name

    def get_parent(self):
        return self.parent

    def get_n_bits(self) -> int:
        return self.n_bits

    def get_n_bytes(self) -> int:
        return max((self.n_bits + 7) // 8, 1)

    def get_fields(self) -> list[uvm_reg_field]:
        return list(self.fields.values())

    def get_field_by_name(self, name: str) -> Optional[uvm_reg_field]:
        return self.fields.get(name)

    def get_default_map(self):
        if self.parent is None:
            return None
        return getattr(self.parent, "default_map", None)

    def get_offset(self, reg_map=None) -> int:
        if reg_map is None:
            return next(iter(self.offsets.values()), 0)
        return self.offsets[reg_map]

    def get_address(self, reg_map=None) -> int:
        if reg_map is None:
            reg_map = self.get_default_map()
        if reg_map is None:
            raise RuntimeError(
                f"{self.get_name()}: no register map is available")
        return int(getattr(reg_map, "base_addr", 0)) + self.get_offset(reg_map)

    def set(self, value: int) -> None:
        self.desired = value & self.get_mask()
        self._scatter_to_fields(self.desired, update_mirror=False)

    def get(self) -> int:
        return self.desired

    def get_mirrored_value(self) -> int:
        return self.mirrored

    def get_reset(self) -> int:
        return self.reset_value

    def set_frontdoor(self, frontdoor) -> None:
        self.frontdoor = frontdoor

    def set_backdoor(self, backdoor) -> None:
        self.backdoor = backdoor

    def predict(
        self,
        value: int,
        kind: UVM_PREDICT = UVM_PREDICT.DIRECT,
        path: UVM_PATH = UVM_PATH.FRONTDOOR,
        reg_map=None,
        byte_en: int = -1,
    ) -> None:
        rw = uvm_reg_item(f"{self.get_name()}_predict")
        rw.element = self
        rw.element_kind = "REG"
        rw.kind = "WRITE" if kind != UVM_PREDICT.READ else "READ"
        rw.path = path
        rw.map = reg_map
        rw.byte_en = byte_en
        rw.status = UVM_STATUS.IS_OK
        rw.set_value(value & self.get_mask())
        self.do_predict(rw, kind=kind, byte_en=byte_en)

    def pre_do_predict(self, rw: uvm_reg_item, kind: UVM_PREDICT) -> None:
        del rw, kind

    def do_predict(self,
                   rw: uvm_reg_item,
                   kind: UVM_PREDICT = UVM_PREDICT.DIRECT,
                   byte_en: int = -1) -> None:
        del byte_en
        self.pre_do_predict(rw, kind)
        masked = rw.get_value() & self.get_mask()
        self.desired = masked
        self.mirrored = masked
        self._scatter_to_fields(self.mirrored,
                                update_mirror=True,
                                kind=kind,
                                reg_map=rw.map,
                                path=rw.path)

    def reset(self, kind: str = "HARD") -> None:
        del kind
        self.desired = self.reset_value
        self.mirrored = self.reset_value
        for field in self.fields.values():
            field.reset()
        self._sync_from_fields()
        self._access_lock = asyncio.Lock()

    def get_mask(self) -> int:
        return (1 << self.n_bits) - 1 if self.n_bits > 0 else 0

    def needs_update(self) -> bool:
        return self.get() != self.get_mirrored_value()

    async def take_lock(self) -> None:
        await self._access_lock.acquire()

    def release_lock(self) -> None:
        if self._access_lock.locked():
            self._access_lock.release()

    async def write(
        self,
        value: int,
        reg_map=None,
        path: UVM_PATH = UVM_PATH.DEFAULT,
        parent=None,
        extension=None,
    ):
        await self.take_lock()
        try:
            rw = self._create_rw("WRITE", value, reg_map, path, parent,
                                 extension)
            await self._do_access(rw)
            self._last_rw = rw
            if rw.status == UVM_STATUS.IS_OK:
                self.predict(rw.get_value(),
                             kind=UVM_PREDICT.WRITE,
                             path=rw.path,
                             reg_map=rw.map,
                             byte_en=rw.byte_en)
                await self.post_write(rw)
            return rw.status
        finally:
            self.release_lock()

    async def read(self,
                   reg_map=None,
                   path: UVM_PATH = UVM_PATH.DEFAULT,
                   parent=None,
                   extension=None):
        await self.take_lock()
        try:
            rw = self._create_rw("READ", 0, reg_map, path, parent, extension)
            await self._do_access(rw)
            self._last_rw = rw
            value = rw.get_value()
            if rw.status == UVM_STATUS.IS_OK:
                self.predict(value,
                             kind=UVM_PREDICT.READ,
                             path=rw.path,
                             reg_map=rw.map,
                             byte_en=rw.byte_en)
                await self.post_read(rw)
            return rw.status, value
        finally:
            self.release_lock()

    async def update(self,
                     reg_map=None,
                     path: UVM_PATH = UVM_PATH.DEFAULT,
                     parent=None,
                     extension=None):
        if self.get() == self.get_mirrored_value():
            return UVM_STATUS.IS_OK
        return await self.write(self.get(),
                                reg_map=reg_map,
                                path=path,
                                parent=parent,
                                extension=extension)

    async def mirror(self,
                     reg_map=None,
                     path: UVM_PATH = UVM_PATH.DEFAULT,
                     parent=None,
                     extension=None):
        return await self.read(reg_map=reg_map,
                               path=path,
                               parent=parent,
                               extension=extension)

    async def peek(self, kind: str = "", parent=None, extension=None):
        del kind
        return await self.read(path=UVM_PATH.BACKDOOR,
                               parent=parent,
                               extension=extension)

    async def poke(self,
                   value: int,
                   kind: str = "",
                   parent=None,
                   extension=None):
        del kind
        return await self.write(value,
                                path=UVM_PATH.BACKDOOR,
                                parent=parent,
                                extension=extension)

    def _create_rw(self, kind: str, value: int, reg_map, path: UVM_PATH,
                   parent, extension) -> uvm_reg_item:
        resolved_map = self._resolve_map(reg_map)
        rw = uvm_reg_item(f"{self.get_name()}_{kind.lower()}")
        rw.element = self
        rw.element_kind = "REG"
        rw.kind = kind
        rw.set_value(value & self.get_mask())
        rw.offset = self.get_offset(resolved_map)
        rw.map = resolved_map
        rw.local_map = resolved_map
        rw.path = path
        rw.parent = parent
        rw.extension = extension
        rw.n_bits = self.n_bits
        rw.byte_en = (1 << self.get_n_bytes()) - 1
        rw.bus_op.kind = kind
        rw.bus_op.addr = self.get_address(resolved_map)
        rw.bus_op.data = rw.get_value()
        rw.bus_op.n_bits = self.n_bits
        rw.bus_op.byte_en = rw.byte_en
        return rw

    def _resolve_map(self, reg_map=None):
        if reg_map is not None:
            return reg_map
        if self.get_default_map() is not None:
            return self.get_default_map()
        if self.offsets:
            return next(iter(self.offsets.keys()))
        raise RuntimeError(f"{self.get_name()}: no register map is available")

    def _resolve_path(self, reg_map, path: UVM_PATH) -> UVM_PATH:
        if path != UVM_PATH.DEFAULT:
            return path
        if self.backdoor is not None or getattr(reg_map, "backdoor",
                                                None) is not None:
            return UVM_PATH.BACKDOOR
        return UVM_PATH.FRONTDOOR

    async def _do_access(self, rw: uvm_reg_item) -> None:
        reg_map = rw.map
        rw.path = self._resolve_path(reg_map, rw.path)
        if rw.path == UVM_PATH.BACKDOOR:
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

    async def post_read(self, rw: uvm_reg_item) -> None:
        del rw

    async def post_write(self, rw: uvm_reg_item) -> None:
        del rw

    def _scatter_to_fields(
        self,
        value: int,
        update_mirror: bool,
        kind: UVM_PREDICT = UVM_PREDICT.DIRECT,
        reg_map=None,
        path: UVM_PATH = UVM_PATH.FRONTDOOR,
    ) -> None:
        for field in self.fields.values():
            field_value = (value >> field.get_lsb_pos()) & field.get_mask()
            field.set(field_value)
            if update_mirror:
                field.predict(field_value,
                              kind=kind,
                              reg_map=reg_map,
                              path=path)

    def _sync_from_fields(self) -> None:
        packed = 0
        reset_value = 0
        for field in self.fields.values():
            packed |= (field.get() & field.get_mask()) << field.get_lsb_pos()
            if field.has_reset:
                reset_value |= (field.reset_value &
                                field.get_mask()) << field.get_lsb_pos()
        self.desired = packed
        self.mirrored = packed
        self.reset_value = reset_value
