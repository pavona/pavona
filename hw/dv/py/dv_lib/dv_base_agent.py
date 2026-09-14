# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
This is a base class for all reset-safe agents. The base class provides reset-safe
functionality by monitoring reset and properly terminating sequences when reset is asserted.
"""

from typing import TYPE_CHECKING, Generic, Optional, TypeVar

import cocotb
from cocotb.triggers import Timer
from pyuvm import (UVM_LOW, UVM_MEDIUM, resolve_uvm_verbosity, uvm_agent,
                   uvm_component)

if TYPE_CHECKING:
    # Forward reference for reset domain - actual implementation should provide
    # wait_reset_assert() and wait_reset_deassert() async methods
    from typing import Protocol

    class ResetDomainProtocol(Protocol):
        """Protocol for reset domain objects."""

        async def wait_reset_assert(self) -> None:
            ...

        async def wait_reset_deassert(self) -> None:
            ...


# Type variables for generic agent
CFG_T = TypeVar('CFG_T')  # Configuration type (typically dv_base_agent_cfg)
DRIVER_T = TypeVar('DRIVER_T', bound=uvm_component)  # Driver type
SEQUENCER_T = TypeVar('SEQUENCER_T', bound=uvm_component)  # Sequencer type
MONITOR_T = TypeVar('MONITOR_T', bound=uvm_component)  # Monitor type
COV_T = TypeVar('COV_T')  # Coverage type (typically dv_base_agent_cov)


class dv_base_agent(uvm_agent, Generic[CFG_T, DRIVER_T, SEQUENCER_T, MONITOR_T,
                                       COV_T]):
    """
    Reset-safe base agent class.

    This agent provides reset-safe functionality by monitoring reset and properly
    terminating sequences when reset is asserted/deasserted.

    Requirements:
    - cfg.reset_domain must be set and provide async methods:
      * wait_reset_assert() -> None
      * wait_reset_deassert() -> None
    - cfg must have:
      * active_or_passive: str or enum - "UVM_ACTIVE" or "UVM_PASSIVE" (or equivalent)
    - Subclass must provide component types through class attributes:
      * MONITOR_T (required)
      * SEQUENCER_T (required for active agent)
      * DRIVER_T (required for active agent)
      * COV_T (optional)
    - If active: creates monitor, sequencer, driver, and optionally coverage
    - If passive: only creates monitor
    """

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None
        self.cov: Optional[COV_T] = None
        self.driver: Optional[DRIVER_T] = None
        self.sequencer: Optional[SEQUENCER_T] = None
        self.monitor: Optional[MONITOR_T] = None

        # Handle for the long-running coroutine that watches reset assertions.
        self._agent_reset_monitor_task: Optional[cocotb.Task] = None
        self.uvm_verbosity: int = int(getattr(parent, "uvm_verbosity",
                                              UVM_LOW))
        self.set_report_verbosity(self.uvm_verbosity)

    def build_phase(self):
        """Build phase - get cfg from ConfigDB and create components."""
        super().build_phase()

        # Get CFG_T object from ConfigDB
        if self.cfg is None:
            self.uvm_report.fatal(
                "DV_BASE_AGENT",
                "cfg is None. Resolve this before proceeding")
        self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                   self.cfg)
        self.set_report_verbosity(self.uvm_verbosity)
        self.uvm_report.info("DV_BASE_AGENT", f"cfg = {self.cfg}", UVM_MEDIUM)

        # Check if agent is active or passive
        if not hasattr(self.cfg, 'active_or_passive'):
            self.uvm_report.fatal("DV_BASE_AGENT",
                                  "cfg.active_or_passive not provided")

        active_or_passive = self.cfg.active_or_passive
        if active_or_passive is None:
            self.uvm_report.fatal("DV_BASE_AGENT",
                                  "cfg.active_or_passive is None")

        # Handle both string and enum types
        if hasattr(active_or_passive, 'name'):
            active_or_passive_str = active_or_passive.name
        else:
            active_or_passive_str = str(active_or_passive)

        if not active_or_passive_str:
            self.uvm_report.fatal("DV_BASE_AGENT",
                                  "cfg.active_or_passive is empty")

        # Check if value is valid (ACTIVE or PASSIVE)
        valid_active = (active_or_passive_str == 'UVM_ACTIVE' or
                        active_or_passive_str == 'ACTIVE' or
                        active_or_passive == 'UVM_ACTIVE' or
                        active_or_passive == 'ACTIVE')
        valid_passive = (active_or_passive_str == 'UVM_PASSIVE' or
                         active_or_passive_str == 'PASSIVE' or
                         active_or_passive == 'UVM_PASSIVE' or
                         active_or_passive == 'PASSIVE')

        if not (valid_active or valid_passive):
            self.uvm_report.fatal(
                "DV_BASE_AGENT", f"""cfg.active_or_passive has invalid value
                                  '{active_or_passive_str}'. Must be 'UVM_ACTIVE', 'ACTIVE',
                                  'UVM_PASSIVE', or 'PASSIVE'""")

        is_active = valid_active

        # Create monitor (always created)
        monitor_class = getattr(type(self), "MONITOR_T", None)
        if monitor_class is None:
            self.uvm_report.fatal("DV_BASE_AGENT", "MONITOR_T is not defined")
        self.monitor = monitor_class("monitor", self)
        self.monitor.cfg = self.cfg

        cov_class = getattr(type(self), "COV_T", None)
        if getattr(self.cfg, "en_cov", False) and cov_class is not None:
            self.cov = cov_class("cov", self)
            self.cov.cfg = self.cfg
            self.monitor.cov = self.cov

        # Create other components only if active
        if is_active:

            # Create sequencer
            sequencer_class = getattr(type(self), "SEQUENCER_T", None)
            if sequencer_class is None:
                self.uvm_report.fatal(
                    "DV_BASE_AGENT",
                    "SEQUENCER_T is not defined for active agent")
            self.sequencer = sequencer_class("sequencer", self)
            self.sequencer.cfg = self.cfg

            # Create driver
            driver_class = getattr(type(self), "DRIVER_T", None)
            if driver_class is None:
                self.uvm_report.fatal(
                    "DV_BASE_AGENT",
                    "DRIVER_T is not defined for active agent")
            self.driver = driver_class("driver", self)
            self.driver.cfg = self.cfg

    def connect_phase(self):
        """Connect phase - connect driver to sequencer; assign vif to driver and monitor."""
        super().connect_phase()

        # When we get to connect_phase() vif and all agent elements should be constructed
        if self.cfg.vif is None:
            self.uvm_report.fatal(
                "DV_BASE_AGENT",
                "vif is None. Resolve this before proceeding")
        if self.cfg.reset_domain is None:
            self.uvm_report.fatal(
                "DV_BASE_AGENT", """reset_domain is None.
                                    Resolve this before proceeding""")

        if self.driver is not None:
            self.driver.vif = self.cfg.vif
            self.driver.reset_domain = self.cfg.reset_domain
        if self.monitor is not None:
            self.monitor.vif = self.cfg.vif
            self.monitor.reset_domain = self.cfg.reset_domain

        # Only connect if agent is active (has driver and sequencer)
        if self.driver is not None and self.sequencer is not None:
            # Connect driver to sequencer
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)

    def start_of_simulation_phase(self):
        """Start of simulation phase - check that reset_domain is set."""
        super().start_of_simulation_phase()

        if self.cfg is None or not hasattr(
                self.cfg, 'reset_domain') or self.cfg.reset_domain is None:
            cfg_name = self.cfg.get_name() if self.cfg and hasattr(
                self.cfg, 'get_name') else 'None'
            self.uvm_report.fatal(
                "DV_BASE_AGENT", f"'cfg.reset_domain' is null. "
                f"Resolve this before proceeding\n cfg name: {cfg_name}")

    async def run_phase(self):
        """Main run phase that handles reset-safe agent operation."""
        if self.cfg is None or self.cfg.reset_domain is None:
            self.uvm_report.fatal(
                "DV_BASE_AGENT", "cfg.reset_domain == None, "
                "please ensure reset_domain is setup in cfg")

        # The first reset is POR. Wait until a full reset cycle is observed
        await self.cfg.reset_domain.wait_reset_assert()
        await self.cfg.reset_domain.wait_reset_deassert()

        self.uvm_report.info("DV_BASE_AGENT", "POR Deasserted", UVM_MEDIUM)

        # Start reset monitoring task (runs forever) using cocotb orchestration
        self._agent_reset_monitor_task = cocotb.start_soon(
            self._agent_reset_thread())

    async def _agent_reset_thread(self):
        """Agent reset monitoring thread that stops sequences on reset."""
        while True:
            await self.cfg.reset_domain.wait_reset_assert()
            self.uvm_report.info("DV_BASE_AGENT", "Reset Asserted",
                                 UVM_MEDIUM)

            if (self.sequencer is not None and
                    hasattr(self.sequencer, 'do_not_reset') and
                    not self.sequencer.do_not_reset):
                self.uvm_report.info(
                    "DV_BASE_AGENT",
                    "Initiating Sequences Termination",
                    UVM_MEDIUM,
                )

                # Stop sequences
                if hasattr(self.sequencer, 'stop_sequences'):
                    self.sequencer.stop_sequences()
                self.uvm_report.info("DV_BASE_AGENT", "Sequences Stopped",
                                     UVM_MEDIUM)

            await self.cfg.reset_domain.wait_reset_deassert()
            self.uvm_report.info("DV_BASE_AGENT", "Reset Deasserted",
                                 UVM_MEDIUM)

    # -------------------------
    # Helpers
    # -------------------------
    async def _wait_until(self, predicate):
        """Poll predicate every 1ns until it becomes True. Mirrors SV: wait(expr)."""
        while not predicate():
            await Timer(1, unit="ns")
