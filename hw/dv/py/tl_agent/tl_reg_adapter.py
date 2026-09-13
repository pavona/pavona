# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink register adapter helper.

Lightweight Python port of SV `tl_reg_adapter`: converts register operations to
`tl_seq_item` and maps TL responses back to register op status/data.
"""

from dataclasses import dataclass
from typing import Any, Optional

try:
    from pyuvm import UVM_READ, UVM_WRITE
except ImportError:
    UVM_READ = "UVM_READ"
    UVM_WRITE = "UVM_WRITE"

from .tl_seq_item import MaskWidth, tl_seq_item


@dataclass
class tl_reg_bus_op:
    """Minimal register bus op container used by tl_reg_adapter."""

    kind: str  # "READ" or "WRITE"
    addr: int
    data: int = 0
    byte_en: int = (1 << MaskWidth) - 1
    status: str = "UNKNOWN"


class tl_reg_adapter:
    """Translate reg operations to TL items and TL responses back to reg ops."""

    def __init__(self, cfg: Optional[Any] = None):
        self.cfg = cfg
        self.supports_byte_enable = True
        self.provides_responses = True

    def reg2bus(self, rw: tl_reg_bus_op) -> tl_seq_item:
        req = tl_seq_item("bus_req")
        req.a_addr = int(rw.addr)
        req.a_mask = int(
            rw.byte_en) if self.supports_byte_enable else (1 << MaskWidth) - 1

        if str(rw.kind).upper() == "READ":
            req.a_opcode = 4  # Get
        else:
            req.a_opcode = 0 if req.a_mask == (
                1 << MaskWidth) - 1 else 1  # PutFullData/PutPartialData
            req.a_data = int(rw.data)

        return req

    def bus2reg(self, bus_rsp: tl_seq_item, rw: tl_reg_bus_op) -> None:
        is_write_fn = getattr(bus_rsp, "is_write", None)
        if callable(is_write_fn):
            rw.kind = UVM_WRITE if bool(is_write_fn()) else UVM_READ
        elif bus_rsp.a_opcode in (0, 1):
            rw.kind = UVM_WRITE
        elif bus_rsp.a_opcode == 4:
            rw.kind = UVM_READ
        else:
            rw.kind = UVM_READ
        is_write = rw.kind == UVM_WRITE
        rw.addr = int(bus_rsp.a_addr)
        rw.byte_en = int(bus_rsp.a_mask)
        rw.data = int(bus_rsp.a_data) if is_write else int(bus_rsp.d_data)
        rw.status = "IS_OK" if bool(bus_rsp.req_completed) else "NOT_OK"
