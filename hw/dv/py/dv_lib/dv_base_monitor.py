# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
This is a base class for all monitors. The base class provides tasks and methods to make the
monitor reset safe.
"""

from typing import Any, Callable, Generic, List, Optional, TypeVar

import cocotb
from cocotb.task import CancelledError
from pyuvm import (UVM_LOW, UVM_MEDIUM, resolve_uvm_verbosity,
                   uvm_analysis_port, uvm_component, uvm_monitor,
                   uvm_sequence_item)

from .dv_rst_domain import dv_rst_domain

# Type variables for generic monitor
ITEM_T = TypeVar('ITEM_T', bound=uvm_sequence_item)
REQ_ITEM_T = TypeVar('REQ_ITEM_T', bound=uvm_sequence_item)
RSP_ITEM_T = TypeVar('RSP_ITEM_T', bound=uvm_sequence_item)
CFG_T = TypeVar('CFG_T')  # Configuration type (typically dv_base_agent_cfg)
COV_T = TypeVar('COV_T')  # Coverage type (typically dv_base_agent_cov)


class dv_base_monitor(uvm_monitor, Generic[ITEM_T, REQ_ITEM_T, RSP_ITEM_T,
                                           CFG_T, COV_T]):
    """
    Reset-safe base monitor class.

    This monitor provides reset-safe functionality by monitoring reset and properly
    terminating and restarting the collect_trans thread when reset is asserted/deasserted.

    Requirements:
    - cfg.reset_domain must be set and provide async methods:
      * wait_reset_assert() -> None
      * wait_reset_deassert() -> None
    - Derived classes must implement:
      * async collect_trans() - main monitor loop
      * reset_monitor() - reset handling

    Callback Usage Examples:
        # Method 1: Direct function callback
        def my_handler(item):
            print(f"Received transaction: {item}")
        monitor.add_callback(my_handler)

        # Method 2: Lambda expression
        monitor.add_callback(lambda item: process_item(item))

        # Method 3: Method from another object
        class MySequence:
            def handle_item(self, item):
                # Process item
                pass

        seq = MySequence()
        monitor.add_callback(seq.handle_item)

        # Method 4: Callable object
        class ItemProcessor:
            def __call__(self, item):
                # Process item
                pass

        processor = ItemProcessor()
        monitor.add_callback(processor)

        # Remove callback
        monitor.remove_callback(my_handler)

        # Clear all callbacks
        monitor.clear_callbacks()

    Monitor Implementation Example:
        class MyMonitor(dv_base_monitor[MyItem, MyReqItem, MyRspItem, MyCfg, MyCov]):
            async def collect_trans(self):
                while True:
                    # Monitor interface and build transactions
                    item = self.create_item()
                    self.notify(item)  # This will invoke callbacks and write to analysis port

            def reset_monitor(self):
                # Reset monitor state
                pass
    """

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None  # Configuration object (CFG_T type)
        self.cov: Optional[COV_T] = None  # Coverage object (COV_T type)
        self.reset_domain: Optional[dv_rst_domain] = None
        # Python interface (cocotb 2.0): TlIf, ClkRstIf, etc. Set from
        # testbench/agent; used to sample pins.
        self.vif: Optional[Any] = None
        self._reset_task: Optional[cocotb.Task] = None
        self._collect_trans_task: Optional[cocotb.Task] = None

        # Pythonic callback registry - simple list of callables
        # Supports functions, methods, lambda, or any callable object
        self._callbacks: List[Callable[[ITEM_T], None]] = []
        self.uvm_verbosity: int = int(getattr(parent, "uvm_verbosity",
                                              UVM_LOW))
        self.set_report_verbosity(self.uvm_verbosity)

    def build_phase(self):
        """Build phase."""
        super().build_phase()
        # Some pyuvm versions do not auto-create analysis_port on uvm_monitor.
        if not hasattr(self, "analysis_port") or self.analysis_port is None:
            self.analysis_port = uvm_analysis_port("analysis_port", self)

    def start_of_simulation_phase(self):
        """Resolve reset_domain before run-time activity starts."""
        super().start_of_simulation_phase()
        self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                   self.cfg)
        self.set_report_verbosity(self.uvm_verbosity)

        if self.vif is None:
            self.uvm_report.fatal("DV_BASE_MONITOR", "vif == None "
                                  "please ensure vif is setup")
        if self.reset_domain is None:
            self.uvm_report.fatal(
                "DV_BASE_MONITOR", "reset_domain == None "
                "please ensure reset_domain is setup")

    async def run_phase(self):
        """Main run phase that handles reset-safe monitor operation."""
        await super().run_phase()

        # The first reset is POR. Wait until a full reset cycle is observed before
        # capturing any transaction on the interface.
        await self.reset_domain.wait_reset_assert()
        self.reset_monitor()

        await self.reset_domain.wait_reset_deassert()
        self.uvm_report.info("DV_BASE_MONITOR", "POR Released", UVM_MEDIUM)

        while True:
            self._reset_task = None
            self._collect_trans_task = None

            # Use Cocotb tasks for concurrent execution
            self.uvm_report.info(
                "DV_BASE_MONITOR",
                "Reset Deasserted - Starting Reset Monitor and Main Thread",
                UVM_MEDIUM,
            )

            # Start reset monitoring task
            self._reset_task = cocotb.start_soon(self._reset_monitor_task())

            # Start transaction collection task
            self._collect_trans_task = cocotb.start_soon(self.collect_trans())

            self.uvm_report.info(
                "DV_BASE_MONITOR",
                "Wait for Reset Monitor Thread to finish",
                UVM_MEDIUM,
            )

            # Wait till reset task finishes. Reset task should be the only one to finish
            # first as the collect_trans task should be a forever loop monitoring the
            # interface signals.
            await self._reset_task

            self.uvm_report.info("DV_BASE_MONITOR", "Reset Thread finished",
                                 UVM_MEDIUM)

            # Check if collect_trans task is still running and cancel it if needed
            if self._collect_trans_task and not self._collect_trans_task.done(
            ):
                self.uvm_report.info(
                    "DV_BASE_MONITOR",
                    "killing collect_trans() task",
                    UVM_MEDIUM,
                )
                self._collect_trans_task.cancel()
                try:
                    await self._collect_trans_task
                except CancelledError:
                    pass
            elif self._collect_trans_task and self._collect_trans_task.done():
                self.uvm_report.fatal(
                    "DV_BASE_MONITOR", "collect_trans() task finished "
                    "before reset thread")

            self.uvm_report.info(
                "DV_BASE_MONITOR",
                "Waiting for Reset to Deassert",
                UVM_MEDIUM,
            )
            await self.reset_domain.wait_reset_deassert()

    async def _reset_monitor_task(self):
        """Monitor reset assertion and handle reset when it occurs."""
        await self.reset_domain.wait_reset_assert()
        self.uvm_report.info("DV_BASE_MONITOR", "Reset Asserted", UVM_MEDIUM)
        self.reset_monitor()

    async def collect_trans(self):
        """
        Main task of the monitor that will observe the interface and build transactions
        that the scoreboard can use.

        This method must be implemented by derived classes.
        """
        self.uvm_report.fatal("DV_BASE_MONITOR",
                              "collect_trans() needs an implementation")

    def reset_monitor(self):
        """
        Reset monitor function is invoked when reset is triggered.

        The derived monitor needs to implement this to get the monitor back to
        the default state when in reset.
        """
        self.uvm_report.fatal("DV_BASE_MONITOR",
                              "reset_monitor() needs an implementation")

    def add_callback(self, callback: Callable[[ITEM_T], None]) -> None:
        """
        Register a callback function to be invoked when notify() is called.

        The callback will receive the transaction item as its argument.
        Supports functions, methods, lambda expressions, or any callable object.

        Args:
            callback: A callable that takes one argument (ITEM_T) and returns None.

        Example:
            # Using a function
            def my_callback(item):
                print(f"Received: {item}")
            monitor.add_callback(my_callback)

            # Using a lambda
            monitor.add_callback(lambda item: process_item(item))

            # Using a method
            monitor.add_callback(self.my_handler)
        """
        if callback not in self._callbacks:
            self._callbacks.append(callback)
            self.logger.debug(f"{self.get_name()}: Added callback {callback}")
        else:
            self.uvm_report.warning("DV_BASE_MONITOR",
                                    f"Callback {callback} already registered")

    def remove_callback(self, callback: Callable[[ITEM_T], None]) -> None:
        """
        Unregister a previously registered callback.

        Args:
            callback: The callback to remove.
        """
        if callback in self._callbacks:
            self._callbacks.remove(callback)
            self.logger.debug(
                f"{self.get_name()}: Removed callback {callback}")
        else:
            self.uvm_report.warning("DV_BASE_MONITOR",
                                    f"Callback {callback} not found")

    def clear_callbacks(self) -> None:
        """Remove all registered callbacks."""
        self._callbacks.clear()
        self.logger.debug(f"{self.get_name()}: Cleared all callbacks")

    def notify(self, trans: ITEM_T):
        """
        Notify method wraps the analysis port 'write()' and performs callbacks
        to registered clients at the same time.

        This method:
        1. Invokes all registered callbacks with the transaction
        2. Writes the transaction to the analysis port for scoreboard/subscribers

        Args:
            trans: The transaction item to notify via the analysis port.
        """
        # Indicate the current transaction being monitored
        self.logger.debug(
            f"{self.get_name()}: dv_base_monitor::notify() - Called")

        # Invoke all registered callbacks (Pythonic approach)
        # This allows sequences and other components to react to monitor events
        for callback in self._callbacks:
            try:
                callback(trans)
            except Exception as e:
                self.uvm_report.error(
                    "DV_BASE_MONITOR",
                    f"Callback {callback} raised exception: {e}")
                # Continue with other callbacks even if one fails

        # Write to analysis port for scoreboard and other subscribers when available.
        if hasattr(self, "analysis_port") and self.analysis_port is not None:
            self.analysis_port.write(trans)
