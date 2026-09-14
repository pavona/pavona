# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink base test."""
import os
from typing import Optional

import cocotb
from cocotb.triggers import with_timeout
from dv_lib.dv_base_test import dv_base_test
from dv_lib.dv_rst_domain import dv_rst_domain
from interfaces import ClkRstIf, TlIf
from pyuvm import UVM_INFO, UVM_LOW, uvm_component

from ..env.seq_lib.tl_agent_base_vseq import tl_agent_base_vseq
from ..env.tl_agent_env import tl_agent_env
from ..env.tl_agent_env_cfg import tl_agent_env_cfg

DEFAULT_TIMEOUT_US = int(os.getenv("TEST_TIMEOUT_US", "80"))


class tl_agent_base_test(dv_base_test[tl_agent_env_cfg, tl_agent_env]):
    """Python port of SV ``tl_agent_base_test``."""

    CFG_CLS = tl_agent_env_cfg
    ENV_CLS = tl_agent_env

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.clk_rst_if = None

    def build_phase(self):
        self.uvm_report.info("TL_AGENT_BASE_TEST", "build_phase()", UVM_LOW)
        tb_top = cocotb.top
        if tb_top is None:
            self.uvm_report.fatal("TL_AGENT_BASE_TEST", "tb_top is required")
            return

        self.clk_rst_if = ClkRstIf(tb_top, self.logger)
        self.clk_rst_if.set_period_ps(10_000)  # 100 MHz
        # self.clk_rst_if.set_freq_mhz(100)
        self.clk_rst_if.set_active(drive_clk_val=True, drive_rst_n_val=True)

        reset_domain = dv_rst_domain(self.clk_rst_if,
                                     name="default_rst_domain")

        tl_vif = TlIf(tb_top,
                      prefix="",
                      clk=self.clk_rst_if.clk,
                      rst_n=self.clk_rst_if.rst_n)

        super().build_phase()
        if self.cfg is None:
            self.uvm_report.fatal("TL_AGENT_BASE_TEST", "cfg is required")
            return

        if tl_vif is None or reset_domain is None:
            self.uvm_report.fatal("TL_AGENT_BASE_TEST",
                                  "tl_vif and reset_domain are required")
            return

        try:
            self.cfg.apply_runtime_args()
        except RuntimeError as err:
            self.uvm_report.fatal("TL_AGENT_BASE_TEST", f"{err}")
            return
        self.cfg.zero_delays = True
        self.cfg.reset_domain = reset_domain

        self.cfg.clk_rst_cfg.vif = self.clk_rst_if
        self.cfg.clk_rst_cfg.reset_domain = reset_domain
        self.cfg.clk_rst_cfg.en_cov = False

        self.cfg.delay_cfg.vif = self.clk_rst_if
        self.cfg.delay_cfg.reset_domain = reset_domain
        self.cfg.delay_cfg.en_cov = False

        self.cfg.host_agent_cfg.vif = tl_vif
        self.cfg.device_agent_cfg.vif = tl_vif
        self.cfg.host_agent_cfg.reset_domain = reset_domain
        self.cfg.device_agent_cfg.reset_domain = reset_domain

        self.cfg.host_agent_cfg.allow_a_valid_drop_wo_a_ready = False
        self.cfg.host_agent_cfg.use_seq_item_a_valid_delay = False
        self.cfg.host_agent_cfg.d_ready_delay_min = 0
        self.cfg.host_agent_cfg.d_ready_delay_max = 0
        self.cfg.device_agent_cfg.allow_d_valid_drop_wo_d_ready = False
        self.cfg.device_agent_cfg.use_seq_item_d_valid_delay = False
        self.cfg.device_agent_cfg.a_ready_delay_min = 0
        self.cfg.device_agent_cfg.a_ready_delay_max = 0

    def configure_sequence(self, seq):
        super().configure_sequence(seq)
        if isinstance(seq, tl_agent_base_vseq):
            seq.num_trans_override = 1
            seq.min_req_cnt = self.cfg.tx_count
            seq.max_req_cnt = self.cfg.tx_count
            seq.out_of_order_rsp = False

    def add_message_demotes(self, catcher):
        super().add_message_demotes(catcher)
        catcher.add_change_sev("*",
                               r"__int__ returned non-int \(type ValueInt\)",
                               UVM_INFO)

    async def run_phase(self):
        self.uvm_report.info("TL_AGENT_BASE_TEST", "run_phase()", UVM_LOW)
        test_task = cocotb.start_soon(super().run_phase())

        self.raise_objection()
        try:
            self.uvm_report.info("TL_AGENT_BASE_TEST", "POR reset()", UVM_LOW)
            await self.clk_rst_if.apply_reset(reset_width_clks=5,
                                              post_reset_dly_clks=1)
            try:
                await with_timeout(test_task, DEFAULT_TIMEOUT_US, "us")
            except RuntimeError as err:
                # Flatten nested task traceback for run_phase failures.
                raise RuntimeError(str(err)) from None
        finally:
            self.drop_objection()
