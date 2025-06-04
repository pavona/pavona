# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.

load("//rules:otbn.bzl", "otbn_binary", "otbn_consttime_test", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

otbn_sim_test(
    name = "kyber512_mlkem_keypair_test",
    srcs = [
        "kyber512_mlkem_keypair_test.s",
    ],
    copts = ["-DKYBER_K=2"],
    dexp = "kyber512_mlkem_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber512_mlkem",
        "//sw/otbn/crypto/mlkem:kyber512_packing",
        "//sw/otbn/crypto/mlkem:kyber512_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber512_mlkem_enc_test",
    srcs = [
        "kyber512_mlkem_enc_test.s",
    ],
    copts = ["-DKYBER_K=2"],
    dexp = "kyber512_mlkem_enc_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber512_mlkem",
        "//sw/otbn/crypto/mlkem:kyber512_packing",
        "//sw/otbn/crypto/mlkem:kyber512_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber512_mlkem_dec_test",
    srcs = [
        "kyber512_mlkem_dec_test.s",
    ],
    copts = ["-DKYBER_K=2"],
    dexp = "kyber512_mlkem_dec_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber512_mlkem",
        "//sw/otbn/crypto/mlkem:kyber512_packing",
        "//sw/otbn/crypto/mlkem:kyber512_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber512_mlkem_false_dec_test",
    srcs = [
        "kyber512_mlkem_false_dec_test.s",
    ],
    copts = ["-DKYBER_K=2"],
    dexp = "kyber512_mlkem_false_dec_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber512_mlkem",
        "//sw/otbn/crypto/mlkem:kyber512_packing",
        "//sw/otbn/crypto/mlkem:kyber512_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber768_mlkem_keypair_test",
    srcs = [
        "kyber768_mlkem_keypair_test.s",
    ],
    copts = ["-DKYBER_K=3"],
    dexp = "kyber768_mlkem_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber768_mlkem",
        "//sw/otbn/crypto/mlkem:kyber768_packing",
        "//sw/otbn/crypto/mlkem:kyber768_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber768_mlkem_enc_test",
    srcs = [
        "kyber768_mlkem_enc_test.s",
    ],
    copts = ["-DKYBER_K=3"],
    dexp = "kyber768_mlkem_enc_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber768_mlkem",
        "//sw/otbn/crypto/mlkem:kyber768_packing",
        "//sw/otbn/crypto/mlkem:kyber768_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber768_mlkem_dec_test",
    srcs = [
        "kyber768_mlkem_dec_test.s",
    ],
    copts = ["-DKYBER_K=3"],
    dexp = "kyber768_mlkem_dec_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber768_mlkem",
        "//sw/otbn/crypto/mlkem:kyber768_packing",
        "//sw/otbn/crypto/mlkem:kyber768_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber768_mlkem_false_dec_test",
    srcs = [
        "kyber768_mlkem_false_dec_test.s",
    ],
    copts = ["-DKYBER_K=3"],
    dexp = "kyber768_mlkem_false_dec_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber768_mlkem",
        "//sw/otbn/crypto/mlkem:kyber768_packing",
        "//sw/otbn/crypto/mlkem:kyber768_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber1024_mlkem_keypair_test",
    srcs = [
        "kyber1024_mlkem_keypair_test.s",
    ],
    copts = ["-DKYBER_K=4"],
    dexp = "kyber1024_mlkem_keypair_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber1024_mlkem",
        "//sw/otbn/crypto/mlkem:kyber1024_packing",
        "//sw/otbn/crypto/mlkem:kyber1024_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber1024_mlkem_enc_test",
    srcs = [
        "kyber1024_mlkem_enc_test.s",
    ],
    copts = ["-DKYBER_K=4"],
    dexp = "kyber1024_mlkem_enc_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber1024_mlkem",
        "//sw/otbn/crypto/mlkem:kyber1024_packing",
        "//sw/otbn/crypto/mlkem:kyber1024_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber1024_mlkem_dec_test",
    srcs = [
        "kyber1024_mlkem_dec_test.s",
    ],
    copts = ["-DKYBER_K=4"],
    dexp = "kyber1024_mlkem_dec_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber1024_mlkem",
        "//sw/otbn/crypto/mlkem:kyber1024_packing",
        "//sw/otbn/crypto/mlkem:kyber1024_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)

otbn_sim_test(
    name = "kyber1024_mlkem_false_dec_test",
    srcs = [
        "kyber1024_mlkem_false_dec_test.s",
    ],
    copts = ["-DKYBER_K=4"],
    dexp = "kyber1024_mlkem_false_dec_test.dexp",
    deps = [
        "//sw/otbn/crypto/mlkem:kyber1024_mlkem",
        "//sw/otbn/crypto/mlkem:kyber1024_packing",
        "//sw/otbn/crypto/mlkem:kyber1024_poly",
        "//sw/otbn/crypto/mlkem:kyber_basemul",
        "//sw/otbn/crypto/mlkem:kyber_cbd_isaext",
        "//sw/otbn/crypto/mlkem:kyber_intt",
        "//sw/otbn/crypto/mlkem:kyber_ntt",
        "//sw/otbn/crypto/mlkem:kyber_poly_gen_matrix",
    ],
)
