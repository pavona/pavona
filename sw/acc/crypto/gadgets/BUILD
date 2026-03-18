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

NAME_BY_SEC_LEVEL = {
    2: "mlkem512",
    3: "mlkem768",
    4: "mlkem1024",
}

acc_library(
    name = "compare_consts",
    srcs = [
        "consts.s",
    ],
)

acc_library(
    name = "linearrefreshmodq_rp10_mlkem",
    srcs = [
        "linearrefreshmodq_rp10_mlkem.s",
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
    name = "mdecode_ospg18",
    srcs = [
        "mdecode_ospg18.s",
    ],
)

acc_library(
    name = "seconebitb2amodq_spog19_mlkem",
    srcs = [
        "seconebitb2amodq_spog19_mlkem.s",
    ],
)

acc_library(
    name = "onebitdecompress_bgr21",
    srcs = [
        "onebitdecompress_bgr21.s",
    ],
)

acc_library(
    name = "poly_compare_bgr21",
    srcs = [
        "poly_compare_bgr21.s",
    ],
)

acc_library(
    name = "poly_rej_samp",
    srcs = [
        "poly_rej_samp_19q.s",
    ],
)

[
    acc_library(
        name = "refresh_bbd16_" + name,
        srcs = [
            "refresh_bbd16.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]

[
    acc_library(
        name = "secadd_cgtv15_" + name,
        srcs = [
            "secadd_cgtv15.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]

[
    acc_library(
        name = "seca2bmodq_spog19_" + name,
        srcs = [
            "seca2bmodq_spog19.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]

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

[
    acc_library(
        name = "secaddmodq_bbe18_" + name,
        srcs = [
            "secaddmodq_bbe18.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]

[
    acc_library(
        name = "secand_isw03_" + name,
        srcs = [
            "secand_isw03.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]

acc_library(
    name = "secsampler1_spog19",
    srcs = [
        "secsampler1_spog19.s",
    ],
)

[
    acc_library(
        name = "sharewise_" + name,
        srcs = [
            "sharewise.s",
        ],
        copts = [
            "-DSCHEME=" + str(scheme),
        ],
    )
    for scheme, name in SCHEME.items()
]
