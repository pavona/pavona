// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_RSA_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_RSA_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define RSA_CMD_MAX_MESSAGE_DIGEST_BYTES 64
#define RSA_CMD_MAX_RAW_MESSAGE_BYTES 446
#define RSA_CMD_MAX_LABEL_BYTES 68
#define RSA_CMD_MAX_SIGNATURE_BYTES 1024
#define RSA_CMD_MAX_CIPHERTEXT_BYTES 514
#define RSA_CMD_MAX_MODULUS_BYTES 512
#define RSA_CMD_MAX_PUBLIC_EXPONENT_BYTES 512
#define RSA_CMD_MAX_PRIVATE_EXPONENT_BYTES 512

// clang-format off

#define RSA_OPERATION(_, value) \
    value(_, Sign) \
    value(_, Verify) \
    value(_, Encrypt) \
    value(_, Decrypt)
UJSON_SERDE_ENUM(CryptotestRsaOperation, cryptotest_rsa_operation_t, RSA_OPERATION);

#define RSA_PADDING(_, value) \
    value(_, Pkcs15) \
    value(_, Pss) \
    value(_, Oaep)
UJSON_SERDE_ENUM(CryptotestRsaPadding, cryptotest_rsa_padding_t, RSA_PADDING);

#define RSA_SECURITY_LEVEL(_, value) \
    value(_, Rsa2048) \
    value(_, Rsa3072) \
    value(_, Rsa4096)
UJSON_SERDE_ENUM(CryptotestRsaSecurityLevel, cryptotest_rsa_security_level_t, RSA_SECURITY_LEVEL);

#define RSA_HASH_ALG(_, value) \
    value(_, Sha256) \
    value(_, Sha384) \
    value(_, Sha512) \
    value(_, Sha3_224) \
    value(_, Sha3_256) \
    value(_, Sha3_384) \
    value(_, Sha3_512) \
    value(_, Shake128) \
    value(_, Shake256)
UJSON_SERDE_ENUM(CryptotestRsaHashAlg, cryptotest_rsa_hash_alg_t, RSA_HASH_ALG);

#define RSA_RAW_MESSAGE(field, string) \
    field(message, uint8_t, RSA_CMD_MAX_RAW_MESSAGE_BYTES) \
    field(message_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaRawMessage, cryptotest_rsa_raw_message_t, RSA_RAW_MESSAGE);

#define RSA_DECRYPT_OUTPUT(field, string) \
    field(success, uint8_t) \
    field(plaintext, uint8_t, RSA_CMD_MAX_RAW_MESSAGE_BYTES)    \
    field(plaintext_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaDecryptOutput, cryptotest_rsa_decrypt_output_t, RSA_DECRYPT_OUTPUT);

#define RSA_LABEL(field, string) \
    field(label, uint8_t, RSA_CMD_MAX_LABEL_BYTES) \
    field(label_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaLabel, cryptotest_rsa_label_t, RSA_LABEL);

#define RSA_MESSAGE_DIGEST(field, string) \
    field(message_digest, uint8_t, RSA_CMD_MAX_MESSAGE_DIGEST_BYTES) \
    field(message_digest_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaMessageDigest, cryptotest_rsa_message_digest_t, RSA_MESSAGE_DIGEST);

#define RSA_SIGNATURE(field, string) \
    field(signature, uint8_t, RSA_CMD_MAX_SIGNATURE_BYTES) \
    field(signature_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaSignature, cryptotest_rsa_signature_t, RSA_SIGNATURE);

#define RSA_CIPHERTEXT(field, string) \
    field(ciphertext, uint8_t, RSA_CMD_MAX_CIPHERTEXT_BYTES) \
    field(ciphertext_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaCiphertext, cryptotest_rsa_ciphertext_t, RSA_CIPHERTEXT);

#define RSA_EXPECTED_LENGTH(field, string) \
    field(expected_len, size_t)
UJSON_SERDE_STRUCT(CryptotestRsaExpectedLength, cryptotest_rsa_expected_length_t, RSA_EXPECTED_LENGTH);

#define RSA_VERIFY_OUTPUT(_, value) \
    value(_, Success) \
    value(_, Failure)
UJSON_SERDE_ENUM(CryptotestRsaVerifyOutput, cryptotest_rsa_verify_output_t, RSA_VERIFY_OUTPUT);

#define RSA_PUBLIC_KEY(field, string) \
    field(n, uint8_t, RSA_CMD_MAX_MODULUS_BYTES) \
    field(n_len, size_t) \
    field(e, uint32_t)
UJSON_SERDE_STRUCT(CryptotestRsaPublicKey, cryptotest_rsa_public_key_t, RSA_PUBLIC_KEY);

#define RSA_PRIVATE_KEY(field, string) \
    field(n, uint8_t, RSA_CMD_MAX_MODULUS_BYTES) \
    field(n_len, size_t) \
    field(d, uint8_t, RSA_CMD_MAX_PRIVATE_EXPONENT_BYTES) \
    field(d_len, size_t) \
    field(e, uint32_t)
UJSON_SERDE_STRUCT(CryptotestRsaPrivateKey, cryptotest_rsa_private_key_t, RSA_PRIVATE_KEY);

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_RSA_COMMANDS_H_
