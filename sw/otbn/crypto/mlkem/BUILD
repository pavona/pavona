# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

NAME_BY_SEC_LEVEL = {
    2: "kyber512",
    3: "kyber768",
    4: "kyber1024",
}

otbn_library(
    name = "kyber_ntt",
    srcs = [
        "kyber_ntt_trn.s",
    ],
)

otbn_library(
    name = "kyber_intt",
    srcs = [
        "kyber_intt_trn.s",
    ],
)

otbn_library(
    name = "kyber_basemul",
    srcs = [
        "kyber_basemul.s",
    ],
)

otbn_library(
    name = "kyber_cbd",
    srcs = [
        "kyber_cbd.s",
    ],
)

otbn_library(
    name = "kyber_cbd_isaext",
    srcs = [
        "kyber_cbd_isaext.s",
    ],
)

[
    otbn_library(
        name = name + "_poly",
        srcs = [
            "kyber_poly.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

otbn_library(
    name = "kyber_poly_gen_matrix",
    srcs = [
        "kyber_poly_gen_matrix.s",
    ],
)

[
    otbn_library(
        name = name + "_packing",
        srcs = [
            "kyber_packing.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

otbn_library(
    name = "kyber_base_ntt",
    srcs = [
        "kyber_base_ntt.s",
    ],
)

otbn_library(
    name = "kyber_base_intt",
    srcs = [
        "kyber_base_intt.s",
    ],
)

otbn_library(
    name = "kyber_base_basemul",
    srcs = [
        "kyber_base_basemul.s",
    ],
)

otbn_library(
    name = "kyber_base_poly_gen_matrix",
    srcs = [
        "kyber_base_poly_gen_matrix.s",
    ],
)

[
    otbn_library(
        name = name + "_base_poly",
        srcs = [
            "kyber_base_poly.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_base_packing",
        srcs = [
            "kyber_base_packing.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_mlkem",
        srcs = [
            "kyber_mlkem.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_base_mlkem",
        srcs = [
            "kyber_base_mlkem.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_plain_mlkem",
        srcs = [
            "kyber_plain_mlkem.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

otbn_library(
    name = "kyber_plain_poly_gen_matrix",
    srcs = [
        "kyber_plain_poly_gen_matrix.s",
    ],
)

[
    otbn_library(
        name = name + "_plain_poly",
        srcs = [
            "kyber_plain_poly.s",
        ],
        copts = ["-DKYBER_K=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]
