# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""pyUVM factory registration for TileLink tests."""

from .tests.tl_agent_base_test import tl_agent_base_test
from .tests.tl_agent_report_demotion_test import tl_agent_report_demotion_test

__all__ = [
    "tl_agent_base_test",
    "tl_agent_report_demotion_test",
]
