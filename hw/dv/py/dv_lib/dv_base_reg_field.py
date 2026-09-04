# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""DV-specific register field overlay."""

from __future__ import annotations

from typing import TYPE_CHECKING, Optional

from pyral import UVM_PREDICT, normalize_access, uvm_reg_field

if TYPE_CHECKING:
    from .dv_base_reg import dv_base_reg


def _mubi_true(width: int) -> int:
    return int("".join("10" for _ in range(width // 2)), 2)


def _mubi_false(width: int) -> int:
    return int("".join("01" for _ in range(width // 2)), 2)


class dv_base_reg_field(uvm_reg_field):
    """DV field semantics layered on top of pyral."""

    def __init__(self, name: str = "dv_base_reg_field"):
        super().__init__(name)
        self._original_access: str = ""
        self.lockable_flds: list[dv_base_reg_field] = []
        self.is_intr_test_fld: bool = False
        self.staged_val: int = 0
        self.committed_val: int = 0
        self.shadowed_val: int = 0
        self.regwen_fld: Optional[dv_base_reg_field] = None
        self.alias_name: str = ""
        self.mubi_access: str = ""
        self.mubi_width: int = 0
        self.has_prediction: bool = False

    def configure(
        self,
        parent,
        size: int,
        lsb_pos: int,
        access: str = "RW",
        mubi_access: str = "",
        volatile: bool = False,
        reset: int = 0,
        has_reset: bool = True,
        is_rand: bool = False,
        individually_accessible: bool = False,
    ) -> None:
        super().configure(
            parent=parent,
            size=size,
            lsb_pos=lsb_pos,
            access=access,
            volatile=volatile,
            reset=reset,
            has_reset=has_reset,
            is_rand=is_rand,
            individually_accessible=individually_accessible,
        )
        self.set_original_access(self.get_access())
        self.mubi_access = normalize_access(mubi_access) if mubi_access else ""
        self.is_intr_test_fld = self.get_parent(
        ) is not None and self.get_parent().get_name().startswith("intr_test")
        self.committed_val = self.get_mirrored_value()
        self.shadowed_val = (~self.committed_val) & self.get_mask()

    def get_dv_base_reg_parent(self) -> "dv_base_reg":
        parent = self.get_parent()
        if parent is None:
            raise RuntimeError(
                f"{self.get_name()}: parent register is not configured")
        return parent

    def get_alias_name(self) -> str:
        return self.alias_name

    def set_alias_name(self, alias_name: str) -> None:
        register = self.get_dv_base_reg_parent()
        reg_block = register.get_dv_base_reg_block()
        register.field_alias_lookup[alias_name] = self.get_name()
        reg_block.field_alias_lookup[alias_name] = self.get_name()
        self.alias_name = alias_name

    def get_original_access(self) -> str:
        return self._original_access

    def set_original_access(self, access: str) -> None:
        if self._original_access:
            raise RuntimeError(
                f"{self.get_name()}: original access can only be written once")
        self._original_access = normalize_access(access)

    def get_field_mask(self) -> int:
        return self.get_register_mask()

    def get_ro_mask(self) -> int:
        return self.get_register_mask() if self.get_access() == "RO" else 0

    def _set_fld_access(self, lock: bool) -> None:
        if lock:
            self.set_access("RO")
        else:
            self.set_access(self._original_access or self.get_access())

    def _normalize_lockable_obj(self, lockable_obj) -> list[dv_base_reg_field]:
        if isinstance(lockable_obj, dv_base_reg_field):
            return [lockable_obj]
        if hasattr(lockable_obj, "get_fields"):
            return [
                fld for fld in lockable_obj.get_fields()
                if isinstance(fld, dv_base_reg_field)
            ]
        raise TypeError(
            f"Unsupported lockable object type: {type(lockable_obj)!r}")

    def add_lockable_reg_or_fld(self, lockable_obj) -> None:
        reg_block = self.get_dv_base_reg_parent().get_dv_base_reg_block()
        if reg_block.is_locked():
            raise RuntimeError(
                "RAL is locked, cannot add lockable reg or field")
        for fld in self._normalize_lockable_obj(lockable_obj):
            self.lockable_flds.append(fld)
            fld.regwen_fld = self

    def locks_reg_or_fld(self, obj) -> bool:
        return any(fld in self.lockable_flds
                   for fld in self._normalize_lockable_obj(obj))

    def is_wen_fld(self) -> bool:
        return bool(self.lockable_flds)

    def set_lockable_flds_access(self, lock: bool) -> None:
        for fld in self.lockable_flds:
            fld._set_fld_access(lock)

    def get_lockable_flds(self) -> list[dv_base_reg_field]:
        return list(self.lockable_flds)

    def set_mubi_width(self, width: int) -> None:
        if self.get_dv_base_reg_parent().get_dv_base_reg_block().is_locked():
            raise RuntimeError(
                "Cannot set mubi width when the block is locked")
        self.mubi_width = width

    def get_mubi_width(self) -> int:
        return self.mubi_width

    def _mubi_or_hi(self, a: int, b: int) -> int:
        return (a | b) & self.get_mask()

    def _mubi_and_hi(self, a: int, b: int) -> int:
        return (a & b) & self.get_mask()

    def _mubi_false(self) -> int:
        if self.mubi_width <= 0:
            return 0
        return _mubi_false(self.mubi_width) & self.get_mask()

    def do_predict(self,
                   rw,
                   kind: UVM_PREDICT = UVM_PREDICT.DIRECT,
                   byte_en: int = -1) -> None:
        if kind == UVM_PREDICT.WRITE and self.mubi_access in {
                "W1S", "W1C", "W0C"
        }:
            if self.mubi_access == "W1S":
                rw.set_value(
                    self._mubi_or_hi(rw.get_value(),
                                     self.get_mirrored_value()))
            elif self.mubi_access == "W1C":
                rw.set_value(
                    self._mubi_and_hi(~rw.get_value(),
                                      self.get_mirrored_value()))
            elif self.mubi_access == "W0C":
                rw.set_value(
                    self._mubi_and_hi(rw.get_value(),
                                      self.get_mirrored_value()))
        elif kind == UVM_PREDICT.READ and self.mubi_access == "RC":
            rw.set_value(self._mubi_false())
        super().do_predict(rw, kind=kind, byte_en=byte_en)
        if kind != UVM_PREDICT.READ:
            self.committed_val = rw.get_value() & self.get_mask()

    def XpredictX(self, cur_val: int, wr_val: int, reg_map=None) -> int:
        if self.get_access(reg_map) == "WO":
            return self.get_reset()
        return super().XpredictX(cur_val, wr_val, reg_map)

    def get_shadow_storage_err(self) -> bool:
        return ((~self.shadowed_val) &
                self.get_mask()) != (self.committed_val & self.get_mask())

    def update_staged_val(self, val: int) -> None:
        self.staged_val = val & self.get_mask()

    def get_staged_val(self) -> int:
        return self.staged_val

    def update_shadowed_val(self, val: int) -> None:
        self.shadowed_val = val & self.get_mask()

    def update_committed_val(self, val: int) -> None:
        self.committed_val = val & self.get_mask()

    def get_committed_val(self) -> int:
        return self.committed_val

    async def post_read(self, rw) -> None:
        del rw
        self.get_dv_base_reg_parent().clear_shadow_wr_staged()

    def reset(self, kind: str = "HARD") -> None:
        super().reset(kind)
        self._set_fld_access(False)
        self.committed_val = self.get_mirrored_value()
        self.shadowed_val = (~self.committed_val) & self.get_mask()
        self.staged_val = self.committed_val
