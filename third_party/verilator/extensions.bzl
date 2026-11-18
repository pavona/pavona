# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

verilator = module_extension(
    implementation = lambda _: _verilator_repos(),
)

def _verilator_repos():
    VERILATOR_VERSION = "5.054"
    http_archive(
        name = "verilator",
        urls = [
            "https://github.com/verilator/verilator/archive/refs/tags/v{}.tar.gz".format(VERILATOR_VERSION),
        ],
        strip_prefix = "verilator-" + VERILATOR_VERSION,
        build_file = "@pavona_pavona//third_party/verilator:BUILD.verilator.bazel",
        sha256 = "18658731b46922ef660bcb650be0aa503d751e5c17eb9d4644fdfabb11835198",
        # Upstream fixes for flex >= 2.6.5. Drop with the next Verilator release.
        patches = [
            Label("//third_party/verilator/patches:0001-Fix-flex-2.6.5.patch"),
            Label("//third_party/verilator/patches:0002-Fix-flex-2.6.9-build.patch"),
        ],
        patch_args = ["-p1"],
    )
