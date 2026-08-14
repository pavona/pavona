# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

load("//rules:autogen.bzl", "pavona_completecfg")

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

filegroup(
    name = "doc_files",
    srcs = glob(["**/*_testplan.hjson"]),
)

filegroup(
    name = "top_xbar_hjsons",
    srcs = glob(["xbar*.hjson"]),
)

pavona_completecfg(
    "completecfg",
    data = [
        ":top_xbar_hjsons",
        "//hw/top_dragonfly/data/otp:otp_ctrl_mmap.hjson",
        "//hw/top_dragonfly/data/racl:all_files",
        "//hw/top_dragonfly/ip:block_descriptions",
    ],
    seed = ":top_dragonfly_seed.testing.hjson",
    top = ":top_dragonfly.hjson",
)
