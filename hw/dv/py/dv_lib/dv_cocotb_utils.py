# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Shared cocotb helper utilities for Python DV testbenches."""

from __future__ import annotations

from importlib import import_module
from typing import Optional

import cocotb


def get_plusarg(name: str) -> Optional[str]:
    """Return a cocotb plusarg value as text, if present."""
    plusargs = getattr(cocotb, "plusargs", None)
    if plusargs is None:
        return None
    value = plusargs.get(name)
    if value in (None, False):
        return None
    if value is True:
        return "1"
    return str(value)


def resolve_pyuvm_test_name(plusarg_name: str = "UVM_TESTNAME") -> str:
    """Resolve a pyUVM test selector to the class name accepted by run_test()."""
    test_name = get_plusarg(plusarg_name)
    if not test_name:
        raise RuntimeError(f"{plusarg_name} plusarg is required")

    if ":" in test_name:
        module_name, class_name = test_name.split(":", 1)
        import_module(module_name)
        return class_name

    module_name, sep, class_name = test_name.rpartition(".")
    if sep:
        import_module(module_name)
        return class_name

    return test_name
