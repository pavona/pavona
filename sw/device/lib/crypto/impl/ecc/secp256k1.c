// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/secp256k1.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/ecc/secp256k1_insn_counts.h"

#include "hw/top_egret/sw/autogen/top_egret.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('k', '2', 'r')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_secp256k1);  // The ACC secp256k1 app.
static const acc_app_t kAccAppSecp256k1 = ACC_APP_T_INIT(run_secp256k1);

// Declare offsets for input and output buffers.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, mode);  // Mode of operation.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, msg);   // ECDSA message digest.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, r);     // ECDSA signature scalar R.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, s);     // ECDSA signature scalar S.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, x);     // Public key x-coordinate.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, y);     // Public key y-coordinate.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1,
                        d0_io);  // Private key scalar d (share 0).
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1,
                        d1_io);               // Private key scalar d (share 1).
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, x_r);  // ECDSA verification result.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, ok);   // Status code.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, session_token);  // Session token.

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_secp256k1, mode);
static const acc_addr_t kAccVarMsg = ACC_ADDR_T_INIT(run_secp256k1, msg);
static const acc_addr_t kAccVarR = ACC_ADDR_T_INIT(run_secp256k1, r);
static const acc_addr_t kAccVarS = ACC_ADDR_T_INIT(run_secp256k1, s);
static const acc_addr_t kAccVarX = ACC_ADDR_T_INIT(run_secp256k1, x);
static const acc_addr_t kAccVarY = ACC_ADDR_T_INIT(run_secp256k1, y);
static const acc_addr_t kAccVarD0 = ACC_ADDR_T_INIT(run_secp256k1, d0_io);
static const acc_addr_t kAccVarD1 = ACC_ADDR_T_INIT(run_secp256k1, d1_io);
static const acc_addr_t kAccVarXr = ACC_ADDR_T_INIT(run_secp256k1, x_r);
static const acc_addr_t kAccVarOk = ACC_ADDR_T_INIT(run_secp256k1, ok);
static const acc_addr_t kAccVarSessionToken =
    ACC_ADDR_T_INIT(run_secp256k1, session_token);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_KEYGEN);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_KEY_CHECK);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_VERIFY);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_ECDH);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_SIDELOAD_KEYGEN);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_SIDELOAD_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_secp256k1, MODE_SIDELOAD_ECDH);
static const uint32_t kAccSecp256k1ModeKeygen =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_KEYGEN);
static const uint32_t kAccSecp256k1ModeKeyCheck =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_KEY_CHECK);
static const uint32_t kAccSecp256k1ModeSign =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_SIGN);
static const uint32_t kAccSecp256k1ModeVerify =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_VERIFY);
static const uint32_t kAccSecp256k1ModeEcdh =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_ECDH);
static const uint32_t kAccSecp256k1ModeSideloadKeygen =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_SIDELOAD_KEYGEN);
static const uint32_t kAccSecp256k1ModeSideloadSign =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_SIDELOAD_SIGN);
static const uint32_t kAccSecp256k1ModeSideloadEcdh =
    ACC_ADDR_T_INIT(run_secp256k1, MODE_SIDELOAD_ECDH);

enum {
  /*
   * Mode is represented by a single word.
   */
  kAccSecp256k1ModeWords = 1,
  /**
   * Number of extra padding words needed for masked scalar shares.
   *
   * Where W is the word size and S is the share size, the padding needed is:
   *   (W - (S % W)) % W
   *
   * The extra outer "% W" ensures that the padding is 0 if (S % W) is 0.
   */
  kMaskedScalarPaddingWords =
      (kAccWideWordNumWords -
       (kSecp256k1MaskedScalarShareWords % kAccWideWordNumWords)) %
      kAccWideWordNumWords,
};

