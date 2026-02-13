# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary")

package(default_visibility = ["//visibility:public"])

acc_binary(
    name = "smoke_test",
    srcs = [
        "smoke_test.s",
    ],
    args = [
        "--defsym",
        "deterministic=1",
    ],
)
