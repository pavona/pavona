// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/p384.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/ecc/p384_insn_counts.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('p', '3', 'r')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_p384);
static const acc_app_t kAccAppP384 = ACC_APP_T_INIT(run_p384);

// Declare offsets for input and output buffers.
ACC_DECLARE_SYMBOL_ADDR(run_p384, mode);   // Mode of operation.
ACC_DECLARE_SYMBOL_ADDR(run_p384, msg);    // ECDSA message digest.
ACC_DECLARE_SYMBOL_ADDR(run_p384, r);      // ECDSA signature scalar R.
ACC_DECLARE_SYMBOL_ADDR(run_p384, s);      // ECDSA signature scalar S.
ACC_DECLARE_SYMBOL_ADDR(run_p384, x);      // Public key x-coordinate.
ACC_DECLARE_SYMBOL_ADDR(run_p384, y);      // Public key y-coordinate.
ACC_DECLARE_SYMBOL_ADDR(run_p384, d0_io);  // Private key scalar d (share 0).
ACC_DECLARE_SYMBOL_ADDR(run_p384, d1_io);  // Private key scalar d (share 1).
ACC_DECLARE_SYMBOL_ADDR(run_p384, x_r);    // ECDSA verification result.
ACC_DECLARE_SYMBOL_ADDR(run_p384, ok);     // Status code.
ACC_DECLARE_SYMBOL_ADDR(run_p384, session_token);  // Session token.

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_p384, mode);
static const acc_addr_t kAccVarMsg = ACC_ADDR_T_INIT(run_p384, msg);
static const acc_addr_t kAccVarR = ACC_ADDR_T_INIT(run_p384, r);
static const acc_addr_t kAccVarS = ACC_ADDR_T_INIT(run_p384, s);
static const acc_addr_t kAccVarX = ACC_ADDR_T_INIT(run_p384, x);
static const acc_addr_t kAccVarY = ACC_ADDR_T_INIT(run_p384, y);
static const acc_addr_t kAccVarD0 = ACC_ADDR_T_INIT(run_p384, d0_io);
static const acc_addr_t kAccVarD1 = ACC_ADDR_T_INIT(run_p384, d1_io);
static const acc_addr_t kAccVarXr = ACC_ADDR_T_INIT(run_p384, x_r);
static const acc_addr_t kAccVarOk = ACC_ADDR_T_INIT(run_p384, ok);
static const acc_addr_t kAccVarSessionToken =
    ACC_ADDR_T_INIT(run_p384, session_token);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_KEYGEN);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_KEY_CHECK);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_VERIFY);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_ECDH);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_SIDELOAD_KEYGEN);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_SIDELOAD_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_p384, MODE_SIDELOAD_ECDH);
static const uint32_t kP384ModeKeygen = ACC_ADDR_T_INIT(run_p384, MODE_KEYGEN);
static const uint32_t kP384ModeKeyCheck =
    ACC_ADDR_T_INIT(run_p384, MODE_KEY_CHECK);
static const uint32_t kP384ModeSign = ACC_ADDR_T_INIT(run_p384, MODE_SIGN);
static const uint32_t kP384ModeVerify = ACC_ADDR_T_INIT(run_p384, MODE_VERIFY);
static const uint32_t kP384ModeEcdh = ACC_ADDR_T_INIT(run_p384, MODE_ECDH);
static const uint32_t kP384ModeSideloadKeygen =
    ACC_ADDR_T_INIT(run_p384, MODE_SIDELOAD_KEYGEN);
static const uint32_t kP384ModeSideloadSign =
    ACC_ADDR_T_INIT(run_p384, MODE_SIDELOAD_SIGN);
static const uint32_t kP384ModeSideloadEcdh =
    ACC_ADDR_T_INIT(run_p384, MODE_SIDELOAD_ECDH);

enum {
  /*
   * Mode is represented by a single word.
   */
  kP384ModeWords = 1,
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
       (kP384MaskedScalarShareWords % kAccWideWordNumWords)) %
      kAccWideWordNumWords,
  /**
   * Number of extra padding words needed for unmasked scalars.
   */
  kScalarPaddingWords =
      (kAccWideWordNumWords - (kP384ScalarWords % kAccWideWordNumWords)) %
      kAccWideWordNumWords,
  /**
   * Number of extra padding words needed for unmasked coordinates.
   */
  kCoordPaddingWords =
      (kAccWideWordNumWords - (kP384CoordWords % kAccWideWordNumWords)) %
      kAccWideWordNumWords,
};

