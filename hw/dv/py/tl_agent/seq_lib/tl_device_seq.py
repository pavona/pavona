# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Reactive TileLink device sequence."""

import random
from typing import Dict, List, Optional

from cocotb.triggers import Event, First, Timer
from dv_lib.dv_base_seq import dv_base_seq
from pyuvm import UVM_LOW

from ..tl_agent_cfg import tl_agent_cfg
from ..tl_seq_item import (AccessAck, AccessAckData, Get, PutFullData,
                           PutPartialData, tl_seq_item)
from ..tl_sequencer import tl_sequencer


class tl_device_seq(dv_base_seq[tl_sequencer, tl_agent_cfg, tl_seq_item,
                                tl_seq_item]):
    """Collect TL requests from the sequencer FIFO and send matching responses."""

    def __init__(self, name: str = "tl_device_seq"):
        super().__init__(name)
        self.rsp_abort_after_d_valid_len: bool = False
        self.rsp_abort_pct: int = 0
        self.min_rsp_delay: int = 0
        self.max_rsp_delay: int = 10
        self.mem: Dict[int, int] = {}
        self.req_q: List[tl_seq_item] = []
        self.out_of_order_rsp: bool = False
        self.stop: bool = False
        self.d_error_pct: int = 0
        self._stop_event: Optional[Event] = None

    async def body(self):
        self.uvm_report.info("TL_DEVICE_SEQ", "start body", UVM_LOW)
        self.stop = False
        self._stop_event = Event()
        collect_task = self.spawn_task(self.collect_request_thread(),
                                       "collect_request_thread")
        send_task = self.spawn_task(self.send_response_thread(),
                                    "send_response_thread")
        try:
            await First(collect_task, send_task)
            while self.req_q:
                await Timer(1, unit="ns")
        finally:
            self.stop = True
            if self._stop_event is not None:
                self._stop_event.set()
            await self.cancel_spawned_tasks()
        self.uvm_report.info("TL_DEVICE_SEQ", "body complete", UVM_LOW)

    async def get_a_chan_req(self):
        req_fifo = getattr(self.sequencer, "a_chan_req_fifo", None)
        if req_fifo is None:
            self.uvm_report.fatal("TL_DEVICE_SEQ",
                                  "requires sequencer.a_chan_req_fifo")
        req_task = self.spawn_task(req_fifo.get(), "req_fifo_get")
        stop_task = self.spawn_task(self._wait_for_stop(), "wait_for_stop")
        done = await First(req_task, stop_task)

        if done is stop_task:
            if not req_task.done():
                req_task.cancel()
            return None

        if not stop_task.done():
            stop_task.cancel()

        if self.stop:
            return None
        return req_task.result()

    async def _wait_for_stop(self):
        await self._stop_event.wait()

    async def collect_request_thread(self):
        self.uvm_report.info("TL_DEVICE_SEQ", "collect_request_thread start",
                             UVM_LOW)
        while not self.stop:
            req = await self.get_a_chan_req()
            if req is not None:
                self.req_q.append(req)
                self.uvm_report.info(
                    "TL_DEVICE_REQ",
                    f"enqueue req src=0x{int(req.a_source):x} queue_depth={len(self.req_q)}",
                    UVM_LOW,
                )
            if self.stop:
                break
        self.uvm_report.info("TL_DEVICE_SEQ", "collect_request_thread stop",
                             UVM_LOW)

    async def send_response_thread(self):
        self.uvm_report.info("TL_DEVICE_SEQ", "send_response_thread start",
                             UVM_LOW)
        while not self.stop:
            if not self.req_q:
                await Timer(1, unit="ns")
                continue
            if self.out_of_order_rsp:
                random.shuffle(self.req_q)
            req = self.req_q[0]
            rsp = req.clone()
            self.randomize_rsp(rsp)
            self.post_randomize_rsp(rsp)
            self.update_mem(rsp)
            self.uvm_report.info(
                "TL_DEVICE_RSP",
                f"send rsp for src=0x{int(rsp.d_source):x} pending_before={len(self.req_q)}",
                UVM_LOW,
            )
            await self.start_item(rsp)
            await self.finish_item(rsp)
            rsp = await self.get_response()
            if rsp.rsp_completed:
                self.req_q.pop(0)
                self.uvm_report.info(
                    "TL_DEVICE_RSP",
                    f"rsp completed src=0x{int(rsp.d_source):x} pending_after={len(self.req_q)}",
                    UVM_LOW,
                )
        self.uvm_report.info("TL_DEVICE_SEQ", "send_response_thread stop",
                             UVM_LOW)

    def randomize_rsp(self, rsp: tl_seq_item):
        rsp.disable_a_chan_randomization()
        rsp.d_valid_delay = random.randint(self.min_rsp_delay,
                                           self.max_rsp_delay)
        rsp.d_opcode = AccessAckData if rsp.a_opcode == Get else AccessAck
        rsp.d_size = rsp.a_size
        rsp.d_source = rsp.a_source
        rsp.d_param = 0
        rsp.d_error = rsp.get_exp_d_error()
        if self.d_error_pct > 0 and random.randint(1, 100) <= self.d_error_pct:
            rsp.d_error = True

    def post_randomize_rsp(self, rsp: tl_seq_item):
        rsp.rsp_abort_after_d_valid_len = bool(
            self.rsp_abort_after_d_valid_len)

    def update_mem(self, rsp: tl_seq_item):
        if rsp.d_error:
            if rsp.a_opcode == Get:
                rsp.d_data = 0
            return
        if rsp.a_opcode in {PutFullData, PutPartialData}:
            data = int(rsp.a_data)
            for i in range(4):
                if (rsp.a_mask >> i) & 1:
                    self.mem[int(rsp.a_addr) + i] = data & 0xFF
                data >>= 8
        else:
            value = 0
            for i in range((1 << int(rsp.a_size)) - 1, -1, -1):
                value = (value << 8) | int(self.mem.get(
                    int(rsp.a_addr) + i, 0))
            rsp.d_data = value

    async def seq_stop(self):
        self.stop = True
        if self._stop_event is not None:
            self._stop_event.set()
        self.uvm_report.info("TL_DEVICE_SEQ", "seq_stop requested", UVM_LOW)
