// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_ED25519_COMMANDS_H_
#define OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_ED25519_COMMANDS_H_
#include "sw/device/lib/ujson/ujson_derive.h"
#ifdef __cplusplus
extern "C" {
#endif

#define MODULE_ID MAKE_MODULE_ID('j', 'e', 'd')

// Signature and public key buffers are oversized to accommodate
// invalid test vectors.
#define ED25519_CMD_MAX_MESSAGE_BYTES 1024
#define ED25519_CMD_MAX_SIGNATURE_BYTES 128  // valid: 64
#define ED25519_CMD_MAX_PUBLIC_KEY_BYTES 64  // valid: 32
#define ED25519_CMD_MAX_PRIVATE_KEY_BYTES 32
#define ED25519_CMD_MAX_CONTEXT_BYTES 256  // max: 255

// clang-format off

#define ED25519_SUBCOMMAND(_, value) \
    value(_, Ed25519Sigver) \
    value(_, Ed25519Siggen)
UJSON_SERDE_ENUM(Ed25519Subcommand, ed25519_subcommand_t, ED25519_SUBCOMMAND);

#define ED25519_SIGN_MODE(_, value) \
    value(_, Eddsa) \
    value(_, HashEddsa)
UJSON_SERDE_ENUM(CryptotestEd25519SignMode, cryptotest_ed25519_sign_mode_t, ED25519_SIGN_MODE);

#define ED25519_MESSAGE(field, string) \
    field(input, uint8_t, ED25519_CMD_MAX_MESSAGE_BYTES) \
    field(input_len, size_t)
UJSON_SERDE_STRUCT(CryptotestEd25519Message, cryptotest_ed25519_message_t, ED25519_MESSAGE);

#define ED25519_SIGNATURE(field, string) \
    field(signature, uint8_t, ED25519_CMD_MAX_SIGNATURE_BYTES) \
    field(signature_len, size_t)
UJSON_SERDE_STRUCT(CryptotestEd25519Signature, cryptotest_ed25519_signature_t, ED25519_SIGNATURE);

#define ED25519_PUBLIC_KEY(field, string) \
    field(pk, uint8_t, ED25519_CMD_MAX_PUBLIC_KEY_BYTES) \
    field(pk_len, size_t)
UJSON_SERDE_STRUCT(CryptotestEd25519PublicKey, cryptotest_ed25519_public_key_t, ED25519_PUBLIC_KEY);

#define ED25519_SIGGEN_DATA(field, string) \
    field(sk, uint8_t, ED25519_CMD_MAX_PRIVATE_KEY_BYTES) \
    field(sk_len, size_t) \
    field(pk, uint8_t, ED25519_CMD_MAX_PUBLIC_KEY_BYTES) \
    field(pk_len, size_t) \
    field(message, uint8_t, ED25519_CMD_MAX_MESSAGE_BYTES) \
    field(message_len, size_t) \
    field(context, uint8_t, ED25519_CMD_MAX_CONTEXT_BYTES) \
    field(context_len, size_t)
UJSON_SERDE_STRUCT(CryptotestEd25519SiggenData, cryptotest_ed25519_siggen_data_t, ED25519_SIGGEN_DATA);

#define ED25519_SIGGEN_OUTPUT(field, string) \
    field(signature, uint8_t, ED25519_CMD_MAX_SIGNATURE_BYTES) \
    field(signature_len, size_t) \
    field(success, bool)
UJSON_SERDE_STRUCT(CryptotestEd25519SiggenOutput, cryptotest_ed25519_siggen_output_t, ED25519_SIGGEN_OUTPUT);

#define ED25519_VERIFY_OUTPUT(_, value) \
    value(_, Success) \
    value(_, Failure)
UJSON_SERDE_ENUM(CryptotestEd25519VerifyOutput, cryptotest_ed25519_verify_output_t, ED25519_VERIFY_OUTPUT);

#undef MODULE_ID

// clang-format on

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_TESTS_CRYPTO_CRYPTOTEST_JSON_ED25519_COMMANDS_H_
