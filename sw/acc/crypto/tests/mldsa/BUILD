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
load("//rules:acc.bzl", "acc_library", "acc_sim_test")

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

# Collecting statistics makes tests run slower, so only do it for benchmarks.
STATS = select({
    "//sw/acc/crypto/tests:acc_bench": True,
    "//conditions:default": False,
})

# The kernels are runtime-parametrized; each test is compiled with -DDILITHIUM_MODE
# only to set up that mode's params/vectors and drive the single runtime kernel.

# Masked keygen wrapper deps (mirror run_mldsa_hardened).
_MASKED_KEYPAIR_DEPS = [
    "//sw/acc/crypto/mldsa:consts_hardened",
    "//sw/acc/crypto/mldsa:dmem_hardened",
    "//sw/acc/crypto/mldsa:gadgets",
    "//sw/acc/crypto/mldsa:gen_twiddles",
    "//sw/acc/crypto/mldsa:intt_hardened",
    "//sw/acc/crypto/mldsa:keypair_hardened",
    "//sw/acc/crypto/mldsa:kmac_send_msg",
    "//sw/acc/crypto/mldsa:masked_setup",
    "//sw/acc/crypto/mldsa:ntt_hardened",
    "//sw/acc/crypto/mldsa:poly_hardened",
    "//sw/acc/crypto/mldsa:poly_add",
    "//sw/acc/crypto/mldsa:poly_pointwise",
    "//sw/acc/crypto/mldsa:poly_sub",
    "//sw/acc/crypto/mldsa:rounding",
    "//sw/acc/crypto/mldsa:scratch",
]

