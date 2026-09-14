# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Common RAL enums and constants."""

from __future__ import annotations

from enum import Enum, auto


class UVM_STATUS(Enum):
    IS_OK = auto()
    NOT_OK = auto()
    HAS_X = auto()


class UVM_PATH(Enum):
    FRONTDOOR = auto()
    BACKDOOR = auto()
    DEFAULT = auto()


class UVM_PREDICT(Enum):
    DIRECT = auto()
    READ = auto()
    WRITE = auto()


class UVM_ACCESS(Enum):
    RW = "RW"
    RO = "RO"
    WO = "WO"
    W1C = "W1C"
    RC = "RC"


def normalize_access(access: str | UVM_ACCESS) -> str:
    """Return an uppercase access policy string."""

    if isinstance(access, UVM_ACCESS):
        return access.value
    return str(access).upper()
