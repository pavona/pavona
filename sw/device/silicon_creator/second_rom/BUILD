# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//rules/pavona:defs.bzl",
    "PAVONA_CPU",
    "pavona_binary",
)
load("//rules:linker.bzl", "ld_library")
load("//hw/top:defs.bzl", "pavona_select_top")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "second_rom_epmp",
    srcs = [
        "second_rom_epmp.c",
    ],
    hdrs = ["second_rom_epmp.h"],
    defines = pavona_select_top(
        {
            "dragonfly": ["PAVONA_IS_DRAGONFLY"],
        },
        [],
    ),
    target_compatible_with = [PAVONA_CPU],
    deps = [
        "//hw/top:rv_dm_c_regs",
        "//hw/top/dt:rv_dm",
        "//hw/top/dt:soc_proxy",
        "//hw/top/dt:sram_ctrl",
        "//sw/device/lib/base:bitfield",
        "//sw/device/lib/base:csr",
        "//sw/device/lib/base:memory",
        "//sw/device/silicon_creator/lib/drivers:epmp",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
    ],
)

cc_library(
    name = "second_rom_lib",
    srcs = [
        "second_rom.c",
        "second_rom_start.S",
    ],
    hdrs = ["second_rom.h"],
    defines = pavona_select_top(
        {
            "egret": ["DISCRETE_OTP_MAP"],
            "dragonfly": ["INTEGRATED_OTP_MAP"],
        },
        [],
    ),
    target_compatible_with = [PAVONA_CPU],
    deps = [
        ":second_rom_epmp",
        "//hw/top:aon_timer_c_regs",
        "//hw/top:ast_c_regs",
        "//hw/top:clkmgr_c_regs",
        "//hw/top:csrng_c_regs",
        "//hw/top:edn_c_regs",
        "//hw/top:gpio_c_regs",
        "//hw/top:lc_ctrl_c_regs",
        "//hw/top:otp_ctrl_c_regs",
        "//hw/top:pinmux_c_regs",
        "//hw/top:pwrmgr_c_regs",
        "//hw/top:rv_core_ibex_c_regs",
        "//hw/top:sram_ctrl_c_regs",
        "//hw/top_dragonfly/sw/autogen:top_dragonfly",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:multibits",
        "//sw/device/lib/crt",
        "//sw/device/silicon_creator/lib:dbg_print",
        "//sw/device/silicon_creator/lib:epmp_state",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib:irq_asm",
        "//sw/device/silicon_creator/lib:manifest",
        "//sw/device/silicon_creator/lib:shutdown",
        "//sw/device/silicon_creator/lib/base:chip",
        "//sw/device/silicon_creator/lib/base:sec_mmio",
        "//sw/device/silicon_creator/lib/base:static_critical",
        "//sw/device/silicon_creator/lib/drivers:ast",
        "//sw/device/silicon_creator/lib/drivers:epmp",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
        "//sw/device/silicon_creator/lib/drivers:rnd",
        "//sw/device/silicon_creator/lib/drivers:watchdog",
        "//sw/device/silicon_creator/rom:boot_rom_ext",
        "//sw/device/silicon_creator/rom:rom_epmp",
    ],
    alwayslink = True,
)

ld_library(
    name = "second_rom_linker_script",
    script = "second_rom.ld",
    deps = [
        "//hw/top_dragonfly/sw/autogen:top_dragonfly_memory",
        "//sw/device:info_sections",
        "//sw/device/silicon_creator/lib/base:static_critical_sections",
    ],
)

pavona_binary(
    name = "second_rom",
    exec_env = [
        "//hw/top_dragonfly:sim_dv_base",
        "//hw/top_dragonfly:sim_verilator_base",
    ],
    kind = "rom",
    linker_script = ":second_rom_linker_script",
    rom_scramble_mode = "second-rom",
    transitive_features = [
        "use_lld",
        "lto",
        "minsize",
    ],
    deps = [
        ":second_rom_lib",
        "//sw/device/silicon_creator/rom:rom_isrs",
    ],
)

[
    # Generate targets with `sim_dv` and `sim_verilator` suffixes as expected
    # by dvsim.
    alias(
        name = "second_rom_{}".format(env),
        actual = ":second_rom",
    )
    for env in [
        "sim_dv",
        "sim_verilator",
    ]
]
