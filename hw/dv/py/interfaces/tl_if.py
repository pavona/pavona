# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
Python translation of SystemVerilog tl_if (cocotb 2.0 only).

TileLink UL interface: host-to-device (h2d) and device-to-host (d2h) channels,
if_mode (Host/Device), and signal access via DUT prefix. Mirrors hw/dv/sv/tl_agent/tl_if.sv
and tlul_pkg structs (tl_h2d_t, tl_d2h_t). All drive/sample use handle.value;
synchronization uses cocotb triggers (e.g. RisingEdge(clk)).
"""

from enum import IntEnum
from typing import Any, Optional

from .tl_widths import (apply_tl_width_overrides, get_tl_widths,
                        register_tl_width_refresher)


class TlAOp(IntEnum):
    """A-channel opcode (request type). Matches tlul_pkg::tl_a_op_e."""

    PutFullData = 0
    PutPartialData = 1
    Get = 4


class TlDOp(IntEnum):
    """D-channel opcode (response type). Matches tlul_pkg::tl_d_op_e."""

    AccessAck = 0
    AccessAckData = 1


class IfMode(IntEnum):
    """Interface mode: Host drives h2d and samples d2h; Device drives d2h and samples h2d."""

    Host = 0
    Device = 1


class TlIf:
    """
    TileLink UL interface bound to DUT by (dut, prefix).

    Signal names are prefix + <name>, e.g. prefix "tl_" yields tl_a_valid, tl_d_ready, etc.
    Optional clk/rst_n can be set for sync; otherwise bind from ClkRstIf or testbench.
    if_mode selects Host (drive h2d, sample d2h) or Device (sample h2d, drive d2h).
    """

    # Default widths (match current SV defaults unless overridden in Python).
    _widths = get_tl_widths()
    TL_AW = _widths.tl_aw
    TL_DW = _widths.tl_dw
    TL_AIW = _widths.tl_aiw
    TL_DIW = _widths.tl_diw
    TL_AUW = _widths.tl_auw
    TL_DUW = _widths.tl_duw
    TL_DBW = _widths.tl_dbw
    TL_SZW = _widths.tl_szw
    TL_OPCODE_W = _widths.tl_opcode_w
    TL_PARAM_W = _widths.tl_param_w

    @classmethod
    def override_widths(cls, **overrides: int) -> None:
        apply_tl_width_overrides(**overrides)

    def __init__(
        self,
        dut: Any,
        prefix: str = "tl_",
        clk: Optional[Any] = None,
        rst_n: Optional[Any] = None,
        if_name: str = "tl",
    ) -> None:
        self._dut = dut
        self._prefix = prefix.rstrip("_") + "_" if prefix else ""
        self.msg_id = f"[TlIf:{if_name}]"
        self._clk = clk
        self._rst_n = rst_n
        self.if_mode: IfMode = IfMode.Host

    def _sig(self, name: str) -> Any:
        n = self._prefix + name
        return getattr(self._dut, n)

    # ---------- Clock / reset (optional) ----------

    @property
    def clk(self) -> Optional[Any]:
        return self._clk

    @property
    def rst_n(self) -> Optional[Any]:
        return self._rst_n

    def set_clk_rst(self, clk: Any, rst_n: Any) -> None:
        self._clk = clk
        self._rst_n = rst_n

    # ---------- Host-to-Device (h2d) channel ----------
    # Host drives these; Device samples. d_ready is driven by Device, sampled by Host.

    @property
    def a_valid(self) -> Any:
        return self._sig("a_valid")

    @property
    def a_opcode(self) -> Any:
        return self._sig("a_opcode")

    @property
    def a_param(self) -> Any:
        return self._sig("a_param")

    @property
    def a_size(self) -> Any:
        return self._sig("a_size")

    @property
    def a_source(self) -> Any:
        return self._sig("a_source")

    @property
    def a_address(self) -> Any:
        return self._sig("a_address")

    @property
    def a_mask(self) -> Any:
        return self._sig("a_mask")

    @property
    def a_data(self) -> Any:
        return self._sig("a_data")

    @property
    def a_user(self) -> Any:
        return self._sig("a_user")

    @property
    def d_ready(self) -> Any:
        return self._sig("d_ready")

    # ---------- Device-to-Host (d2h) channel ----------
    # Device drives these; Host samples. a_ready is driven by Device, sampled by Host.

    @property
    def d_valid(self) -> Any:
        return self._sig("d_valid")

    @property
    def d_opcode(self) -> Any:
        return self._sig("d_opcode")

    @property
    def d_param(self) -> Any:
        return self._sig("d_param")

    @property
    def d_size(self) -> Any:
        return self._sig("d_size")

    @property
    def d_source(self) -> Any:
        return self._sig("d_source")

    @property
    def d_sink(self) -> Any:
        return self._sig("d_sink")

    @property
    def d_data(self) -> Any:
        return self._sig("d_data")

    @property
    def d_user(self) -> Any:
        return self._sig("d_user")

    @property
    def d_error(self) -> Any:
        return self._sig("d_error")

    @property
    def a_ready(self) -> Any:
        return self._sig("a_ready")

    # ---------- Convenience: drive idle (TL_H2D_DEFAULT / TL_D2H_DEFAULT style) ----------

    def drive_h2d_idle(self) -> None:
        """Drive h2d channel to idle (Host): a_valid=0, d_ready=1, others default."""
        self.a_valid.value = 0
        self.d_ready.value = 1

    def drive_d2h_idle(self) -> None:
        """Drive d2h channel to idle (Device): d_valid=0, a_ready=1, others default."""
        self.d_valid.value = 0
        self.a_ready.value = 1


def _refresh_tl_if_widths(widths) -> None:
    TlIf.TL_AW = widths.tl_aw
    TlIf.TL_DW = widths.tl_dw
    TlIf.TL_AIW = widths.tl_aiw
    TlIf.TL_DIW = widths.tl_diw
    TlIf.TL_AUW = widths.tl_auw
    TlIf.TL_DUW = widths.tl_duw
    TlIf.TL_DBW = widths.tl_dbw
    TlIf.TL_SZW = widths.tl_szw
    TlIf.TL_OPCODE_W = widths.tl_opcode_w
    TlIf.TL_PARAM_W = widths.tl_param_w


register_tl_width_refresher(_refresh_tl_if_widths)
_refresh_tl_if_widths(get_tl_widths())
