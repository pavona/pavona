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
        sha256 = "97a7305c32b62cbcae97891823176e18ca96d9eaafc3728587d75bb113862a40",
        strip_prefix = "mldsa-native-2.0.0",
        urls = [
            "https://github.com/pq-code-package/mldsa-native/archive/v2.0.0.tar.gz",
        ],
    )
