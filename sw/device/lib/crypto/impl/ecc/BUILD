# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

load("//rules/opentitan:defs.bzl", "OPENTITAN_CPU")
load("//rules:autogen.bzl", "autogen_otbn_insn_count_header")

cc_library(
    name = "p256",
    srcs = ["p256.c"],
    hdrs = ["p256.h"],
    target_compatible_with = [OPENTITAN_CPU],
    deps = [
        ":p256_insn_counts",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/device/lib/crypto/impl:status",
        "//sw/otbn/crypto:run_p256",
    ],
)

cc_library(
    name = "p384",
    srcs = ["p384.c"],
    hdrs = ["p384.h"],
    target_compatible_with = [OPENTITAN_CPU],
    deps = [
        ":p384_insn_counts",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/device/lib/crypto/impl:status",
        "//sw/otbn/crypto:run_p384",
    ],
)

cc_library(
    name = "ed25519",
    srcs = ["ed25519.c"],
    hdrs = ["ed25519.h"],
    target_compatible_with = [OPENTITAN_CPU],
    deps = [
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/device/lib/crypto/impl:status",
        "//sw/otbn/crypto:run_ed25519",
    ],
)

autogen_otbn_insn_count_header(
    name = "p256_insn_counts",
    hjson = "p256_modes.hjson",
    template = "p256_insn_counts.h.tpl",
    deps = [
        "//sw/otbn/crypto:run_p256",
    ],
)

autogen_otbn_insn_count_header(
    name = "p384_insn_counts",
    hjson = "p384_modes.hjson",
    template = "p384_insn_counts.h.tpl",
    deps = [
        "//sw/otbn/crypto:run_p384",
    ],
)
