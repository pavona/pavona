# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""DV-specific register overlay."""

from __future__ import annotations

import asyncio

from pyral import UVM_PATH, UVM_PREDICT, uvm_reg

from .dv_base_reg_field import _mubi_true, dv_base_reg_field


class dv_base_reg(uvm_reg):
    """DV register semantics layered on top of pyral."""

    def __init__(self,
                 name: str = "dv_base_reg",
                 n_bits: int = 32,
                 has_coverage: int = 0):
        super().__init__(name=name, n_bits=n_bits, has_coverage=has_coverage)
        self.is_ext_reg = False
        self.is_shadowed = False
        self.shadow_wr_staged = False
        self.shadow_update_err = False
        self.backdoor_write_shadow_val = False
        self.do_update_shadow_vals = False
        self.shadow_fatal_lock = False
        self.update_err_alert_name = ""
        self.storage_err_alert_name = ""
        self.writes_ignore_errors = False
        self.alias_name = ""
        self.field_alias_lookup: dict[str, str] = {}
        self.atomic_en_shadow_wr = asyncio.Lock()

    def get_dv_base_reg_fields(self) -> list[dv_base_reg_field]:
        return [
            fld for fld in self.get_fields()
            if isinstance(fld, dv_base_reg_field)
        ]

    def get_dv_base_reg_block(self):
        parent = self.get_parent()
        if parent is None:
            raise RuntimeError(
                f"{self.get_name()}: parent block is not configured")
        return parent

    def get_alias_name(self) -> str:
        return self.alias_name

    def set_alias_name(self, alias_name: str) -> None:
        reg_block = self.get_dv_base_reg_block()
        reg_block.register_alias_lookup[alias_name] = self.get_name()
        self.alias_name = alias_name

    def get_predicted_mask(self) -> int:
        mask = 0
        for field in self.get_dv_base_reg_fields():
            if field.has_prediction:
                mask |= field.get_field_mask()
        return mask

    def get_n_used_bits(self) -> int:
        return sum(field.get_n_bits() for field in self.get_fields())

    def get_msb_pos(self) -> int:
        return max((field.get_lsb_pos() + field.get_n_bits() - 1)
                   for field in self.get_fields())

    def get_dv_base_reg_field_by_name(
            self,
            fld_name: str,
            check_fld_exist: bool = True) -> dv_base_reg_field | None:
        field = self.get_field_by_name(fld_name)
        if field is None and check_fld_exist:
            raise KeyError(
                f"{fld_name} does not exist in reg {self.get_name()}")
        return field

    def get_reg_mask(self) -> int:
        return sum(field.get_field_mask()
                   for field in self.get_dv_base_reg_fields())

    def get_ro_mask(self) -> int:
        return sum(field.get_ro_mask()
                   for field in self.get_dv_base_reg_fields())

    def add_lockable_reg_or_fld(self, lockable_obj) -> None:
        fields = self.get_dv_base_reg_fields()
        if len(fields) != 1:
            raise RuntimeError(
                "Register has more than one field; use the field-level method instead"
            )
        fields[0].add_lockable_reg_or_fld(lockable_obj)

    def locks_reg_or_fld(self, obj) -> bool:
        fields = self.get_dv_base_reg_fields()
        if len(fields) != 1:
            raise RuntimeError(
                "Register has more than one field; use the field-level method instead"
            )
        return fields[0].locks_reg_or_fld(obj)

    def get_lockable_flds(self) -> list[dv_base_reg_field]:
        fields = self.get_dv_base_reg_fields()
        if len(fields) != 1:
            raise RuntimeError(
                "Register has more than one field; use the field-level method instead"
            )
        return fields[0].get_lockable_flds()

    def is_wen_reg(self) -> bool:
        return any(field.is_wen_fld()
                   for field in self.get_dv_base_reg_fields())

    def is_staged(self) -> bool:
        return self.shadow_wr_staged

    def set_is_shadowed(self) -> None:
        self.is_shadowed = True

    def clear_shadow_wr_staged(self) -> None:
        if self.is_shadowed:
            self.shadow_wr_staged = False
            self.clear_shadow_update_err()

    def get_is_shadowed(self) -> bool:
        return self.is_shadowed

    def get_shadow_update_err(self) -> bool:
        return self.shadow_update_err

    def get_shadow_storage_err(self) -> bool:
        return any(field.get_shadow_storage_err()
                   for field in self.get_dv_base_reg_fields())

    def clear_shadow_update_err(self) -> None:
        self.shadow_update_err = False

    def _field_value(self, field: dv_base_reg_field, reg_value: int) -> int:
        return (reg_value >> field.get_lsb_pos()) & field.get_mask()

    def pre_do_predict(self, rw, kind: UVM_PREDICT) -> None:
        if rw.status.name != "IS_OK" or kind != UVM_PREDICT.WRITE or self.backdoor_write_shadow_val:
            return
        if self.is_shadowed and not self.shadow_fatal_lock:
            fields = self.get_dv_base_reg_fields()
            for field in fields:
                wr_data = self._field_value(field, rw.get_value())
                if field.get_shadow_storage_err() or field.get_access(
                ) == "RO":
                    continue
                if not self.shadow_wr_staged:
                    field.update_staged_val(wr_data)
                    continue
                if field.get_staged_val() == wr_data:
                    field.update_committed_val(wr_data)
                    field.update_shadowed_val(~wr_data)
                else:
                    self.shadow_update_err = True
            self.shadow_wr_staged = not self.shadow_wr_staged
            if not self.shadow_wr_staged and fields and fields[0].get_access(
            ) != "RW":
                self.do_update_shadow_vals = True

    def do_predict(self,
                   rw,
                   kind: UVM_PREDICT = UVM_PREDICT.DIRECT,
                   byte_en: int = -1) -> None:
        self.pre_do_predict(rw, kind)
        if self.is_shadowed and kind != UVM_PREDICT.READ:
            if self.shadow_wr_staged or (self.shadow_fatal_lock and
                                         rw.path != UVM_PATH.BACKDOOR):
                return
            rw.set_value(self.get_committed_val())
        super().do_predict(rw, kind=kind, byte_en=byte_en)
        if self.is_shadowed and kind != UVM_PREDICT.READ and not self.shadow_fatal_lock:
            self.shadow_wr_staged = False
        if self.do_update_shadow_vals:
            for field in self.get_dv_base_reg_fields():
                if not field.get_shadow_storage_err():
                    field.update_committed_val(field.get_mirrored_value())
                    field.update_shadowed_val(~field.get_mirrored_value())
            self.do_update_shadow_vals = False
        self.lock_lockable_flds(rw.get_value(), kind)

    def lock_lockable_flds(self, val: int, kind: UVM_PREDICT) -> None:
        if not self.is_wen_reg():
            return
        for field in self.get_dv_base_reg_fields():
            if not field.is_wen_fld():
                continue
            field_val = val & field.get_field_mask()
            field_access = field.get_access()
            if field_access == "RO":
                continue
            if field.get_mubi_width() == 0:
                if field_access not in {"W0C", "RW0C"}:
                    raise RuntimeError(
                        f"{field.get_name()}: field has access "
                        f"{field_access} and is not a MuBi type"
                    )
                if kind == UVM_PREDICT.WRITE and field_val == 0:
                    field.set_lockable_flds_access(True)
                elif kind == UVM_PREDICT.DIRECT:
                    field.set_lockable_flds_access(
                        bool((~field_val) & field.get_field_mask()))
            else:
                if field_access != "RW":
                    raise RuntimeError(
                        f"{field.get_name()}: field has access {field_access} but is a MuBi type"
                    )
                encoded_true = _mubi_true(
                    field.get_mubi_width()) & field.get_field_mask()
                if field_val != encoded_true:
                    field.set_lockable_flds_access(True)

    async def poke(self,
                   value: int,
                   kind: str = "",
                   parent=None,
                   extension=None):
        for field in self.get_dv_base_reg_fields():
            if kind == "BkdrRegPathRtlShadow":
                field.update_shadowed_val(self._field_value(field, value))
                self.backdoor_write_shadow_val = True
            elif kind in {"", "BkdrRegPathRtl"}:
                field.update_committed_val(self._field_value(field, value))
                self.backdoor_write_shadow_val = True
        try:
            return await super().poke(value,
                                      kind=kind,
                                      parent=parent,
                                      extension=extension)
        finally:
            self.backdoor_write_shadow_val = False

    def get_committed_val(self) -> int:
        val = 0
        for field in self.get_dv_base_reg_fields():
            val |= field.get_committed_val() << field.get_lsb_pos()
        return val & self.get_mask()

    def reset(self, kind: str = "HARD") -> None:
        super().reset(kind)
        if self.is_shadowed:
            self.shadow_update_err = False
            self.shadow_wr_staged = False
            self.shadow_fatal_lock = False
            self.atomic_en_shadow_wr = asyncio.Lock()

    def add_update_err_alert(self, name: str) -> None:
        if not self.update_err_alert_name:
            self.update_err_alert_name = name

    def add_storage_err_alert(self, name: str) -> None:
        if not self.storage_err_alert_name:
            self.storage_err_alert_name = name

    def get_update_err_alert_name(self) -> str:
        block = self.get_dv_base_reg_block()
        if block.get_parent() is None:
            return self.update_err_alert_name
        return f"{block.get_ip_name()}_{self.update_err_alert_name}"

    def lock_shadow_reg(self) -> None:
        self.shadow_fatal_lock = True

    def shadow_reg_is_locked(self) -> bool:
        return self.shadow_fatal_lock

    def get_storage_err_alert_name(self) -> str:
        block = self.get_dv_base_reg_block()
        if block.get_parent() is None:
            return self.storage_err_alert_name
        return f"{block.get_ip_name()}_{self.storage_err_alert_name}"

    def get_field_by_name(self, name: str):
        mapped = self.field_alias_lookup.get(name, name)
        return super().get_field_by_name(mapped)

    async def post_read(self, rw) -> None:
        del rw
        self.clear_shadow_wr_staged()

    def set_is_ext_reg(self, is_ext: bool) -> None:
        self.is_ext_reg = is_ext

    def get_is_ext_reg(self) -> bool:
        return self.is_ext_reg
