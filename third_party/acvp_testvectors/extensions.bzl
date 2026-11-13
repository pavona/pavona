# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load(
    ":vector_sets.bzl",
    "ACVP_SERVER_VERSION",
    "ACVP_VECTORS_URL",
    "ACVP_VECTOR_SETS",
)

acvp_testvectors = module_extension(
    implementation = lambda _: _acvp_testvectors_repos(),
)

def _acvp_vectors_impl(rctx):
    rctx.file("BUILD.bazel", "".join([
        'alias(name = "{}", actual = "@{}//file", visibility = ["//visibility:public"])\n'.format(name, repo)
        for name, repo in rctx.attr.files.items()
    ]))

# Makes each file of the vector sets available as
# `@acvp_vectors//:<registration>/<file>`, such as
# `@acvp_vectors//:kdf-kmac/prompt.json`.
_acvp_vectors = repository_rule(
    implementation = _acvp_vectors_impl,
    attrs = {"files": attr.string_dict()},
)

def _acvp_testvectors_repos():
    files = {}
    for registration, vector_set in ACVP_VECTOR_SETS.items():
        for file, sha256 in vector_set["files"].items():
            repo = "acvp_vectors_{}_{}".format(registration, file)
            http_file(
                name = repo,
                sha256 = sha256,
                downloaded_file_path = file,
                url = "/".join([
                    ACVP_VECTORS_URL,
                    ACVP_SERVER_VERSION,
                    vector_set["algorithm"],
                    vector_set["registration_sha256"],
                    file,
                ]),
            )
            files["{}/{}".format(registration, file)] = repo
    _acvp_vectors(name = "acvp_vectors", files = files)

    http_archive(
        name = "acvp_testvectors",
        build_file = Label("//third_party/acvp_testvectors:BUILD.acvp_testvectors.bazel"),
        sha256 = "394c1b549364e5ee76e249a9ca40c59a38342d2826579d8e4b4c478e5d05485a",
        strip_prefix = "ACVP-Server-1.1.0.43/gen-val/json-files",
        url = "https://github.com/usnistgov/ACVP-Server/archive/refs/tags/v1.1.0.43.tar.gz",
        # Subdirectories need BUILD files for Bazel to treat them as packages.
        patch_cmds = [
            "for dir in */; do echo 'exports_files(glob([\"**\"]))' > \"${dir}BUILD.bazel\"; done",
        ],
    )
