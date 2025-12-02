# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

NAME_BY_SEC_LEVEL = {
    2: "mldsa44",
    3: "mldsa65",
    5: "mldsa87",
}

otbn_library(
    name = "kmac_send_msg",
    srcs = [
        "kmac_send_msg.s",
    ],
)

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
    name = "poly_pointwise",
    srcs = [
        "poly_pointwise.s",
    ],
)

otbn_library(
    name = "poly_add",
    srcs = [
        "poly_add.s",
    ],
)

otbn_library(
    name = "poly_sub",
    srcs = [
        "poly_sub.s",
    ],
)

[
    otbn_library(
        name = name + "_keypair",
        srcs = [
            "mldsa_keypair.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_verify",
        srcs = [
            "mldsa_verify.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_poly",
        srcs = [
            "poly.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_rounding",
        srcs = [
            "rounding.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_sign",
        srcs = [
            "mldsa_sign.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = name + "_consts",
        srcs = [
            "mldsa_consts.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]
