# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Register map model."""

from __future__ import annotations

from collections import OrderedDict
from typing import Optional

from .uvm_mem import uvm_mem
from .uvm_reg import uvm_reg
from .uvm_reg_backdoor import uvm_reg_backdoor
from .uvm_reg_frontdoor import uvm_reg_frontdoor


class uvm_reg_map:
    """Generic address map with access binding hooks."""

    def __init__(self, name: str = "uvm_reg_map"):
        self.name = name
        self.parent: Optional[object] = None
        self.base_addr: int = 0
        self.n_bytes: int = 4
        self.endian: str = "little"
        self.byte_addressing: bool = True
        self.regs_by_name: "OrderedDict[str, uvm_reg]" = OrderedDict()
        self.regs_by_offset: "OrderedDict[int, uvm_reg]" = OrderedDict()
        self.mems_by_name: "OrderedDict[str, uvm_mem]" = OrderedDict()
        self.mems_by_offset: "OrderedDict[int, uvm_mem]" = OrderedDict()
        self.sequencer = None
        self.adapter = None
        self.frontdoor: Optional[uvm_reg_frontdoor] = None
        self.backdoor: Optional[uvm_reg_backdoor] = None
        self.policy: dict[str, object] = {}

    def configure(
        self,
        parent,
        base_addr: int,
        n_bytes: int,
        endian: str = "little",
        byte_addressing: bool = True,
    ) -> None:
        self.parent = parent
        self.base_addr = base_addr
        self.n_bytes = n_bytes
        self.endian = endian
        self.byte_addressing = byte_addressing

    def get_name(self) -> str:
        return self.name

    def add_reg(self,
                reg: uvm_reg,
                offset: int,
                rights: str = "RW",
                unmapped: bool = False) -> None:
        del rights, unmapped
        self.regs_by_name[reg.get_name()] = reg
        self.regs_by_offset[offset] = reg
        reg.add_map(self, offset)

    def add_mem(self,
                mem: uvm_mem,
                offset: int,
                rights: str = "RW",
                unmapped: bool = False) -> None:
        del rights, unmapped
        self.mems_by_name[mem.get_name()] = mem
        self.mems_by_offset[offset] = mem
        mem.add_map(self, offset)

    def get_reg_by_name(self, name: str) -> Optional[uvm_reg]:
        return self.regs_by_name.get(name)

    def get_reg_by_offset(self, offset: int) -> Optional[uvm_reg]:
        return self.regs_by_offset.get(offset)

    def get_registers(self) -> list[uvm_reg]:
        return list(self.regs_by_name.values())

    def get_mem_by_name(self, name: str) -> Optional[uvm_mem]:
        return self.mems_by_name.get(name)

    def get_mem_by_offset(self, offset: int) -> Optional[uvm_mem]:
        return self.mems_by_offset.get(offset)

    def get_memories(self) -> list[uvm_mem]:
        return list(self.mems_by_name.values())

    def set_sequencer(self, sequencer, adapter) -> None:
        self.sequencer = sequencer
        self.adapter = adapter

    def set_frontdoor(self, frontdoor: Optional[uvm_reg_frontdoor]) -> None:
        self.frontdoor = frontdoor

    def set_backdoor(self, backdoor: Optional[uvm_reg_backdoor]) -> None:
        self.backdoor = backdoor

    def set_base_addr(self, base_addr: int) -> None:
        self.base_addr = base_addr

    def get_parent(self):
        return self.parent
