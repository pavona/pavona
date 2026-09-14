# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink host sequence for a single caller-controlled request."""

from math import log2

from pyuvm import UVM_LOW

from ..tl_seq_item import (AddrWidth, DataWidth, Get, MaskWidth, OpcodeWidth,
                           PutFullData, PutPartialData, SizeWidth, SourceWidth,
                           tl_seq_item)
from .tl_host_seq import tl_host_seq


class tl_host_single_seq(tl_host_seq):
    """Send one request with most fields supplied by the caller."""

    def __init__(self, name: str = "tl_host_single_seq"):
        super().__init__(name)
        self.req_cnt = 1
        self.write: bool = False
        self.addr: int = 0
        self.opcode: int = Get
        self.size: int = 2
        self.source: int = 0
        self.mask: int = (1 << MaskWidth) - 1
        self.data: int = 0
        self.control_addr_alignment: bool = False
        self.control_rand_size: bool = False
        self.control_rand_source: bool = False
        self.control_rand_opcode: bool = False

    def _infer_size_from_mask(self, mask: int) -> int:
        count = max(1, int(mask).bit_count())
        if count & (count - 1):
            return int(self.size) & ((1 << SizeWidth) - 1)
        return min(int(log2(count)), (1 << SizeWidth) - 1)

    def randomize_req(self, req: tl_seq_item, idx: int):
        req.a_valid_delay = req.random.randint(self.min_req_delay,
                                               self.max_req_delay)
        req.a_data = int(self.data) & ((1 << DataWidth) - 1)
        req.a_mask = int(self.mask) & ((1 << MaskWidth) - 1)
        req.a_addr = int(self.addr) & ((1 << AddrWidth) - 1)
        req.a_param = 0
        req.a_user = 0

        self.override_a_source_val = bool(self.control_rand_source)
        self.overridden_a_source_val = int(self.source) & (
            (1 << SourceWidth) - 1)

        if self.control_rand_size:
            req.a_size = int(self.size) & ((1 << SizeWidth) - 1)
        else:
            req.a_size = self._infer_size_from_mask(req.a_mask)

        if self.control_rand_opcode:
            req.a_opcode = int(self.opcode) & ((1 << OpcodeWidth) - 1)
        else:
            req.a_opcode = Get if not self.write else (
                PutFullData if req.a_mask == 0xF else PutPartialData)

        if not self.control_addr_alignment:
            req.a_addr &= ~((1 << int(req.a_size)) - 1)
        self.uvm_report.info(
            "TL_HOST_SINGLE_SEQ",
            f"randomized req[{idx}] "
            f"addr=0x{int(req.a_addr):x} data=0x{int(req.a_data):x} "
            f"size={int(req.a_size)} "
            f"src=0x{int(self.overridden_a_source_val):x} "
            f"opcode={int(req.a_opcode)}",
            UVM_LOW,
        )
