# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

verilator = module_extension(
    implementation = lambda _: _verilator_repos(),
)

def _verilator_repos():
    VERILATOR_VERSION = "5.046"
    http_archive(
        name = "verilator",
        urls = [
            "https://github.com/verilator/verilator/archive/refs/tags/v{}.tar.gz".format(VERILATOR_VERSION),
        ],
        strip_prefix = "verilator-" + VERILATOR_VERSION,
        build_file = "@pavona_pavona//third_party/verilator:BUILD.verilator.bazel",
        sha256 = "002bc6d92b203eb8b4612e1d198d8108517d4ec9859e131ef328015352fe6d0c",
    )
