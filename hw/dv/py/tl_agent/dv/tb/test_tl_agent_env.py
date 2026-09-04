# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import cocotb
import tl_agent.dv.pyuvm_registry  # noqa: F401 Register pyUVM tests.
from cocotb.triggers import Timer, with_timeout
from dv_lib.dv_cocotb_utils import get_plusarg, resolve_pyuvm_test_name
from pyuvm import uvm_root


@cocotb.test()
async def run_tl_agent_env_pyuvm(dut):
    del dut
    test_name = resolve_pyuvm_test_name()
    timeout_us = int(get_plusarg("TEST_TIMEOUT_US") or "80", 0)
    test_task = cocotb.start_soon(uvm_root().run_test(test_name))

    # A wait on the timer is essential to allow cocotb scheduler to build pyUVM TB and allow the
    # test to proceed
    await Timer(1, unit="ns")
    await with_timeout(test_task, timeout_us, "us")
