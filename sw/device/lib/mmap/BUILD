# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_skylib//rules:run_binary.bzl", "run_binary")
load("//hw/top:defs.bzl", "pavona_if_ip")

# Generate unified nonvolatile memory (NVM) C/C++ header for the selected
# top-level design.
run_binary(
    name = "flash_info_mmap",
    srcs = [
        "flash_info.h.tpl",
        "//hw/top:top_flash_info_map",
    ],
    outs = ["flash_info.h"],
    args = [
        "--template",
        "$(execpath :flash_info.h.tpl)",
        "--output",
        "$(execpath :flash_info.h)",
        "--mmap",
        "$(execpath //hw/top:top_flash_info_map)",
    ],
    tool = "//util/design:gen-flash-info-mmap",
)

cc_library(
    name = "flash_info",
    hdrs = [
        "flash_info_types.h",
        ":flash_info.h",
    ],
    visibility = ["//visibility:public"],
    deps = [
        "//hw/top:flash_ctrl_c_regs",
        "//hw/top/dt:flash_ctrl",
    ],
)
