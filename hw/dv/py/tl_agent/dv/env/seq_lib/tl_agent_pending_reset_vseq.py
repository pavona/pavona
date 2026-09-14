# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Top-level pyUVM sequence that asserts reset while requests are pending."""

from __future__ import annotations

from clk_rst_agent.seq_lib.delay_seq import delay_seq
from clk_rst_agent.seq_lib.reset_seq import reset_seq
from cocotb.triggers import Timer
from pyuvm import UVM_LOW, UVM_MEDIUM

from ....seq_lib.tl_device_seq import tl_device_seq
from ....seq_lib.tl_host_seq import tl_host_seq
from .tl_agent_base_vseq import tl_agent_base_vseq


class tl_agent_pending_reset_vseq(tl_agent_base_vseq):
    """Start traffic, hold responses off, then assert reset with pending requests."""

    def __init__(self, name: str = "tl_agent_pending_reset_vseq"):
        super().__init__(name)

    async def reset_trigger_thread(self) -> None:
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.clk_rst_sequencer_h is None:
            self.uvm_report.fatal(
                "TL_AGENT_PENDING_RESET_VSEQ",
                "virtual sequencer clk_rst_sequencer_h is missing")
        if p_sequencer.delay_sequencer_h is None:
            self.uvm_report.fatal(
                "TL_AGENT_PENDING_RESET_VSEQ",
                "virtual sequencer delay_sequencer_h is missing")

        self.uvm_report.info("TL_AGENT_PENDING_RESET_VSEQ",
                             "Waiting 10 cycles before triggering reset",
                             UVM_MEDIUM)
        del_seq = delay_seq("delay_sequence:pending_reset",
                            delay_time_steps=10)
        await p_sequencer.delay_sequencer_h.start_sequence(del_seq)

        self.uvm_report.info(
            "TL_AGENT_PENDING_RESET_VSEQ",
            "Triggering reset with pending requests expected", UVM_MEDIUM)
        rst_seq = reset_seq("pending_reset_sequence")
        await p_sequencer.clk_rst_sequencer_h.start_sequence(rst_seq)

    async def main_thread(self) -> None:
        self.uvm_report.info("TL_AGENT_PENDING_RESET_VSEQ",
                             "main_thread start", UVM_LOW)
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.device_seqr is None:
            self.uvm_report.fatal("TL_AGENT_PENDING_RESET_VSEQ",
                                  "virtual sequencer device_seqr is missing")

        device_seq = tl_device_seq("device_seq_pending_reset")
        device_seq.min_rsp_delay = 50
        device_seq.max_rsp_delay = 80
        p_sequencer.device_seqr.spawn_sequence(device_seq)

        try:
            host_seq = tl_host_seq("host_seq_pending_reset")
            host_seq.req_cnt = 16
            host_seq.min_req_delay = 0
            host_seq.max_req_delay = 0
            await self.start_host_seq(host_seq)

            # Keep main_thread alive until reset testing cancels it after reset assertion.
            await Timer(1, unit="us")
        finally:
            self.stop_device_seq()
        self.uvm_report.info("TL_AGENT_PENDING_RESET_VSEQ", "main_thread done",
                             UVM_LOW)
