# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("@ot_python_deps//:requirements.bzl", "requirement")
load("//hw/top_dragonfly/data/autogen:defs.bzl", "DRAGONFLY_IPS")
load("//hw/top_egret/data/autogen:defs.bzl", "EGRET_IPS")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

py_library(
    name = "basegen",
    srcs = [
        "__init__.py",
        "lib.py",
        "typing.py",
        "validate.py",
    ],
    data = [
        "//util/basegen/schemas",
        "//util/ipgen/schemas",
        "//util/raclgen/schemas",
        "//util/reggen/schemas",
        "//util/tlgen/schemas",
        "//util/topgen/schemas",
    ],
    imports = [".."],
    deps = [
        requirement("hjson"),
        requirement("jsonschema"),
        requirement("jsonschema2md"),
    ],
)

py_test(
    name = "test_lib",
    srcs = ["tests/test_lib.py"],
    deps = [
        ":basegen",
        requirement("pytest"),
    ],
)

py_test(
    name = "test_validate",
    srcs = ["tests/test_validate.py"],
    data = [
        # top configurations
        "//hw/top_dragonfly/data:top_dragonfly.hjson",
        "//hw/top_egret/data:top_egret.hjson",

        # IP descriptions
        "//hw/ip:block_descriptions",

        # xbar configurations
        "//hw/top_dragonfly/ip/xbar_dbg/data:all_files",
        "//hw/top_dragonfly/ip/xbar_main/data:all_files",
        "//hw/top_dragonfly/ip/xbar_mbx/data:all_files",
        "//hw/top_dragonfly/ip/xbar_peri/data:all_files",
        "//hw/top_egret/ip/xbar_main/data:all_files",
        "//hw/top_egret/ip/xbar_peri/data:all_files",

        # template descriptions
        "//hw/ip_templates:all_files",

        # RACL configurations and mappings
        "//hw/top_dragonfly/data/racl:all_files",

        # includes key for documentation tests
        ":all_files",
    ] + [
        ip.attrs["ipconfig"]  # ipgen IP configurations
        for ip in DRAGONFLY_IPS + EGRET_IPS
        if "ipconfig" in ip.attrs
    ],
    deps = [
        ":basegen",
        requirement("pytest"),
    ],
)
