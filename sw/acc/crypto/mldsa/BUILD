# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_library")

package(default_visibility = ["//visibility:public"])

acc_library(
    name = "gadgets",
    srcs = [
        "gadgets.s",
    ],
)

acc_library(
    name = "gadgets_test",
    srcs = [
        "gadgets.s",
    ],
    copts = [
        "-DMLDSA_REJ_SAMPLE_TEST",
    ],
)

acc_library(
    name = "scratch",
    srcs = [
        "scratch.s",
    ],
)

acc_library(
    name = "kmac_send_msg",
    srcs = [
        "kmac_send_msg.s",
    ],
)

acc_library(
    name = "ntt",
    srcs = [
        "ntt.s",
    ],
)

acc_library(
    name = "gen_twiddles",
    srcs = [
        "gen_twiddles.s",
    ],
)

acc_library(
    name = "ntt_hardened",
    srcs = [
        "ntt.s",
    ],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "intt_hardened",
    srcs = [
        "intt.s",
    ],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "intt",
    srcs = [
        "intt.s",
    ],
)

acc_library(
    name = "poly_pointwise",
    srcs = [
        "poly_pointwise.s",
    ],
)

acc_library(
    name = "poly_add",
    srcs = [
        "poly_add.s",
    ],
)

acc_library(
    name = "poly_sub",
    srcs = [
        "poly_sub.s",
    ],
)

acc_library(
    name = "keypair",
    srcs = ["mldsa_keypair.s"],
)

acc_library(
    name = "keypair_hardened",
    srcs = ["mldsa_keypair.s"],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "verify",
    srcs = ["mldsa_verify.s"],
)

acc_library(
    name = "verify_hardened",
    srcs = ["mldsa_verify.s"],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "poly",
    srcs = ["poly.s"],
)

acc_library(
    name = "poly_hardened",
    srcs = ["poly.s"],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "rounding",
    srcs = ["rounding.s"],
)

acc_library(
    name = "sign",
    srcs = ["mldsa_sign.s"],
)

acc_library(
    name = "sign_hardened",
    srcs = ["mldsa_sign.s"],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "consts",
    srcs = ["mldsa_consts.s"],
)

acc_library(
    name = "consts_hardened",
    srcs = ["mldsa_consts.s"],
    copts = ["-DHARDENED"],
)

acc_library(
    name = "dmem_unprotected",
    srcs = ["mldsa_dmem.s"],
)

acc_library(
    name = "dmem_hardened",
    srcs = ["mldsa_dmem.s"],
    copts = ["-DHARDENED"],
)

# Runtime population of the masked broadcast constant vectors.
acc_library(
    name = "masked_setup",
    srcs = ["mldsa_masked_setup.s"],
    copts = ["-DHARDENED"],
)

filegroup(
    name = "asm_srcs",
    srcs = glob(["*.s"]),
)
