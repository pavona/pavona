# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:autogen.bzl", "pavona_ip_reg_rtl")
load("//rules:files.bzl", "copy_files")

package(default_visibility = ["//visibility:public"])

exports_files(glob(["**/*"]))

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

pavona_ip_reg_rtl(
    name = "regs",
    hjson = "//hw/top_dragonfly/ip_autogen/ac_range_check/data:ac_range_check.hjson",
    ip = "ac_range_check",
)

copy_files(
    name = "gen_regs",
    srcs = [":regs"],
    dest = "hw/top_dragonfly/ip_autogen/ac_range_check/rtl",
    tags = ["manual"],
)
