# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Concrete smoke test for the TL-agent RAL migration bench."""

from __future__ import annotations

from typing import Optional

from pyuvm import uvm_component

from .tl_agent_ral_base_test import tl_agent_ral_base_test


class tl_agent_ral_smoke_test(tl_agent_ral_base_test):
    """Runs the initial register-model smoke virtual sequence by default."""

    def __init__(self, name: str, parent: Optional[uvm_component] = None):
        super().__init__(name, parent)
        self.test_seq_s = "tl_agent_ral.seq_lib.tl_agent_ral_smoke_vseq.tl_agent_ral_smoke_vseq"
