# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink environment base virtual sequence."""

from __future__ import annotations

from clk_rst_agent.seq_lib.delay_seq import delay_seq
from clk_rst_agent.seq_lib.reset_seq import reset_seq
from dv_lib.dv_base_vseq import dv_base_vseq
from pyuvm import UVM_LOW, UVM_MEDIUM

from ...tl_agent_config_parameters import tl_agent_config_parameters
from ...tl_agent_test_seq_parameters import tl_agent_test_seq_parameters
from ....seq_lib.tl_device_seq import tl_device_seq
from ....seq_lib.tl_host_seq import tl_host_seq
from ..tl_agent_env_cfg import tl_agent_env_cfg
from ..tl_agent_env_cov import tl_agent_env_cov
from ..tl_agent_virtual_sequencer import tl_agent_virtual_sequencer


class tl_agent_base_vseq(dv_base_vseq[None, tl_agent_env_cfg, tl_agent_env_cov,
                                      tl_agent_virtual_sequencer,
                                      tl_agent_test_seq_parameters,
                                      tl_agent_config_parameters, ]):
    """Python port of SV ``tl_agent_base_vseq``."""

    TEST_PARAMS_CLS = tl_agent_test_seq_parameters
    CONFIG_PARAMS_CLS = tl_agent_config_parameters

    def __init__(self, name: str = "tl_agent_base_vseq"):
        super().__init__(name)
        self.min_req_cnt: int = 100
        self.max_req_cnt: int = 200
        self.out_of_order_rsp: bool = True
        self.num_trans_override: int | None = None

    async def dut_init(self) -> None:
        return

    async def reset_trigger_thread(self) -> None:
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.clk_rst_sequencer_h is None:
            self.uvm_report.fatal(
                "TL_AGENT_BASE_VSEQ",
                "virtual sequencer clk_rst_sequencer_h is missing")
        if p_sequencer.delay_sequencer_h is None:
            self.uvm_report.fatal(
                "TL_AGENT_BASE_VSEQ",
                "virtual sequencer delay_sequencer_h is missing")

        if self.config_params is None:
            self.uvm_report.fatal("TL_AGENT_BASE_VSEQ",
                                  "config_params is required for reset delay")
        rand_reset_delay = int(self.config_params.rand_reset_delay)

        self.uvm_report.info(
            "TL_AGENT_BASE_VSEQ",
            f"Waiting {rand_reset_delay} cycles before triggering reset",
            UVM_MEDIUM,
        )
        del_seq = delay_seq("delay_sequence:reset_trigger",
                            delay_time_steps=rand_reset_delay)
        await p_sequencer.delay_sequencer_h.start_sequence(del_seq)

        self.uvm_report.info("TL_AGENT_BASE_VSEQ", "Triggering Reset",
                             UVM_MEDIUM)
        rst_seq = reset_seq("reset_sequence")
        await p_sequencer.clk_rst_sequencer_h.start_sequence(rst_seq)

    async def run_host_seq(self) -> None:
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.host_seqr is None:
            self.uvm_report.fatal("TL_AGENT_BASE_VSEQ",
                                  "virtual sequencer host_seqr is missing")

        host_seq = tl_host_seq("host_seq")
        min_req_cnt = self.min_req_cnt
        max_req_cnt = self.max_req_cnt
        if self.config_params is not None:
            min_req_cnt = int(self.config_params.host_min_req_cnt)
            max_req_cnt = int(self.config_params.host_max_req_cnt)
        host_seq.req_cnt = host_seq.random.randint(min_req_cnt, max_req_cnt)
        await p_sequencer.host_seqr.start_sequence(host_seq)
        self.uvm_report.info(
            "TL_AGENT_BASE_VSEQ",
            f"host_seq finished sending {host_seq.req_cnt} requests",
            UVM_LOW,
        )

    async def start_host_seq(self, host_seq) -> None:
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.host_seqr is None:
            self.uvm_report.fatal("TL_AGENT_BASE_VSEQ",
                                  "virtual sequencer host_seqr is missing")
        await p_sequencer.host_seqr.start_sequence(host_seq)

    def start_device_seq(self) -> None:
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.device_seqr is None:
            self.uvm_report.fatal("TL_AGENT_BASE_VSEQ",
                                  "virtual sequencer device_seqr is missing")
        device_seq = tl_device_seq("device_seq")
        out_of_order_rsp = self.out_of_order_rsp
        if self.config_params is not None:
            out_of_order_rsp = bool(int(self.config_params.out_of_order_rsp))
        device_seq.out_of_order_rsp = out_of_order_rsp
        p_sequencer.device_seqr.spawn_sequence(device_seq)

    def stop_device_seq(self) -> None:
        p_sequencer = self._get_p_sequencer()
        if p_sequencer.device_seqr is not None:
            p_sequencer.device_seqr.stop_sequences()

    async def main_thread(self) -> None:
        self.uvm_report.info(
            "TL_AGENT_BASE_VSEQ",
            "main_thread() - Starting...",
            UVM_MEDIUM,
        )
        p_sequencer = self._get_p_sequencer()
        self.start_device_seq()
        try:
            if p_sequencer.delay_sequencer_h is None:
                self.uvm_report.fatal(
                    "TL_AGENT_BASE_VSEQ",
                    "virtual sequencer delay_sequencer_h is missing")
            main_active_delay_seq = delay_seq(
                "delay_sequence:main_thread_active", delay_time_steps=101)
            await p_sequencer.delay_sequencer_h.start_sequence(
                main_active_delay_seq)

            num_trans = 1 if self.test_params is None else self.test_params.num_trans
            if self.num_trans_override is not None:
                num_trans = self.num_trans_override
            for _ in range(num_trans):
                await self.run_host_seq()
        finally:
            self.stop_device_seq()

        self.uvm_report.info(
            "TL_AGENT_BASE_VSEQ",
            "main_thread() - ...Exiting",
            UVM_MEDIUM,
        )
