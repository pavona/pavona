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

py_binary(
    name = "mldsa_masked_keypair_testgen",
    srcs = ["mldsa_masked_keypair_testgen.py"],
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
        name = params + "_keypair_masked_test" + str(i) + "_2shares",
        srcs = ["mldsa_keypair_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
            "-DNSHARES=2",
        ],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mldsa_masked_keypair_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:masked_poly_uniform_eta_" + params,
            "//sw/acc/crypto/mldsa:intt",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_eta",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22_d2",
            "//sw/acc/crypto/mldsa/gadgets:secunmask_modq",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
            "//sw/acc/crypto/mldsa:" + params + "_consts",
            "//sw/acc/crypto/mldsa:" + params + "_keypair_masked_2shares",
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

_SIGN_DEPS = {
    params: [
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
    ]
    for params in MLDSA_PARAMS
}

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
        deps = _SIGN_DEPS[params],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

# 10-vector mean set from https://github.com/zerorisc/mldsa-sign-bench.
[
    acc_autogen_sim_test(
        name = params + "_sign_bench_mean_" + str(idx),
        timeout = "long",
        srcs = ["mldsa_sign_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
        ],
        pqc = True,
        seed = 0,
        stats = STATS,
        tags = ["manual"],
        testgen = ":mldsa_sign_testgen",
        testgen_args = [params],
        vector_index = idx,
        vectors = "@mldsa_sign_bench//:testsets/mean/" + params + "_10.json",
        deps = _SIGN_DEPS[params],
    )
    for idx in range(10)
    for params in MLDSA_PARAMS
]

[
    test_suite(
        name = params + "_sign_bench_mean",
        tags = ["manual"],
        tests = [params + "_sign_bench_mean_" + str(idx) for idx in range(10)],
    )
    for params in MLDSA_PARAMS
]

# Masked signature generation tests
NSHARES = [2]

MLDSA_MASKED_PARAMS = [
    "mldsa44",
    "mldsa65",
    "mldsa87",
]

py_binary(
    name = "mldsa_masked_sign_testgen",
    srcs = ["mldsa_masked_sign_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

_MASKED_SIGN_DEPS = {
    params: [
        "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa_k32",
        "//sw/acc/crypto/mldsa/gadgets:masked_poly_uniform_eta_" + params,
        "//sw/acc/crypto/mldsa/gadgets:masked_poly_uniform_gamma1_" + params,
        "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
        "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
        "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
        "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
        "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22_d2",
        "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:secb2amodq_eta",
        "//sw/acc/crypto/mldsa/gadgets:secboundcheck_mldsa",
        "//sw/acc/crypto/mldsa/gadgets:secdecompose_" + params,
        "//sw/acc/crypto/mldsa/gadgets:secleq",
        "//sw/acc/crypto/mldsa/gadgets:secunmask_modq",
        "//sw/acc/crypto/mldsa/gadgets:scratch",
        "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
        "//sw/acc/crypto/mldsa:intt",
        "//sw/acc/crypto/mldsa:kmac_send_msg",
        "//sw/acc/crypto/mldsa:" + params + "_consts_masked",
        "//sw/acc/crypto/mldsa:" + params + "_poly",
        "//sw/acc/crypto/mldsa:" + params + "_rounding",
        "//sw/acc/crypto/mldsa:ntt",
        "//sw/acc/crypto/mldsa:poly_add",
        "//sw/acc/crypto/mldsa:poly_pointwise",
        "//sw/acc/crypto/mldsa:poly_sub",
    ] + (
        # seccompress is only used by mldsa44 SecDecompose.
        ["//sw/acc/crypto/mldsa/gadgets:seccompress"] if params == "mldsa44" else []
    )
    for params in MLDSA_MASKED_PARAMS
}

[
    acc_autogen_sim_test(
        name = params + "_masked_sign_test" + str(i) + "_" + str(nshares) + "shares",
        timeout = "long",
        srcs = ["mldsa_masked_sign_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mldsa_masked_sign_testgen",
        testgen_args = [params],
        deps = _MASKED_SIGN_DEPS[params] + [
            "//sw/acc/crypto/mldsa:" + params + "_sign_masked_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
    for params in MLDSA_MASKED_PARAMS
]

# 10-vector mean set from https://github.com/zerorisc/mldsa-sign-bench.
[
    acc_autogen_sim_test(
        name = params + "_masked_sign_bench_mean_" + str(idx) + "_" + str(nshares) + "shares",
        timeout = "long",
        srcs = ["mldsa_masked_sign_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = 0,
        stats = STATS,
        tags = ["manual"],
        testgen = ":mldsa_masked_sign_testgen",
        testgen_args = [params],
        vector_index = idx,
        vectors = "@mldsa_sign_bench//:testsets/mean/" + params + "_10.json",
        deps = _MASKED_SIGN_DEPS[params] + [
            "//sw/acc/crypto/mldsa:" + params + "_sign_masked_" + str(nshares) + "shares",
        ],
    )
    for idx in range(10)
    for nshares in NSHARES
    for params in MLDSA_MASKED_PARAMS
]

[
    test_suite(
        name = params + "_masked_sign_bench_mean_" + str(nshares) + "shares",
        tags = ["manual"],
        tests = [
            params + "_masked_sign_bench_mean_" + str(idx) + "_" + str(nshares) + "shares"
            for idx in range(10)
        ],
    )
    for nshares in NSHARES
    for params in MLDSA_MASKED_PARAMS
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
