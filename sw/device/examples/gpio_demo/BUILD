# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules/pavona:defs.bzl", "pavona_binary")
load("//rules:files.bzl", "exclude_files")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

package(default_visibility = ["//visibility:public"])

pavona_binary(
    name = "gpio_demo",
    testonly = True,
    srcs = ["gpio_demo.c"],
    exec_env = [
        "//hw/top_egret:fpga_cw310",
        "//hw/top_egret:fpga_cw340",
        "//hw/top_egret:sim_dv",
        "//hw/top_egret:sim_verilator",
    ],
    deps = [
        ":gpio_demo_lib",
        "//sw/device/lib/base:mmio",
    ],
)

cc_library(
    name = "gpio_demo_lib",
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
    srcs = [":gpio_demo"],
    prefix = "egret/examples",
)
