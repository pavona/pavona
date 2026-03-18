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
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_binary", "acc_consttime_test", "acc_library", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

NSHARES = [2]

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

[
    acc_autogen_sim_test(
        name = params + "_keypair_test" + str(i) + "_1shares",
        srcs = ["mlkem_keypair_test.s"],
        copts = [
            "-DNSHARES=1",
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = 1,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mlkem_keypair_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:cbd",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_keypair_1shares",
            "//sw/acc/crypto/mlkem:mlkem_keypair_1shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:" + params + "_keypair_bss_1shares",
        ],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

[
    acc_autogen_sim_test(
        name = params + "_keypair_test" + str(i) + "_" + str(nshares) + "shares",
        srcs = ["mlkem_keypair_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mlkem_keypair_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:bs_mlkem",
            "//sw/acc/crypto/bs_gadgets:masked_cbd_bc22",
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/bs_gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:refreshios_bc22",
            "//sw/acc/crypto/bs_gadgets:seca2bmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secaddmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secb2amodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
            "//sw/acc/crypto/mlkem:mlkem_keypair_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_keypair_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:" + params + "_keypair_bss_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
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

[
    acc_autogen_sim_test(
        name = params + "_encap_test" + str(i),
        srcs = ["mlkem_encap_test.s"],
        copts = [
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mlkem_encap_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:cbd",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:mlkem_encap",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_enc",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:" + params + "_indcpa_enc_bss_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:pack_ciphertext",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
        ],
    )
    for i in range(NTESTS)
    for nshares in [1]
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

[
    acc_autogen_sim_test(
        name = params + "_non_bs_decap_test" + str(i) + "_" + str(nshares) + "shares",
        srcs = ["mlkem_decap_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        # TODO: 2-share non-bitsliced decap needs more DMEM than is available.
        tags = ["manual"] if nshares == 2 else [],
        testgen = ":mlkem_decap_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/gadgets:compare_consts",
            "//sw/acc/crypto/gadgets:mdecode_ospg18",
            "//sw/acc/crypto/gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:onebitdecompress_bgr21",
            "//sw/acc/crypto/gadgets:poly_compare_bgr21",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
            "//sw/acc/crypto/gadgets:refresh_bbd16_mlkem",
            "//sw/acc/crypto/gadgets:seca2bmodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secadd_cgtv15_mlkem",
            "//sw/acc/crypto/gadgets:secaddmodq_bbe18_mlkem",
            "//sw/acc/crypto/gadgets:secand_isw03_mlkem",
            "//sw/acc/crypto/gadgets:seconebitb2amodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secsampler1_spog19",
            "//sw/acc/crypto/gadgets:sharewise_mlkem",
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:mlkem_non_bs_decap_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_non_bs_indcpa_dec_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_non_bs_indcpa_enc_cmp_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:unpack_ciphertext",
            "//sw/acc/crypto/mlkem:" + params + "_decap_bss_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
    for params in MODE_FOR_PARAMS
]

[
    acc_autogen_sim_test(
        name = params + "_non_bs_false_decap_test" + str(i) + "_" + str(nshares) + "shares",
        srcs = ["mlkem_decap_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        # TODO: 2-share non-bitsliced decap needs more DMEM than is available.
        tags = ["manual"] if nshares == 2 else [],
        # stats = STATS,
        testgen = ":mlkem_decap_testgen",
        testgen_args = [
            "-i",
            params,
        ],
        deps = [
            "//sw/acc/crypto/gadgets:compare_consts",
            "//sw/acc/crypto/gadgets:mdecode_ospg18",
            "//sw/acc/crypto/gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:onebitdecompress_bgr21",
            "//sw/acc/crypto/gadgets:poly_compare_bgr21",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
            "//sw/acc/crypto/gadgets:refresh_bbd16_mlkem",
            "//sw/acc/crypto/gadgets:seca2bmodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secadd_cgtv15_mlkem",
            "//sw/acc/crypto/gadgets:secaddmodq_bbe18_mlkem",
            "//sw/acc/crypto/gadgets:secand_isw03_mlkem",
            "//sw/acc/crypto/gadgets:seconebitb2amodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secsampler1_spog19",
            "//sw/acc/crypto/gadgets:sharewise_mlkem",
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:mlkem_non_bs_decap_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_non_bs_indcpa_dec_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_non_bs_indcpa_enc_cmp_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:unpack_ciphertext",
            "//sw/acc/crypto/mlkem:" + params + "_decap_bss_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
    for params in MODE_FOR_PARAMS
]

[
    acc_autogen_sim_test(
        name = params + "_decap_test" + str(i) + "_" + str(nshares) + "shares",
        srcs = ["mlkem_decap_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mlkem_decap_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:bs_mlkem",
            "//sw/acc/crypto/bs_gadgets:hocompress_cgmz21b_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:linearrefreshmodq_rp10_mlkem_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:masked_cbd_bc22",
            "//sw/acc/crypto/bs_gadgets:masked_compare_bc22",
            "//sw/acc/crypto/bs_gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:masked_poly_tomsg",
            "//sw/acc/crypto/bs_gadgets:onebitdecompress_bgr21",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
            "//sw/acc/crypto/bs_gadgets:refreshios_bc22",
            "//sw/acc/crypto/bs_gadgets:seca2b_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2bmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secaddmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secb2amodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seconebitb2amodq_spog19_mlkem",
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:" + params + "_decap_bss_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_decap_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_dec_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_enc_cmp_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:unpack_ciphertext",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
    for params in MODE_FOR_PARAMS
]

[
    acc_autogen_sim_test(
        name = params + "_false_decap_test" + str(i) + "_" + str(nshares) + "shares",
        srcs = ["mlkem_decap_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = nshares,
        pqc = True,
        # stats = STATS,
        seed = i,
        testgen = ":mlkem_decap_testgen",
        testgen_args = [
            "-i",
            params,
        ],
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:bs_mlkem",
            "//sw/acc/crypto/bs_gadgets:hocompress_cgmz21b_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:linearrefreshmodq_rp10_mlkem_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:masked_cbd_bc22",
            "//sw/acc/crypto/bs_gadgets:masked_compare_bc22",
            "//sw/acc/crypto/bs_gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:masked_poly_tomsg",
            "//sw/acc/crypto/bs_gadgets:onebitdecompress_bgr21",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
            "//sw/acc/crypto/bs_gadgets:refreshios_bc22",
            "//sw/acc/crypto/bs_gadgets:seca2b_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2bmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secaddmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secb2amodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seconebitb2amodq_spog19_mlkem",
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:" + params + "_decap_bss_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_decap_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_dec_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_enc_cmp_" + str(nshares) + "shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:unpack_ciphertext",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
    for params in MODE_FOR_PARAMS
]

[
    acc_autogen_sim_test(
        name = params + "_decap_test" + str(i) + "_1shares",
        srcs = ["mlkem_decap_test.s"],
        copts = [
            "-DNSHARES=1",
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = 1,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mlkem_decap_testgen",
        testgen_args = [params],
        deps = [
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:cbd",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:mlkem_decap_1shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_dec_1shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_enc_cmp_1shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_ciphertext",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:unpack_ciphertext",
            "//sw/acc/crypto/mlkem:" + params + "_decap_bss_1shares",
        ],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]

[
    acc_autogen_sim_test(
        name = params + "_false_decap_test" + str(i) + "_1shares",
        srcs = ["mlkem_decap_test.s"],
        copts = [
            "-DNSHARES=1",
            "-DKYBER_K=" + str(MODE_FOR_PARAMS[params]),
        ],
        nshares = 1,
        pqc = True,
        seed = i,
        # stats = STATS,
        testgen = ":mlkem_decap_testgen",
        testgen_args = [
            "-i",
            params,
        ],
        deps = [
            "//sw/acc/crypto/mlkem:basemul",
            "//sw/acc/crypto/mlkem:cbd",
            "//sw/acc/crypto/mlkem:intt",
            "//sw/acc/crypto/mlkem:kmac_send_msg",
            "//sw/acc/crypto/mlkem:mlkem_consts",
            "//sw/acc/crypto/mlkem:mlkem_decap_1shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_dec_1shares",
            "//sw/acc/crypto/mlkem:mlkem_indcpa_enc_cmp_1shares",
            "//sw/acc/crypto/mlkem:ntt",
            "//sw/acc/crypto/mlkem:pack_ciphertext",
            "//sw/acc/crypto/mlkem:pack_keys",
            "//sw/acc/crypto/mlkem:poly",
            "//sw/acc/crypto/mlkem:poly_gen_matrix",
            "//sw/acc/crypto/mlkem:unpack_ciphertext",
            "//sw/acc/crypto/mlkem:" + params + "_decap_bss_1shares",
        ],
    )
    for i in range(NTESTS)
    for params in MODE_FOR_PARAMS
]
