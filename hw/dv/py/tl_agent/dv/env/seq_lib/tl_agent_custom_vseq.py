# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Top-level pyUVM sequence that exercises ``tl_host_custom_seq``."""

from __future__ import annotations

from pyuvm import UVM_LOW

from ....seq_lib.tl_host_custom_seq import tl_host_custom_seq
from .tl_agent_base_vseq import tl_agent_base_vseq


class tl_agent_custom_vseq(tl_agent_base_vseq):
    """Send a caller-programmed protocol-violating request through the custom host sequence."""

    def __init__(self, name: str = "tl_agent_custom_vseq"):
        super().__init__(name)

    async def main_thread(self) -> None:
        self.uvm_report.info("TL_AGENT_CUSTOM_VSEQ", "main_thread start",
                             UVM_LOW)
        self.start_device_seq()
        try:
            host_seq = tl_host_custom_seq("host_custom_seq")
            host_seq.addr = 0x23
            host_seq.mask = 0xF
            host_seq.data = 0x1234_5678
            host_seq.size = 2
            host_seq.opcode = 7
            await self.start_host_seq(host_seq)

            rsp = host_seq.rsp
            if rsp is None:
                self.uvm_report.fatal(
                    "TL_AGENT_CUSTOM_VSEQ",
                    "host sequence did not capture a response")
            if not rsp.d_error:
                self.uvm_report.fatal(
                    "TL_AGENT_CUSTOM_VSEQ",
                    "expected protocol error response from custom seq")
        finally:
            self.stop_device_seq()
        self.uvm_report.info("TL_AGENT_CUSTOM_VSEQ", "main_thread done",
                             UVM_LOW)
