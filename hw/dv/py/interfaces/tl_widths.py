# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Default TileLink widths with explicit Python-side override hooks."""

from dataclasses import dataclass, replace
from typing import Callable, List


@dataclass(frozen=True)
class TlWidths:
    tl_aw: int = 32
    tl_dw: int = 32
    tl_aiw: int = 8
    tl_diw: int = 1
    tl_auw: int = 28
    tl_duw: int = 14
    tl_dbw: int = 4
    tl_szw: int = 2
    tl_opcode_w: int = 3
    tl_param_w: int = 3


_TL_WIDTHS = TlWidths()
_REFRESHERS: List[Callable[[TlWidths], None]] = []


def get_tl_widths() -> TlWidths:
    return _TL_WIDTHS


def set_tl_widths(**overrides: int) -> TlWidths:
    global _TL_WIDTHS
    _TL_WIDTHS = replace(_TL_WIDTHS, **overrides)
    return _TL_WIDTHS


def register_tl_width_refresher(refresher: Callable[[TlWidths], None]) -> None:
    _REFRESHERS.append(refresher)


def apply_tl_width_overrides(**overrides: int) -> TlWidths:
    widths = set_tl_widths(**overrides)
    for refresher in _REFRESHERS:
        refresher(widths)
    return widths
