# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_binary")
load("@ot_python_deps//:requirements.bzl", "requirement")

package(default_visibility = ["//visibility:public"])

py_binary(
    name = "acc_as",
    srcs = ["acc_as.py"],
    deps = [
        "//hw/ip/acc/util/shared:bit_ranges",
        "//hw/ip/acc/util/shared:encoding",
        "//hw/ip/acc/util/shared:insn_yaml",
        "//hw/ip/acc/util/shared:operand",
        "//hw/ip/acc/util/shared:toolchain",
    ],
)

py_binary(
    name = "acc_ld",
    srcs = ["acc_ld.py"],
    deps = [
        "//hw/ip/acc/util/shared:mem_layout",
        "//hw/ip/acc/util/shared:toolchain",
        requirement("mako"),
    ],
)

py_binary(
    name = "acc_objdump",
    srcs = ["acc_objdump.py"],
    deps = [
        "//hw/ip/acc/util/shared:insn_yaml",
        "//hw/ip/acc/util/shared:toolchain",
    ],
)

py_binary(
    name = "check_const_time",
    srcs = ["check_const_time.py"],
    deps = [
        "//hw/ip/acc/util/shared:check",
        "//hw/ip/acc/util/shared:control_flow",
        "//hw/ip/acc/util/shared:decode",
        "//hw/ip/acc/util/shared:information_flow_analysis",
        requirement("pyelftools"),
    ],
)

py_binary(
    name = "get_instruction_count_range",
    srcs = ["get_instruction_count_range.py"],
    deps = [
        "//hw/ip/acc/util/shared:decode",
        "//hw/ip/acc/util/shared:instruction_count_range",
    ],
)

py_binary(
    name = "gen_instruction_count_header",
    srcs = ["gen_instruction_count_header.py"],
    deps = [
        "//hw/ip/acc/util/shared:decode",
        "//hw/ip/acc/util/shared:instruction_count_range",
        requirement("mako"),
        requirement("pyelftools"),
    ],
)

py_binary(
    name = "acc_sim_test",
    srcs = ["acc_sim_test.py"],
    deps = [
        "//hw/ip/acc/util/shared:check",
        "//hw/ip/acc/util/shared:mem_layout",
        "//hw/ip/acc/util/shared:reg_dump",
        requirement("pyelftools"),
    ],
)
