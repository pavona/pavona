# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
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

otbn_library(
    name = "mldsa44_keypair_data",
    srcs = [
        "mldsa44_keypair_data.s",
    ],
)

otbn_library(
    name = "mldsa65_keypair_data",
    srcs = [
        "mldsa65_keypair_data.s",
    ],
)

otbn_library(
    name = "mldsa87_keypair_data",
    srcs = [
        "mldsa87_keypair_data.s",
    ],
)

otbn_library(
    name = "mldsa44_sign_data",
    srcs = [
        "mldsa44_sign_data.s",
    ],
)

otbn_library(
    name = "mldsa65_sign_data",
    srcs = [
        "mldsa65_sign_data.s",
    ],
)

otbn_library(
    name = "mldsa87_sign_data",
    srcs = [
        "mldsa87_sign_data.s",
    ],
)

otbn_library(
    name = "mldsa44_verify_data",
    srcs = [
        "mldsa44_verify_data.s",
    ],
)

otbn_library(
    name = "mldsa65_verify_data",
    srcs = [
        "mldsa65_verify_data.s",
    ],
)

otbn_library(
    name = "mldsa87_verify_data",
    srcs = [
        "mldsa87_verify_data.s",
    ],
)

otbn_sim_test(
    name = "mldsa44_keypair_test",
    srcs = [
        "mldsa_keypair_test.s",
    ],
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "dilithium2_keypair_test.dexp",
    pqc = True,
    deps = [
        ":mldsa44_keypair_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_consts",
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
    pqc = True,
    deps = [
        ":mldsa44_sign_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_consts",
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
    pqc = True,
    deps = [
        ":mldsa44_verify_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_consts",
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
    pqc = True,
    deps = [
        ":mldsa65_keypair_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa65_consts",
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
    pqc = True,
    deps = [
        ":mldsa65_sign_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa65_consts",
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
    pqc = True,
    deps = [
        ":mldsa65_verify_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa65_consts",
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
    pqc = True,
    deps = [
        ":mldsa87_keypair_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa87_consts",
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
    pqc = True,
    deps = [
        ":mldsa87_sign_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa87_consts",
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
    pqc = True,
    deps = [
        ":mldsa87_verify_data",
        "//sw/otbn/crypto/mldsa:intt",
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa87_consts",
        "//sw/otbn/crypto/mldsa:mldsa87_poly",
        "//sw/otbn/crypto/mldsa:mldsa87_rounding",
        "//sw/otbn/crypto/mldsa:mldsa87_verify",
        "//sw/otbn/crypto/mldsa:ntt",
        "//sw/otbn/crypto/mldsa:poly_add",
        "//sw/otbn/crypto/mldsa:poly_pointwise",
        "//sw/otbn/crypto/mldsa:poly_sub",
    ],
)

otbn_sim_test(
    name = "poly_uniform_test",
    srcs = [
        "poly_uniform_test.s",
    ],
    # poly_uniform should be unaffected by mode, but other parts of the
    # polynomial library require some mode to be set.
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "poly_uniform_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_consts",
        "//sw/otbn/crypto/mldsa:mldsa44_poly",
        "//sw/otbn/crypto/mldsa:mldsa44_rounding",
    ],
)

otbn_sim_test(
    name = "poly_uniform_postprocess_test",
    srcs = [
        "poly_uniform_postprocess_test.s",
    ],
    # poly_uniform should be unaffected by mode, but other parts of the
    # polynomial library require some mode to be set.
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "poly_uniform_postprocess_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mldsa:kmac_send_msg",
        "//sw/otbn/crypto/mldsa:mldsa44_consts",
        "//sw/otbn/crypto/mldsa:mldsa44_poly",
        "//sw/otbn/crypto/mldsa:mldsa44_rounding",
    ],
)
