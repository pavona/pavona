# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//sw/device/silicon_creator/manuf/base:provisioning_inputs.bzl",
    "EGRET_SKUS",
)

package(default_visibility = ["//visibility:public"])

exports_files(glob(["**"]))

filegroup(
    name = "all",
    srcs = depset([
        config["orchestrator_cfg"]
        for _, config in EGRET_SKUS.items()
    ]).to_list(),
)
