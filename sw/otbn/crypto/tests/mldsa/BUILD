# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.

load("//rules:otbn.bzl", "otbn_binary", "otbn_consttime_test", "otbn_library", "otbn_sim_test")

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
    name = "dilithium2_keypair_test",
    srcs = [
        "dilithium_keypair_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=2"],
    dexp = "dilithium2_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:key_pair_dilithium2",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium2",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium2",
    ],
)

otbn_sim_test(
    name = "dilithium2_sign_test",
    srcs = [
        "dilithium_sign_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=2"],
    dexp = "dilithium2_sign_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium2",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:poly_sub_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium2",
        "//sw/otbn/crypto/mldsa:sign_dilithium2",
    ],
)

otbn_sim_test(
    name = "dilithium2_verify_test",
    srcs = [
        "dilithium_verify_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=2"],
    dexp = "dilithium2_verify_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium2",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:poly_sub_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium2",
        "//sw/otbn/crypto/mldsa:verify_dilithium2",
    ],
)

otbn_sim_test(
    name = "dilithium3_keypair_test",
    srcs = [
        "dilithium_keypair_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=3"],
    dexp = "dilithium3_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:key_pair_dilithium3",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium3",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium3",
    ],
)

otbn_sim_test(
    name = "dilithium3_sign_test",
    srcs = [
        "dilithium_sign_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=3"],
    dexp = "dilithium3_sign_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium3",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:poly_sub_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium3",
        "//sw/otbn/crypto/mldsa:sign_dilithium3",
    ],
)

otbn_sim_test(
    name = "dilithium3_verify_test",
    srcs = [
        "dilithium_verify_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=3"],
    dexp = "dilithium3_verify_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium3",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:poly_sub_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium3",
        "//sw/otbn/crypto/mldsa:verify_dilithium3",
    ],
)

otbn_sim_test(
    name = "dilithium5_keypair_test",
    srcs = [
        "dilithium_keypair_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=5"],
    dexp = "dilithium5_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:key_pair_dilithium5",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium5",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium5",
    ],
)

otbn_sim_test(
    name = "dilithium5_sign_test",
    srcs = [
        "dilithium_sign_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=5"],
    dexp = "dilithium5_sign_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium5",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:poly_sub_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium5",
        "//sw/otbn/crypto/mldsa:sign_dilithium5",
    ],
)

otbn_sim_test(
    name = "dilithium5_verify_test",
    srcs = [
        "dilithium_verify_test.s",
    ],
    copts = ["-DDILITHIUM_MODE=5"],
    dexp = "dilithium5_verify_test.dexp",
    deps = [
        "//sw/otbn/crypto/mldsa:intt_dilithium",
        "//sw/otbn/crypto/mldsa:ntt_dilithium",
        "//sw/otbn/crypto/mldsa:poly_add_dilithium",
        "//sw/otbn/crypto/mldsa:poly_dilithium5",
        "//sw/otbn/crypto/mldsa:poly_pointwise_dilithium",
        "//sw/otbn/crypto/mldsa:poly_sub_dilithium",
        "//sw/otbn/crypto/mldsa:rounding_dilithium5",
        "//sw/otbn/crypto/mldsa:verify_dilithium5",
    ],
)
