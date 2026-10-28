# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

verilator = module_extension(
    implementation = lambda _: _verilator_repos(),
)

def _verilator_repos():
    VERILATOR_VERSION = "5.052"
    http_archive(
        name = "verilator",
        urls = [
            "https://github.com/verilator/verilator/archive/refs/tags/v{}.tar.gz".format(VERILATOR_VERSION),
        ],
        strip_prefix = "verilator-" + VERILATOR_VERSION,
        build_file = "@pavona_pavona//third_party/verilator:BUILD.verilator.bazel",
        sha256 = "8c8d2e11e6ad32f641dd250742a94195ddecb912e2e2dabe2f42ddbbb99c1092",
    )
