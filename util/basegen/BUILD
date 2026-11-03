# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("@ot_python_deps//:requirements.bzl", "requirement")
load("//hw/top_dragonfly/data/autogen:defs.bzl", "DRAGONFLY_IPS")
load("//hw/top_egret/data/autogen:defs.bzl", "EGRET_IPS")
load("@tops_desc//:defs.bzl", "ALL_TOPS")

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
    data = (
        # top configurations
        ["//hw/top_{}/data:top_{}.hjson".format(
            top.name,
            top.name,
        ) for top in ALL_TOPS] +

        # seed configurations
        ["//hw/top_{}/data:top_{}_seed.testing.hjson".format(
            top.name,
            top.name,
        ) for top in ALL_TOPS] +

        # IP descriptions
        [
            "//hw/ip:block_descriptions",
        ] +

        # xbar configurations (rtl_files target contains xbar configs)
        ["//hw/top_{}/ip:rtl_files".format(top.name) for top in ALL_TOPS] +

        # template descriptions
        [
            "//hw/ip_templates:all_files",
        ] +

        # ipgen IP configurations
        [
            ip.attrs["ipconfig"]
            for ip in DRAGONFLY_IPS + EGRET_IPS
            if "ipconfig" in ip.attrs
        ] +

        # RACL configurations and mappings (only top_dragonfly has RACL)
        [
            "//hw/top_dragonfly/data/racl:all_files",
        ] +

        # includes key for documentation tests
        [
            ":all_files",
        ]
    ),
    deps = [
        ":basegen",
        requirement("pytest"),
    ],
)
