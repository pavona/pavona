# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary", "acc_library")

package(default_visibility = ["//visibility:public"])

NSHARES = [
    2,
    3,
    4,
]

SCHEME = {
    0: "mlkem",
    1: "mldsa",
}

acc_library(
    name = "bitcopymask_bc22_mlkem",
    srcs = [
        "bitcopymask_bc22_mlkem.s",
    ],
)

acc_library(
    name = "bs_mlkem",
    srcs = [
        "bs_mlkem.s",
    ],
)

[
    acc_library(
        name = "hocompress_cgmz21b_" + str(nshares) + "shares",
        srcs = [
            "hocompress_cgmz21b.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = "linearrefreshmodq_rp10_mlkem_" + str(nshares) + "shares",
        srcs = [
            "linearrefreshmodq_rp10_mlkem.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

acc_library(
    name = "masked_cbd_bc22",
    srcs = [
        "masked_cbd_bc22.s",
    ],
)

acc_library(
    name = "masked_compare_bc22",
    srcs = [
        "masked_compare_bc22.s",
    ],
)

[
    acc_library(
        name = "masked_poly_getnoise_" + str(nshares) + "shares",
        srcs = [
            "masked_poly_getnoise.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

acc_library(
    name = "masked_poly_tomsg",
    srcs = [
        "masked_poly_tomsg.s",
    ],
)

acc_library(
    name = "onebitdecompress_bgr21",
    srcs = [
        "onebitdecompress_bgr21.s",
    ],
)

acc_library(
    name = "poly_rej_samp",
    srcs = [
        "poly_rej_samp_19q.s",
    ],
)

acc_library(
    name = "refreshios_bc22",
    srcs = [
        "refreshios_bc22.s",
    ],
)

acc_library(
    name = "secadd_bc22",
    srcs = [
        "secadd_bc22.s",
    ],
)

[
    acc_library(
        name = "seca2b_bc22_" + str(nshares) + "shares",
        srcs = [
            "seca2b_bc22.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

acc_library(
    name = "seca2bmodq_bc22_mlkem",
    srcs = [
        "seca2bmodq_bc22_mlkem.s",
    ],
)

acc_library(
    name = "secb2amodq_bc22_mlkem",
    srcs = [
        "secb2amodq_bc22_mlkem.s",
    ],
)

[
    acc_library(
        name = "secb2amodq_spog19_" + name,
        srcs = [
            "secb2amodq_spog19.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]

acc_library(
    name = "secaddmodq_bc22_mlkem",
    srcs = [
        "secaddmodq_bc22_mlkem.s",
    ],
)

[
    acc_library(
        name = "secand_cs20_" + str(nshares) + "shares",
        srcs = [
            "secand_cs20.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

[
    acc_library(
        name = "secfulladder_bc22_" + str(nshares) + "shares",
        srcs = [
            "secfulladder_bc22.s",
        ],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
    )
    for nshares in NSHARES
]

acc_library(
    name = "seconebitb2amodq_spog19_mlkem",
    srcs = [
        "seconebitb2amodq_spog19_mlkem.s",
    ],
)
