// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/ecc/p256.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/impl/ecc/p256_insn_counts.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('p', '2', 'r')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_p256);  // The ACC P-256 app.
static const acc_app_t kAccAppP256 = ACC_APP_T_INIT(run_p256);

// Declare offsets for input and output buffers.
ACC_DECLARE_SYMBOL_ADDR(run_p256, mode);   // Mode of operation.
ACC_DECLARE_SYMBOL_ADDR(run_p256, msg);    // ECDSA message digest.
ACC_DECLARE_SYMBOL_ADDR(run_p256, r);      // ECDSA signature scalar R.
ACC_DECLARE_SYMBOL_ADDR(run_p256, s);      // ECDSA signature scalar S.
ACC_DECLARE_SYMBOL_ADDR(run_p256, x);      // Public key x-coordinate.
ACC_DECLARE_SYMBOL_ADDR(run_p256, y);      // Public key y-coordinate.
ACC_DECLARE_SYMBOL_ADDR(run_p256, d0_io);  // Private key scalar d (share 0).
ACC_DECLARE_SYMBOL_ADDR(run_p256, d1_io);  // Private key scalar d (share 1).
ACC_DECLARE_SYMBOL_ADDR(run_p256, x_r);    // ECDSA verification result.
ACC_DECLARE_SYMBOL_ADDR(run_p256, ok);     // Status code.

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_p256, mode);
static const acc_addr_t kAccVarMsg = ACC_ADDR_T_INIT(run_p256, msg);
static const acc_addr_t kAccVarR = ACC_ADDR_T_INIT(run_p256, r);
static const acc_addr_t kAccVarS = ACC_ADDR_T_INIT(run_p256, s);
static const acc_addr_t kAccVarX = ACC_ADDR_T_INIT(run_p256, x);
static const acc_addr_t kAccVarY = ACC_ADDR_T_INIT(run_p256, y);
static const acc_addr_t kAccVarD0 = ACC_ADDR_T_INIT(run_p256, d0_io);
static const acc_addr_t kAccVarD1 = ACC_ADDR_T_INIT(run_p256, d1_io);
static const acc_addr_t kAccVarXr = ACC_ADDR_T_INIT(run_p256, x_r);
static const acc_addr_t kAccVarOk = ACC_ADDR_T_INIT(run_p256, ok);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_KEYGEN);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_KEY_CHECK);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_VERIFY);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_ECDH);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_SIDELOAD_KEYGEN);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_SIDELOAD_SIGN);
ACC_DECLARE_SYMBOL_ADDR(run_p256, MODE_SIDELOAD_ECDH);
static const uint32_t kAccP256ModeKeygen =
    ACC_ADDR_T_INIT(run_p256, MODE_KEYGEN);
static const uint32_t kAccP256ModeKeyCheck =
    ACC_ADDR_T_INIT(run_p256, MODE_KEY_CHECK);
static const uint32_t kAccP256ModeSign = ACC_ADDR_T_INIT(run_p256, MODE_SIGN);
static const uint32_t kAccP256ModeVerify =
    ACC_ADDR_T_INIT(run_p256, MODE_VERIFY);
static const uint32_t kAccP256ModeEcdh = ACC_ADDR_T_INIT(run_p256, MODE_ECDH);
static const uint32_t kAccP256ModeSideloadKeygen =
    ACC_ADDR_T_INIT(run_p256, MODE_SIDELOAD_KEYGEN);
static const uint32_t kAccP256ModeSideloadSign =
    ACC_ADDR_T_INIT(run_p256, MODE_SIDELOAD_SIGN);
static const uint32_t kAccP256ModeSideloadEcdh =
    ACC_ADDR_T_INIT(run_p256, MODE_SIDELOAD_ECDH);

enum {
  /*
   * Mode is represented by a single word.
   */
  kAccP256ModeWords = 1,
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
       (kP256MaskedScalarShareWords % kAccWideWordNumWords)) %
      kAccWideWordNumWords,
};

