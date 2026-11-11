# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_python//python:defs.bzl", "py_test")
load("//third_party/acvp_testvectors:vector_sets.bzl", "ACVP_VECTOR_SETS")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "doc_files",
    srcs = ["README.md"],
)

py_test(
    name = "registration_hash_test",
    srcs = ["registration_hash_test.py"],
    args = [
        "$(rootpath registration/{}.json)={}".format(
            registration,
            vector_set["registration_sha256"],
        )
        for registration, vector_set in ACVP_VECTOR_SETS.items()
    ],
    data = glob(["registration/*.json"]),
)
