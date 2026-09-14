# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink device driver."""

import random

import cocotb
from cocotb.triggers import Event, RisingEdge
from dv_lib.dv_base_driver import dv_base_driver

from .tl_agent_cfg import tl_agent_cfg
from .tl_seq_item import tl_seq_item

# dv_base_driver[ITEM_T, CFG_T, RSP_ITEM_T]
TL_ITEM_T = tl_seq_item
TL_CFG_T = tl_agent_cfg
TL_RSP_T = tl_seq_item


class tl_device_driver(dv_base_driver[TL_ITEM_T, TL_CFG_T, TL_RSP_T]):
    """Drives TL D-channel responses while generating A-channel ready."""

    def __init__(self, name: str, parent=None):
        super().__init__(name, parent)
        self.reset_asserted = False
        self._a_task = None
        self._d_task = None

    def build_phase(self):
        super().build_phase()
        self.vif = self.cfg.vif
        if self.vif is None:
            self.uvm_report.fatal("TL_DEVICE_DRIVER",
                                  "cfg.vif must be set before build_phase")

    async def get_and_drive(self):
        # Base reset-safe driver invokes get_and_drive() only after reset deassertion.
        await self.wait_for_clk()

        self._a_task = cocotb.start_soon(self.a_channel_thread())
        self._d_task = cocotb.start_soon(self.d_channel_thread())

        stopper = Event()
        try:
            await stopper.wait()
        finally:
            for t in (self._a_task, self._d_task):
                if t is not None and not t.done():
                    t.cancel()

    def reset_interface_and_driver(self):
        self.invalidate_d_channel()
        self.vif.a_ready.value = 0
        self.reset_asserted = True

    async def a_channel_thread(self):
        while True:
            ready_delay = random.randint(self.cfg.a_ready_delay_min,
                                         self.cfg.a_ready_delay_max)
            for _ in range(ready_delay):
                await self.wait_for_clk()
            self.vif.a_ready.value = 1
            await self.wait_for_clk()
            self.vif.a_ready.value = 0

    async def d_channel_thread(self):
        while True:
            rsp = await self.get_next_item()

            if self.cfg.use_seq_item_d_valid_delay:
                d_valid_delay = int(rsp.d_valid_delay)
            else:
                d_valid_delay = random.randint(self.cfg.d_valid_delay_min,
                                               self.cfg.d_valid_delay_max)
            for _ in range(d_valid_delay):
                await self.wait_for_clk()

            if self.cfg.allow_d_valid_drop_wo_d_ready or rsp.rsp_abort_after_d_valid_len:
                if self.cfg.use_seq_item_d_valid_len:
                    d_valid_len = int(rsp.d_valid_len)
                else:
                    d_valid_len = random.randint(self.cfg.d_valid_len_min,
                                                 self.cfg.d_valid_len_max)
            else:
                d_valid_len = 0

            self.vif.d_valid.value = 1
            self.vif.d_opcode.value = rsp.d_opcode
            self.vif.d_data.value = rsp.d_data
            self.vif.d_source.value = rsp.d_source
            self.vif.d_param.value = rsp.d_param
            self.vif.d_error.value = int(bool(rsp.d_error))
            self.vif.d_sink.value = rsp.d_sink
            self.vif.d_user.value = rsp.d_user
            self.vif.d_size.value = rsp.d_size

            d_valid_cnt = 0
            rsp_abort = False
            while True:
                await self.wait_for_clk()
                d_valid_cnt += 1
                if int(self.vif.d_ready.value):
                    break
                if ((self.cfg.allow_d_valid_drop_wo_d_ready or
                     rsp.rsp_abort_after_d_valid_len) and
                        d_valid_cnt >= d_valid_len):
                    rsp_abort = bool(rsp.rsp_abort_after_d_valid_len)
                    break

            self.invalidate_d_channel()
            rsp.rsp_completed = not rsp_abort
            self.item_done()
            self.seq_item_port.put_response(rsp)

    def invalidate_d_channel(self):
        self.vif.d_opcode.value = 0
        self.vif.d_param.value = 0
        self.vif.d_size.value = 0
        self.vif.d_source.value = 0
        self.vif.d_sink.value = 0
        self.vif.d_data.value = 0
        self.vif.d_user.value = 0
        self.vif.d_error.value = 0
        self.vif.d_valid.value = 0

    async def wait_for_clk(self):
        await RisingEdge(self.vif.clk)
