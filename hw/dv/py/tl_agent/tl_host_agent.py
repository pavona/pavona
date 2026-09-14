# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink host agent wrapper."""

from dv_lib.dv_base_agent import dv_base_agent

from .tl_agent_cfg import tl_agent_cfg
from .tl_agent_cov import tl_agent_cov
from .tl_host_driver import tl_host_driver
from .tl_monitor import tl_monitor
from .tl_sequencer import tl_sequencer

# dv_base_agent[CFG_T, DRIVER_T, SEQUENCER_T, MONITOR_T, COV_T]
TL_CFG_T = tl_agent_cfg
TL_DRIVER_T = tl_host_driver
TL_SEQR_T = tl_sequencer
TL_MON_T = tl_monitor
TL_COV_T = tl_agent_cov


class tl_host_agent(dv_base_agent[TL_CFG_T, TL_DRIVER_T, TL_SEQR_T, TL_MON_T,
                                  TL_COV_T]):
    """TL host agent with monitor->sequencer A-channel FIFO connection."""
    MONITOR_T = tl_monitor
    SEQUENCER_T = tl_sequencer
    DRIVER_T = tl_host_driver
    COV_T = tl_agent_cov

    def build_phase(self):
        super().build_phase()
        self.cfg.if_mode = "Host"
        self.cfg.has_req_fifo = True

    def connect_phase(self):
        super().connect_phase()
        if self.cfg.vif is None:
            self.uvm_report.fatal("TL_HOST_AGENT",
                                  "cfg.vif must be set by testbench")
        if (self.monitor is not None and self.sequencer is not None and
                self.monitor.a_chan_port is not None and
                getattr(self.sequencer, "a_chan_req_fifo", None) is not None):
            self.monitor.a_chan_port.connect(
                self.sequencer.a_chan_req_fifo.analysis_export)