# Key generation tests
py_binary(
    name = "mldsa_keypair_testgen",
    srcs = ["mldsa_keypair_testgen.py"],
    imports = ["../../../../../hw/ip/acc/util"],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    genrule(
        name = params + "_keypair_tc" + str(i) + "_unprotected",
        outs = [params + "_keypair_tc" + str(i) + "_unprotected.hjson"],
        cmd = "$(location :mldsa_keypair_testgen) -s " + str(i) + " " +
              params + " $@",
        tools = [":mldsa_keypair_testgen"],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_keypair_test" + str(i) + "_unprotected",
        binary = "//sw/acc/crypto:run_mldsa",
        pqc = True,
        stats = STATS,
        testcase = params + "_keypair_tc" + str(i) + "_unprotected.hjson",
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

py_binary(
    name = "mldsa_masked_keypair_testgen",
    srcs = ["mldsa_masked_keypair_testgen.py"],
    imports = ["../../../../../hw/ip/acc/util"],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    genrule(
        name = params + "_masked_keypair_tc" + str(i),
        outs = [params + "_masked_keypair_tc" + str(i) + ".hjson"],
        cmd = "$(location :mldsa_masked_keypair_testgen) -s " + str(i) +
              " -n 2 " + params + " $@",
        tools = [":mldsa_masked_keypair_testgen"],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_keypair_test" + str(i) + "_hardened",
        srcs = ["mldsa_masked_keypair_test.s"],
        copts = [
            "-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params]),
            "-DHARDENED",
        ],
        pqc = True,
        stats = STATS,
        testcase = params + "_masked_keypair_tc" + str(i) + ".hjson",
        deps = _MASKED_KEYPAIR_DEPS,
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

# Signature generation tests
py_binary(
    name = "mldsa_sign_testgen",
    srcs = ["mldsa_sign_testgen.py"],
    imports = ["../../../../../hw/ip/acc/util"],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    genrule(
        name = params + "_sign_tc" + str(i) + "_unprotected",
        outs = [params + "_sign_tc" + str(i) + "_unprotected.hjson"],
        cmd = "$(location :mldsa_sign_testgen) -s " + str(i) + " " +
              params + " $@",
        tools = [":mldsa_sign_testgen"],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_sign_test" + str(i) + "_unprotected",
        timeout = "long",
        binary = "//sw/acc/crypto:run_mldsa",
        pqc = True,
        stats = STATS,
        testcase = params + "_sign_tc" + str(i) + "_unprotected.hjson",
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

# 10-vector mean set from https://github.com/zerorisc/mldsa-sign-bench.
[
    genrule(
        name = params + "_sign_bench_tc" + str(idx) + "_unprotected",
        srcs = ["@mldsa_sign_bench//:testsets/mean/" + params + "_10.json"],
        outs = [params + "_sign_bench_tc" + str(idx) + "_unprotected.hjson"],
        cmd = "$(location :mldsa_sign_testgen) -s 0 " + params +
              " --from-vector $(location @mldsa_sign_bench//:testsets/mean/" +
              params + "_10.json) --index " + str(idx) + " $@",
        tags = ["manual"],
        tools = [":mldsa_sign_testgen"],
    )
    for idx in range(10)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_sign_bench_mean_test" + str(idx) + "_unprotected",
        timeout = "long",
        binary = "//sw/acc/crypto:run_mldsa",
        pqc = True,
        stats = STATS,
        tags = ["manual"],
        testcase = params + "_sign_bench_tc" + str(idx) + "_unprotected.hjson",
    )
    for idx in range(10)
    for params in MLDSA_PARAMS
]

[
    test_suite(
        name = params + "_sign_bench_mean_unprotected",
        tags = ["manual"],
        tests = [params + "_sign_bench_mean_test" + str(idx) + "_unprotected" for idx in range(10)],
    )
    for params in MLDSA_PARAMS
]

# Masked signature generation tests
py_binary(
    name = "mldsa_masked_sign_testgen",
    srcs = ["mldsa_masked_sign_testgen.py"],
    imports = ["../../../../../hw/ip/acc/util"],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

# Masked sign runs run_mldsa_hardened with a generated testcase; the signature
# is public, so it is deterministic despite masking.
[
    genrule(
        name = params + "_masked_sign_tc" + str(i),
        outs = [params + "_masked_sign_tc" + str(i) + ".hjson"],
        cmd = "$(location :mldsa_masked_sign_testgen) -s " + str(i) + " -n 2 " +
              params + " $@",
        tools = [":mldsa_masked_sign_testgen"],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_sign_test" + str(i) + "_hardened",
        timeout = "long",
        binary = "//sw/acc/crypto:run_mldsa_hardened",
        pqc = True,
        stats = STATS,
        testcase = params + "_masked_sign_tc" + str(i) + ".hjson",
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

# 10-vector mean set from https://github.com/zerorisc/mldsa-sign-bench.
[
    genrule(
        name = params + "_masked_sign_bench_tc" + str(idx),
        srcs = ["@mldsa_sign_bench//:testsets/mean/" + params + "_10.json"],
        outs = [params + "_masked_sign_bench_tc" + str(idx) + ".hjson"],
        cmd = "$(location :mldsa_masked_sign_testgen) -s 0 -n 2 " + params +
              " --from-vector $(location @mldsa_sign_bench//:testsets/mean/" +
              params + "_10.json) --index " + str(idx) + " $@",
        tags = ["manual"],
        tools = [":mldsa_masked_sign_testgen"],
    )
    for idx in range(10)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_sign_bench_mean_test" + str(idx) + "_hardened",
        timeout = "long",
        binary = "//sw/acc/crypto:run_mldsa_hardened",
        pqc = True,
        stats = STATS,
        tags = ["manual"],
        testcase = params + "_masked_sign_bench_tc" + str(idx) + ".hjson",
    )
    for idx in range(10)
    for params in MLDSA_PARAMS
]

[
    test_suite(
        name = params + "_sign_bench_mean_hardened",
        tags = ["manual"],
        tests = [params + "_sign_bench_mean_test" + str(idx) + "_hardened" for idx in range(10)],
    )
    for params in MLDSA_PARAMS
]

# Signature verification tests
py_binary(
    name = "mldsa_verify_testgen",
    srcs = ["mldsa_verify_testgen.py"],
    imports = ["../../../../../hw/ip/acc/util"],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

# Verify runs the run_mldsa app binary with a generated testcase.
[
    genrule(
        name = params + "_verify_tc" + str(i),
        outs = [params + "_verify_tc" + str(i) + ".hjson"],
        cmd = "$(location :mldsa_verify_testgen) -s " + str(i) + " " +
              params + " $@",
        tools = [":mldsa_verify_testgen"],
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_verify_test" + str(i),
        binary = "//sw/acc/crypto:run_mldsa",
        pqc = True,
        stats = STATS,
        testcase = params + "_verify_tc" + str(i) + ".hjson",
    )
    for i in range(NTESTS)
    for params in MLDSA_PARAMS
]

[
    acc_sim_test(
        name = params + "_poly_make_hint_test",
        srcs = ["poly_make_hint_test.s"],
        copts = ["-DDILITHIUM_MODE=" + str(MODE_FOR_PARAMS[params])],
        dexp = "poly_make_hint_test.dexp",
        pqc = True,
        deps = [
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:poly",
            "//sw/acc/crypto/mldsa:rounding",
        ],
    )
    for params in MLDSA_PARAMS
]

acc_sim_test(
    name = "gen_twiddles_test",
    srcs = ["gen_twiddles_test.s"],
    dexp = "gen_twiddles_test.dexp",
    pqc = True,
    deps = [
        "//sw/acc/crypto/mldsa:consts",
        "//sw/acc/crypto/mldsa:gen_twiddles",
        "//sw/acc/crypto/mldsa:scratch",
    ],
)

acc_sim_test(
    name = "gen_twiddles_inv_test",
    srcs = ["gen_twiddles_inv_test.s"],
    dexp = "gen_twiddles_inv_test.dexp",
    pqc = True,
    deps = [
        "//sw/acc/crypto/mldsa:consts",
        "//sw/acc/crypto/mldsa:gen_twiddles",
        "//sw/acc/crypto/mldsa:scratch",
    ],
)

acc_sim_test(
    name = "poly_uniform_test",
    srcs = ["poly_uniform_test.s"],
    copts = ["-DDILITHIUM_MODE=2"],
    dexp = "poly_uniform_test.dexp",
    pqc = True,
    deps = [
        "//sw/acc/crypto/mldsa:consts",
        "//sw/acc/crypto/mldsa:kmac_send_msg",
        "//sw/acc/crypto/mldsa:poly",
        "//sw/acc/crypto/mldsa:rounding",
    ],
)

acc_sim_test(
    name = "poly_uniform_postprocess_test",
    srcs = ["poly_uniform_postprocess_test.s"],
    copts = ["-DDILITHIUM_MODE=2"],
    dexp = "poly_uniform_postprocess_test.dexp",
    pqc = True,
    deps = [
        "//sw/acc/crypto/mldsa:consts",
        "//sw/acc/crypto/mldsa:kmac_send_msg",
        "//sw/acc/crypto/mldsa:poly",
        "//sw/acc/crypto/mldsa:rounding",
    ],
)

test_suite(
    name = "mldsa_benchmarks",
    tests = [
        ":" + params + "_verify_test" + str(i)
        for i in range(NTESTS)
        for params in MLDSA_PARAMS
    ] + [
        ":" + params + "_keypair_test" + str(i) + "_" + variant
        for i in range(NTESTS)
        for params in MLDSA_PARAMS
        for variant in [
            "hardened",
            "unprotected",
        ]
    ] + [
        # Signing cost varies with the rejection-sampling attempts.
        ":" + params + "_sign_bench_mean_test" + str(i) + "_" + variant
        for i in range(10)
        for params in MLDSA_PARAMS
        for variant in [
            "hardened",
            "unprotected",
        ]
    ],
)
