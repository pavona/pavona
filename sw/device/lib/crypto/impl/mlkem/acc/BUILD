# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

load("//rules/pavona:defs.bzl", "PAVONA_CPU")
load("//rules:autogen.bzl", "autogen_acc_insn_count_header")

cc_library(
    name = "mlkem_acc",
    srcs = ["mlkem_acc.c"],
    hdrs = ["mlkem_acc.h"],
    target_compatible_with = [PAVONA_CPU],
    deps = [
        ":mlkem_insn_counts",
        "//sw/acc/crypto:run_mlkem",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/base:math",
        "//sw/device/lib/crypto/drivers:acc",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/device/lib/crypto/impl:status",
    ],
)

autogen_acc_insn_count_header(
    name = "mlkem_insn_counts",
    hjson = "mlkem_modes.hjson",
    template = "mlkem_insn_counts.h.tpl",
    deps = [
        "//sw/acc/crypto:run_mlkem",
    ],
)
