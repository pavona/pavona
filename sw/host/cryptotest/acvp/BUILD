# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "cryptotest_acvp",
    srcs = ["src/lib.rs"],
    deps = [
        "@crate_index//:anyhow",
        "@crate_index//:clap",
        "@crate_index//:log",
        "@crate_index//:serde",
        "@crate_index//:serde_json",
    ],
)
