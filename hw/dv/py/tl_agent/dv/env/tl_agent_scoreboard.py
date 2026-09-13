# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink environment scoreboard."""

from __future__ import annotations

from collections import defaultdict
from typing import Any, Dict, List

import cocotb
from dv_lib.dv_base_scoreboard import dv_base_scoreboard
from pyuvm import uvm_tlm_analysis_fifo

from ...tl_seq_item import tl_seq_item
from .tl_agent_env_cfg import tl_agent_env_cfg


class scoreboard_pkg:
    """Small Python shim for the constants used by the SV scoreboard wiring."""

    kSrcPort = "src"
    kDstPort = "dst"
    kInOrderCheck = "in_order"


class tl_agent_scoreboard(dv_base_scoreboard[None, tl_agent_env_cfg, object]):
    """Python port of SV ``tl_agent_scoreboard``."""

    def __init__(self, name: str, parent=None):
        super().__init__(name, parent)
        self.chan_prefix_len: int = 7
        self.item_fifos: Dict[str, uvm_tlm_analysis_fifo] = {}
        self._port_dir: Dict[str, str] = {}
        self._queue_check_type: Dict[str, str] = {}
        self._queue_src: Dict[str, List[tl_seq_item]] = defaultdict(list)
        self._queue_dst: Dict[str, List[tl_seq_item]] = defaultdict(list)
        self._reader_tasks: List[cocotb.Task] = []

    def add_item_port(self, name: str, port_kind: str) -> None:
        self.item_fifos[name] = uvm_tlm_analysis_fifo(name, self)
        self._port_dir[name] = port_kind

    def add_item_queue(self, name: str, check_type: str) -> None:
        self._queue_check_type[name] = check_type

    def get_queue_name(self, tr: tl_seq_item, port_name: str) -> str:
        del tr
        if port_name in {"host_req_chan", "device_req_chan"}:
            return "req_chan"
        return "rsp_chan"

    async def run_phase(self):
        await super().run_phase()
        for port_name, fifo in self.item_fifos.items():
            self._reader_tasks.append(
                cocotb.start_soon(self._consume_port(port_name, fifo)))

    async def _consume_port(self, port_name: str,
                            fifo: uvm_tlm_analysis_fifo) -> None:
        while True:
            item = await fifo.get()
            queue_name = self.get_queue_name(item, port_name)
            if self._port_dir.get(port_name) == scoreboard_pkg.kSrcPort:
                self._queue_src[queue_name].append(item)
            else:
                self._queue_dst[queue_name].append(item)
            self._check_in_order(queue_name)

    def _check_in_order(self, queue_name: str) -> None:
        if self._queue_check_type.get(
                queue_name) != scoreboard_pkg.kInOrderCheck:
            return

        src_q = self._queue_src[queue_name]
        dst_q = self._queue_dst[queue_name]
        while src_q and dst_q:
            src = src_q.pop(0)
            dst = dst_q.pop(0)
            if not self._items_match(src, dst):
                self.uvm_report.error(
                    "TL_AGENT_SCOREBOARD", f"queue '{queue_name}' mismatch\n"
                    f"src={src.convert2string()}\n"
                    f"dst={dst.convert2string()}")

    def _items_match(self, lhs: Any, rhs: Any) -> bool:
        do_compare = getattr(lhs, "do_compare", None)
        if callable(do_compare):
            return bool(do_compare(rhs))
        return lhs == rhs
