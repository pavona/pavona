# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary", "acc_library")

package(default_visibility = ["//visibility:public"])

NSHARES = [
    1,
    2,
    3,
]

NAME_BY_SEC_LEVEL = {
    2: "mlkem512",
    3: "mlkem768",
    4: "mlkem1024",
}

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

[
    acc_library(
        name = name + "_indcpa_enc_bss_" + str(nshares) + "shares",
        srcs = [
            "mlkem_indcpa_enc_bss.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    acc_library(
        name = name + "_keypair",
        srcs = [
            "mlkem_keypair.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

acc_library(
    name = "mlkem_encap",
    srcs = [
        "mlkem_encap.s",
    ],
)

acc_library(
    name = "mlkem_consts",
    srcs = [
        "mlkem_consts.s",
    ],
)

acc_library(
    name = "kmac_send_msg",
    srcs = [
        "kmac_send_msg.s",
    ],
)

[
    acc_library(
        name = "mlkem_non_bs_decap_" + str(nshares) + "shares",
        srcs = [
            "mlkem_non_bs_decap.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = "mlkem_non_bs_indcpa_dec_" + str(nshares) + "shares",
        srcs = [
            "mlkem_non_bs_indcpa_dec.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = "mlkem_non_bs_indcpa_enc_cmp_" + str(nshares) + "shares",
        srcs = [
            "mlkem_non_bs_indcpa_enc_cmp.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = name + "_decap_bss_" + str(nshares) + "shares",
        srcs = [
            "mlkem_decap_bss.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for nshares in NSHARES
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    acc_library(
        name = "mlkem_decap_" + str(nshares) + "shares",
        srcs = [
            "mlkem_decap.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = "mlkem_indcpa_dec_" + str(nshares) + "shares",
        srcs = [
            "mlkem_indcpa_dec.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = "mlkem_indcpa_enc_cmp_" + str(nshares) + "shares",
        srcs = [
            "mlkem_indcpa_enc_cmp.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

acc_library(
    name = "unpack_ciphertext",
    srcs = [
        "unpack_ciphertext.s",
    ],
)

[
    acc_library(
        name = "mlkem_keypair_" + str(nshares) + "shares",
        srcs = [
            "mlkem_keypair.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = name + "_keypair_bss_" + str(nshares) + "shares",
        srcs = [
            "mlkem_keypair_bss.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for nshares in NSHARES
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    acc_library(
        name = "mlkem_indcpa_keypair_" + str(nshares) + "shares",
        srcs = [
            "mlkem_indcpa_keypair.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]
