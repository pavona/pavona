# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:autogen.bzl", "pavona_ip_reg_rtl")
load("//rules:files.bzl", "copy_files")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

exports_files(glob(["**/*"]))

pavona_ip_reg_rtl(
    name = "regs",
    ip = "csrng",
)

copy_files(
    name = "gen_regs",
    srcs = [":regs"],
    dest = "hw/ip/csrng/rtl",
    tags = ["manual"],
)
