# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//hw/top:defs.bzl", "opentitan_require_ip", "opentitan_require_top", "opentitan_select_top")
load(
    "//rules/opentitan:defs.bzl",
    "OPENTITAN_CPU",
    "opentitan_binary",
    "opentitan_test",
)
load("//rules/opentitan:legacy.bzl", "legacy_rom_targets")
load("//rules:files.bzl", "output_groups")
load("//rules:linker.bzl", "ld_library")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

package(default_visibility = ["//visibility:public"])

ld_library(
    name = "linker_script",
    script = "test_second_rom.ld",
    deps = [
        "//hw/top:top_ld",
        "//sw/device:info_sections",
        "//sw/device/lib/testing/test_framework:ottf_ld_top_config",
        "//sw/device/silicon_creator/lib/base:static_critical_sections",
    ],
)

opentitan_binary(
    name = "test_second_rom",
    exec_env = [
        "//hw/top_darjeeling:sim_dv_base",
        "//hw/top_darjeeling:sim_verilator_base",
    ],
    features = ["use_lld"],
    kind = "rom",
    linker_script = ":linker_script",
    rom_scramble_mode = "second-rom",
    deps = [
        ":test_second_rom_lib",
    ],
)

[
    # Generate targets with `sim_dv` and `sim_verilator` suffixes as expected
    # by dvsim.
    alias(
        name = "test_second_rom_{}".format(env),
        actual = ":test_second_rom",
    )
    for env in [
        "sim_dv",
        "sim_verilator",
    ]
]

[
    filegroup(
        name = "test_second_rom_{}_hashfile".format(dev),
        srcs = [":test_second_rom"],
        output_group = "{}_hashfile".format(dev),
    )
    for dev in [
        "sim_dv",
        "sim_verilator",
        "fpga_cw305",
        "fpga_cw310",
        "fpga_cw340",
    ]
]

cc_library(
    name = "darjeeling_test_second_rom_lib",
    srcs = [
        "darjeeling_fake_driver_funcs.c",
    ],
)

cc_library(
    name = "test_second_rom_lib",
    srcs = [
        "test_second_rom.c",
        "test_second_rom_start.S",
    ],
    deps = [
        ":darjeeling_test_second_rom_lib",
        "//hw/top:ast_c_regs",
        "//hw/top:clkmgr_c_regs",
        "//hw/top:csrng_c_regs",
        "//hw/top:edn_c_regs",
        "//hw/top:entropy_src_c_regs",
        "//hw/top:otp_ctrl_c_regs",
        "//hw/top:sram_ctrl_c_regs",
        "//hw/top:top_lib",
        "//hw/top/dt:otp_ctrl",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base:abs_mmio",
        "//sw/device/lib/base:bitfield",
        "//sw/device/lib/base:mmio",
        "//sw/device/lib/crt",
        "//sw/device/lib/dif:clkmgr",
        "//sw/device/lib/dif:gpio",
        "//sw/device/lib/dif:pinmux",
        "//sw/device/lib/dif:rv_core_ibex",
        "//sw/device/lib/dif:spi_device",
        "//sw/device/lib/dif:uart",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print_uart",
        "//sw/device/lib/testing:pinmux_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:status",
        "//sw/device/silicon_creator/lib:chip_info",
        "//sw/device/silicon_creator/lib:manifest",
        "//sw/device/silicon_creator/lib/base:sec_mmio",
        "//sw/device/silicon_creator/lib/base:static_critical",
        "//sw/device/silicon_creator/lib/drivers:retention_sram",
    ],
)

opentitan_test(
    name = "test_second_rom_test",
    srcs = ["test_second_rom_test.c"],
    exec_env = {
        "//hw/top_darjeeling:sim_dv": None,
        "//hw/top_darjeeling:sim_verilator": None,
    },
    deps = [
        "//sw/device/lib/testing/test_framework:ottf_main",
    ],
)

output_groups(
    name = "pre_package",
    testonly = True,
    srcs = [":test_second_rom"],
    groups = [
        "sim_dv_elf",
        "sim_dv_rom",
        "sim_dv_logs",
        "sim_dv_mapfile",
        "sim_verilator_elf",
        "sim_verilator_rom",
        "sim_verilator_mapfile",
    ],
)

pkg_files(
    name = "package",
    testonly = True,
    srcs = [":pre_package"],
    prefix = opentitan_select_top(
        {
            "darjeeling": "darjeeling/test_second_rom",
        },
        "test_second_rom",
    ),
)
