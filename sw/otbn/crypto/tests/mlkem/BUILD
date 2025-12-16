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

otbn_sim_test(
    name = "mlkem512_encap_test",
    srcs = [
        "mlkem_encap_test.s",
    ],
    copts = [
        "-DKYBER_K=2",
    ],
    dexp = "mlkem512_encap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem512_consts",
        "//sw/otbn/crypto/mlkem:mlkem512_encap",
        "//sw/otbn/crypto/mlkem:mlkem512_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem512_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem512_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem512_decap_test",
    srcs = [
        "mlkem_decap_test.s",
    ],
    copts = [
        "-DKYBER_K=2",
    ],
    dexp = "mlkem512_decap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem512_consts",
        "//sw/otbn/crypto/mlkem:mlkem512_decap",
        "//sw/otbn/crypto/mlkem:mlkem512_encap",
        "//sw/otbn/crypto/mlkem:mlkem512_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem512_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem512_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem512_false_decap_test",
    srcs = [
        "mlkem_false_decap_test.s",
    ],
    copts = [
        "-DKYBER_K=2",
    ],
    dexp = "mlkem512_false_decap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem512_consts",
        "//sw/otbn/crypto/mlkem:mlkem512_decap",
        "//sw/otbn/crypto/mlkem:mlkem512_encap",
        "//sw/otbn/crypto/mlkem:mlkem512_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem512_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem512_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem768_encap_test",
    srcs = [
        "mlkem_encap_test.s",
    ],
    copts = [
        "-DKYBER_K=3",
    ],
    dexp = "mlkem768_encap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem768_consts",
        "//sw/otbn/crypto/mlkem:mlkem768_encap",
        "//sw/otbn/crypto/mlkem:mlkem768_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem768_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem768_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem768_decap_test",
    srcs = [
        "mlkem_decap_test.s",
    ],
    copts = [
        "-DKYBER_K=3",
    ],
    dexp = "mlkem768_decap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem768_consts",
        "//sw/otbn/crypto/mlkem:mlkem768_decap",
        "//sw/otbn/crypto/mlkem:mlkem768_encap",
        "//sw/otbn/crypto/mlkem:mlkem768_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem768_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem768_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem768_false_decap_test",
    srcs = [
        "mlkem_false_decap_test.s",
    ],
    copts = [
        "-DKYBER_K=3",
    ],
    dexp = "mlkem768_false_decap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem768_consts",
        "//sw/otbn/crypto/mlkem:mlkem768_decap",
        "//sw/otbn/crypto/mlkem:mlkem768_encap",
        "//sw/otbn/crypto/mlkem:mlkem768_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem768_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem768_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem1024_encap_test",
    srcs = [
        "mlkem_encap_test.s",
    ],
    copts = [
        "-DKYBER_K=4",
    ],
    dexp = "mlkem1024_encap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem1024_consts",
        "//sw/otbn/crypto/mlkem:mlkem1024_encap",
        "//sw/otbn/crypto/mlkem:mlkem1024_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem1024_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem1024_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem1024_decap_test",
    srcs = [
        "mlkem_decap_test.s",
    ],
    copts = [
        "-DKYBER_K=4",
    ],
    dexp = "mlkem1024_decap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem1024_consts",
        "//sw/otbn/crypto/mlkem:mlkem1024_decap",
        "//sw/otbn/crypto/mlkem:mlkem1024_encap",
        "//sw/otbn/crypto/mlkem:mlkem1024_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem1024_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem1024_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "mlkem1024_false_decap_test",
    srcs = [
        "mlkem_false_decap_test.s",
    ],
    copts = [
        "-DKYBER_K=4",
    ],
    dexp = "mlkem1024_false_decap_test.dexp",
    pqc = True,
    deps = [
        "//sw/otbn/crypto/mlkem:basemul",
        "//sw/otbn/crypto/mlkem:cbd",
        "//sw/otbn/crypto/mlkem:intt",
        "//sw/otbn/crypto/mlkem:kmac_send_msg",
        "//sw/otbn/crypto/mlkem:mlkem1024_consts",
        "//sw/otbn/crypto/mlkem:mlkem1024_decap",
        "//sw/otbn/crypto/mlkem:mlkem1024_encap",
        "//sw/otbn/crypto/mlkem:mlkem1024_pack_ciphertext",
        "//sw/otbn/crypto/mlkem:mlkem1024_pack_keys",
        "//sw/otbn/crypto/mlkem:mlkem1024_poly",
        "//sw/otbn/crypto/mlkem:ntt",
        "//sw/otbn/crypto/mlkem:poly_gen_matrix",
    ],
)