OT_WARN_UNUSED_RESULT
static status_t p256_masked_scalar_write(const p256_masked_scalar_t *src,
                                         const acc_addr_t share0_addr,
                                         const acc_addr_t share1_addr) {
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kP256MaskedScalarShareWords, src->share0, share0_addr));
  ACC_WIPE_IF_ERROR(
      acc_dmem_write(kP256MaskedScalarShareWords, src->share1, share1_addr));

  // Write trailing 0s so that ACC's 256-bit read of the second share does not
  // cause an error.
  ACC_WIPE_IF_ERROR(acc_dmem_set(kMaskedScalarPaddingWords, 0,
                                 share0_addr + kP256MaskedScalarShareBytes));
  return acc_dmem_set(kMaskedScalarPaddingWords, 0,
                      share1_addr + kP256MaskedScalarShareBytes);
}

status_t p256_keygen_start(void) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into keygen.
  uint32_t mode = kAccP256ModeKeygen;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Start the ACC routine.
  return acc_execute();
}

status_t p256_sideload_keygen_start(void) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into sideload-keygen.
  uint32_t mode = kAccP256ModeSideloadKeygen;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Start the ACC routine.
  return acc_execute();
}

status_t p256_keygen_finalize(p256_masked_scalar_t *private_key,
                              p256_point_t *public_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP256KeygenMinInstructionCount,
                       kP256KeygenMaxInstructionCount);

  // Read the masked private key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256MaskedScalarShareWords, kAccVarD0,
                                  private_key->share0));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256MaskedScalarShareWords, kAccVarD1,
                                  private_key->share1));

  // Read the public key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256CoordWords, kAccVarX, public_key->x));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256CoordWords, kAccVarY, public_key->y));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p256_sideload_keygen_finalize(p256_point_t *public_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP256SideloadKeygenMinInstructionCount,
                       kP256SideloadKeygenMaxInstructionCount);

  // Read the public key from ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256CoordWords, kAccVarX, public_key->x));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256CoordWords, kAccVarY, public_key->y));

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
static status_t set_message_digest(const uint32_t digest[kP256ScalarWords]) {
  // Set the message digest. We swap all the bytes so that ACC can interpret
  // the digest as a little-endian integer, which is a more natural fit for the
  // architecture than the big-endian form requested by the specification (FIPS
  // 186-5, section B.2.1).
  uint32_t digest_little_endian[kP256ScalarWords];
  size_t i = 0;
  for (; launder32(i) < kP256ScalarWords; i++) {
    digest_little_endian[i] =
        __builtin_bswap32(digest[kP256ScalarWords - 1 - i]);
  }
  HARDENED_CHECK_EQ(i, kP256ScalarWords);
  return acc_dmem_write(kP256ScalarWords, digest_little_endian, kAccVarMsg);
}

status_t p256_public_key_check_start(p256_point_t *public_key) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into signing.
  uint32_t mode = kAccP256ModeKeyCheck;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->y, kAccVarY));

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t p256_public_key_check_finalize(hardened_bool_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Read the status code out of DMEM (false if the public key is invalid)
  HARDENED_TRY(acc_dmem_read(1, kAccVarOk, result));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p256_ecdsa_sign_start(const uint32_t digest[kP256ScalarWords],
                               const p256_masked_scalar_t *private_key) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into signing.
  uint32_t mode = kAccP256ModeSign;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest));

  // Set the private key shares.
  ACC_WIPE_IF_ERROR(
      p256_masked_scalar_write(private_key, kAccVarD0, kAccVarD1));

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t p256_ecdsa_sideload_sign_start(
    const uint32_t digest[kP256ScalarWords]) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into sideloaded signing.
  uint32_t mode = kAccP256ModeSideloadSign;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest));

  // Start the ACC routine.
  return acc_execute();
}

