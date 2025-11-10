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
        sha256 = "23bcd38bc9d91e93c39df47189d6c4e5eb7172334700579c32951ff31857b9e5",
        strip_prefix = "mldsa-native-421e6622f250f99da5b57660572e921c91cbfcf4",
        urls = [
            "https://github.com/pq-code-package/mldsa-native/archive/421e6622f250f99da5b57660572e921c91cbfcf4.tar.gz",
        ],
    )
