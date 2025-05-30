# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.

load("//rules:otbn.bzl", "otbn_consttime_test", "otbn_library", "otbn_sim_test", "otbn_binary")

package(default_visibility = ["//visibility:public"])

otbn_sim_test(
    name = "poly_add_dilithium_test",
    srcs = [
        "poly_add_dilithium_test.s",
    ],
    dexp = "poly_add_dilithium_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
            ],
)

otbn_sim_test(
    name = "poly_reduce32_dilithium_test",
    srcs = [
        "poly_reduce32_dilithium_test.s",
    ],
    dexp = "poly_reduce32_dilithium_test.exp",
    deps = [
        "//sw/otbn/crypto/mldsa:poly_base_dilithium",
            ],
)

otbn_sim_test(
    name = "poly_pointwise_dilithium_test",
    srcs = [
        "poly_pointwise_dilithium_test.s",
    ],
    dexp = "poly_pointwise_dilithium_test.dexp",
    exp = "poly_pointwise_dilithium_test.exp",
    deps = [
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
            ],
)