status_t p256_ecdsa_sign_finalize(p256_ecdsa_signature_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP256SignMinInstructionCount,
                       kP256SignMaxInstructionCount);

  // Read signature R out of ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256ScalarWords, kAccVarR, result->r));

  // Read signature S out of ACC dmem.
  ACC_WIPE_IF_ERROR(acc_dmem_read(kP256ScalarWords, kAccVarS, result->s));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p256_ecdsa_verify_start(const p256_ecdsa_signature_t *signature,
                                 const uint32_t digest[kP256ScalarWords],
                                 const p256_point_t *public_key) {
  // Load the P-256 app and set up data pointers
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into verifying.
  uint32_t mode = kAccP256ModeVerify;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Set the message digest.
  HARDENED_TRY(set_message_digest(digest));

  // Set the signature R.
  HARDENED_TRY(acc_dmem_write(kP256ScalarWords, signature->r, kAccVarR));

  // Set the signature S.
  HARDENED_TRY(acc_dmem_write(kP256ScalarWords, signature->s, kAccVarS));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->y, kAccVarY));

  // Start the ACC routine.
  return acc_execute();
}

status_t p256_ecdsa_verify_finalize(const p256_ecdsa_signature_t *signature,
                                    hardened_bool_t *result) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Read the status code out of DMEM (false if basic checks on the validity of
  // the signature and public key failed).
  uint32_t ok;
  HARDENED_TRY(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP256VerifyMinInstructionCount,
                       kP256VerifyMaxInstructionCount);

  // Read x_r (recovered R) out of ACC dmem.
  uint32_t x_r[kP256ScalarWords];
  HARDENED_TRY(acc_dmem_read(kP256ScalarWords, kAccVarXr, x_r));

  *result = hardened_memeq(x_r, signature->r, kP256ScalarWords);

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p256_ecdh_start(const p256_masked_scalar_t *private_key,
                         const p256_point_t *public_key) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into shared-key generation.
  uint32_t mode = kAccP256ModeEcdh;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->y, kAccVarY));

  // Set the private key shares.
  ACC_WIPE_IF_ERROR(
      p256_masked_scalar_write(private_key, kAccVarD0, kAccVarD1));

  // Start the ACC routine.
  ACC_WIPE_IF_ERROR(acc_execute());
  return OTCRYPTO_OK;
}

status_t p256_ecdh_finalize(p256_ecdh_shared_key_t *shared_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Read the code indicating if the public key is valid.
  uint32_t ok;
  ACC_WIPE_IF_ERROR(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP256EcdhMinInstructionCount,
                       kP256EcdhMaxInstructionCount);

  // Read the shares of the key from ACC dmem (at vars x and y).
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP256CoordWords, kAccVarX, shared_key->share0));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP256CoordWords, kAccVarY, shared_key->share1));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}

status_t p256_sideload_ecdh_start(const p256_point_t *public_key) {
  // Load the P-256 app. Fails if ACC is non-idle.
  HARDENED_TRY(acc_load_app(kAccAppP256));

  // Set mode so start() will jump into shared-key generation.
  uint32_t mode = kAccP256ModeSideloadEcdh;
  HARDENED_TRY(acc_dmem_write(kAccP256ModeWords, &mode, kAccVarMode));

  // Set the public key x coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->x, kAccVarX));

  // Set the public key y coordinate.
  HARDENED_TRY(acc_dmem_write(kP256CoordWords, public_key->y, kAccVarY));

  // Start the ACC routine.
  return acc_execute();
}

status_t p256_sideload_ecdh_finalize(p256_ecdh_shared_key_t *shared_key) {
  // Return `OTCRYTPO_ASYNC_INCOMPLETE` if ACC not done.
  HARDENED_TRY(acc_assert_idle());

  // Read the code indicating if the public key is valid.
  uint32_t ok;
  ACC_WIPE_IF_ERROR(acc_dmem_read(1, kAccVarOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // Check instruction count.
  ACC_CHECK_INSN_COUNT(kP256SideloadEcdhMinInstructionCount,
                       kP256SideloadEcdhMaxInstructionCount);

  // Read the shares of the key from ACC dmem (at vars x and y).
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP256CoordWords, kAccVarX, shared_key->share0));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kP256CoordWords, kAccVarY, shared_key->share1));

  // Wipe DMEM.
  return acc_dmem_sec_wipe();
}
