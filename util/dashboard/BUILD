# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_library")
load("@ot_python_deps//:requirements.bzl", "requirement")

package(default_visibility = ["//visibility:public"])

py_library(
    name = "dashboard",
    srcs = glob(["*.py"]),
    imports = [".."],
    deps = [
        "//util/reggen:ip_block",
        "//util/reggen:lib",
        requirement("hjson"),
        requirement("mistletoe"),
    ],
)
