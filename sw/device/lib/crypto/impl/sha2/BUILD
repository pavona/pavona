# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

load("//rules/opentitan:defs.bzl", "OPENTITAN_CPU")
load("//rules:autogen.bzl", "autogen_otbn_insn_count_header")

cc_library(
    name = "sha256",
    srcs = ["sha256.c"],
    hdrs = ["sha256.h"],
    target_compatible_with = [OPENTITAN_CPU],
    deps = [
        ":sha256_insn_counts",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/base:macros",
        "//sw/device/lib/base:memory",
        "//sw/device/lib/crypto/drivers:hmac",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/otbn/crypto:run_sha256",
    ],
)

cc_library(
    name = "sha512",
    srcs = ["sha512.c"],
    hdrs = ["sha512.h"],
    target_compatible_with = [OPENTITAN_CPU],
    deps = [
        ":sha512_insn_counts",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/base:macros",
        "//sw/device/lib/base:memory",
        "//sw/device/lib/crypto/drivers:hmac",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/otbn/crypto:run_sha512",
    ],
)

autogen_otbn_insn_count_header(
    name = "sha256_insn_counts",
    hjson = "sha256_modes.hjson",
    template = "sha256_insn_counts.h.tpl",
    deps = [
        "//sw/otbn/crypto:run_sha256",
    ],
)

autogen_otbn_insn_count_header(
    name = "sha512_insn_counts",
    hjson = "sha512_modes.hjson",
    template = "sha512_insn_counts.h.tpl",
    deps = [
        "//sw/otbn/crypto:run_sha512",
    ],
)