OT_WARN_UNUSED_RESULT
static status_t p384_masked_scalar_write(const p384_masked_scalar_t *src,
                                         const acc_addr_t share0_addr,
                                         const acc_addr_t share1_addr) {
  HARDENED_TRY(
      acc_dmem_write(kP384MaskedScalarShareWords, src->share0, share0_addr));
  HARDENED_TRY(
      acc_dmem_write(kP384MaskedScalarShareWords, src->share1, share1_addr));

  // Write trailing 0s so that ACC's 384-bit read of the second share does not
  // cause an error.
  HARDENED_TRY(acc_dmem_set(kMaskedScalarPaddingWords, 0,
                            share0_addr + kP384MaskedScalarShareBytes));
  return acc_dmem_set(kMaskedScalarPaddingWords, 0,
                      share1_addr + kP384MaskedScalarShareBytes);
}

/**
 * Write a scalar-sized value into DMEM, with padding as needed.
 *
 * @param src Source value.
 * @param addr DMEM address to write.
 */
OT_WARN_UNUSED_RESULT
static status_t p384_scalar_write(const uint32_t src[kP384ScalarWords],
                                  const acc_addr_t addr) {
  HARDENED_TRY(acc_dmem_write(kP384ScalarWords, src, addr));

  return acc_dmem_set(kScalarPaddingWords, 0, addr + kP384ScalarBytes);
}

/**
 * Write a point into the x and y buffers, with padding as needed.
 *
 * @param p Point to write.
 */
OT_WARN_UNUSED_RESULT
static status_t set_public_key(const p384_point_t *p) {
  HARDENED_TRY(acc_dmem_write(kP384CoordWords, p->x, kAccVarX));
  HARDENED_TRY(acc_dmem_write(kP384CoordWords, p->y, kAccVarY));

  HARDENED_TRY(acc_dmem_set(kCoordPaddingWords, 0, kAccVarX + kP384CoordBytes));
  return acc_dmem_set(kCoordPaddingWords, 0, kAccVarY + kP384CoordBytes);
}

OT_WARN_UNUSED_RESULT
static status_t set_message_digest(const uint32_t digest[kP384ScalarWords],
                                   const acc_addr_t dst) {
  // Set the message digest. We swap all the bytes so that ACC can interpret
  // the digest as a little-endian integer, which is a more natural fit for the
  // architecture than the big-endian form requested by the specification (FIPS
  // 186-5, section B.2.1).
  uint32_t digest_little_endian[kP384ScalarWords];
  size_t i = 0;
  for (; launder32(i) < kP384ScalarWords; i++) {
    digest_little_endian[i] =
        __builtin_bswap32(digest[kP384ScalarWords - 1 - i]);
  }
  HARDENED_CHECK_EQ(i, kP384ScalarWords);
  return p384_scalar_write(digest_little_endian, dst);
}

