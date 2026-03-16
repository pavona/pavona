# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules/pavona:defs.bzl", "PAVONA_CPU")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "bitmaps",
    srcs = [
        "ot_logo_bitmap.c",
    ],
    hdrs = ["bitmaps.h"],
    target_compatible_with = [PAVONA_CPU],
)
