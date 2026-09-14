# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
Base configuration class for all agents. Provides common knobs for active/passive
mode, coverage, interface mode, and reset/phase behavior. Monitor-to-sequencer
connections should ideally use callbacks (monitor.add_callback()); analysis
FIFOs (has_req_fifo/has_rsp_fifo) are optional when needed.
"""

from typing import Any, Optional


class dv_base_agent_cfg:
    """
    Base agent configuration.

    Subclass this for agent-specific config; set reset_domain and other knobs
    before passing cfg to the agent via ConfigDB.
    """

    def __init__(self) -> None:
        self.reset_domain: Optional[
            Any] = None  # Object with wait_reset_assert/deassert

        # Agent cfg knobs
        self.active_or_passive: str = "UVM_ACTIVE"  # Active driver/sequencer or passive monitor
        self.en_cov: bool = True  # Enable coverage
        self.if_mode: str = "Host"  # Interface mode hint, e.g. "Host" or "Device"
        self.uvm_verbosity: int | None = None

        self.vif = None
        self.reset_domain = None

        # Create and connect driver to sequencer when True.
        self.has_driver: bool = True

        # Monitor-to-sequencer: prefer callbacks (monitor.add_callback()) for all
        # connections. Optional analysis FIFOs below are an alternative when needed.
        self.has_req_fifo: bool = False
        self.has_rsp_fifo: bool = False
