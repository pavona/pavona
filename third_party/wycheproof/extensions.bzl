# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

wycheproof = module_extension(
    implementation = lambda _: _wycheproof_repos(),
)

def _wycheproof_repos():
    http_archive(
        name = "wycheproof",
        build_file = Label("//third_party/wycheproof:BUILD.wycheproof_common.bazel"),
        sha256 = "8b5be7c35cf56da4aa7c0b2823333ad5da651517daa23e3a1a01eb2f33b29513",
        strip_prefix = "wycheproof-45d916899992c5e42dba75106104ca8ce7ff8370",
        url = "https://github.com/C2SP/wycheproof/archive/45d916899992c5e42dba75106104ca8ce7ff8370.tar.gz",
        # C2SP upstream doesn't include BUILD files for subdirectories
        # (the lowRISC fork did). Create them so existing references like
        # @wycheproof//testvectors_v1:foo.json continue to work.
        patch_cmds = [
            "echo 'exports_files(glob([\"**\"]))' > testvectors_v1/BUILD.bazel",
        ],
    )
