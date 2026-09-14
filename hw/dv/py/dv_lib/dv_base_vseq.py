# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Reset-safe base virtual sequence."""

from importlib import import_module
from typing import Generic, Optional, Type, TypeVar, cast

import cocotb
from cocotb.task import CancelledError
from cocotb.triggers import Timer
from pyuvm import UVM_MEDIUM, resolve_uvm_verbosity, uvm_sequence

from .dv_base_env_cfg import dv_base_env_cfg
from .dv_base_env_cov import dv_base_env_cov
from .dv_base_sequence_core import dv_base_sequence_core
from .dv_cocotb_utils import get_plusarg
from .dv_config_parameters import dv_config_parameters
from .dv_test_seq_parameters import EnableType, dv_test_seq_parameters

RAL_T = TypeVar("RAL_T")
CFG_T = TypeVar("CFG_T", bound=dv_base_env_cfg)
COV_T = TypeVar("COV_T", bound=dv_base_env_cov)
VIRTUAL_SEQUENCER_T = TypeVar("VIRTUAL_SEQUENCER_T")
TEST_PARAMS_T = TypeVar("TEST_PARAMS_T", bound=dv_test_seq_parameters)
CONFIG_PARAMS_T = TypeVar("CONFIG_PARAMS_T", bound=dv_config_parameters)


