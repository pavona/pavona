# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------#
# PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
# util/topgen.py -t hw/top_scafi_deprecated/data/top_scafi_deprecated.hjson
#                -o hw/top_scafi_deprecated/

load("//rules:linker.bzl", "ld_library")
load("//hw/top:defs.bzl", "pavona_require_top")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "top_scafi_deprecated",
    srcs = [
        "top_scafi_deprecated.c",
    ],
    hdrs = [
        "top_scafi_deprecated.h",
        "top_scafi_deprecated_memory.h",
    ],
    defines = ["OPENTITAN_IS_SCAFI_DEPRECATED"],
    target_compatible_with = pavona_require_top("scafi_deprecated"),
)

ld_library(
    name = "top_scafi_deprecated_memory",
    defines = [
        "OPENTITAN_TOP_MEMORY_LD=top_scafi_deprecated_memory.ld",
        "OPENTITAN_IS_SCAFI_DEPRECATED",
    ],
    includes = ["top_scafi_deprecated_memory.ld"],
    target_compatible_with = pavona_require_top("scafi_deprecated"),
)