status_t p384_keygen_start(uint32_t *session_token) {
  // Load the ECDH/P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into keygen.
  uint32_t mode = kP384ModeKeygen;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t p384_keygen_finalize(uint32_t session_token,
                              p384_masked_scalar_t *private_key,
                              p384_point_t *public_key) {
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
  ACC_CHECK_INSN_COUNT(kP384KeygenMinInstructionCount,
                       kP384KeygenMaxInstructionCount);

  // Read the masked private key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384MaskedScalarShareWords, kAccVarD0,
                                  private_key->share0));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384MaskedScalarShareWords, kAccVarD1,
                                  private_key->share1));

  // Read the public key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384CoordWords, kAccVarX, public_key->x));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384CoordWords, kAccVarY, public_key->y));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p384_sideload_keygen_start(uint32_t *session_token) {
  // Load the ECDH/P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into keygen.
  uint32_t mode = kP384ModeSideloadKeygen;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t p384_sideload_keygen_finalize(uint32_t session_token,
                                       p384_point_t *public_key) {
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
  ACC_CHECK_INSN_COUNT(kP384SideloadKeygenMinInstructionCount,
                       kP384SideloadKeygenMaxInstructionCount);

  // Read the public key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384CoordWords, kAccVarX, public_key->x));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384CoordWords, kAccVarY, public_key->y));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p384_public_key_check_start(p384_point_t *public_key,
                                     uint32_t *session_token) {
  // Load the P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into signing.
  uint32_t mode = kP384ModeKeyCheck;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Set the public key.
  HARDENED_TRY(set_public_key(public_key));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t p384_public_key_check_finalize(uint32_t session_token,
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

status_t p384_ecdsa_sign_start(const uint32_t digest[kP384ScalarWords],
                               const p384_masked_scalar_t *private_key,
                               uint32_t *session_token) {
  // Load the ECDSA/P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into sideloaded signing.
  uint32_t mode = kP384ModeSign;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest, kAccVarMsg));

  // Set the private key shares.
  ACC_WIPE_IF_ERROR(
      p384_masked_scalar_write(private_key, kAccVarD0, kAccVarD1));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t p384_ecdsa_sideload_sign_start(const uint32_t digest[kP384ScalarWords],
                                        uint32_t *session_token) {
  // Load the ECDSA/P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into sideloaded signing.
  uint32_t mode = kP384ModeSideloadSign;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest, kAccVarMsg));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t p384_ecdsa_sign_finalize(uint32_t session_token,
                                  p384_ecdsa_signature_t *result) {
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
  ACC_CHECK_INSN_COUNT(kP384SignMinInstructionCount,
                       kP384SignMaxInstructionCount);

  // Read signature R out of ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384ScalarWords, kAccVarR, result->r));

  // Read signature S out of ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP384ScalarWords, kAccVarS, result->s));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p384_ecdsa_verify_start(const p384_ecdsa_signature_t *signature,
                                 const uint32_t digest[kP384ScalarWords],
                                 const p384_point_t *public_key,
                                 uint32_t *session_token) {
  // Load the ECDSA/P-384 app
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into ECDSA verify.
  uint32_t mode = kP384ModeVerify;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest, kAccVarMsg));

  // Set the signature R.
  HARDENED_TRY(p384_scalar_write(signature->r, kAccVarR));

  // Set the signature S.
  HARDENED_TRY(p384_scalar_write(signature->s, kAccVarS));

  // Set the public key.
  HARDENED_TRY(set_public_key(public_key));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t p384_ecdsa_verify_finalize(const p384_ecdsa_signature_t *signature,
                                    uint32_t session_token,
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
  ACC_CHECK_INSN_COUNT(kP384VerifyMinInstructionCount,
                       kP384VerifyMaxInstructionCount);

  // Read x_r (recovered R) out of ACC dmem.
  uint32_t x_r[kP384ScalarWords];
  HARDENED_TRY(acc_dmem_read(kP384ScalarWords, kAccVarXr, x_r));

  *result = hardened_memeq(x_r, signature->r, kP384ScalarWords);

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p384_ecdh_start(const p384_masked_scalar_t *private_key,
                         const p384_point_t *public_key,
                         uint32_t *session_token) {
  // Load the ECDH/P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into shared-key generation.
  uint32_t mode = kP384ModeEcdh;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Set the public key.
  HARDENED_TRY(set_public_key(public_key));

  // Set the private key shares.
  ACC_WIPE_IF_ERROR(
      p384_masked_scalar_write(private_key, kAccVarD0, kAccVarD1));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t p384_ecdh_finalize(uint32_t session_token,
                            p384_ecdh_shared_key_t *shared_key) {
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
  ACC_WIPE_IF_ERROR(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP384EcdhMinInstructionCount,
                       kP384EcdhMaxInstructionCount);

  // Read the shares of the key from ACC dmem (at vars x and y).
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP384CoordWords, kAccVarX, shared_key->share0));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP384CoordWords, kAccVarY, shared_key->share1));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p384_sideload_ecdh_start(const p384_point_t *public_key,
                                  uint32_t *session_token) {
  // Load the ECDH/P-384 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP384));

  // Set mode so start() will jump into shared-key generation.
  uint32_t mode = kP384ModeSideloadEcdh;
  HARDENED_TRY(acc_dmem_write(kP384ModeWords, &mode, kAccVarMode));

  // Set the public key.
  HARDENED_TRY(set_public_key(public_key));

  // Generate a fresh session token, and store it in DMEM.
  uint32_t token = ibex_rnd32_read();
  HARDENED_TRY(acc_dmem_write(1, &token, kAccVarSessionToken));
  *session_token = token;

  // Start the ACC routine.
  return acc_execute();
}

status_t p384_sideload_ecdh_finalize(uint32_t session_token,
                                     p384_ecdh_shared_key_t *shared_key) {
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
  ACC_WIPE_IF_ERROR(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP384SideloadEcdhMinInstructionCount,
                       kP384SideloadEcdhMaxInstructionCount);

  // Read the shares of the key from ACC dmem (at vars x and y).
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP384CoordWords, kAccVarX, shared_key->share0));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP384CoordWords, kAccVarY, shared_key->share1));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}
