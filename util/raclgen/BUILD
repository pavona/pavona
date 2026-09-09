# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_library")

package(default_visibility = ["//visibility:public"])

py_library(
    name = "raclgen",
    srcs = [
        "__init__.py",
        "lib.py",
    ],
    data = ["//util/raclgen/schemas"],
    imports = [".."],
    deps = [
        "//util/reggen:ip_block",
        "//util/reggen:md_helpers",
        "//util/reggen:multi_register",
        "//util/reggen:register",
        "//util/reggen:validate",
        "//util/reggen:window",
    ],
)
