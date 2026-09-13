# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink environment."""

from __future__ import annotations

from typing import Optional

from clk_rst_agent import clk_rst_agent, delay_agent
from dv_lib.dv_base_env import dv_base_env
from pyuvm import uvm_component

from ...tl_agent import tl_agent
from .tl_agent_env_cfg import tl_agent_env_cfg
from .tl_agent_env_cov import tl_agent_env_cov
from .tl_agent_scoreboard import scoreboard_pkg, tl_agent_scoreboard
from .tl_agent_virtual_sequencer import tl_agent_virtual_sequencer


class tl_agent_env(dv_base_env[tl_agent_env_cfg, tl_agent_virtual_sequencer,
                               tl_agent_scoreboard, tl_agent_env_cov, ]):
    """Python port of SV ``tl_agent_env``."""

    VIRTUAL_SEQUENCER_CLS = tl_agent_virtual_sequencer
    SCOREBOARD_CLS = tl_agent_scoreboard
    COV_CLS = tl_agent_env_cov

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.clk_rst_agent_h: Optional[clk_rst_agent] = None
        self.delay_agent_h: Optional[delay_agent] = None
        self.host_agent: Optional[tl_agent] = None
        self.device_agent: Optional[tl_agent] = None

    def build_phase(self):
        super().build_phase()
        assert self.cfg is not None

        if self.cfg.host_agent_cfg is None or self.cfg.device_agent_cfg is None:
            self.uvm_report.fatal(
                "TL_AGENT_ENV",
                "host_agent_cfg and device_agent_cfg must be initialized")

        if self.cfg.host_agent_cfg.uvm_verbosity is None:
            self.cfg.host_agent_cfg.uvm_verbosity = self.uvm_verbosity
        if self.cfg.device_agent_cfg.uvm_verbosity is None:
            self.cfg.device_agent_cfg.uvm_verbosity = self.uvm_verbosity
        self.cfg.host_agent_cfg.en_cov = self.cfg.en_cov
        self.cfg.device_agent_cfg.en_cov = self.cfg.en_cov

        self.host_agent = tl_agent("host_agent", self)
        self.host_agent.cfg = self.cfg.host_agent_cfg

        self.device_agent = tl_agent("device_agent", self)
        self.device_agent.cfg = self.cfg.device_agent_cfg

        self.clk_rst_agent_h = clk_rst_agent("clk_rst_agent", self)
        self.clk_rst_agent_h.cfg = self.cfg.clk_rst_cfg

        self.delay_agent_h = delay_agent("delay_agent", self)
        self.delay_agent_h.cfg = self.cfg.delay_cfg

        if self.cfg.zero_delays:
            self.cfg.host_agent_cfg.a_valid_delay_min = 0
            self.cfg.host_agent_cfg.a_valid_delay_max = 0
            self.cfg.host_agent_cfg.d_ready_delay_min = 0
            self.cfg.host_agent_cfg.d_ready_delay_max = 0
            self.cfg.device_agent_cfg.d_valid_delay_min = 0
            self.cfg.device_agent_cfg.d_valid_delay_max = 0
            self.cfg.device_agent_cfg.a_ready_delay_min = 0
            self.cfg.device_agent_cfg.a_ready_delay_max = 0

        if self.scoreboard is None:
            self.uvm_report.fatal("TL_AGENT_ENV",
                                  "scoreboard was not created")

        self.scoreboard.add_item_port("host_req_chan", scoreboard_pkg.kSrcPort)
        self.scoreboard.add_item_port("host_rsp_chan", scoreboard_pkg.kDstPort)
        self.scoreboard.add_item_port("device_req_chan",
                                      scoreboard_pkg.kDstPort)
        self.scoreboard.add_item_port("device_rsp_chan",
                                      scoreboard_pkg.kSrcPort)

        self.scoreboard.add_item_queue("req_chan",
                                       scoreboard_pkg.kInOrderCheck)
        self.scoreboard.add_item_queue("rsp_chan",
                                       scoreboard_pkg.kInOrderCheck)

    def connect_phase(self):
        super().connect_phase()
        if self.cfg.host_agent_cfg.vif is None or self.cfg.device_agent_cfg.vif is None:
            self.uvm_report.fatal(
                "TL_AGENT_ENV",
                "host_agent_cfg.vif and device_agent_cfg.vif must be initialized"
            )

        if self.cfg.is_active:
            if (self.virtual_sequencer is None or self.host_agent is None or
                    self.device_agent is None or
                    self.clk_rst_agent_h is None or
                    self.delay_agent_h is None):
                self.uvm_report.fatal(
                    "TL_AGENT_ENV",
                    "virtual_sequencer/host_agent/device_agent/reset agents missing"
                )
            self.virtual_sequencer.host_seqr = self.host_agent.sequencer
            self.virtual_sequencer.device_seqr = self.device_agent.sequencer
            self.virtual_sequencer.clk_rst_sequencer_h = self.clk_rst_agent_h.sequencer
            self.virtual_sequencer.delay_sequencer_h = self.delay_agent_h.sequencer

        if self.host_agent is None or self.device_agent is None or self.scoreboard is None:
            self.uvm_report.fatal("TL_AGENT_ENV",
                                  "failed to create agents/scoreboard")

        self.host_agent.monitor.a_chan_port.connect(
            self.scoreboard.item_fifos["host_req_chan"].analysis_export)
        self.host_agent.monitor.d_chan_port.connect(
            self.scoreboard.item_fifos["host_rsp_chan"].analysis_export)
        self.device_agent.monitor.a_chan_port.connect(
            self.scoreboard.item_fifos["device_req_chan"].analysis_export)
        self.device_agent.monitor.d_chan_port.connect(
            self.scoreboard.item_fifos["device_rsp_chan"].analysis_export)
