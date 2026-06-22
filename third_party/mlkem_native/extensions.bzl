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
        sha256 = "fb1eeb64974ea13cdbec8d1e6ae7e69316dc959926c5660437dabf8462c965bf",
        strip_prefix = "mlkem-native-1.2.0",
        urls = [
            "https://github.com/pq-code-package/mlkem-native/archive/v1.2.0.tar.gz",
        ],
    )
