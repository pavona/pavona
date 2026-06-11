# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary", "acc_library")

package(default_visibility = ["//visibility:public"])

acc_library(
    name = "kmac_send_msg",
    srcs = ["kmac_send_msg.s"],
)

acc_library(
    name = "ntt",
    srcs = ["ntt.s"],
)

acc_library(
    name = "intt",
    srcs = ["intt.s"],
)

acc_library(
    name = "poly_pointwise",
    srcs = ["poly_pointwise.s"],
)

acc_library(
    name = "poly_add",
    srcs = ["poly_add.s"],
)

acc_library(
    name = "poly_sub",
    srcs = ["poly_sub.s"],
)

acc_library(
    name = "keypair",
    srcs = ["mldsa_keypair.s"],
)

acc_library(
    name = "verify",
    srcs = ["mldsa_verify.s"],
)

acc_library(
    name = "poly",
    srcs = ["poly.s"],
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
    name = "consts",
    srcs = ["mldsa_consts.s"],
)
