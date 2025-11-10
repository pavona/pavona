# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028)
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.

load("//rules:otbn.bzl", "otbn_binary", "otbn_consttime_test", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# Refactor ML-DSA VER2

otbn_sim_test(
    name = "mldsa44_keypair_test",
    srcs = [
        "mldsa_keypair_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "dilithium2_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_keypair",
        "//sw/otbn/crypto/mldsa:mldsa44_poly",
        "//sw/otbn/crypto/mldsa:mldsa44_rounding",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
    ],
)

otbn_sim_test(
    name = "mldsa44_sign_test",
    srcs = [
        "mldsa_sign_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "dilithium2_sign_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_poly",
        "//sw/otbn/crypto/mldsa:mldsa44_rounding",
        "//sw/otbn/crypto/mldsa:mldsa44_sign",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)

otbn_sim_test(
    name = "mldsa44_verify_test",
    srcs = [
        "mldsa_verify_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "dilithium2_verify_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_poly",
        "//sw/otbn/crypto/mldsa:mldsa44_rounding",
        "//sw/otbn/crypto/mldsa:mldsa44_verify",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)

otbn_sim_test(
    name = "mldsa65_keypair_test",
    srcs = [
        "mldsa_keypair_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=3",
    ],
    dexp = "dilithium3_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa65_keypair",
        "//sw/otbn/crypto/mldsa:mldsa65_poly",
        "//sw/otbn/crypto/mldsa:mldsa65_rounding",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
    ],
)

otbn_sim_test(
    name = "mldsa65_sign_test",
    srcs = [
        "mldsa_sign_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=3",
    ],
    dexp = "dilithium3_sign_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa65_poly",
        "//sw/otbn/crypto/mldsa:mldsa65_rounding",
        "//sw/otbn/crypto/mldsa:mldsa65_sign",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)

otbn_sim_test(
    name = "mldsa65_verify_test",
    srcs = [
        "mldsa_verify_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=3",
    ],
    dexp = "dilithium3_verify_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa65_poly",
        "//sw/otbn/crypto/mldsa:mldsa65_rounding",
        "//sw/otbn/crypto/mldsa:mldsa65_verify",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)

otbn_sim_test(
    name = "mldsa87_keypair_test",
    srcs = [
        "mldsa_keypair_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=5",
    ],
    dexp = "dilithium5_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa87_keypair",
        "//sw/otbn/crypto/mldsa:mldsa87_poly",
        "//sw/otbn/crypto/mldsa:mldsa87_rounding",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
    ],
)

otbn_sim_test(
    name = "mldsa87_sign_test",
    srcs = [
        "mldsa_sign_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=5",
    ],
    dexp = "dilithium5_sign_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa87_poly",
        "//sw/otbn/crypto/mldsa:mldsa87_rounding",
        "//sw/otbn/crypto/mldsa:mldsa87_sign",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)

otbn_sim_test(
    name = "mldsa87_verify_test",
    srcs = [
        "mldsa_verify_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=5",
    ],
    dexp = "dilithium5_verify_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa87_poly",
        "//sw/otbn/crypto/mldsa:mldsa87_rounding",
        "//sw/otbn/crypto/mldsa:mldsa87_verify",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)
