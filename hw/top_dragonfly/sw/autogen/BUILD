# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------#
# PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
# util/gen_top_sw.py -t hw/top_dragonfly/data/autogen/top_dragonfly.gen.hjson

load("//rules:linker.bzl", "ld_library")
load("//hw/top:defs.bzl", "pavona_require_top")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "top_dragonfly",
    srcs = [
        "top_dragonfly.c",
    ],
    hdrs = [
        "top_dragonfly.h",
        "top_dragonfly_memory.h",
    ],
    defines = ["OPENTITAN_IS_DRAGONFLY"],
    target_compatible_with = pavona_require_top("dragonfly"),
)

ld_library(
    name = "top_dragonfly_memory",
    defines = [
        "OPENTITAN_TOP_MEMORY_LD=top_dragonfly_memory.ld",
        "OPENTITAN_IS_DRAGONFLY",
    ],
    includes = ["top_dragonfly_memory.ld"],
    target_compatible_with = pavona_require_top("dragonfly"),
)
