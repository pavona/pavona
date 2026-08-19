# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028).
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("//rules:acc.bzl", "acc_binary", "acc_consttime_test", "acc_library", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

MODE_FOR_PARAMS = {
    "mlkem512": 2,
    "mlkem768": 3,
    "mlkem1024": 4,
}

NTESTS = 10

STATS = True  # makes tests run slower but logs detailed execution stats

# Key generation tests
py_binary(
    name = "mlkem_keypair_testgen",
    srcs = ["mlkem_keypair_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("kyber-py"),
    ],
)

# Unprotected keygen runs the run_mlkem app binary directly.
[
    genrule(
        name = params + "_keypair_tc" + str(i) + "_unprotected",
        outs = [params + "_keypair_tc" + str(i) + "_unprotected.hjson"],
        cmd = "$(location :mlkem_keypair_testgen) -s " + str(i) + " " +
              params + " $@",
        tools = [":mlkem_keypair_testgen"],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

[
    acc_sim_test(
        name = params + "_keypair_test" + str(i) + "_unprotected",
        binary = "//sw/acc/crypto:run_mlkem",
        pqc = True,
        stats = STATS,
        testcase = params + "_keypair_tc" + str(i) + "_unprotected.hjson",
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

# Masked keygen runs a thin wrapper that unmasks dk (in place, using the shared
# layout's keygen-dead scratch) for the check.
[
    genrule(
        name = params + "_keypair_tc" + str(i) + "_hardened",
        outs = [params + "_keypair_tc" + str(i) + "_hardened.hjson"],
        cmd = "$(location :mlkem_keypair_testgen) -s " + str(i) + " --hardened " +
              params + " $@",
        tools = [":mlkem_keypair_testgen"],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

[
    acc_sim_test(
        name = params + "_keypair_test" + str(i) + "_hardened",
        srcs = ["mlkem_keypair_masked_test.s"],
        copts = ["-DKYBER_K=" + str(MODE_FOR_PARAMS[params])],
        pqc = True,
        stats = STATS,
        testcase = params + "_keypair_tc" + str(i) + "_hardened.hjson",
        deps = [
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:dmem_hardened",
            "//sw/acc/crypto/mlkem:gadgets",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_keypair_hardened",
            "//sw/acc/crypto/mlkem:mlkem_keypair_hardened",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:whitening",
        ],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

# Encapsulation tests
py_binary(
    name = "mlkem_encap_testgen",
    srcs = ["mlkem_encap_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("kyber-py"),
    ],
)

# Encap runs the run_mlkem app binary with a generated testcase.
[
    genrule(
        name = params + "_encap_tc" + str(i),
        outs = [params + "_encap_tc" + str(i) + ".hjson"],
        cmd = "$(location :mlkem_encap_testgen) -s " + str(i) + " " +
              params + " $@",
        tools = [":mlkem_encap_testgen"],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

[
    acc_sim_test(
        name = params + "_encap_test" + str(i),
        binary = "//sw/acc/crypto:run_mlkem",
        pqc = True,
        stats = STATS,
        testcase = params + "_encap_tc" + str(i) + ".hjson",
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

# (Masked) decapsulation tests
py_binary(
    name = "mlkem_decap_testgen",
    srcs = ["mlkem_decap_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("kyber-py"),
    ],
)

HARDENED_DECAP_DEPS = [
    "//sw/acc/crypto/mlkem:gadgets",
    "//sw/acc/crypto/mlkem:basemul",
    "//sw/acc/crypto/mlkem:intt",
    "//sw/acc/crypto/mlkem:consts",
    "//sw/acc/crypto/mlkem:mlkem_decap_hardened",
    "//sw/acc/crypto/mlkem:mlkem_indcpa_dec_hardened",
    "//sw/acc/crypto/mlkem:mlkem_indcpa_enc_cmp_hardened",
    "//sw/acc/crypto/mlkem:ntt",
    "//sw/acc/crypto/mlkem:pack_keys",
    "//sw/acc/crypto/mlkem:poly",
    "//sw/acc/crypto/mlkem:poly_gen_matrix",
    "//sw/acc/crypto/mlkem:unpack_ciphertext",
    "//sw/acc/crypto/mlkem:whitening",
]

UNPROTECTED_DECAP_DEPS = [
    "//sw/acc/crypto/mlkem:basemul",
    "//sw/acc/crypto/mlkem:cbd",
    "//sw/acc/crypto/mlkem:intt",
    "//sw/acc/crypto/mlkem:consts",
    "//sw/acc/crypto/mlkem:mlkem_decap_unprotected",
    "//sw/acc/crypto/mlkem:mlkem_indcpa_dec_unprotected",
    "//sw/acc/crypto/mlkem:mlkem_indcpa_enc_cmp_unprotected",
    "//sw/acc/crypto/mlkem:ntt",
    "//sw/acc/crypto/mlkem:pack_ciphertext",
    "//sw/acc/crypto/mlkem:pack_keys",
    "//sw/acc/crypto/mlkem:poly",
    "//sw/acc/crypto/mlkem:poly_gen_matrix",
    "//sw/acc/crypto/mlkem:unpack_ciphertext",
]

# Decap runs run_mlkem (unprotected) or a thin wrapper that recombines the ss
# shares (masked); false_decap feeds a tampered ciphertext.
[
    genrule(
        name = params + "_" + kind + "_tc" + str(i) + "_unprotected",
        outs = [params + "_" + kind + "_tc" + str(i) + "_unprotected.hjson"],
        cmd = "$(location :mlkem_decap_testgen) -s " + str(i) + " " +
              inv + params + " $@",
        tools = [":mlkem_decap_testgen"],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
    for kind, inv in [
        ("decap_test", ""),
        ("false_decap_test", "-i "),
    ]
]

[
    acc_sim_test(
        name = params + "_" + kind + str(i) + "_unprotected",
        binary = "//sw/acc/crypto:run_mlkem",
        pqc = True,
        stats = STATS,
        testcase = params + "_" + kind + "_tc" + str(i) + "_unprotected.hjson",
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
    for kind in [
        "decap_test",
        "false_decap_test",
    ]
]

[
    genrule(
        name = params + "_" + kind + "_tc" + str(i) + "_hardened",
        outs = [params + "_" + kind + "_tc" + str(i) + "_hardened.hjson"],
        cmd = "$(location :mlkem_decap_testgen) -s " + str(i) + " --hardened " +
              inv + params + " $@",
        tools = [":mlkem_decap_testgen"],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
    for kind, inv in [
        ("decap_test", ""),
        ("false_decap_test", "-i "),
    ]
]

[
    acc_sim_test(
        name = params + "_" + kind + str(i) + "_hardened",
        srcs = ["mlkem_decap_masked_test.s"],
        copts = ["-DKYBER_K=" + str(MODE_FOR_PARAMS[params])],
        pqc = True,
        stats = STATS,
        testcase = params + "_" + kind + "_tc" + str(i) + "_hardened.hjson",
        deps = HARDENED_DECAP_DEPS + [
            "//sw/acc/crypto/mlkem:dmem_hardened",
        ],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
    for kind in [
        "decap_test",
        "false_decap_test",
    ]
]
