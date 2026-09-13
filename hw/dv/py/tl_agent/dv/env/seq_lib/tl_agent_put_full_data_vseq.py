# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Top-level pyUVM sequence that exercises a legal ``PutFullData`` request."""

from __future__ import annotations

from pyuvm import UVM_LOW

from ....seq_lib.tl_host_single_seq import tl_host_single_seq
from ....tl_seq_item import PutFullData
from .tl_agent_base_vseq import tl_agent_base_vseq


class tl_agent_put_full_data_vseq(tl_agent_base_vseq):
    """Drive one legal full-width TL write through the Python agent."""

    def __init__(self, name: str = "tl_agent_put_full_data_vseq"):
        super().__init__(name)

    async def main_thread(self) -> None:
        self.uvm_report.info("TL_AGENT_PUT_FULL_DATA_VSEQ",
                             "main_thread start", UVM_LOW)
        self.start_device_seq()
        try:
            cases = (
                (0x20, 0x1, 0x11_22_33_44),
                (0x21, 0x2, 0x55_66_77_88),
                (0x22, 0x4, 0x99_AA_BB_CC),
                (0x23, 0x8, 0xDD_EE_F0_01),
                (0x20, 0x3, 0x12_34_56_78),
                (0x22, 0xC, 0x87_65_43_21),
                (0x20, 0xF, 0xAB_CD_EF_01),
            )
            for idx, (addr, mask, data) in enumerate(cases):
                host_seq = tl_host_single_seq(f"host_put_full_data_seq_{idx}")
                host_seq.addr = addr
                host_seq.mask = mask
                host_seq.data = data
                host_seq.write = True
                host_seq.opcode = PutFullData
                host_seq.control_rand_opcode = True
                await self.start_host_seq(host_seq)

                rsp = host_seq.rsp
                if rsp is None:
                    self.uvm_report.fatal(
                        "TL_AGENT_PUT_FULL_DATA_VSEQ",
                        "host sequence did not capture a response")
                if rsp.d_error:
                    self.uvm_report.fatal(
                        "TL_AGENT_PUT_FULL_DATA_VSEQ",
                        f"expected non-error response for mask=0x{mask:x}, got d_error=1"
                    )
        finally:
            self.stop_device_seq()
        self.uvm_report.info("TL_AGENT_PUT_FULL_DATA_VSEQ",
                             "main_thread done", UVM_LOW)
