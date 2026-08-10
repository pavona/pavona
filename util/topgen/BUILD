# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_library")
load("@ot_python_deps//:requirements.bzl", "requirement")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "doc_files",
    srcs = glob(["**/*.md"]),
)

# The modules of this package import each other in a cycle: `__init__.py` pulls
# in `lib`, `merge` and `validate`, each of which imports the package again.
# They therefore have to live in a single target.
py_library(
    name = "topgen",
    srcs = glob(["*.py"]),
    imports = [".."],
    deps = [
        "//util:version_file",
        "//util/basegen",
        "//util/raclgen",
        "//util/reggen:gen_dv",
        "//util/reggen:gen_selfdoc",
        "//util/reggen:inter_signal",
        "//util/reggen:interrupt",
        "//util/reggen:ip_block",
        "//util/reggen:lib",
        "//util/reggen:md_helpers",
        "//util/reggen:params",
        "//util/reggen:reg_block",
        "//util/reggen:validate",
        "//util/reggen:window",
        requirement("hjson"),
        requirement("mako"),
        requirement("pycryptodome"),
        requirement("tabulate"),
    ],
)

filegroup(
    name = "tpl_files",
    srcs = glob(["**/*.tpl"]),
)
