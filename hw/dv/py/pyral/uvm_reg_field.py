# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Register field model."""

from __future__ import annotations

from typing import Optional

from .uvm_reg_item import uvm_reg_item
from .uvm_reg_model import UVM_PATH, UVM_PREDICT, UVM_STATUS, normalize_access


class uvm_reg_field:
    """Generic register field with parent-register normalization."""

    def __init__(self, name: str = "uvm_reg_field"):
        self.name = name
        self.parent: Optional[object] = None
        self.size: int = 0
        self.lsb_pos: int = 0
        self.access: str = "RW"
        self.volatile: bool = False
        self.reset_value: int = 0
        self.has_reset: bool = True
        self.is_rand: bool = False
        self.individually_accessible: bool = False
        self.desired: int = 0
        self.mirrored: int = 0

    def configure(
        self,
        parent,
        size: int,
        lsb_pos: int,
        access: str = "RW",
        volatile: bool = False,
        reset: int = 0,
        has_reset: bool = True,
        is_rand: bool = False,
        individually_accessible: bool = False,
    ) -> None:
        self.parent = parent
        self.size = size
        self.lsb_pos = lsb_pos
        self.access = normalize_access(access)
        self.volatile = volatile
        self.reset_value = reset
        self.has_reset = has_reset
        self.is_rand = is_rand
        self.individually_accessible = individually_accessible
        self.desired = reset if has_reset else 0
        self.mirrored = reset if has_reset else 0

    def get_name(self) -> str:
        return self.name

    def get_n_bits(self) -> int:
        return self.size

    def get_lsb_pos(self) -> int:
        return self.lsb_pos

    def get_parent(self):
        return self.parent

    def get_access(self, reg_map=None) -> str:
        del reg_map
        return self.access

    def set_access(self, access: str) -> str:
        self.access = normalize_access(access)
        return self.access

    def get_mask(self) -> int:
        return (1 << self.size) - 1 if self.size > 0 else 0

    def get_reset(self) -> int:
        return self.reset_value & self.get_mask()

    def set(self, value: int) -> None:
        self.desired = value & self.get_mask()

    def get(self) -> int:
        return self.desired

    def get_mirrored_value(self) -> int:
        return self.mirrored

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
        rw.element_kind = "FIELD"
        rw.kind = "WRITE" if kind != UVM_PREDICT.READ else "READ"
        rw.path = path
        rw.map = reg_map
        rw.byte_en = byte_en
        rw.status = UVM_STATUS.IS_OK
        rw.set_value(value & self.get_mask())
        self.do_predict(rw, kind=kind, byte_en=byte_en)

    def do_predict(self,
                   rw: uvm_reg_item,
                   kind: UVM_PREDICT = UVM_PREDICT.DIRECT,
                   byte_en: int = -1) -> None:
        del kind, byte_en
        masked = rw.get_value() & self.get_mask()
        self.desired = masked
        self.mirrored = masked

    def XpredictX(self, cur_val: int, wr_val: int, reg_map=None) -> int:
        del cur_val, reg_map
        return wr_val & self.get_mask()

    def XupdateX(self) -> int:
        return self.get()

    def reset(self, kind: str = "HARD") -> None:
        del kind
        if self.has_reset:
            self.desired = self.reset_value & self.get_mask()
            self.mirrored = self.reset_value & self.get_mask()

    def get_register_mask(self) -> int:
        return self.get_mask() << self.get_lsb_pos()

    def extract_from_register(self, reg_value: int) -> int:
        return (reg_value >> self.get_lsb_pos()) & self.get_mask()

    def insert_into_register(self, reg_value: int, field_value: int) -> int:
        register_mask = self.get_register_mask()
        masked_field = (field_value & self.get_mask()) << self.get_lsb_pos()
        return (reg_value & ~register_mask) | masked_field

    def _require_parent(self):
        if self.parent is None:
            raise RuntimeError(
                f"{self.get_name()}: parent register is not configured")
        return self.parent

    async def read(self,
                   reg_map=None,
                   path: UVM_PATH = UVM_PATH.DEFAULT,
                   parent=None,
                   extension=None):
        reg = self._require_parent()
        status, reg_value = await reg.read(reg_map=reg_map,
                                           path=path,
                                           parent=parent,
                                           extension=extension)
        await self.post_read(getattr(reg, "_last_rw", None))
        return status, self.extract_from_register(reg_value)

    async def write(
        self,
        value: int,
        reg_map=None,
        path: UVM_PATH = UVM_PATH.DEFAULT,
        parent=None,
        extension=None,
    ):
        reg = self._require_parent()
        reg_value = self.insert_into_register(reg.get_mirrored_value(), value)
        status = await reg.write(reg_value,
                                 reg_map=reg_map,
                                 path=path,
                                 parent=parent,
                                 extension=extension)
        await self.post_write(getattr(reg, "_last_rw", None))
        return status

    async def update(self,
                     reg_map=None,
                     path: UVM_PATH = UVM_PATH.DEFAULT,
                     parent=None,
                     extension=None):
        reg = self._require_parent()
        reg_value = self.insert_into_register(reg.get_mirrored_value(),
                                              self.get())
        if reg_value == reg.get_mirrored_value():
            return UVM_STATUS.IS_OK
        return await reg.write(reg_value,
                               reg_map=reg_map,
                               path=path,
                               parent=parent,
                               extension=extension)

    async def mirror(self,
                     reg_map=None,
                     path: UVM_PATH = UVM_PATH.DEFAULT,
                     parent=None,
                     extension=None):
        reg = self._require_parent()
        status, reg_value = await reg.mirror(reg_map=reg_map,
                                             path=path,
                                             parent=parent,
                                             extension=extension)
        await self.post_read(getattr(reg, "_last_rw", None))
        return status, self.extract_from_register(reg_value)

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

    async def post_read(self, rw) -> None:
        del rw

    async def post_write(self, rw) -> None:
        del rw
