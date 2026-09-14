# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
This is a base class for all drivers. The base class provides tasks and methods to make the
driver reset safe.
"""

from typing import Any, Generic, Optional, TypeVar

import cocotb
from cocotb.task import CancelledError
from cocotb.triggers import Timer
from pyuvm import (UVM_LOW, UVM_MEDIUM, resolve_uvm_verbosity, uvm_component,
                   uvm_driver, uvm_object, uvm_sequence_item)

from .dv_rst_domain import dv_rst_domain

# Type variables for generic driver
ITEM_T = TypeVar('ITEM_T', bound=uvm_sequence_item)
CFG_T = TypeVar(
    'CFG_T',
    bound=uvm_object)  # Configuration type (typically dv_base_agent_cfg)
RSP_ITEM_T = TypeVar('RSP_ITEM_T', bound=uvm_sequence_item)


class dv_base_driver(uvm_driver, Generic[ITEM_T, CFG_T, RSP_ITEM_T]):
    """
    Reset-safe base driver class.

    This driver provides reset-safe functionality by monitoring reset and properly
    terminating and restarting the drive thread when reset is asserted/deasserted.

    Requirements:
    - cfg.reset_domain must be set and provide async methods:
      * wait_reset_assert() -> None
      * wait_reset_deassert() -> None
    - Derived classes must implement:
      * async get_and_drive() - main driver loop
      * reset_interface_and_driver() - reset handling

    Usage:
        class MyDriver(dv_base_driver[MyItem, MyCfg, MyRspItem]):
            async def get_and_drive(self):
                while True:
                    item = await self.get_next_item()
                    # Drive item to DUT
                    self.item_done()

            def reset_interface_and_driver(self):
                # Reset interface signals
                pass
    """

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None  # Configuration object (CFG_T type)
        self.reset_domain: Optional[dv_rst_domain] = None
        # Python interface (cocotb 2.0): TlIf, ClkRstIf, etc. Set from
        # testbench/agent; used to drive pins.
        self.vif: Optional[Any] = None
        self.processing_item = False
        self._reset_task: Optional[cocotb.Task] = None
        self._drive_task: Optional[cocotb.Task] = None
        self.uvm_verbosity: int = int(getattr(parent, "uvm_verbosity",
                                              UVM_LOW))
        self.set_report_verbosity(self.uvm_verbosity)

    def start_of_simulation_phase(self):
        """Resolve reset_domain before run-time activity starts."""
        super().start_of_simulation_phase()
        self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                   self.cfg)
        self.set_report_verbosity(self.uvm_verbosity)

        if self.vif is None:
            self.uvm_report.fatal(
                "DV_BASE_DRIVER", "reset_domain == None "
                "please ensure reset_domain is setup")
        if self.reset_domain is None:
            self.uvm_report.fatal(
                "DV_BASE_DRIVER", "reset_domain == None "
                "please ensure reset_domain is setup")

    async def run_phase(self):
        """Main run phase that handles reset-safe driver operation."""
        await super().run_phase()

        # The first reset is POR. Wait until a full reset cycle is observed before
        # driving any transaction on the interface.
        await self.reset_domain.wait_reset_assert()
        self.reset_interface_and_driver()

        await self.reset_domain.wait_reset_deassert()
        self.uvm_report.info("DV_BASE_DRIVER", "POR Released", UVM_MEDIUM)

        while True:
            self._reset_task = None
            self._drive_task = None

            # Use Cocotb tasks for concurrent execution
            self.uvm_report.info(
                "DV_BASE_DRIVER",
                "Reset Deasserted - Starting Reset Monitor and Main Thread",
                UVM_MEDIUM,
            )

            # Start reset monitoring task
            self._reset_task = cocotb.start_soon(self._reset_monitor_task())

            # Start interface driving task
            self._drive_task = cocotb.start_soon(self.get_and_drive())

            self.uvm_report.info("DV_BASE_DRIVER", "Wait for Process Handles",
                                 UVM_MEDIUM)

            # Give tasks a moment to start (cocotb.start_soon returns immediately)
            await Timer(1, unit='ns')

            self.uvm_report.info(
                "DV_BASE_DRIVER",
                "Wait for Reset Monitor Thread to finish",
                UVM_MEDIUM,
            )

            # Wait till reset task finishes. Reset task should be the only one to finish
            # first as the drive task should be a forever loop getting transactions from
            # the sequencer and driving the interface signals.
            await self._reset_task

            self.uvm_report.info("DV_BASE_DRIVER", "Reset Thread finished",
                                 UVM_MEDIUM)

            # Check if drive task is still running and cancel it if needed
            if self._drive_task and not self._drive_task.done():
                self.uvm_report.info(
                    "DV_BASE_DRIVER",
                    "killing get_and_drive_thread() task",
                    UVM_MEDIUM,
                )
                self._drive_task.cancel()
                try:
                    await self._drive_task
                except CancelledError:
                    pass

                if self.processing_item:
                    self.uvm_report.info(
                        "DV_BASE_DRIVER",
                        "get_and_drive_thread() killed while processing item",
                        UVM_MEDIUM,
                    )
                self.processing_item = False
            elif self._drive_task and self._drive_task.done():
                self.uvm_report.fatal(
                    "DV_BASE_DRIVER", "get_and_drive_thread() task finished "
                    "before reset thread")

            self.uvm_report.info(
                "DV_BASE_DRIVER",
                "Waiting for Reset to Deassert",
                UVM_MEDIUM,
            )
            await self.reset_domain.wait_reset_deassert()

    async def _reset_monitor_task(self):
        """Monitor reset assertion and handle reset when it occurs."""
        await self.reset_domain.wait_reset_assert()
        self.uvm_report.info("DV_BASE_DRIVER", "Reset Asserted", UVM_MEDIUM)
        self.reset_interface_and_driver()

    async def get_and_drive(self):
        """
        Main task of the driver that will fetch a transaction from the sequencer and
        then convert the commands in the transaction to pin wiggles on the interface of the DUT.

        This method must be implemented by derived classes.
        """
        self.uvm_report.fatal("DV_BASE_DRIVER",
                              "get_and_drive() needs an implementation")

    def reset_interface_and_driver(self):
        """
        Reset interface and driver function is invoked when reset is triggered.

        The derived driver needs to implement this to get the driver and the pins to
        the default state when in reset.
        """
        self.uvm_report.fatal(
            "DV_BASE_DRIVER",
            "reset_interface_and_driver() needs an implementation")

    async def get_next_item(self) -> ITEM_T:
        """
        Get the next item from the sequencer.

        Returns:
            The next sequence item from the sequencer.
        """
        item = await self.seq_item_port.get_next_item()
        self.processing_item = True
        return item

    def item_done(self):
        """Signal that the current item processing is complete."""
        self.seq_item_port.item_done()
        self.processing_item = False
