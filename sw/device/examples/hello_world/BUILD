# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules/pavona:defs.bzl", "pavona_binary")
load("//rules:files.bzl", "exclude_files")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

package(default_visibility = ["//visibility:public"])

pavona_binary(
    name = "hello_world",
    testonly = True,
    srcs = ["hello_world.c"],
    copts = [
        # Disable the date-time warning only for the hello world program.
        "-Wno-date-time",
    ],
    exec_env = [
        "//hw/top_egret:fpga_cw310",
        "//hw/top_egret:fpga_cw340",
        "//hw/top_egret:sim_dv",
        "//hw/top_egret:sim_verilator",
        # For some reason, this target makes scafi_deprecated builds fail.
        #"//hw/top_egret:silicon_owner_sival_rom_ext",
    ],
    deps = [
        ":hello_world_lib",
        "//sw/device/lib/base:mmio",
    ],
)

cc_library(
    name = "hello_world_lib",
    deps = [
        "//hw/top_egret/sw/autogen:top_egret",
        "//sw/device/examples:demos",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/crt",
        "//sw/device/lib/dif:gpio",
        "//sw/device/lib/dif:pinmux",
        "//sw/device/lib/dif:uart",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print_uart",
        "//sw/device/lib/testing:pinmux_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_start",
        "//sw/device/lib/testing/test_framework:ottf_test_config",
    ],
)

pkg_files(
    name = "package",
    testonly = True,
    srcs = [":hello_world"],
    prefix = "egret/examples",
)
