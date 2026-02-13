# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_binary")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "doc_files",
    srcs = glob(["**/*.md"]),
)

py_binary(
    name = "standalone",
    srcs = ["standalone.py"],
    deps = [
        "//hw/ip/acc/dv/accsim/sim:load_elf",
        "//hw/ip/acc/dv/accsim/sim:standalonesim",
        "//hw/ip/acc/dv/accsim/sim:stats",
    ],
)
