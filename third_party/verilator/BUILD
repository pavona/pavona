# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_foreign_cc//foreign_cc:configure.bzl", "configure_make")

exports_files(["BUILD.verilator.bazel"])

configure_make(
    name = "build_verilator",
    # Speed up the build with multiple jobs, but set an upper bound to constrain
    # memory consumption. Bazel is not aware of foreign builds' resource usage.
    # See <https://github.com/bazelbuild/rules_foreign_cc/issues/329>.
    args = [
        "-j",
        "`nproc`",
    ],
    autoconf = True,
    configure_in_place = True,
    lib_source = "@verilator//:all_srcs",
    out_binaries = [
        "verilator",
        "verilator_bin",
        "verilator_bin_dbg",
        "verilator_coverage",
        "verilator_coverage_bin_dbg",
        "verilator_gantt",
        "verilator_profcfunc",
    ],
    out_data_dirs = ["share"],
)

# Extract the `verilator` binary from :build_verilator. Although the binary itself
# is executable, Bazel does not believe it is runnable.
filegroup(
    name = "verilator",
    srcs = [":build_verilator"],
    output_group = "verilator",
    visibility = ["//visibility:public"],
)
