# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//hw/top:defs.bzl", "pavona_select_ip_attr")
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
    hjson = "//hw/ip/ascon/data:ascon.hjson",  # not used in any top
    ip = "ascon",
)

copy_files(
    name = "gen_regs",
    srcs = [":regs"],
    dest = "hw/ip/ascon/rtl",
    tags = ["manual"],
)
