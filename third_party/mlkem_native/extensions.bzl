# Copyright The mlkem-native project authors
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

mlkem_native = module_extension(
    implementation = lambda _: _mlkem_native_repos(),
)

def _mlkem_native_repos():
    http_archive(
        name = "mlkem_native",
        build_file = Label("//third_party/mlkem_native:BUILD.mlkem_native.bazel"),
        sha256 = "ae8d178cc14c15721644898cbe36234a434568306e8d5e3000e36b538f41d598",
        strip_prefix = "mlkem-native-2.1.0",
        urls = [
            "https://github.com/pq-code-package/mlkem-native/archive/v2.1.0.tar.gz",
        ],
    )
