# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules/pavona:defs.bzl", "pavona_test", "verilator_params")

package(default_visibility = ["//visibility:public"])

pavona_test(
    name = "hello_world",
    srcs = ["hello_world.c"],
    copts = [
        # Disable the date-time warning only for the hello world program.
        "-Wno-date-time",
    ],
    exec_env = {
        "//hw/top_egret:fpga_cw310_sival_rom_ext": None,
        "//hw/top_egret:sim_dv": None,
        "//hw/top_egret:sim_verilator": None,
        "//hw/top_egret:sim_verilator_rom_with_fake_keys": None,
        "//hw/top_dragonfly:sim_dv": None,
        "//hw/top_dragonfly:sim_verilator": None,
        "//hw/top_dragonfly:sim_verilator_rom_with_fake_keys": None,
    },
    verilator = verilator_params(timeout = "long"),
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/dif:uart",
        "//sw/device/lib/runtime:print_uart",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_start",
        "//sw/device/lib/testing/test_framework:ottf_test_config",
    ],
)
