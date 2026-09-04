# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Smoke sequence for early register-model migration."""

from __future__ import annotations

from cocotb.triggers import Timer
from pyuvm import UVM_LOW
from tl_agent.dv.env.seq_lib.tl_agent_base_vseq import tl_agent_base_vseq

from ..tl_agent_ral_frontdoor import tl_agent_ral_frontdoor


class tl_agent_ral_smoke_vseq(tl_agent_base_vseq):
    """Touches the stub RAL model without issuing real bus traffic yet."""

    def __init__(self, name: str = "tl_agent_ral_smoke_vseq"):
        super().__init__(name)

    async def main_thread(self) -> None:
        self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ", "main_thread start",
                             UVM_LOW)
        ral = self.ral
        if ral is None:
            self.uvm_report.fatal("TL_AGENT_RAL_SMOKE_VSEQ",
                                  "ral is required")

        control = ral.get_reg_by_name("control")
        if control is None:
            self.uvm_report.fatal("TL_AGENT_RAL_SMOKE_VSEQ",
                                  "control register missing from RAL")
        self.uvm_report.info(
            "TL_AGENT_RAL_SMOKE_VSEQ",
            f"got control reg addr=0x{control.get_address():x}",
            UVM_LOW,
        )

        p_sequencer = self._get_p_sequencer()
        if p_sequencer.host_seqr is None:
            self.uvm_report.fatal("TL_AGENT_RAL_SMOKE_VSEQ",
                                  "virtual sequencer host_seqr is missing")
        self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ",
                             "host_seqr is available", UVM_LOW)

        self.start_device_seq()
        self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ",
                             "device sequence started", UVM_LOW)
        frontdoor = tl_agent_ral_frontdoor(p_sequencer.host_seqr)
        try:
            self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ", "issuing write",
                                 UVM_LOW)
            write_status = await frontdoor.write_reg(control, 0x5)
            if write_status != "IS_OK":
                self.uvm_report.fatal(
                    "TL_AGENT_RAL_SMOKE_VSEQ",
                    f"write failed with status {write_status}")

            self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ", "issuing read",
                                 UVM_LOW)
            read_status, read_data = await frontdoor.read_reg(control)
            if read_status != "IS_OK":
                self.uvm_report.fatal(
                    "TL_AGENT_RAL_SMOKE_VSEQ",
                    f"read failed with status {read_status}")
            if read_data != 0x5:
                self.uvm_report.fatal(
                    "TL_AGENT_RAL_SMOKE_VSEQ",
                    f"expected control readback 0x5, got 0x{read_data:x}")
        finally:
            self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ",
                                 "stopping device sequence", UVM_LOW)
            self.stop_device_seq()
            self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ",
                                 "device sequence stopped", UVM_LOW)

        self.uvm_report.info(
            "TL_AGENT_RAL_SMOKE_VSEQ",
            f"RAL control desired=0x{control.get():x} mirrored=0x{control.get_mirrored_value():x}",
            UVM_LOW,
        )
        await Timer(1, unit="us")
        self.uvm_report.info("TL_AGENT_RAL_SMOKE_VSEQ", "main_thread done",
                             UVM_LOW)