OT_WARN_UNUSED_RESULT
static status_t secp256k1_masked_scalar_write(
    const secp256k1_masked_scalar_t *src, const acc_addr_t share0_addr,
    const acc_addr_t share1_addr) {
  ACC_WIPE_IF_ERROR(acc_dmem_write(kSecp256k1MaskedScalarShareWords,
                                   src->share0, share0_addr));
  ACC_WIPE_IF_ERROR(acc_dmem_write(kSecp256k1MaskedScalarShareWords,
                                   src->share1, share1_addr));

  // Write trailing 0s so that ACC's 256-bit read of the second share does not
  // cause an error.
  ACC_WIPE_IF_ERROR(
      acc_dmem_set(kMaskedScalarPaddingWords, 0,
                   share0_addr + kSecp256k1MaskedScalarShareBytes));
  return acc_dmem_set(kMaskedScalarPaddingWords, 0,
                      share1_addr + kSecp256k1MaskedScalarShareBytes);
}

status_t secp256k1_keygen_start(uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into keygen.
  uint32_t mode = kAccSecp256k1ModeKeygen;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t secp256k1_sideload_keygen_start(uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into sideload-keygen.
  uint32_t mode = kAccSecp256k1ModeSideloadKeygen;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t secp256k1_keygen_finalize(uint32_t session_token,
                                   secp256k1_masked_scalar_t *private_key,
                                   secp256k1_point_t *public_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kSecp256k1KeygenMinInstructionCount,
                       kSecp256k1KeygenMaxInstructionCount);

  // Read the masked private key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kSecp256k1MaskedScalarShareWords, kAccVarD0,
                                  private_key->share0));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kSecp256k1MaskedScalarShareWords, kAccVarD1,
                                  private_key->share1));

  // Read the public key from ACC dmem.
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarX, public_key->x));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarY, public_key->y));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t secp256k1_sideload_keygen_finalize(uint32_t session_token,
                                            secp256k1_point_t *public_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kSecp256k1SideloadKeygenMinInstructionCount,
                       kSecp256k1SideloadKeygenMaxInstructionCount);

  // Read the public key from ACC dmem.
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarX, public_key->x));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarY, public_key->y));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

