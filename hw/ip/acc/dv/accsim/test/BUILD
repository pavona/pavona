# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_library", "py_test")

py_library(
    name = "testutil",
    srcs = ["testutil.py"],
    imports = ["."],
    deps = [
        "//hw/ip/acc/dv/accsim/sim:load_elf",
        "//hw/ip/acc/dv/accsim/sim:standalonesim",
    ],
)

py_test(
    name = "stats_test",
    srcs = ["stats_test.py"],
    data = glob([
        "simple/**/*.s",
        "simple/**/*.exp",
    ]) + [
        "@llvm_toolchain_llvm//:bin/clang",
        "@llvm_toolchain_llvm//:bin/ld.lld",
    ],
    env = {
        "RV32_TOOL_GCC": "$(location @llvm_toolchain_llvm//:bin/clang)",
        "RV32_TOOL_AS": "$(location @llvm_toolchain_llvm//:bin/clang)",
        "RV32_TOOL_LD": "$(location @llvm_toolchain_llvm//:bin/ld.lld)",
    },
    deps = [
        ":testutil",
        "//hw/ip/acc/dv/accsim/sim:standalonesim",
        "//hw/ip/acc/dv/accsim/sim:stats",
        "//hw/ip/acc/util:acc_as_lib",
        "//hw/ip/acc/util:acc_ld_lib",
    ],
)

py_test(
    name = "simple_test",
    srcs = ["simple_test.py"],
    data = glob([
        "simple/**/*.s",
        "simple/**/*.exp",
    ]) + [
        "@llvm_toolchain_llvm//:bin/clang",
        "@llvm_toolchain_llvm//:bin/ld.lld",
    ],
    env = {
        "RV32_TOOL_GCC": "$(location @llvm_toolchain_llvm//:bin/clang)",
        "RV32_TOOL_AS": "$(location @llvm_toolchain_llvm//:bin/clang)",
        "RV32_TOOL_LD": "$(location @llvm_toolchain_llvm//:bin/ld.lld)",
    },
    deps = [
        ":testutil",
        "//hw/ip/acc/dv/accsim:standalone_lib",
        "//hw/ip/acc/util:acc_as_lib",
        "//hw/ip/acc/util:acc_ld_lib",
        "//hw/ip/acc/util/shared:reg_dump",
    ],
)

py_test(
    name = "state_test",
    srcs = ["state_test.py"],
    data = glob([
        "simple/**/*.s",
        "simple/**/*.exp",
    ]) + [
        "@llvm_toolchain_llvm//:bin/clang",
        "@llvm_toolchain_llvm//:bin/ld.lld",
    ],
    env = {
        "RV32_TOOL_GCC": "$(location @llvm_toolchain_llvm//:bin/clang)",
        "RV32_TOOL_AS": "$(location @llvm_toolchain_llvm//:bin/clang)",
        "RV32_TOOL_LD": "$(location @llvm_toolchain_llvm//:bin/ld.lld)",
    },
    deps = [
        ":testutil",
        "//hw/ip/acc/dv/accsim/sim:constants",
        "//hw/ip/acc/util:acc_as_lib",
        "//hw/ip/acc/util:acc_ld_lib",
    ],
)
