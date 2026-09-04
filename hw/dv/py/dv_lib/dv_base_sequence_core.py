# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Shared runtime helpers for pyUVM sequences."""

from __future__ import annotations

from typing import Optional

import cocotb
from pyuvm import UVM_LOW, uvm_sequence


class dv_base_sequence_core(uvm_sequence):
    """Common sequence runtime and spawned-task ownership."""

    def __init__(self, name: str = "dv_base_sequence_core") -> None:
        super().__init__(name)
        self.uvm_verbosity: int = UVM_LOW
        self.set_report_verbosity(self.uvm_verbosity)
        self._spawned_tasks: dict[int, tuple[str, cocotb.task.Task]] = {}

    def spawn_task(self, coro, name: Optional[str] = None):
        task = cocotb.start_soon(coro)
        task_name = name or getattr(coro, "__name__",
                                    f"{self.get_name()}_task")
        self._spawned_tasks[id(task)] = (task_name, task)
        return task

    async def cancel_spawned_tasks(self) -> None:
        for key, (_, task) in list(self._spawned_tasks.items()):
            if not task.done():
                task.cancel()
            self._spawned_tasks.pop(key, None)
