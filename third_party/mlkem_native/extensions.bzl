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
        sha256 = "ee2d81d17cac5f83eac439cd7e2b762b7807e48605ae1fd03d9a1c8c8f7a7308",
        strip_prefix = "mlkem-native-51f64209d5ea7aa052a45e797c8743fcbae9a2a7",
        urls = [
            "https://github.com/pq-code-package/mlkem-native/archive/51f64209d5ea7aa052a45e797c8743fcbae9a2a7.tar.gz",
        ],
    )
