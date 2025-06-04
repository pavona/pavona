# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

NAME_BY_SEC_LEVEL = {
    2: "dilithium2",
    3: "dilithium3",
    5: "dilithium5",
}

otbn_library(
    name = "ntt_dilithium",
    srcs = [
        "ntt_dilithium.s",
    ],
)

otbn_library(
    name = "ntt_base_dilithium",
    srcs = [
        "ntt_base_dilithium.s",
    ],
)

otbn_library(
    name = "intt_dilithium",
    srcs = [
        "intt_dilithium.s",
    ],
)

otbn_library(
    name = "intt_base_dilithium",
    srcs = [
        "intt_base_dilithium.s",
    ],
)

otbn_library(
    name = "poly_pointwise_dilithium",
    srcs = [
        "poly_pointwise_dilithium.s",
    ],
)

otbn_library(
    name = "poly_pointwise_acc_dilithium",
    srcs = [
        "poly_pointwise_dilithium.s",
    ],
)

otbn_library(
    name = "poly_add_dilithium",
    srcs = [
        "poly_add_dilithium.s",
    ],
)

otbn_library(
    name = "poly_add_base_dilithium",
    srcs = [
        "poly_add_base_dilithium.s",
    ],
)

otbn_library(
    name = "poly_sub_dilithium",
    srcs = [
        "poly_sub_dilithium.s",
    ],
)

[
    otbn_library(
        name = "key_pair_" + name,
        srcs = [
            "key_pair_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "key_pair_base_" + name,
        srcs = [
            "key_pair_base_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "key_pair_plain_" + name,
        srcs = [
            "key_pair_plain_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "verify_" + name,
        srcs = [
            "verify_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "verify_base_" + name,
        srcs = [
            "verify_base_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "verify_plain_" + name,
        srcs = [
            "verify_plain_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "poly_" + name,
        srcs = [
            "poly_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "poly_base_" + name,
        srcs = [
            "poly_base_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "poly_plain_" + name,
        srcs = [
            "poly_plain_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "rounding_" + name,
        srcs = [
            "rounding_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "sign_" + name,
        srcs = [
            "sign_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "sign_base_" + name,
        srcs = [
            "sign_base_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]

[
    otbn_library(
        name = "sign_plain_" + name,
        srcs = [
            "sign_plain_dilithium.s",
        ],
        copts = ["-DDILITHIUM_MODE=" + str(sec_level)],
    )
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
]
