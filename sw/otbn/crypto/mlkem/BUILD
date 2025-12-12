# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

NAME_BY_SEC_LEVEL = {
    2: "mlkem512",
    3: "mlkem768",
    4: "mlkem1024",
}

otbn_library(
    name = "ntt",
    srcs = [
        "ntt.s",
    ],
)

otbn_library(
    name = "intt",
    srcs = [
        "intt.s",
    ],
)

otbn_library(
    name = "basemul",
    srcs = [
        "basemul.s",
    ],
)

otbn_library(
    name = "cbd",
    srcs = [
        "cbd.s",
    ],
)

[
    otbn_library(
        name = name + "_poly",
        srcs = [
            "poly.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

otbn_library(
    name = "poly_gen_matrix",
    srcs = [
        "poly_gen_matrix.s",
    ],
)

[
    otbn_library(
        name = name + "_pack_ciphertext",
        srcs = [
            "pack_ciphertext.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_pack_keys",
        srcs = [
            "pack_keys.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
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

[
    otbn_library(
        name = name + "_encap",
        srcs = [
            "mlkem_encap.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_decap",
        srcs = [
            "mlkem_decap.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_consts",
        srcs = [
            "mlkem_consts.s",
        ],
        copts = [
            "-DKYBER_K=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

otbn_library(
    name = "kmac_send_msg",
    srcs = [
        "kmac_send_msg.s",
    ],
)
