# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//rules/opentitan:defs.bzl", "DARJEELING_TEST_ENVS", "opentitan_binary", "opentitan_test")
load("//rules:files.bzl", "exclude_files")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

package(default_visibility = ["//visibility:public"])

opentitan_binary(
    name = "hello_world",
    testonly = True,
    srcs = ["hello_world.c"],
    copts = [
        # Disable the date-time warning only for the hello world program.
        "-Wno-date-time",
    ],
    exec_env = [
        "//hw/top_earlgrey:fpga_cw310",
        "//hw/top_earlgrey:fpga_cw340",
        "//hw/top_earlgrey:sim_dv",
        "//hw/top_earlgrey:sim_verilator",
    ],
    deps = [
        ":hello_world_lib",
        "//sw/device/lib/base:mmio",
    ],
)

cc_library(
    name = "hello_world_lib",
    deps = [
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
    ] + select({
        "//hw/top:earlgrey": [
            "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        ],
        "//hw/top:darjeeling": [
            "//hw/top_darjeeling/sw/autogen:top_darjeeling",
        ],
    }),
)

pkg_files(
    name = "package",
    testonly = True,
    srcs = [":hello_world"],
    prefix = "earlgrey/examples",
)

opentitan_test(
    name = "hello_world_test",
    srcs = ["hello_world.c"],
    copts = [
        # Disable the date-time warning only for the hello world program.
        "-Wno-date-time",
    ],
    ecdsa_key = {"//sw/device/silicon_creator/rom/keys/fake/ecdsa:test_key_0_ecdsa_p256": "test_key_0"},
    exec_env = {
        "//hw/top_darjeeling:sim_verilator": None,
    },
    deps = [
        ":hello_world_lib",
        "//sw/device/lib/base:mmio",
    ],
)
