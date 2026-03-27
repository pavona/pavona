# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_binary", "acc_consttime_test", "acc_library", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

acc_sim_test(
    name = "bnxd_test",
    srcs = [
        "bnxd_test.s",
    ],
    exp = "bnxd_test.exp",
)
