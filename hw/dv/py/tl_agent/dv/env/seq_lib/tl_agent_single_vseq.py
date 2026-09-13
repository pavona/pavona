# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Top-level pyUVM sequence that exercises ``tl_host_single_seq``."""

from __future__ import annotations

from pyuvm import UVM_LOW

from ....seq_lib.tl_host_single_seq import tl_host_single_seq
from ....tl_seq_item import Get
from .tl_agent_base_vseq import tl_agent_base_vseq


class tl_agent_single_vseq(tl_agent_base_vseq):
    """Drive a single legal TL transaction through the Python agent."""

    def __init__(self, name: str = "tl_agent_single_vseq"):
        super().__init__(name)

    async def main_thread(self) -> None:
        self.uvm_report.info("TL_AGENT_SINGLE_VSEQ", "main_thread start",
                             UVM_LOW)
        self.start_device_seq()
        try:
            host_seq = tl_host_single_seq("host_single_seq")
            host_seq.addr = 0x24
            host_seq.mask = 0xF
            host_seq.data = 0xA5A5_5A5A
            host_seq.write = False
            host_seq.opcode = Get
            await self.start_host_seq(host_seq)

            rsp = host_seq.rsp
            if rsp is None:
                self.uvm_report.fatal(
                    "TL_AGENT_SINGLE_VSEQ",
                    "host sequence did not capture a response")
            if rsp.d_error:
                self.uvm_report.fatal(
                    "TL_AGENT_SINGLE_VSEQ",
                    "expected non-error response, got d_error=1")
        finally:
            self.stop_device_seq()
        self.uvm_report.info("TL_AGENT_SINGLE_VSEQ", "main_thread done",
                             UVM_LOW)
