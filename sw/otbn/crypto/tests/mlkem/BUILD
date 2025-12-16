# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028)
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.

load("@ot_python_deps//:requirements.bzl", "requirement")
load("//rules:otbn.bzl", "otbn_binary", "otbn_consttime_test", "otbn_library", "otbn_sim_test", "otbn_autogen_sim_test")

package(default_visibility = ["//visibility:public"])

MODE_FOR_PARAMS = {"mlkem512": 2, "mlkem768": 3, "mlkem1024": 4}
NTESTS = 10
STATS = True # makes tests run slower but logs detailed execution stats

# Key generation tests
py_binary(
    name = "mlkem_keypair_testgen",
    srcs = ["mlkem_keypair_testgen.py"],
    imports = [
        "../../../../../hw/ip/otbn/util",
    ],
    deps = [
        "//hw/ip/otbn/util/shared:testgen",
        requirement("kyber-py"),
    ],
)
[
    otbn_autogen_sim_test(
        name = params + "_keypair_test" + str(i),
        srcs = ["mlkem_keypair_test.s"],
        seed = i,
        testgen = ":mlkem_keypair_testgen",
        testgen_args = [params],
        stats = STATS,
        copts = [
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:" + params + "_consts",
        "//sw/otbn/crypto/mlkem:" + params + "_keypair",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_keys",
        "//sw/otbn/crypto/mlkem:" + params + "_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
        ],
    )
    for i in range(NTESTS) for params in MODE_FOR_PARAMS
]

# Encapsulation tests
py_binary(
    name = "mlkem_encap_testgen",
    srcs = ["mlkem_encap_testgen.py"],
    imports = [
        "../../../../../hw/ip/otbn/util",
    ],
    deps = [
        "//hw/ip/otbn/util/shared:testgen",
        requirement("kyber-py"),
    ],
)
[
    otbn_autogen_sim_test(
        name = params + "_encap_test" + str(i),
        srcs = ["mlkem_encap_test.s"],
        seed = i,
        testgen = ":mlkem_encap_testgen",
        testgen_args = [params],
        stats = STATS,
        copts = [
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:" + params + "_consts",
        "//sw/otbn/crypto/mlkem:" + params + "_encap",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_keys",
        "//sw/otbn/crypto/mlkem:" + params + "_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
        ],
    )
    for i in range(NTESTS) for params in MODE_FOR_PARAMS
]

# Encapsulation tests
py_binary(
    name = "mlkem_decap_testgen",
    srcs = ["mlkem_decap_testgen.py"],
    imports = [
        "../../../../../hw/ip/otbn/util",
    ],
    deps = [
        "//hw/ip/otbn/util/shared:testgen",
        requirement("kyber-py"),
    ],
)
[
    otbn_autogen_sim_test(
        name = params + "_decap_test" + str(i),
        srcs = ["mlkem_decap_test.s"],
        seed = i,
        testgen = ":mlkem_decap_testgen",
        testgen_args = [params],
        stats = STATS,
        copts = [
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:" + params + "_consts",
        "//sw/otbn/crypto/mlkem:" + params + "_decap",
        "//sw/otbn/crypto/mlkem:" + params + "_encap",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_keys",
        "//sw/otbn/crypto/mlkem:" + params + "_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
        ],
    )
    for i in range(NTESTS) for params in MODE_FOR_PARAMS
]
[
    otbn_autogen_sim_test(
        name = params + "_false_decap_test" + str(i),
        srcs = ["mlkem_decap_test.s"],
        seed = i,
        testgen = ":mlkem_decap_testgen",
        testgen_args = ['-i', params],
        stats = STATS,
        copts = [
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:" + params + "_consts",
        "//sw/otbn/crypto/mlkem:" + params + "_decap",
        "//sw/otbn/crypto/mlkem:" + params + "_encap",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:" + params + "_pack_keys",
        "//sw/otbn/crypto/mlkem:" + params + "_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
        ],
    )
    for i in range(NTESTS) for params in MODE_FOR_PARAMS
]
