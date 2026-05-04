# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary", "acc_library")

package(default_visibility = ["//visibility:public"])

acc_library(
    name = "ntt",
    srcs = [
        "ntt.s",
    ],
)

acc_library(
    name = "intt",
    srcs = [
        "intt.s",
    ],
)

acc_library(
    name = "basemul",
    srcs = [
        "basemul.s",
    ],
)

acc_library(
    name = "cbd",
    srcs = [
        "cbd.s",
    ],
)

acc_library(
    name = "poly",
    srcs = ["poly.s"],
)

acc_library(
    name = "poly_gen_matrix",
    srcs = ["poly_gen_matrix.s"],
)

acc_library(
    name = "pack_ciphertext",
    srcs = ["pack_ciphertext.s"],
)

acc_library(
    name = "pack_keys",
    srcs = ["pack_keys.s"],
)

acc_library(
    name = "indcpa_enc",
    srcs = ["mlkem_indcpa_enc.s"],
)

acc_library(
    name = "keypair",
    srcs = ["mlkem_keypair.s"],
)

acc_library(
    name = "encap",
    srcs = ["mlkem_encap.s"],
)

acc_library(
    name = "decap",
    srcs = ["mlkem_decap.s"],
)

acc_library(
    name = "consts",
    srcs = ["mlkem_consts.s"],
)

acc_library(
    name = "kmac_send_msg",
    srcs = [
        "kmac_send_msg.s",
    ],
)
