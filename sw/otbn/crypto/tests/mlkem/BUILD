# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.


load("//rules:otbn.bzl", "otbn_consttime_test", "otbn_library", "otbn_sim_test", "otbn_binary")

package(default_visibility = ["//visibility:public"])

otbn_sim_test(
    name = "kyber768_mlkem_keypair_test",
    srcs = [
        "kyber768_mlkem_keypair_test.s",
    ],
    dexp = "kyber768_mlkem_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber_packing",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
        "//sw/otbn/crypto/mlkem:kyber_poly",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_mlkem",
    ]
)