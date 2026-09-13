# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink host driver."""

import random
from typing import List

import cocotb
from cocotb.triggers import Event, RisingEdge
from dv_lib.dv_base_driver import dv_base_driver
from pyuvm import UVM_DEBUG

from .tl_agent_cfg import tl_agent_cfg
from .tl_seq_item import tl_seq_item

# dv_base_driver[ITEM_T, CFG_T, RSP_ITEM_T]
TL_ITEM_T = tl_seq_item
TL_CFG_T = tl_agent_cfg
TL_RSP_T = tl_seq_item


class tl_host_driver(dv_base_driver[TL_ITEM_T, TL_CFG_T, TL_RSP_T]):
    """Drives TL A-channel requests and captures TL D-channel responses."""

    def __init__(self, name: str, parent=None):
        super().__init__(name, parent)
        self.pending_a_req: List[tl_seq_item] = []
        self.reset_asserted: bool = False
        self._a_task = None
        self._d_task = None
        self._d_ready_task = None

    def build_phase(self):
        super().build_phase()
        self.vif = self.cfg.vif
        if self.vif is None:
            self.uvm_report.fatal("TL_HOST_DRIVER",
                                  "cfg.vif must be set before build_phase")

    async def get_and_drive(self):
        # Base reset-safe driver invokes get_and_drive() only after reset deassertion.
        await self.wait_for_clk()
        self.reset_asserted = False

        self._a_task = cocotb.start_soon(self.a_channel_thread())
        self._d_task = cocotb.start_soon(self.d_channel_thread())
        self._d_ready_task = cocotb.start_soon(self.d_ready_rsp())

        stopper = Event()
        try:
            await stopper.wait()
        finally:
            for t in (self._a_task, self._d_task, self._d_ready_task):
                if t is not None and not t.done():
                    t.cancel()

    def reset_interface_and_driver(self):
        self.invalidate_a_channel()
        self.vif.d_ready.value = 0
        self.pending_a_req.clear()
        self.reset_asserted = True

    async def a_channel_thread(self):
        await self.wait_for_clk()
        while True:
            req = await self.get_next_item()
            await self.send_a_channel_request(req)
            self.item_done()

    async def send_a_channel_request(self, req: tl_seq_item):
        while self.is_source_in_pending_req(req.a_source):
            await self.wait_for_clk()

        if self.cfg.use_seq_item_a_valid_delay:
            a_valid_delay = int(req.a_valid_delay)
        else:
            a_valid_delay = random.randint(self.cfg.a_valid_delay_min,
                                           self.cfg.a_valid_delay_max)

        if req.req_abort_after_a_valid_len or self.cfg.allow_a_valid_drop_wo_a_ready:
            if self.cfg.use_seq_item_a_valid_len:
                a_valid_len = int(req.a_valid_len)
            else:
                a_valid_len = random.randint(self.cfg.a_valid_len_min,
                                             self.cfg.a_valid_len_max)
        else:
            a_valid_len = 0

        for _ in range(a_valid_delay):
            await self.wait_for_clk()

        self.pending_a_req.append(req)

        self.vif.a_address.value = req.a_addr
        self.vif.a_opcode.value = req.a_opcode
        self.vif.a_size.value = req.a_size
        self.vif.a_param.value = req.a_param
        self.vif.a_data.value = req.a_data
        self.vif.a_mask.value = req.a_mask
        self.vif.a_user.value = req.a_user
        self.vif.a_source.value = req.a_source
        self.vif.a_valid.value = 1

        req_done, req_abort = await self.send_a_request_body(req, a_valid_len)
        self.invalidate_a_channel()

        if req_abort:
            req.req_completed = False
            req.d_source = req.a_source
            self.seq_item_port.put_response(req)
        else:
            req.req_completed = bool(req_done)

    async def send_a_request_body(self, req: tl_seq_item, a_valid_len: int):
        a_valid_cnt = 0
        req_abort = False
        while True:
            await self.wait_for_clk()
            a_valid_cnt += 1

            if int(self.vif.a_ready.value):
                self.vif.a_valid.value = 0
                return True, False

            abort_condition = ((req.req_abort_after_a_valid_len or
                                self.cfg.allow_a_valid_drop_wo_a_ready) and
                               a_valid_cnt >= a_valid_len)
            if abort_condition:
                req_abort = bool(req.req_abort_after_a_valid_len)
                self.vif.a_valid.value = 0
                if self.pending_a_req and self.pending_a_req[-1] is req:
                    self.pending_a_req.pop()
                await self.wait_for_clk()
                return False, req_abort

    async def d_ready_rsp(self):
        while True:
            d_ready_delay = random.randint(self.cfg.d_ready_delay_min,
                                           self.cfg.d_ready_delay_max)
            for _ in range(d_ready_delay):
                if (not self.cfg.host_can_stall_rsp_when_a_valid_high) and int(
                        self.vif.a_valid.value):
                    break
                await self.wait_for_clk()

            self.vif.d_ready.value = 1
            await self.wait_for_clk()
            self.vif.d_ready.value = 0

    async def d_channel_thread(self):
        while True:
            if int(self.vif.d_valid.value) and int(self.vif.d_ready.value):
                dsrc = int(self.vif.d_source.value)
                idx = next((i for i, req in enumerate(self.pending_a_req)
                            if int(req.a_source) == dsrc), None)
                if idx is not None:
                    rsp = self.pending_a_req.pop(idx)
                    rsp.d_opcode = int(self.vif.d_opcode.value)
                    rsp.d_data = int(self.vif.d_data.value)
                    rsp.d_param = int(self.vif.d_param.value)
                    rsp.d_sink = int(self.vif.d_sink.value)
                    rsp.d_size = int(self.vif.d_size.value)
                    rsp.d_user = int(self.vif.d_user.value)
                    rsp.d_error = bool(int(self.vif.d_error.value))
                    rsp.d_source = dsrc
                    rsp.rsp_completed = not self.reset_asserted
                    self.uvm_report.info(
                        "TL_HOST_DRIVER",
                        f"captured d_chan rsp src=0x{dsrc:x} "
                        f"pending_after={len(self.pending_a_req)} "
                        f"rsp_completed={int(rsp.rsp_completed)}",
                        UVM_DEBUG,
                    )
                    self.seq_item_port.put_response(rsp)
                else:
                    self.uvm_report.warning(
                        "TL_HOST_DRIVER",
                        f"observed d_chan src=0x{dsrc:x} with no pending request"
                    )
            await self.wait_for_clk()

    def is_source_in_pending_req(self, source: int) -> bool:
        return any(
            int(req.a_source) == int(source) for req in self.pending_a_req)

    def invalidate_a_channel(self):
        self.vif.a_opcode.value = 0
        self.vif.a_param.value = 0
        self.vif.a_size.value = 0
        self.vif.a_source.value = 0
        self.vif.a_address.value = 0
        self.vif.a_mask.value = 0
        self.vif.a_data.value = 0
        self.vif.a_user.value = 0
        self.vif.a_valid.value = 0

    async def wait_for_clk(self):
        await RisingEdge(self.vif.clk)
