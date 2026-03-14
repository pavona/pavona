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
        sha256 = "79bf96b6d2d9a9d38d6aea420fc056b744898235d05e23ca0b7ce90edc922362",
        strip_prefix = "mlkem-native-1.1.0",
        urls = [
            "https://github.com/pq-code-package/mlkem-native/archive/v1.1.0.tar.gz",
        ],
    )
