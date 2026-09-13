# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink host sequence supporting multiple outstanding requests."""

from typing import List

from pyuvm import UVM_LOW

from ..tl_seq_item import tl_seq_item
from .tl_host_base_seq import tl_host_base_seq


class tl_host_seq(tl_host_base_seq):
    """Generate random host requests and match responses."""

    def __init__(self, name: str = "tl_host_seq"):
        super().__init__(name)
        self.req_cnt: int = 1
        self.req_abort_after_a_valid_len: bool = False
        self.req_abort_pct: int = 0
        self.pending_req: List[tl_seq_item] = []
        self.min_req_delay: int = 0
        self.max_req_delay: int = 10
        self.reqs_started: int = 0
        self.rsp = None

    async def body(self):
        self.uvm_report.info("TL_HOST_SEQ",
                             f"start body req_cnt={self.req_cnt}", UVM_LOW)
        for i in range(self.req_cnt):
            req = tl_seq_item(f"req_{i}")
            await self.pre_start_item(req)
            await self.start_item(req)
            self.reqs_started += 1
            self.randomize_req(req, i)
            self.post_randomize_req(req, i)
            self.uvm_report.info("TL_HOST_REQ",
                                 f"send req[{i}] {req.convert2string()}",
                                 UVM_LOW)
            self.pending_req.append(req)
            await self.finish_item(req)

        for i in range(self.req_cnt):
            rsp = await self.get_base_response()
            self.uvm_report.info("TL_HOST_RSP",
                                 f"got rsp[{i}] {rsp.convert2string()}",
                                 UVM_LOW)
            self.rsp = rsp
            match_idx = next(
                (idx for idx, req in enumerate(self.pending_req)
                 if int(req.a_source) == int(rsp.d_source)),
                None,
            )
            if match_idx is None:
                self.uvm_report.fatal(
                    "TL_HOST_MATCH",
                    f"failed to find matching req for rsp[{i}]: {rsp.convert2string()}",
                )
            req = self.pending_req.pop(match_idx)
            self.uvm_report.info(
                "TL_HOST_MATCH",
                f"match rsp[{i}] with req a_source=0x{int(req.a_source):x}",
                UVM_LOW,
            )
            self.process_response(req, rsp)
        self.uvm_report.info("TL_HOST_SEQ", "body complete", UVM_LOW)

    async def pre_start_item(self, req: tl_seq_item):
        return

    def randomize_req(self, req: tl_seq_item, idx: int):
        req.randomize()
        req.a_valid_delay = req.random.randint(self.min_req_delay,
                                               self.max_req_delay)
        req.a_user = 0

    def post_randomize_req(self, req: tl_seq_item, idx: int):
        req.req_abort_after_a_valid_len = bool(
            self.req_abort_after_a_valid_len)

    def process_response(self, req: tl_seq_item, rsp: tl_seq_item):
        return
