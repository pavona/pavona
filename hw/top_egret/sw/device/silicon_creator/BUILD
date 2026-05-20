# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules/pavona:defs.bzl", "PAVONA_CPU")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "hooks",
    srcs = [
        "lib/acc_boot_services.c",
    ],
    target_compatible_with = [PAVONA_CPU],
    deps = [
        "//sw/device/lib/base:macros",
        "//sw/device/lib/base:memory",
        "//sw/device/silicon_creator/lib:attestation",
        "//sw/device/silicon_creator/lib:dbg_print",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib/drivers:flash_ctrl",
    ],
)
