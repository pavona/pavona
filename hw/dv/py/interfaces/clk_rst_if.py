# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
Python translation of SystemVerilog clk_rst_if (cocotb 2.0 only).

Generic clock and reset interface: drive clk/rst_n, wait for edges/cycles,
apply reset schemes, optional jitter/freq scaling. All signal drives and
synchronization use only cocotb 2.0: handle.value, Timer, RisingEdge,
FallingEdge, ClockCycles, First.
"""

import random
from enum import IntEnum
from typing import Any, Optional

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, First, RisingEdge, Timer
from pyuvm import UVM_LOW, uvm_reporter


class RstScheme(IntEnum):
    """Reset scheme: sync/async assert and deassert."""

    RstAssertSyncDeassertSync = 0
    RstAssertAsyncDeassertSync = 1
    RstAssertAsyncDeassertASync = 2


class ClkRstIf:
    """
    Clock and reset interface: drive clk and rst_n, wait for clocks/reset.

    Bound to DUT by (dut, prefix): clk = getattr(dut, prefix + "clk"),
    rst_n = getattr(dut, prefix + "rst_n"). All drives/samples use
    handle.value; all waits use cocotb.triggers.
    """

    def __init__(self,
                 dut: Any,
                 logger: Any,
                 prefix: str = "",
                 if_name: str = "main") -> None:
        self._dut = dut
        self._prefix = prefix
        self.logger = logger
        self.uvm_report = uvm_reporter(logger, UVM_LOW)
        self.msg_id = f"ClkRstIf:{if_name}"

        # Drive enable (set by set_active)
        self.drive_clk: bool = True
        self.drive_rst_n: bool = True

        # Period / frequency (50 MHz default)
        self.clk_period_ps: int = 20_000
        self.clk_freq_mhz: float = 50.0
        self.duty_cycle: int = 50  # 1–99

        # Jitter
        self.max_plus_jitter_ps: int = 1000
        self.max_minus_jitter_ps: int = 1000
        self.jitter_chance_pc: int = 0

        # Freq scaling (percent)
        self.clk_freq_scaling_pc: int = 0
        self.clk_freq_scaling_chance_pc: int = 50
        self.clk_freq_scale_up: bool = False

        # Internal for clock loop
        self._recompute: bool = True
        self._clk_hi_ps: int = 0
        self._clk_lo_ps: int = 0
        self._clk_hi_modified_ps: float = 0.0
        self._clk_lo_modified_ps: float = 0.0
        self.sole_clock: bool = False

        self._clock_task: Optional[cocotb.Task] = None

    def _sig(self, name: str) -> Any:
        n = self._prefix + name if self._prefix else name
        return getattr(self._dut, n)

    @property
    def clk(self) -> Any:
        return self._sig("clk")

    @property
    def rst_n(self) -> Any:
        return self._sig("rst_n")

    def _drive_clk_val(self, val: int) -> None:
        self.clk.value = val

    def _drive_rst_n_val(self, val: int) -> None:
        self.rst_n.value = val

    # ---------- Configuration (mirror SV functions) ----------

    def set_freq_khz(self, freq_khz: int) -> None:
        if freq_khz <= 0:
            raise ValueError(f"{self.msg_id} freq_khz must be > 0")
        self.clk_freq_mhz = freq_khz / 1000.0
        self.clk_period_ps = int(1_000_000 / self.clk_freq_mhz)
        self._recompute = True

    def set_freq_mhz(self, freq_mhz: int) -> None:
        if freq_mhz <= 0:
            raise ValueError(f"{self.msg_id} freq_mhz must be > 0")
        self.set_freq_khz(freq_mhz * 1000)

    def set_period_ps(self, period_ps: int) -> None:
        self.clk_period_ps = period_ps
        self.clk_freq_mhz = 1_000_000 / period_ps
        self._recompute = True

    def set_duty_cycle(self, duty: int) -> None:
        if duty < 1 or duty > 99:
            raise ValueError(f"{self.msg_id} duty_cycle must be 1–99")
        self.duty_cycle = duty
        self._recompute = True

    def set_freq_scaling(
        self,
        freq_scaling_pc: int,
        freq_scaling_chance_pc: int = 50,
        freq_scale_up: bool = False,
    ) -> None:
        if freq_scaling_pc < 0:
            raise ValueError(f"{self.msg_id} freq_scaling_pc >= 0")
        if not 0 <= freq_scaling_chance_pc <= 100:
            raise ValueError(f"{self.msg_id} freq_scaling_chance_pc 0-100")
        self.clk_freq_scaling_pc = freq_scaling_pc
        self.clk_freq_scaling_chance_pc = freq_scaling_chance_pc
        self.clk_freq_scale_up = freq_scale_up

    def set_max_jitter_ps(self,
                          plus_jitter_ps: int,
                          minus_jitter_ps: Optional[int] = None) -> None:
        self.max_plus_jitter_ps = plus_jitter_ps
        self.max_minus_jitter_ps = (
            minus_jitter_ps if minus_jitter_ps is not None else plus_jitter_ps)

    def set_jitter_chance_pc(self, jitter_chance: int) -> None:
        if not 0 <= jitter_chance <= 100:
            raise ValueError(f"{self.msg_id} jitter_chance 0-100")
        self.jitter_chance_pc = jitter_chance

    def set_sole_clock(self, is_sole: bool = True) -> None:
        self.sole_clock = is_sole

    def set_active(self,
                   drive_clk_val: bool = True,
                   drive_rst_n_val: bool = True) -> None:
        self.drive_clk = drive_clk_val
        self.drive_rst_n = drive_rst_n_val
        if self.drive_clk and self._clock_task is None:
            self._clock_task = cocotb.start_soon(self._clock_gen())

    async def start_clk(self, wait_for_posedge: bool = False) -> None:
        self.clk_gate = False
        if wait_for_posedge:
            await ClockCycles(self.clk, 1)

    def stop_clk(self) -> None:
        self.clk_gate = True

    def drive_rst_pin(self, val: int = 0) -> None:
        if self.drive_rst_n:
            self._drive_rst_n_val(val)

    # ---------- Wait / sync (cocotb 2.0 triggers only) ----------

    async def wait_clks(self, num_clks: int) -> None:
        await ClockCycles(self.clk, num_clks)

    async def wait_n_clks(self, num_clks: int) -> None:
        for _ in range(num_clks):
            await FallingEdge(self.clk)

    async def wait_for_reset(
        self,
        wait_negedge: bool = True,
        wait_posedge: bool = True,
    ) -> None:
        r = self.rst_n
        v = r.value
        if wait_negedge and (v is None or int(v) != 0):
            await FallingEdge(r)
        if wait_posedge:
            await RisingEdge(r)

    async def wait_clks_or_rst(self, num_clks: int) -> None:

        async def wait_rst() -> None:
            await self.wait_for_reset(wait_negedge=True, wait_posedge=False)

        await First(ClockCycles(self.clk, num_clks), wait_rst())

    # ---------- Apply reset ----------

    async def apply_reset(
        self,
        reset_width_clks: int = 50,
        post_reset_dly_clks: int = 0,
        rst_n_scheme: RstScheme = RstScheme.RstAssertAsyncDeassertSync,
    ) -> None:
        self.uvm_report.info(self.msg_id, "apply_reset()", UVM_LOW)
        if not self.drive_rst_n:
            self.uvm_report.info(self.msg_id, "NOT DRIVING RESET", UVM_LOW)
            return
        dly_ps = random.randint(
            0, self.clk_period_ps) if self.clk_period_ps else 0

        if rst_n_scheme == RstScheme.RstAssertSyncDeassertSync:
            self._drive_rst_n_val(0)
            await self.wait_clks(reset_width_clks)
            self._drive_rst_n_val(1)
        elif rst_n_scheme == RstScheme.RstAssertAsyncDeassertSync:
            if dly_ps > 0:
                await Timer(dly_ps, unit="ps")
            self._drive_rst_n_val(0)
            await self.wait_clks(reset_width_clks)
            self._drive_rst_n_val(1)
        elif rst_n_scheme == RstScheme.RstAssertAsyncDeassertASync:
            if dly_ps > 0:
                await Timer(dly_ps, unit="ps")
            self._drive_rst_n_val(0)
            await self.wait_clks(reset_width_clks)
            dly_ps = random.randint(
                0, self.clk_period_ps) if self.clk_period_ps else 0
            if dly_ps > 0:
                await Timer(dly_ps, unit="ps")
            self._drive_rst_n_val(1)
        else:
            raise ValueError(
                f"{self.msg_id} rst_n_scheme not supported: {rst_n_scheme}")

        if post_reset_dly_clks:
            await self.wait_clks(post_reset_dly_clks)

    # ---------- Clock generator (cocotb 2.0: Timer only) ----------

    def _apply_freq_scaling(self) -> None:
        if random.randint(1, 100) > self.clk_freq_scaling_chance_pc:
            return
        mult = 1.0 if (self.clk_freq_scale_up and
                       random.randint(0, 1)) else -1.0
        scale = 1.0 + mult * random.randint(0,
                                            self.clk_freq_scaling_pc) / 100.0
        self._clk_hi_modified_ps = self._clk_hi_ps * scale
        scale = 1.0 + mult * random.randint(0,
                                            self.clk_freq_scaling_pc) / 100.0
        self._clk_lo_modified_ps = self._clk_lo_ps * scale

    def _apply_jitter(self) -> None:
        if random.randint(1, 100) <= self.jitter_chance_pc:
            j = random.randint(0, self.max_plus_jitter_ps // 2)
            if random.randint(0, 1):
                j = -random.randint(0, self.max_minus_jitter_ps // 2)
            self._clk_hi_modified_ps = self._clk_hi_ps + j
        if random.randint(1, 100) <= self.jitter_chance_pc:
            j = random.randint(0, self.max_plus_jitter_ps // 2)
            if random.randint(0, 1):
                j = -random.randint(0, self.max_minus_jitter_ps // 2)
            self._clk_lo_modified_ps = self._clk_lo_ps + j

    async def _clock_gen(self) -> None:
        if self.drive_rst_n:
            await self.wait_for_reset(wait_posedge=False)
            await Timer(1, unit="ps")
        self._drive_clk_val(0)
        if not self.sole_clock:
            dly_ps = random.randint(
                0, self.clk_period_ps) if self.clk_period_ps else 0
            if dly_ps > 0:
                await Timer(dly_ps, unit="ps")

        while True:
            if self._recompute:
                self._clk_hi_ps = self.clk_period_ps * self.duty_cycle // 100
                self._clk_lo_ps = self.clk_period_ps - self._clk_hi_ps
                self._clk_hi_modified_ps = float(self._clk_hi_ps)
                self._clk_lo_modified_ps = float(self._clk_lo_ps)
                self._recompute = False
            if self.clk_freq_scaling_pc and self.clk_freq_scaling_chance_pc:
                self._apply_freq_scaling()
            if self.jitter_chance_pc:
                self._apply_jitter()
            await Timer(self._clk_lo_modified_ps, unit="ps")
            self._drive_clk_val(1)
            await Timer(self._clk_hi_modified_ps, unit="ps")
            self._drive_clk_val(0)
