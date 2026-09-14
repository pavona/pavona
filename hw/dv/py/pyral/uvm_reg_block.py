# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Register block model."""

from __future__ import annotations

from collections import OrderedDict
from typing import Optional

from .uvm_mem import uvm_mem
from .uvm_reg import uvm_reg
from .uvm_reg_map import uvm_reg_map


class uvm_reg_block:
    """Generic register block container."""

    def __init__(self, name: str = "uvm_reg_block", has_coverage: int = 0):
        del has_coverage
        self.name = name
        self.parent: Optional[object] = None
        self.default_map: Optional[uvm_reg_map] = None
        self.maps: "OrderedDict[str, uvm_reg_map]" = OrderedDict()
        self.regs: "OrderedDict[str, uvm_reg]" = OrderedDict()
        self.blocks: "OrderedDict[str, uvm_reg_block]" = OrderedDict()
        self.mems: "OrderedDict[str, uvm_mem]" = OrderedDict()
        self.locked: bool = False
        self.hdl_path_root: str = ""

    def configure(self, parent=None, hdl_path: str = "") -> None:
        self.parent = parent
        self.hdl_path_root = hdl_path

    def build(self, base_addr: int = 0) -> None:
        del base_addr

    def create_map(
        self,
        name: str,
        base_addr: int,
        n_bytes: int,
        endian: str = "little",
        byte_addressing: bool = True,
    ) -> uvm_reg_map:
        reg_map = uvm_reg_map(name)
        reg_map.configure(self,
                          base_addr,
                          n_bytes,
                          endian=endian,
                          byte_addressing=byte_addressing)
        self.maps[name] = reg_map
        if self.default_map is None:
            self.default_map = reg_map
        return reg_map

    def add_reg(self, reg: uvm_reg) -> None:
        self.regs[reg.get_name()] = reg

    def add_block(self, block) -> None:
        self.blocks[block.get_name()] = block

    def add_mem(self, mem: uvm_mem) -> None:
        self.mems[mem.get_name()] = mem

    def get_name(self) -> str:
        return self.name

    def get_parent(self):
        return self.parent

    def get_reg_by_name(self, name: str) -> Optional[uvm_reg]:
        return self.regs.get(name)

    def get_map_by_name(self, name: str) -> Optional[uvm_reg_map]:
        return self.maps.get(name)

    def get_block_by_name(self, name: str):
        return self.blocks.get(name)

    def get_mem_by_name(self, name: str) -> Optional[uvm_mem]:
        return self.mems.get(name)

    def get_registers(self) -> list[uvm_reg]:
        regs = list(self.regs.values())
        for block in self.blocks.values():
            regs.extend(block.get_registers())
        return regs

    def get_blocks(self) -> list:
        return list(self.blocks.values())

    def get_memories(self) -> list[uvm_mem]:
        mems = list(self.mems.values())
        for block in self.blocks.values():
            mems.extend(block.get_memories())
        return mems

    def set_default_map(self, reg_map: uvm_reg_map) -> None:
        self.default_map = reg_map

    def lock_model(self) -> None:
        self.locked = True
        for block in self.blocks.values():
            block.lock_model()

    def is_locked(self) -> bool:
        return self.locked

    def reset(self, kind: str = "HARD") -> None:
        for reg in self.regs.values():
            reg.reset(kind)
        for mem in self.mems.values():
            mem.reset(kind)
        for block in self.blocks.values():
            block.reset(kind)
