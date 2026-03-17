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
        sha256 = "2f83fb2199f52297f675bad2be5c8a15cca90061ef593b205fc6fd994dc38f47",
        strip_prefix = "wycheproof-78898104021ebd2cd98820e4112da89b1531d999",
        url = "https://github.com/C2SP/wycheproof/archive/78898104021ebd2cd98820e4112da89b1531d999.tar.gz",
        # C2SP upstream doesn't include BUILD files for subdirectories
        # (the lowRISC fork did). Create them so existing references like
        # @wycheproof//testvectors_v1:foo.json continue to work.
        patch_cmds = [
            "echo 'exports_files(glob([\"**\"]))' > testvectors_v1/BUILD.bazel",
        ],
    )
