# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

acvp_testvectors = module_extension(
    implementation = lambda _: _acvp_testvectors_repos(),
)

def _acvp_testvectors_repos():
    http_archive(
        name = "acvp_testvectors",
        build_file = Label("//third_party/acvp_testvectors:BUILD.acvp_testvectors.bazel"),
        sha256 = "f5dac4d893f3660a397f4597db3a8be344137d8f06f14cd89e38feaf733f790e",
        strip_prefix = "ACVP-Server-1.1.0.41/gen-val/json-files",
        url = "https://github.com/usnistgov/ACVP-Server/archive/refs/tags/v1.1.0.41.tar.gz",
        # Subdirectories need BUILD files for Bazel to treat them as packages.
        patch_cmds = [
            "for dir in */; do echo 'exports_files(glob([\"**\"]))' > \"${dir}BUILD.bazel\"; done",
        ],
    )
