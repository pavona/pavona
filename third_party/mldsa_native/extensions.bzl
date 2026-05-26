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
        sha256 = "722f0c778cfb33ad24e1877c3c9c6e169428393b863a00492c1e0a4dcea39465",
        strip_prefix = "mldsa-native-1.0.0-beta2",
        urls = [
            "https://github.com/pq-code-package/mldsa-native/archive/v1.0.0-beta2.tar.gz",
        ],
    )
