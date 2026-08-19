# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary", "acc_library")

package(default_visibility = ["//visibility:public"])

VARIANTS = {
    "unprotected": [],
    "hardened": ["-DHARDENED"],
}

acc_library(
    name = "gadgets",
    srcs = [
        "gadgets.s",
    ],
)

# gadgets.s with poly_rej_samp reading its randomness from DMEM instead of
# URND, so poly_rej_samp can be tested deterministically.
acc_library(
    name = "gadgets_rej_sample_test",
    srcs = [
        "gadgets.s",
    ],
    copts = [
        "-DMLKEM_REJ_SAMPLE_TEST",
    ],
)

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
    srcs = [
        "poly.s",
    ],
)

acc_library(
    name = "poly_gen_matrix",
    srcs = [
        "poly_gen_matrix.s",
    ],
)

acc_library(
    name = "pack_ciphertext",
    srcs = [
        "pack_ciphertext.s",
    ],
)

acc_library(
    name = "pack_keys",
    srcs = [
        "pack_keys.s",
    ],
)

acc_library(
    name = "mlkem_indcpa_enc",
    srcs = [
        "mlkem_indcpa_enc.s",
    ],
)

acc_library(
    name = "mlkem_encap",
    srcs = [
        "mlkem_encap.s",
    ],
)

acc_library(
    name = "consts",
    srcs = [
        "mlkem_consts.s",
    ],
)

[
    acc_library(
        name = "dmem_" + variant,
        srcs = ["mlkem_dmem.s"],
        copts = variant_copts,
    )
    for variant, variant_copts in VARIANTS.items()
]

[
    acc_library(
        name = "mlkem_decap_" + variant,
        srcs = [
            "mlkem_decap.s",
        ],
        copts = variant_copts,
    )
    for variant, variant_copts in VARIANTS.items()
]

[
    acc_library(
        name = "mlkem_indcpa_dec_" + variant,
        srcs = [
            "mlkem_indcpa_dec.s",
        ],
        copts = variant_copts,
    )
    for variant, variant_copts in VARIANTS.items()
]

[
    acc_library(
        name = "mlkem_indcpa_enc_cmp_" + variant,
        srcs = [
            "mlkem_indcpa_enc_cmp.s",
        ],
        copts = variant_copts,
    )
    for variant, variant_copts in VARIANTS.items()
]

acc_library(
    name = "unpack_ciphertext",
    srcs = [
        "unpack_ciphertext.s",
    ],
)

[
    acc_library(
        name = "mlkem_keypair_" + variant,
        srcs = [
            "mlkem_keypair.s",
        ],
        copts = variant_copts,
    )
    for variant, variant_copts in VARIANTS.items()
]

[
    acc_library(
        name = "mlkem_indcpa_keypair_" + variant,
        srcs = [
            "mlkem_indcpa_keypair.s",
        ],
        copts = variant_copts,
    )
    for variant, variant_copts in VARIANTS.items()
]

acc_library(
    name = "whitening",
    srcs = [
        "whitening.s",
    ],
)
