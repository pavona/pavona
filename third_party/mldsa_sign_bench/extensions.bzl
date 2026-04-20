# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

mldsa_sign_bench = module_extension(
    implementation = lambda _: _mldsa_sign_bench_repos(),
)

def _mldsa_sign_bench_repos():
    http_archive(
        name = "mldsa_sign_bench",
        build_file = Label("//third_party/mldsa_sign_bench:BUILD.mldsa_sign_bench.bazel"),
        sha256 = "adfc61b35a64df8d43c67ac6c2b190a6344115f9f12ff357af56f1d57b08ff8b",
        strip_prefix = "mldsa-sign-bench-66da53064d4323c024fcd15e423c2afc28b2ecf4",
        urls = [
            "https://github.com/zerorisc/mldsa-sign-bench/archive/66da53064d4323c024fcd15e423c2afc28b2ecf4.tar.gz",
        ],
    )
