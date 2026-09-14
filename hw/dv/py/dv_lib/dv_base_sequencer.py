# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
This is a base class for all sequencers. The base class provides optional analysis FIFOs
for communication between monitors and sequences.
"""

from typing import TYPE_CHECKING, Generic, Optional, TypeVar

import cocotb
from cocotb.task import CancelledError
from pyuvm import (UVM_LOW, resolve_uvm_verbosity, uvm_component,
                   uvm_sequence_item, uvm_sequencer)

if TYPE_CHECKING:
    from pyuvm import uvm_tlm_fifo

# Type variables for generic sequencer
ITEM_T = TypeVar('ITEM_T', bound=uvm_sequence_item)
CFG_T = TypeVar('CFG_T')  # Configuration type (typically dv_base_agent_cfg)
RSP_ITEM_T = TypeVar('RSP_ITEM_T', bound=uvm_sequence_item)


class dv_base_sequencer(uvm_sequencer, Generic[ITEM_T, CFG_T, RSP_ITEM_T]):
    """
    Base sequencer class with optional analysis FIFOs.

    These FIFOs collect items when req/rsp is received, which are used to
    communicate between monitor and sequences. These FIFOs are optional.

    - When device is re-active, it gets items from req_analysis_fifo
      and send rsp to driver
    - When this is a high-level agent, monitors put items to these 2 FIFOs
      for high-level seq

    Usage:
        class MySequencer(dv_base_sequencer[MyItem, MyCfg, MyRspItem]):
            pass
    """

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.cfg: Optional[CFG_T] = None  # Configuration object (CFG_T type)
        self.do_not_reset: bool = False
        self.is_virtual_sequencer: bool = False
        self._active_sequence_tasks: dict[int, tuple[object,
                                                     cocotb.task.Task]] = {}
        # These FIFOs are created conditionally in build_phase
        self.req_analysis_fifo: Optional['uvm_tlm_fifo[ITEM_T]'] = None
        self.rsp_analysis_fifo: Optional['uvm_tlm_fifo[RSP_ITEM_T]'] = None
        self.uvm_verbosity: int = int(getattr(parent, "uvm_verbosity",
                                              UVM_LOW))
        self.set_report_verbosity(self.uvm_verbosity)

    def build_phase(self):
        """Build phase - create analysis FIFOs if configured."""
        super().build_phase()

        # Avoid null pointer if the cfg is not defined.
        if not self.is_virtual_sequencer and self.cfg is None:
            self.uvm_report.fatal("DV_BASE_SEQUENCER", "cfg handle is null.")
        elif self.cfg is not None:
            self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                       self.cfg)
            self.set_report_verbosity(self.uvm_verbosity)
            # Import here to avoid circular dependencies
            from pyuvm import uvm_tlm_fifo

            if hasattr(self.cfg, 'has_req_fifo') and self.cfg.has_req_fifo:
                self.req_analysis_fifo = uvm_tlm_fifo("req_analysis_fifo",
                                                      self)
            if hasattr(self.cfg, 'has_rsp_fifo') and self.cfg.has_rsp_fifo:
                self.rsp_analysis_fifo = uvm_tlm_fifo("rsp_analysis_fifo",
                                                      self)

    async def _run_registered_sequence(self,
                                       seq,
                                       *,
                                       propagate_cancel: bool = True):
        task = cocotb.start_soon(seq.start(self))
        self._active_sequence_tasks[id(seq)] = (seq, task)
        try:
            return await task
        except CancelledError:
            if not task.done():
                task.cancel()
                try:
                    await task
                except CancelledError:
                    pass
            if propagate_cancel:
                raise
            return None
        finally:
            self._active_sequence_tasks.pop(id(seq), None)

    async def start_sequence(self, seq):
        return await self._run_registered_sequence(seq, propagate_cancel=True)

    def spawn_sequence(self, seq):
        return cocotb.start_soon(
            self._run_registered_sequence(seq, propagate_cancel=False))

    def flush_queues_on_reset(self):
        if hasattr(self, "seq_q") and self.seq_q is not None:
            self.seq_q._queue.clear()

        seq_item_export = getattr(self, "seq_item_export", None)
        if seq_item_export is not None:
            if hasattr(seq_item_export,
                       "req_q") and seq_item_export.req_q is not None:
                seq_item_export.req_q._queue.clear()
            if hasattr(seq_item_export,
                       "rsp_q") and seq_item_export.rsp_q is not None:
                seq_item_export.rsp_q._queue.clear()
            seq_item_export.current_item = None

        for fifo_name in ("req_analysis_fifo", "rsp_analysis_fifo",
                          "a_chan_req_fifo", "d_chan_rsp_fifo"):
            fifo = getattr(self, fifo_name, None)
            if fifo is None:
                continue
            while True:
                try:
                    success, _ = fifo.try_get()
                except Exception:
                    break
                if not success:
                    break

    def stop_sequences(self):
        for _, task in list(self._active_sequence_tasks.values()):
            if not task.done():
                task.cancel()
        self._active_sequence_tasks.clear()
        self.flush_queues_on_reset()
