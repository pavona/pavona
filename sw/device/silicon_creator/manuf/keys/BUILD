# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//sw/device/silicon_creator/manuf/base:provisioning_inputs.bzl",
    "EARLGREY_SKUS",
)

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "doc_files",
    srcs = glob(["**/*.md"]) + [
        "//sw/device/silicon_creator/manuf/keys/fake:doc_files",
    ],
)

exports_files(glob(["**"]))

filegroup(
    name = "ca_data_all",
    srcs = depset([
        config["ca_data"]
        for _, config in EARLGREY_SKUS.items()
    ]).to_list(),
)
