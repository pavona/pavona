# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generic Python register abstraction layer."""

from .uvm_mem import uvm_mem
from .uvm_reg import uvm_reg
from .uvm_reg_adapter import uvm_reg_adapter
from .uvm_reg_backdoor import uvm_reg_backdoor
from .uvm_reg_block import uvm_reg_block
from .uvm_reg_field import uvm_reg_field
from .uvm_reg_frontdoor import uvm_reg_frontdoor
from .uvm_reg_item import uvm_reg_bus_op, uvm_reg_item
from .uvm_reg_map import uvm_reg_map
from .uvm_reg_model import (UVM_ACCESS, UVM_PATH, UVM_PREDICT, UVM_STATUS,
                            normalize_access)
from .uvm_reg_predictor import uvm_reg_predictor
from .uvm_reg_sequence import uvm_reg_sequence

__all__ = [
    "UVM_ACCESS",
    "UVM_PATH",
    "UVM_PREDICT",
    "UVM_STATUS",
    "normalize_access",
    "uvm_reg_bus_op",
    "uvm_reg_item",
    "uvm_reg_adapter",
    "uvm_reg_field",
    "uvm_reg",
    "uvm_reg_map",
    "uvm_reg_block",
    "uvm_mem",
    "uvm_reg_predictor",
    "uvm_reg_sequence",
    "uvm_reg_frontdoor",
    "uvm_reg_backdoor",
]