/**
 * Set the message digest for signature generation or verification.
 *
 * ACC requires the digest in little-endian form, so this routine flips the
 * bytes.
 *
 * @param digest Digest to set (big-endian).
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t set_message_digest(
    const uint32_t digest[kSecp256k1ScalarWords]) {
  // Set the message digest. We swap all the bytes so that ACC can interpret
  // the digest as a little-endian integer, which is a more natural fit for the
  // architecture than the big-endian form requested by the specification (FIPS
  // 186-5, section B.2.1).
  uint32_t digest_little_endian[kSecp256k1ScalarWords];
  size_t i = 0;
  for (; launder32(i) < kSecp256k1ScalarWords; i++) {
    digest_little_endian[i] =
        __builtin_bswap32(digest[kSecp256k1ScalarWords - 1 - i]);
  }
  HARDENED_CHECK_EQ(i, kSecp256k1ScalarWords);
  return acc_dmem_write(kSecp256k1ScalarWords, digest_little_endian,
                        kAccVarMsg);
}

status_t secp256k1_public_key_check_start(secp256k1_point_t *public_key,
                                          uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into signing.
  uint32_t mode = kAccSecp256k1ModeKeyCheck;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->y, kAccVarY));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t secp256k1_public_key_check_finalize(uint32_t session_token,
                                             hardened_bool_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Read the status code out of DMEM (false if the public key is invalid)
  HARDENED_TRY(acc_dmem_read(1, kAccVarOk, result));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t secp256k1_ecdsa_sign_start(
    const uint32_t digest[kSecp256k1ScalarWords],
    const secp256k1_masked_scalar_t *private_key, uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into signing.
  uint32_t mode = kAccSecp256k1ModeSign;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest));

  // Set the private key shares.
  ACC_WIPE_IF_ERROR(
      secp256k1_masked_scalar_write(private_key, kAccVarD0, kAccVarD1));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t secp256k1_ecdsa_sideload_sign_start(
    const uint32_t digest[kSecp256k1ScalarWords], uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into sideloaded signing.
  uint32_t mode = kAccSecp256k1ModeSideloadSign;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t secp256k1_ecdsa_sign_finalize(uint32_t session_token,
                                       secp256k1_ecdsa_signature_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kSecp256k1SignMinInstructionCount,
                       kSecp256k1SignMaxInstructionCount);

  // Read signature R out of ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kSecp256k1ScalarWords, kAccVarR, result->r));

  // Read signature S out of ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kSecp256k1ScalarWords, kAccVarS, result->s));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t secp256k1_ecdsa_verify_start(
    const secp256k1_ecdsa_signature_t *signature,
    const uint32_t digest[kSecp256k1ScalarWords],
    const secp256k1_point_t *public_key, uint32_t *session_token) {
  // Load the secp256k1 app and set up data pointers
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into verifying.
  uint32_t mode = kAccSecp256k1ModeVerify;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest));

  // Set the signature R.
  HARDENED_TRY(acc_dmem_write(kSecp256k1ScalarWords, signature->r, kAccVarR));

  // Set the signature S.
  HARDENED_TRY(acc_dmem_write(kSecp256k1ScalarWords, signature->s, kAccVarS));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->y, kAccVarY));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t secp256k1_ecdsa_verify_finalize(
    const secp256k1_ecdsa_signature_t *signature, uint32_t session_token,
    hardened_bool_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Read the status code out of DMEM (false if basic checks on the validity of
  // the signature and public key failed).
  uint32_t ok;
  HARDENED_TRY(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kSecp256k1VerifyMinInstructionCount,
                       kSecp256k1VerifyMaxInstructionCount);

  // Read x_r (recovered R) out of ACC dmem.
  uint32_t x_r[kSecp256k1ScalarWords];
  HARDENED_TRY(acc_dmem_read(kSecp256k1ScalarWords, kAccVarXr, x_r));

  *result = hardened_memeq(x_r, signature->r, kSecp256k1ScalarWords);

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t secp256k1_ecdh_start(const secp256k1_masked_scalar_t *private_key,
                              const secp256k1_point_t *public_key,
                              uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into shared-key generation.
  uint32_t mode = kAccSecp256k1ModeEcdh;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->y, kAccVarY));

  // Set the private key shares.
  ACC_WIPE_IF_ERROR(
      secp256k1_masked_scalar_write(private_key, kAccVarD0, kAccVarD1));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t secp256k1_ecdh_finalize(uint32_t session_token,
                                 secp256k1_ecdh_shared_key_t *shared_key) {
  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Read the code indicating if the public key is valid.
  uint32_t ok;
  ACC_WIPE_IF_ERROR(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kSecp256k1EcdhMinInstructionCount,
                       kSecp256k1EcdhMaxInstructionCount);

  // Read the shares of the key from ACC dmem (at vars x and y).
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarX, shared_key->share0));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarY, shared_key->share1));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t secp256k1_sideload_ecdh_start(const secp256k1_point_t *public_key,
                                       uint32_t *session_token) {
  // Load the secp256k1 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppSecp256k1));

  // Set mode so start() will jump into shared-key generation.
  uint32_t mode = kAccSecp256k1ModeSideloadEcdh;
  HARDENED_TRY(acc_dmem_write(kAccSecp256k1ModeWords, &mode, kAccVarMode));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kSecp256k1CoordWords, public_key->y, kAccVarY));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t secp256k1_sideload_ecdh_finalize(
    uint32_t session_token, secp256k1_ecdh_shared_key_t *shared_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check the session token matches the expected one.
  // If this check fails, either the cryptolib client's logic is broken and
  // providing an incorrect value for the token, or another cryptolib client
  // (e.g. in a multitenant OS) has erroneously been allowed to access the ACC
  // before the client which started the operation can clear the results. To
  // maintain security, both of these must be treated as unrecoverable errors.
  uint32_t stored_token = 0;
  HARDENED_TRY(acc_dmem_read(1, kAccVarSessionToken, &stored_token));
  if (launder32(stored_token) != session_token) {
    return OTCRYPTO_FATAL_ERR;
  }
  HARDENED_CHECK_EQ(stored_token, session_token);

  // Read the code indicating if the public key is valid.
  uint32_t ok;
  ACC_WIPE_IF_ERROR(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kSecp256k1SideloadEcdhMinInstructionCount,
                       kSecp256k1SideloadEcdhMaxInstructionCount);

  // Read the shares of the key from ACC dmem (at vars x and y).
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarX, shared_key->share0));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kSecp256k1CoordWords, kAccVarY, shared_key->share1));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}
