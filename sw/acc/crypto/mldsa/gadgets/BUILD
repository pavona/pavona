# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_library")

package(default_visibility = ["//visibility:public"])

acc_library(
    name = "secunmask_modq",
    srcs = [
        "secunmask_modq.s",
    ],
)

acc_library(
    name = "secleq",
    srcs = [
        "secleq.s",
    ],
)

acc_library(
    name = "seccompress",
    srcs = [
        "seccompress.s",
    ],
)

acc_library(
    name = "secboundcheck_mldsa",
    srcs = [
        "secboundcheck.s",
    ],
)

acc_library(
    name = "secand_cs20",
    srcs = [
        "secand_cs20.s",
    ],
)

# Drop-in d=2 specialization of secand_cs20
acc_library(
    name = "secand_cs20_d2",
    srcs = [
        "secand_cs20_d2.s",
    ],
)

acc_library(
    name = "secfulladder_bc22",
    srcs = [
        "secfulladder_bc22.s",
    ],
)

# d=2 specialization of secfulladder_bc22.s
acc_library(
    name = "secfulladder_bc22_d2",
    srcs = [
        "secfulladder_bc22_d2.s",
    ],
)

acc_library(
    name = "secadd_bc22",
    srcs = [
        "secadd_bc22.s",
    ],
)

acc_library(
    name = "secadd_bc22_immd_d1",
    srcs = [
        "secadd_bc22_immd_d1.s",
    ],
)

acc_library(
    name = "secadd_bc22_immd_d2",
    srcs = [
        "secadd_bc22_immd_d2.s",
    ],
)

acc_library(
    name = "secaddmodq_bc22_mldsa",
    srcs = [
        "secaddmodq_bc22.s",
    ],
)

acc_library(
    name = "secadd_constant_bmsk_mldsa",
    srcs = [
        "secadd_constant_bmsk_mldsa.s",
    ],
)

acc_library(
    name = "seca2bmodq_bc22_mldsa",
    srcs = [
        "seca2bmodq_bc22.s",
    ],
)

acc_library(
    name = "secb2amodq_bc22_mldsa",
    srcs = [
        "secb2amodq_bc22.s",
    ],
)

acc_library(
    name = "secb2amodq_eta",
    srcs = [
        "secb2amodq_eta.s",
    ],
)

acc_library(
    name = "poly_rej_samp_bitsliced_mldsa",
    srcs = [
        "poly_rej_samp_bitsliced.s",
    ],
)

acc_library(
    name = "poly_rej_samp_bitsliced_mldsa_test",
    srcs = [
        "poly_rej_samp_bitsliced.s",
    ],
    copts = [
        "-DTEST=1",
    ],
)

# Shared scratchpad buffer for the masking gadgets.
acc_library(
    name = "scratch",
    srcs = [
        "scratch.s",
    ],
)

acc_library(
    name = "bitslice_mldsa",
    srcs = [
        "bitslice.s",
    ],
)

# k=32 variant: emits all 32 bit-stripes (vs the default 23).  Used by
# seccompress so it can transpose y_i with the bottom 24 rounding bits
# intact, then SecAdd mod 2^32.
acc_library(
    name = "bitslice_mldsa_k32",
    srcs = [
        "bitslice.s",
    ],
    copts = [
        "-DBITSLICE_KBITS=32",
    ],
)

acc_library(
    name = "unbitslice_mldsa",
    srcs = [
        "unbitslice.s",
    ],
)

[
    acc_library(
        name = "masked_poly_uniform_gamma1_" + name,
        srcs = [
            "masked_poly_uniform_gamma1.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in {
        2: "mldsa44",
        3: "mldsa65",
        5: "mldsa87",
    }.items()
]

[
    acc_library(
        name = "masked_poly_uniform_eta_" + name,
        srcs = [
            "masked_poly_uniform_eta.s",
        ],
        copts = [
            "-DETA=" + str(eta),
        ],
    )
    for name, eta in {
        "mldsa44": 2,
        "mldsa65": 4,
        "mldsa87": 2,
    }.items()
]

[
    acc_library(
        name = "secdecompose_" + name,
        srcs = [
            "secdecompose.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(sec_level),
        ],
    )
    for sec_level, name in {
        2: "mldsa44",
        3: "mldsa65",
        5: "mldsa87",
    }.items()
]
