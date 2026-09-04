# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
Base configuration class for all DV environments. Provides common knobs for
scoreboard, coverage, reset handling, RAL models, and clock/reset configuration.
"""

from typing import Any, Dict, List, Optional, TypeVar

from pyuvm import uvm_object

# Type variable for RAL (register abstraction layer) block type.
# When a Python RAL implementation exists, bind it here; until then Any is used.
RAL_T = TypeVar("RAL_T", bound=Any)


class dv_base_env_cfg(uvm_object):
    """
    Base environment configuration.

    Subclass this for env-specific config; set ral_model_names, then call
    initialize() before randomizing or using the config. The primary RAL
    instance is in .ral; additional RALs are in .ral_models[name].
    """

    def __init__(self, name: str = "cfg") -> None:
        super().__init__(name)
        self._cfg_uvm_verbosity: int | None = None

        # Activity and scoreboard
        self.is_active: bool = True
        self.en_scb: bool = True  # can be changed at run-time
        self.en_scb_tl_err_chk: bool = True
        self.en_scb_mem_chk: bool = True
        self.en_scb_ping_chk: bool = True
        self.en_cov: bool = False  # Enable via plusarg when coverage is on
        self.uvm_verbosity: int | None = None

        # Set by initialize(); required before randomize
        self.is_initialized: bool = False

        # Zero delays for high-bandwidth tests (typically randomized)
        self.zero_delays: bool = False

        # RAL: primary model and map of name -> reg block
        self.ral: Optional[Any] = None  # RAL_T in SV; primary RAL instance
        self.ral_models: Dict[str, Any] = {}  # name -> dv_base_reg_block

        # Names of RAL models to create in initialize(); default is [primary RAL type name]
        # Subclasses set this before calling super().initialize()
        self.ral_model_names: List[str] = []

        # Clock/reset: access only via reset domain(s), e.g. reset_domain.clk_rst_vif,
        # reset_domains[name].clk_rst_vif (set during env build_phase).
        # self.clk_freq_mhz: int = 0  # default; often randomized
        # self.clk_freqs_mhz: Dict[str, int] = {}

        self.clk_rst_cfg = None
        self.delay_cfg = None

        # Reset domains: default and per-RAL
        self.reset_domain: Optional[Any] = None
        # self.reset_domains: Dict[str, Any] = {}

    @property
    def uvm_verbosity(self) -> int | None:
        return self._cfg_uvm_verbosity

    @uvm_verbosity.setter
    def uvm_verbosity(self, verbosity: int | None) -> None:
        self._cfg_uvm_verbosity = verbosity
        if verbosity is not None:
            self.set_report_verbosity(verbosity)

    def pre_randomize(self) -> None:
        """Call before randomizing; ensures initialize() was run."""
        if not self.is_initialized:
            self.uvm_report.fatal(
                "DV_BASE_ENV_CFG",
                "Call cfg.initialize() before randomization")

    def randomize(self) -> bool:
        """Compatibility shim for SV-style ``randomize()`` call sites."""
        self.pre_randomize()
        self.post_randomize()
        return True

    def constraint_mode(self, enabled: int) -> None:
        """Compatibility stub for code that disables random constraints."""
        return None

    def post_randomize(self) -> None:
        """Call after randomizing; e.g. sync primary clk_freq into clk_freqs_mhz."""

    def initialize(self, csr_base_addr: int = (1 << 32) - 1) -> None:
        """
        Build RAL models and prepare for randomization.
        csr_base_addr: base address for CSRs; all-1s means randomize base internally.
        """
        self.is_initialized = True
        self.create_ral_models(csr_base_addr)
        for name in self.ral_model_names:
            self.clk_freqs_mhz[name] = 0

    def pre_build_ral_settings(self, ral: Any) -> None:
        """Override to set pre-build RAL knobs. No-op in base."""
        ...

    def post_build_ral_settings(self, ral: Any) -> None:
        """Override for post-build, pre-lock RAL fixes. No-op in base."""
        ...

    def create_ral_models(self, csr_base_addr: int = (1 << 32) - 1) -> None:
        """
        Create RAL models and set base addresses.
        csr_base_addr all-1s means randomize base address internally.
        Override or extend in subclasses when a Python RAL implementation exists.
        """
        for ral_name in self.ral_model_names:
            reg_blk = self.create_ral_by_name(ral_name)
            if reg_blk is None:
                raise RuntimeError(f"Could not create RAL model: {ral_name}")
            reg_blk_type_name = getattr(reg_blk, "get_name",
                                        lambda: reg_blk.__class__.__name__)()
            current_ral_type_name = (self.ral.__class__.__name__
                                     if self.ral is not None else None)
            if self.ral is None or reg_blk_type_name == current_ral_type_name:
                self.ral = reg_blk
            self.ral_models[ral_name] = reg_blk

    def create_ral_by_name(self, name: str) -> Optional[Any]:
        """
        Factory: create a RAL block by type name.
        Override in subclass or replace with real factory when RAL is ported.
        """
        # Stub: no Python RAL yet; subclasses can create by name via their factory
        return None