class dv_base_vseq(
        dv_base_sequence_core,
        Generic[RAL_T, CFG_T, COV_T, VIRTUAL_SEQUENCER_T, TEST_PARAMS_T,
                CONFIG_PARAMS_T],
):
    """Reset-safe base virtual sequence for Python DV environments."""

    TEST_PARAMS_CLS: Type[TEST_PARAMS_T] = dv_test_seq_parameters
    CONFIG_PARAMS_CLS: Type[CONFIG_PARAMS_T] = dv_config_parameters

    def __init__(self, name: str = "dv_base_vseq") -> None:
        super().__init__(name)
        self.p_sequencer: Optional[VIRTUAL_SEQUENCER_T] = None
        self.cfg: Optional[CFG_T] = None
        self.ral: Optional[RAL_T] = None
        self.cov: Optional[COV_T] = None
        self.in_reset: bool = True
        self.test_params: Optional[TEST_PARAMS_T] = None
        self.config_params: Optional[CONFIG_PARAMS_T] = None
        self._reset_monitor_task: Optional[cocotb.Task] = None

    async def dut_init(self) -> None:
        self.uvm_report.fatal(
            "DV_BASE_VSEQ",
            "Derived classes need to provide a dut_init() implementation",
        )

    async def dut_shutdown(self) -> None:
        return

    async def post_apply_reset(self, reset_kind: str = "HARD") -> None:
        del reset_kind

    def create_seq_by_name(self, name: str) -> uvm_sequence:
        """Create a sequence from a fully-qualified Python class path."""
        module_name: str
        class_name: str
        if ":" in name:
            module_name, class_name = name.split(":", 1)
        else:
            module_name, _, class_name = name.rpartition(".")
        if not module_name or not class_name:
            self.uvm_report.fatal(
                "DV_BASE_VSEQ", f"""cannot resolve sequence name '{name}'""")

        cls = getattr(import_module(module_name), class_name)
        seq = cls()
        if not isinstance(seq, uvm_sequence):
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  f"""'{name}' is not a uvm_sequence""")
        return seq

    def _get_p_sequencer(self) -> VIRTUAL_SEQUENCER_T:
        if self.p_sequencer is not None:
            return self.p_sequencer
        sequencer = getattr(self, "sequencer", None)
        if sequencer is None:
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  """Did you forget to set the sequencer?""")

        self.p_sequencer = cast(VIRTUAL_SEQUENCER_T, sequencer)
        return self.p_sequencer

    def _bind_from_sequencer(self) -> None:
        p_sequencer = self._get_p_sequencer()
        self.cfg = cast(CFG_T, getattr(p_sequencer, "cfg", None))
        self.cov = cast(Optional[COV_T], getattr(p_sequencer, "cov", None))
        if self.cfg is not None:
            self.ral = cast(Optional[RAL_T], self.cfg.ral)
            self.uvm_verbosity = resolve_uvm_verbosity(self.uvm_verbosity,
                                                       self.cfg)
            self.set_report_verbosity(self.uvm_verbosity)

    async def pre_body(self) -> None:
        await super().pre_body()
        self._bind_from_sequencer()
        if self.cfg is None:
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  "p_sequencer.cfg is required")

    async def post_start(self) -> None:
        await super().post_start()
        if self.test_params is not None and self.test_params.do_dut_shutdown:
            await self.dut_shutdown()

    def create_test_params(self) -> TEST_PARAMS_T:
        return self.TEST_PARAMS_CLS("test_seq_parameters")

    def create_config_params(self) -> CONFIG_PARAMS_T:
        return self.CONFIG_PARAMS_CLS("config_parameters")

    def _is_reset_testing_forced(self) -> bool:
        value = get_plusarg("en_reset_testing")
        if value is None:
            return False
        return value.strip().lower() not in ("0", "false", "no", "")

    def randomize_test_params(self) -> None:
        if self.test_params is None:
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  "test_params is not initialized")
        try:
            if self._is_reset_testing_forced():
                with self.test_params.randomize_with():
                    self.test_params.reset_testing == int(EnableType.ENABLE)
            else:
                self.test_params.randomize()
        except Exception as err:
            self.uvm_report.fatal(
                "DV_BASE_VSEQ",
                f"DV Test Parameters Randomization Failed: {err}")

    def randomize_config_params(self) -> None:
        if self.config_params is None:
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  "config_params is not initialized")
        try:
            self.config_params.randomize()
        except Exception as err:
            self.uvm_report.fatal(
                "DV_BASE_VSEQ",
                f"DV Config Parameters Randomization Failed: {err}")

    def freeze_test_params(self) -> None:
        if self.test_params is not None:
            self.test_params.constraint_mode(0)

    async def body(self) -> None:
        if self.cfg is None:
            self._bind_from_sequencer()

        self.uvm_report.info("DV_BASE_VSEQ", "body() - Starting", UVM_MEDIUM)
        self.test_params = self.create_test_params()
        self.config_params = None

        self.randomize_test_params()
        self.freeze_test_params()

        await self.monitor_reset()

        while self.test_params.num_reset_loops > 0:
            self.config_params = self.create_config_params()
            self.randomize_config_params()
            self.test_params.num_reset_loops -= 1

            if self.in_reset:
                await self.cfg.reset_domain.wait_reset_deassert()

            if self.test_params.do_dut_init:
                await self.dut_init()

            self.uvm_report.info("DV_BASE_VSEQ", "Reset Loop: Starting Forks",
                                 UVM_MEDIUM)
            reset_task = cocotb.start_soon(self._run_reset_thread_iteration())
            main_task = cocotb.start_soon(self.main_thread())

            # use of Timer here is essential to allow the cocotb tasks scheduler to start
            # reset_task and main_task
            await Timer(1, unit="ns")
            await reset_task

            if (self.test_params.num_reset_loops != 0 and
                    self.test_params.reset_testing == EnableType.ENABLE):
                if not main_task.done():
                    self.uvm_report.info(
                        "DV_BASE_VSEQ",
                        "body() - killing main_thread()",
                        UVM_MEDIUM,
                    )
                    main_task.cancel()
                    try:
                        await main_task
                    except CancelledError:
                        pass
                else:
                    self.uvm_report.warning(
                        "DV_BASE_VSEQ",
                        "Reset testing enabled and main_thread() finished before "
                        "reset_trigger_thread()")
            else:
                self.uvm_report.info(
                    "DV_BASE_VSEQ",
                    "Waiting for main_thread() to complete",
                    UVM_MEDIUM,
                )
                await main_task

        self.uvm_report.info("DV_BASE_VSEQ", "body() - Exiting", UVM_MEDIUM)

    async def monitor_reset(self) -> None:
        """Wait for POR release, then spawn a background reset monitor."""
        if self.cfg is None or self.cfg.reset_domain is None:
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  "cfg.reset_domain is required")

        self.uvm_report.info("DV_BASE_VSEQ", "Waiting for POR Release",
                             UVM_MEDIUM)
        await self.cfg.reset_domain.wait_reset_assert()
        await self.cfg.reset_domain.wait_reset_deassert()

        self.uvm_report.info("DV_BASE_VSEQ",
                             "POR Released - Starting Reset Monitoring",
                             UVM_MEDIUM)
        self.in_reset = False

        if self._reset_monitor_task is None or self._reset_monitor_task.done():
            self._reset_monitor_task = cocotb.start_soon(
                self._monitor_reset_thread())

    async def _run_reset_thread_iteration(self) -> None:
        if self.test_params is None:
            self.uvm_report.fatal("DV_BASE_VSEQ",
                                  "test_params not initialized")
        if (self.test_params.num_reset_loops != 0 and
                self.test_params.reset_testing == EnableType.ENABLE):
            await self.reset_trigger_thread()
            if self.cfg is None or self.cfg.reset_domain is None:
                self.uvm_report.fatal("DV_BASE_VSEQ",
                                      "cfg.reset_domain is required")
            await self.cfg.reset_domain.wait_reset_assert()

        self.uvm_report.info(
            "DV_BASE_VSEQ",
            "dv_base_seq::_run_reset_thread_iteration() - Exiting",
            UVM_MEDIUM,
        )

    async def _monitor_reset_thread(self) -> None:
        while True:
            assert self.cfg is not None and self.cfg.reset_domain is not None
            await self.cfg.reset_domain.wait_reset_assert()
            self.uvm_report.info("DV_BASE_VSEQ",
                                 "Reset Assertion - Stopping Sequences",
                                 UVM_MEDIUM)
            self.in_reset = True
            await self.cfg.reset_domain.wait_reset_deassert()
            self.in_reset = False

    async def reset_trigger_thread(self) -> None:
        self.uvm_report.fatal(
            "DV_BASE_VSEQ", f"""
          {self.get_name()}: Derived sequence needs to provide reset_trigger_thread()"""
        )

    async def main_thread(self) -> None:
        self.uvm_report.fatal(
            "DV_BASE_VSEQ", "Derived sequence needs to provide main_thread()")

    def handle_reset_assertion(self) -> None:
        self.uvm_report.fatal(
            "DV_BASE_VSEQ", f"""
          {self.get_name()}: Derived sequence needs to provide handle_reset_assertion()"""
        )
