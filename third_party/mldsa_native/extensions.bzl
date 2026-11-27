# Copyright The mldsa-native project authors
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

mldsa_native = module_extension(
    implementation = lambda _: _mldsa_native_repos(),
)

def _mldsa_native_repos():
    http_archive(
        name = "mldsa_native",
        build_file = Label("//third_party/mldsa_native:BUILD.mldsa_native.bazel"),
        sha256 = "6983c47f9df878dc327d09bf512ccbf092b8077f8dcde8c7c4c43935f5220a5f",
        strip_prefix = "mldsa-native-2.1.0",
        urls = [
            "https://github.com/pq-code-package/mldsa-native/archive/v2.1.0.tar.gz",
        ],
    )
