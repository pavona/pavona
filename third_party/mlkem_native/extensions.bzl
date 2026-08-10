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
        sha256 = "76bf71771f09a25f30463218974ae10752d72bca34bbc470c7f6f8655f51d622",
        strip_prefix = "mlkem-native-2.0.0",
        urls = [
            "https://github.com/pq-code-package/mlkem-native/archive/v2.0.0.tar.gz",
        ],
    )
