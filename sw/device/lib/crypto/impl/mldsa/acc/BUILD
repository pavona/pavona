# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

load("//rules/pavona:defs.bzl", "PAVONA_CPU")
load("//rules:autogen.bzl", "autogen_acc_insn_count_header")

cc_library(
    name = "mldsa_acc",
    srcs = ["mldsa_acc.c"],
    hdrs = ["mldsa_acc.h"],
    target_compatible_with = [PAVONA_CPU],
    deps = [
        ":mldsa_insn_counts",
        "//sw/acc/crypto:run_mldsa",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/base:math",
        "//sw/device/lib/crypto/drivers:acc",
        "//sw/device/lib/crypto/drivers:kmac",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/device/lib/crypto/impl:status",
    ],
)

autogen_acc_insn_count_header(
    name = "mldsa_insn_counts",
    hjson = "mldsa_modes.hjson",
    template = "mldsa_insn_counts.h.tpl",
    deps = [
        "//sw/acc/crypto:run_mldsa",
    ],
)
