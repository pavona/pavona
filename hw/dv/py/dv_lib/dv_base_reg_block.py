# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""DV-specific register block overlay."""

from __future__ import annotations

from dataclasses import dataclass
from pyral import uvm_reg_block


@dataclass
class addr_range_t:
    start_addr: int
    end_addr: int


class dv_base_reg_block(uvm_reg_block):
    """DV block semantics layered on top of pyral."""

    def __init__(self, name: str = "dv_base_reg_block", has_coverage: int = 0):
        super().__init__(name=name, has_coverage=has_coverage)
        self.addr_width = 64
        self.data_width = 32
        self.be_width = 4
        self.ip_name = ""
        self.csr_excl = None
        self.addr_mask: dict[object, int] = {}
        self.csr_addrs: list[int] = []
        self.mem_ranges: list[addr_range_t] = []
        self.mapped_addr_ranges: list[addr_range_t] = []
        self.unmapped_access_ok = False
        self.supports_byte_enable = True
        self.supports_sub_word_csr_writes = False
        self.en_dv_reg_cov = True
        self.has_unmapped_addrs = False
        self.unmapped_addr_ranges: list[addr_range_t] = []
        self.register_alias_lookup: dict[str, str] = {}
        self.field_alias_lookup: dict[str, str] = {}

    def set_ip_name(self, name: str) -> None:
        self.ip_name = name

    def create_map(
        self,
        name: str,
        base_addr: int,
        n_bytes: int,
        endian: str = "little",
        byte_addressing: bool = True,
    ):
        from .dv_base_reg_map import dv_base_reg_map

        reg_map = dv_base_reg_map(name)
        reg_map.configure(self,
                          base_addr,
                          n_bytes,
                          endian=endian,
                          byte_addressing=byte_addressing)
        self.maps[name] = reg_map
        if self.default_map is None:
            self.default_map = reg_map
        return reg_map

    def get_ip_name(self) -> str:
        if not self.ip_name:
            raise RuntimeError("ip_name hasn't been set yet")
        return self.ip_name

    def get_excl_item(self):
        return self.csr_excl

    def set_unmapped_access_ok(self, ok: bool) -> None:
        self.unmapped_access_ok = ok

    def get_unmapped_access_ok(self) -> bool:
        return self.unmapped_access_ok

    def set_supports_byte_enable(self, enable: bool) -> None:
        self.supports_byte_enable = enable

    def get_supports_byte_enable(self) -> bool:
        return self.supports_byte_enable

    def set_supports_sub_word_csr_writes(self, enable: bool) -> None:
        self.supports_sub_word_csr_writes = enable

    def get_supports_sub_word_csr_writes(self) -> bool:
        return self.supports_sub_word_csr_writes

    def get_dv_base_reg_blocks(self):
        return [
            blk for blk in self.get_blocks()
            if isinstance(blk, dv_base_reg_block)
        ]

    def get_dv_base_regs(self):
        from .dv_base_reg import dv_base_reg

        return [
            reg for reg in self.get_registers()
            if isinstance(reg, dv_base_reg)
        ]

    def get_dv_base_reg_by_name(self,
                                csr_name: str,
                                check_csr_exist: bool = True):
        reg = self.get_reg_by_name(csr_name)
        if reg is None and check_csr_exist:
            raise KeyError(
                f"{csr_name} does not exist in block {self.get_name()}")
        return reg

    def get_shadowed_regs(self):
        return [
            reg for reg in self.get_dv_base_regs() if reg.get_is_shadowed()
        ]

    def has_shadowed_regs(self) -> bool:
        return bool(self.get_shadowed_regs())

    def _compute_addr_mask(self, reg_map) -> None:
        blocks = self.get_blocks()
        if blocks:
            self.addr_mask[reg_map] = (1 << self.addr_width) - 1
            return
        max_offset = self.get_max_offset(reg_map)
        alignment = 0
        while max_offset > 0:
            alignment += 1
            max_offset >>= 1
        if alignment <= 0:
            raise RuntimeError(
                "Cannot compute address mask for an empty register block")
        self.addr_mask[reg_map] = (1 << alignment) - 1

    def compute_csr_addrs(self) -> None:
        self.csr_addrs = [csr.get_address() for csr in self.regs.values()]

    def compute_mem_addr_ranges(self) -> None:
        self.mem_ranges = []
        for mem in self.mems.values():
            start = mem.get_address()
            end = start + mem.get_size() * mem.get_n_bytes() - 1
            self.mem_ranges.append(addr_range_t(start, end))

    def compute_mapped_addr_ranges(self) -> None:
        self.compute_csr_addrs()
        self.compute_mem_addr_ranges()
        self.mapped_addr_ranges = []
        for csr in self.regs.values():
            start = csr.get_address()
            self.mapped_addr_ranges.append(
                addr_range_t(start, start + csr.get_n_bytes() - 1))
        self.mapped_addr_ranges.extend(self.mem_ranges)
        self.mapped_addr_ranges.sort(key=lambda item: item.start_addr)

    def compute_unmapped_addr_ranges(self) -> None:
        self.compute_mapped_addr_ranges()
        highest_addr = self.default_map.base_addr + self.get_addr_mask()
        self.unmapped_addr_ranges = []
        if not self.mapped_addr_ranges:
            self.unmapped_addr_ranges.append(
                addr_range_t(self.default_map.base_addr, highest_addr))
        else:
            first = self.mapped_addr_ranges[0]
            if first.start_addr > self.default_map.base_addr:
                self.unmapped_addr_ranges.append(
                    addr_range_t(self.default_map.base_addr,
                                 first.start_addr - 1))
            for left, right in zip(self.mapped_addr_ranges,
                                   self.mapped_addr_ranges[1:]):
                if left.end_addr + 1 < right.start_addr:
                    self.unmapped_addr_ranges.append(
                        addr_range_t(left.end_addr + 1, right.start_addr - 1))
            last = self.mapped_addr_ranges[-1]
            if last.end_addr < highest_addr:
                self.unmapped_addr_ranges.append(
                    addr_range_t(last.end_addr + 1, highest_addr))
        self.has_unmapped_addrs = bool(self.unmapped_addr_ranges)

    def get_max_offset(self, reg_map=None) -> int:
        if reg_map is None:
            reg_map = self.default_map
        regs = self.regs.values()
        mems = self.mems.values()
        if not regs and not mems:
            raise RuntimeError(
                "Cannot compute max offset for an empty register block")
        max_offset = 0
        for reg in regs:
            max_offset = max(max_offset,
                             reg.get_offset(reg_map) + reg.get_n_bytes() - 1)
        for mem in mems:
            max_offset = max(
                max_offset,
                mem.get_offset(reg_map) + mem.get_size() * mem.get_n_bytes() -
                1)
        return max_offset

    def get_addr_mask(self, reg_map=None) -> int:
        if not self.is_locked():
            raise RuntimeError(
                "Address mask is only defined after the model is locked")
        if reg_map is None:
            reg_map = self.default_map
        if reg_map not in self.addr_mask:
            self._compute_addr_mask(reg_map)
        return self.addr_mask[reg_map]

    def set_base_addr(self,
                      base_addr: int,
                      reg_map=None,
                      randomize_base_addr: bool = False) -> int:
        del randomize_base_addr
        if reg_map is None:
            reg_map = self.default_map
        mask = self.get_addr_mask(reg_map)
        if base_addr & mask:
            raise ValueError(
                f"Base address 0x{base_addr:x} is not aligned to mask 0x{mask:x}"
            )
        reg_map.set_base_addr(base_addr)
        return base_addr

    def get_word_aligned_addr(self, byte_addr: int) -> int:
        shift = max((self.be_width.bit_length() - 1), 0)
        return (byte_addr >> shift) << shift

    def get_addr_from_offset(self,
                             byte_offset: int,
                             word_aligned: bool = True,
                             reg_map=None) -> int:
        if reg_map is None:
            reg_map = self.default_map
        offset = self.get_word_aligned_addr(
            byte_offset) if word_aligned else byte_offset
        return offset + reg_map.base_addr

    def get_normalized_addr(self, byte_addr: int, reg_map=None) -> int:
        if reg_map is None:
            reg_map = self.default_map
        return self.get_addr_from_offset(byte_addr &
                                         self.get_addr_mask(reg_map),
                                         word_aligned=True,
                                         reg_map=reg_map)

    def set_default_map_w_subblks_by_name(self, map_name: str) -> None:
        reg_map = self.get_map_by_name(map_name)
        if reg_map is None:
            raise KeyError(
                f"Map {map_name} does not exist in {self.get_name()}")
        self.set_default_map(reg_map)
        for block in self.get_dv_base_reg_blocks():
            block.set_default_map_w_subblks_by_name(map_name)

    def get_reg_by_name(self, name: str):
        mapped = self.register_alias_lookup.get(name, name)
        return super().get_reg_by_name(mapped)

    def get_field_by_name(self, name: str):
        mapped = self.field_alias_lookup.get(name, name)
        for reg in self.get_registers():
            field = reg.get_field_by_name(mapped)
            if field is not None:
                return field
        return None

    def set_en_dv_reg_cov(self, val: bool) -> None:
        if self.regs:
            raise RuntimeError(
                "Cannot set en_dv_reg_cov after the register model is built")
        self.en_dv_reg_cov = val

    def get_en_dv_reg_cov(self) -> bool:
        return self.en_dv_reg_cov
