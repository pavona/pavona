# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028)
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.

load("@ot_python_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_binary", "acc_consttime_test", "acc_library", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

MLDSA_PARAMS = [
    "mldsa44",
    "mldsa65",
    "mldsa87",
]

MODE_FOR_PARAMS = {
    "mldsa44": 2,
    "mldsa65": 3,
    "mldsa87": 5,
}

NTESTS = 3

STATS = True  # makes tests run slower but logs detailed execution stats

# Key generation tests
py_binary(
    name = "mldsa_keypair_testgen",
    srcs = ["mldsa_keypair_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    acc_autogen_sim_test(
        name = params + "_keypair_test" + str(i),
        srcs = ["mldsa_keypair_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
        ],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mldsa_keypair_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mldsa:intt",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:" + params + "_consts",
            "//sw/acc/crypto/mldsa:" + params + "_keypair",
            "//sw/acc/crypto/mldsa:" + params + "_poly",
            "//sw/acc/crypto/mldsa:" + params + "_rounding",
            "//sw/acc/crypto/mldsa:ntt",
            "//sw/acc/crypto/mldsa:poly_add",
            "//sw/acc/crypto/mldsa:poly_pointwise",
        ],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

# Signature generation tests
py_binary(
    name = "mldsa_sign_testgen",
    srcs = ["mldsa_sign_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    acc_autogen_sim_test(
        name = params + "_sign_test" + str(i),
        timeout = "long",
        srcs = ["mldsa_sign_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
        ],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mldsa_sign_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mldsa:intt",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:" + params + "_consts",
            "//sw/acc/crypto/mldsa:" + params + "_poly",
            "//sw/acc/crypto/mldsa:" + params + "_rounding",
            "//sw/acc/crypto/mldsa:" + params + "_sign",
            "//sw/acc/crypto/mldsa:ntt",
            "//sw/acc/crypto/mldsa:poly_add",
            "//sw/acc/crypto/mldsa:poly_pointwise",
            "//sw/acc/crypto/mldsa:poly_sub",
        ],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

# Signature verification tests
py_binary(
    name = "mldsa_verify_testgen",
    srcs = ["mldsa_verify_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    acc_autogen_sim_test(
        name = params + "_verify_test" + str(i),
        srcs = ["mldsa_verify_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
        ],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mldsa_verify_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mldsa:intt",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:" + params + "_consts",
            "//sw/acc/crypto/mldsa:" + params + "_poly",
            "//sw/acc/crypto/mldsa:" + params + "_rounding",
            "//sw/acc/crypto/mldsa:" + params + "_verify",
            "//sw/acc/crypto/mldsa:ntt",
            "//sw/acc/crypto/mldsa:poly_add",
            "//sw/acc/crypto/mldsa:poly_pointwise",
            "//sw/acc/crypto/mldsa:poly_sub",
        ],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_poly_make_hint_test",
        srcs = [
            "poly_make_hint_test.s",
        ],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
        ],
        dexp = "poly_make_hint_test.dexp",
        pqc = True,
        deps = [
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:" + params + "_consts",
            "//sw/acc/crypto/mldsa:" + params + "_poly",
            "//sw/acc/crypto/mldsa:" + params + "_rounding",
        ],
    )
    for params in MLDSA_PARAMS
]

acc_sim_test(
    name = "poly_uniform_test",
    srcs = [
        "poly_uniform_test.s",
    ],
    # poly_uniform should be unaffected by mode, but other parts of the
    # polynomial library require some mode to be set.
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "poly_uniform_test.dexp",
    pqc = True,
    deps = [
        "//sw/acc/crypto/mldsa:kmac_send_msg",
        "//sw/acc/crypto/mldsa:mldsa44_consts",
        "//sw/acc/crypto/mldsa:mldsa44_poly",
        "//sw/acc/crypto/mldsa:mldsa44_rounding",
    ],
)

acc_sim_test(
    name = "poly_uniform_postprocess_test",
    srcs = [
        "poly_uniform_postprocess_test.s",
    ],
    # poly_uniform should be unaffected by mode, but other parts of the
    # polynomial library require some mode to be set.
    copts = [
        "-DDILITHIUM_MODE=2",
    ],
    dexp = "poly_uniform_postprocess_test.dexp",
    pqc = True,
    deps = [
        "//sw/acc/crypto/mldsa:kmac_send_msg",
        "//sw/acc/crypto/mldsa:mldsa44_consts",
        "//sw/acc/crypto/mldsa:mldsa44_poly",
        "//sw/acc/crypto/mldsa:mldsa44_rounding",
    ],
)
