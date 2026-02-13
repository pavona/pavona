# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:acc.bzl", "acc_binary", "acc_library")

package(default_visibility = ["//visibility:public"])

acc_binary(
    name = "boot",
    srcs = [
        "boot.s",
    ],
    deps = [
        ":p256_base",
        ":p256_isoncurve",
        ":p256_sign",
        ":p256_verify",
    ],
)

acc_library(
    name = "ed25519",
    srcs = [
        "ed25519.s",
    ],
)

acc_library(
    name = "ed25519_scalar",
    srcs = [
        "ed25519_scalar.s",
    ],
)

acc_binary(
    name = "run_ed25519",
    srcs = [
        "run_ed25519.s",
    ],
    deps = [
        ":ed25519",
        ":ed25519_scalar",
        ":field25519",
        ":sha512_compact",
        ":sha512_interface",
        ":sha512_padding",
    ],
)

acc_library(
    name = "div",
    srcs = [
        "div.s",
    ],
)

acc_library(
    name = "field25519",
    srcs = [
        "field25519.s",
    ],
)

acc_library(
    name = "gcd",
    srcs = [
        "gcd.s",
    ],
)

acc_library(
    name = "lcm",
    srcs = [
        "lcm.s",
    ],
)

acc_library(
    name = "modexp",
    srcs = [
        "modexp.s",
    ],
)

acc_library(
    name = "modinv",
    srcs = [
        "modinv.s",
    ],
)

acc_library(
    name = "montmul",
    srcs = [
        "montmul.s",
    ],
)

acc_library(
    name = "mul",
    srcs = [
        "mul.s",
    ],
)

acc_library(
    name = "p256_shared_key",
    srcs = [
        "p256_shared_key.s",
    ],
)

acc_library(
    name = "p256_base",
    srcs = [
        "p256_base.s",
    ],
)

acc_library(
    name = "p256_isoncurve",
    srcs = [
        "p256_isoncurve.s",
    ],
)

acc_library(
    name = "p256_isoncurve_proj",
    srcs = [
        "p256_isoncurve_proj.s",
    ],
)

acc_library(
    name = "p256_sign",
    srcs = [
        "p256_sign.s",
    ],
)

acc_library(
    name = "p256_verify",
    srcs = [
        "p256_verify.s",
    ],
)

acc_binary(
    name = "run_p256",
    srcs = [
        "run_p256.s",
    ],
    deps = [
        ":p256_base",
        ":p256_isoncurve",
        ":p256_isoncurve_proj",
        ":p256_shared_key",
        ":p256_sign",
        ":p256_verify",
    ],
)

acc_library(
    name = "p384_base",
    srcs = [
        "p384_base.s",
    ],
)

acc_library(
    name = "p384_a2b",
    srcs = [
        "p384_a2b.s",
    ],
)

acc_library(
    name = "p384_b2a",
    srcs = [
        "p384_b2a.s",
    ],
)

acc_library(
    name = "p384_isoncurve",
    srcs = [
        "p384_isoncurve.s",
    ],
)

acc_library(
    name = "p384_isoncurve_proj",
    srcs = [
        "p384_isoncurve_proj.s",
    ],
)

acc_library(
    name = "p384_sign",
    srcs = [
        "p384_sign.s",
    ],
)

acc_library(
    name = "p384_internal_mult",
    srcs = [
        "p384_internal_mult.s",
    ],
)

acc_library(
    name = "p384_keygen",
    srcs = [
        "p384_keygen.s",
    ],
)

acc_library(
    name = "p384_keygen_from_seed",
    srcs = [
        "p384_keygen_from_seed.s",
    ],
)

acc_library(
    name = "p384_base_mult",
    srcs = [
        "p384_base_mult.s",
    ],
)

acc_library(
    name = "p384_modinv",
    srcs = [
        "p384_modinv.s",
    ],
)

acc_library(
    name = "p384_scalar_mult",
    srcs = [
        "p384_scalar_mult.s",
    ],
)

acc_library(
    name = "p384_verify",
    srcs = [
        "p384_verify.s",
    ],
)

acc_library(
    name = "primality",
    srcs = [
        "primality.s",
    ],
)

acc_binary(
    name = "rsa",
    srcs = [
        "rsa.s",
    ],
    deps = [
        ":div",
        ":modexp",
        ":montmul",
        ":mul",
    ],
)

acc_binary(
    name = "run_rsa_modexp",
    srcs = [
        "run_rsa_modexp.s",
    ],
    deps = [
        ":div",
        ":modexp",
        ":montmul",
        ":mul",
    ],
)

acc_library(
    name = "rsa_keygen",
    srcs = [
        "rsa_keygen.s",
    ],
)

acc_binary(
    name = "run_rsa_keygen",
    srcs = [
        "run_rsa_keygen.s",
    ],
    deps = [
        ":div",
        ":gcd",
        ":lcm",
        ":modinv",
        ":montmul",
        ":mul",
        ":primality",
        ":rsa_keygen",
    ],
)

acc_binary(
    name = "p256_ecdsa_sca",
    srcs = [
        "p256_ecdsa_sca.s",
    ],
    deps = [
        ":p256_base",
        ":p256_isoncurve",
        ":p256_sign",
        ":p256_verify",
    ],
)

acc_binary(
    name = "p256_key_from_seed_sca",
    srcs = [
        "p256_key_from_seed_sca.s",
    ],
    deps = [
        ":p256_base",
        ":p256_isoncurve",
    ],
)

acc_binary(
    name = "p256_mod_inv_sca",
    srcs = [
        "p256_mod_inv_sca.s",
    ],
    deps = [
        ":p256_base",
        ":p256_isoncurve",
    ],
)

acc_binary(
    name = "p384_ecdsa_sca",
    srcs = [
        "p384_ecdsa_sca.s",
    ],
    deps = [
        ":p384_base",
        ":p384_internal_mult",
        ":p384_isoncurve",
        ":p384_modinv",
        ":p384_sign",
    ],
)

acc_binary(
    name = "run_p384",
    srcs = [
        "run_p384.s",
    ],
    deps = [
        ":p384_a2b",
        ":p384_b2a",
        ":p384_base",
        ":p384_base_mult",
        ":p384_internal_mult",
        ":p384_isoncurve",
        ":p384_isoncurve_proj",
        ":p384_keygen",
        ":p384_keygen_from_seed",
        ":p384_modinv",
        ":p384_scalar_mult",
        ":p384_sign",
        ":p384_verify",
    ],
)

acc_library(
    name = "sha256",
    srcs = [
        "sha256.s",
    ],
)

acc_binary(
    name = "run_sha256",
    srcs = [
        "run_sha256.s",
    ],
    deps = [
        ":sha256",
    ],
)

acc_library(
    name = "sha512",
    srcs = [
        "sha512.s",
    ],
)

acc_library(
    name = "sha512_interface",
    srcs = [
        "sha512_interface.s",
    ],
)

acc_library(
    name = "sha512_padding",
    srcs = [
        "sha512_padding.s",
    ],
)

acc_binary(
    name = "run_sha512",
    srcs = [
        "run_sha512.s",
    ],
    deps = [
        ":sha512",
    ],
)

acc_library(
    name = "sha512_compact",
    srcs = [
        "sha512_compact.s",
    ],
)

acc_library(
    name = "sha3_shake",
    srcs = [
        "sha3_shake.s",
    ],
)

acc_library(
    name = "x25519",
    srcs = [
        "x25519.s",
    ],
)

acc_binary(
    name = "x25519_sideload",
    srcs = [
        "x25519_sideload.s",
    ],
    deps = [
        ":field25519",
        ":x25519",
    ],
)
