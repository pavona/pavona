// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_acc.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/kmac.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#ifdef ACC_MLDSA_HARDENED
#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_insn_counts_hardened.h"
#else
#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_insn_counts.h"
#endif

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'd', 'a')

// Declare the ACC app.
#ifdef ACC_MLDSA_HARDENED
ACC_DECLARE_APP_SYMBOLS(run_mldsa_hardened);
static const acc_app_t kAccAppMldsa = ACC_APP_T_INIT(run_mldsa_hardened);
#else
ACC_DECLARE_APP_SYMBOLS(run_mldsa);
static const acc_app_t kAccAppMldsa = ACC_APP_T_INIT(run_mldsa);
#endif

// Declare offsets for input and output buffers.
#ifdef ACC_MLDSA_HARDENED
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, mode);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, zeta_shares);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, pk);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, sk);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, sig);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, mu);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, rnd);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, result);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, s1s2_shares);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, K_shares);

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_mldsa_hardened, mode);
static const acc_addr_t kAccVarZetaShares =
    ACC_ADDR_T_INIT(run_mldsa_hardened, zeta_shares);
static const acc_addr_t kAccVarPk = ACC_ADDR_T_INIT(run_mldsa_hardened, pk);
static const acc_addr_t kAccVarSk = ACC_ADDR_T_INIT(run_mldsa_hardened, sk);
static const acc_addr_t kAccVarSig = ACC_ADDR_T_INIT(run_mldsa_hardened, sig);
static const acc_addr_t kAccVarRnd = ACC_ADDR_T_INIT(run_mldsa_hardened, rnd);
static const acc_addr_t kAccVarResult =
    ACC_ADDR_T_INIT(run_mldsa_hardened, result);
static const acc_addr_t kAccVarMu = ACC_ADDR_T_INIT(run_mldsa_hardened, mu);
static const acc_addr_t kAccVarS1s2Shares =
    ACC_ADDR_T_INIT(run_mldsa_hardened, s1s2_shares);
static const acc_addr_t kAccVarKShares =
    ACC_ADDR_T_INIT(run_mldsa_hardened, K_shares);
#else
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, mode);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, zeta);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, pk);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, sk);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, sig);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, mu);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, rnd);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, result);

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_mldsa, mode);
static const acc_addr_t kAccVarZeta = ACC_ADDR_T_INIT(run_mldsa, zeta);
static const acc_addr_t kAccVarPk = ACC_ADDR_T_INIT(run_mldsa, pk);
static const acc_addr_t kAccVarSk = ACC_ADDR_T_INIT(run_mldsa, sk);
static const acc_addr_t kAccVarSig = ACC_ADDR_T_INIT(run_mldsa, sig);
static const acc_addr_t kAccVarRnd = ACC_ADDR_T_INIT(run_mldsa, rnd);
static const acc_addr_t kAccVarResult = ACC_ADDR_T_INIT(run_mldsa, result);
static const acc_addr_t kAccVarMu = ACC_ADDR_T_INIT(run_mldsa, mu);
#endif

// Declare mode constants.
#ifdef ACC_MLDSA_HARDENED
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_KEYGEN_44);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_KEYGEN_65);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_KEYGEN_87);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_SIGN_44);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_SIGN_65);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_SIGN_87);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_VERIFY_44);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_VERIFY_65);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa_hardened, MODE_VERIFY_87);

static const uint32_t kAccMldsaModeKeygen44 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_KEYGEN_44);
static const uint32_t kAccMldsaModeKeygen65 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_KEYGEN_65);
static const uint32_t kAccMldsaModeKeygen87 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_KEYGEN_87);
static const uint32_t kAccMldsaModeSign44 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_SIGN_44);
static const uint32_t kAccMldsaModeSign65 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_SIGN_65);
static const uint32_t kAccMldsaModeSign87 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_SIGN_87);
static const uint32_t kAccMldsaModeVerify44 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_VERIFY_44);
static const uint32_t kAccMldsaModeVerify65 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_VERIFY_65);
static const uint32_t kAccMldsaModeVerify87 =
    ACC_ADDR_T_INIT(run_mldsa_hardened, MODE_VERIFY_87);
#else
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_KEYGEN_44);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_KEYGEN_65);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_KEYGEN_87);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_SIGN_44);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_SIGN_65);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_SIGN_87);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_VERIFY_44);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_VERIFY_65);
ACC_DECLARE_SYMBOL_ADDR(run_mldsa, MODE_VERIFY_87);

static const uint32_t kAccMldsaModeKeygen44 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_KEYGEN_44);
static const uint32_t kAccMldsaModeKeygen65 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_KEYGEN_65);
static const uint32_t kAccMldsaModeKeygen87 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_KEYGEN_87);
static const uint32_t kAccMldsaModeSign44 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_SIGN_44);
static const uint32_t kAccMldsaModeSign65 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_SIGN_65);
static const uint32_t kAccMldsaModeSign87 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_SIGN_87);
static const uint32_t kAccMldsaModeVerify44 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_VERIFY_44);
static const uint32_t kAccMldsaModeVerify65 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_VERIFY_65);
static const uint32_t kAccMldsaModeVerify87 =
    ACC_ADDR_T_INIT(run_mldsa, MODE_VERIFY_87);
#endif

enum {
  kAccMldsaModeWords = 1,
  kAccMldsaLenWords = 1,
  kAccMldsaResultWords = 1,
  // kMldsaMuBytes is declared in mldsa_acc.h (needed there for the public
  // mu-based function signatures).
  kMldsaTrBytes = 64,
  kMldsaSkTrOffset = 64,
  // Packed bytes of one t0 polynomial (13 bits * 256 / 8).
  kMldsaPolyT0PackedBytes = 416,
  // Length of a FIPS 204 HashML-DSA hash-algorithm OID (DER-encoded).
  kMldsaPreHashOidBytes = 11,
};

// Write `num_bytes` from `src` to DMEM at `dest`, then zero the remainder of
// the final 32-byte word. The ACC reads these inputs as full 256-bit words, so
// the bytes between `num_bytes` and the next 32-byte boundary must be
// initialized; otherwise the ACC reads uninitialized DMEM and raises an
// integrity violation.
OT_WARN_UNUSED_RESULT
static status_t mldsa_dmem_write_padded(size_t num_bytes, const uint32_t *src,
                                        acc_addr_t dest) {
  size_t num_words = ceil_div(num_bytes, sizeof(uint32_t));
  size_t padded_words = ceil_div(num_bytes, 32) * (32 / sizeof(uint32_t));
  HARDENED_TRY(acc_dmem_write(num_words, src, dest));
  if (padded_words > num_words) {
    HARDENED_TRY(acc_dmem_set(padded_words - num_words, 0,
                              dest + num_words * sizeof(uint32_t)));
  }
  return OTCRYPTO_OK;
}

// Writes the FIPS 204 HashML-DSA OID (DER-encoded, Table 1) for `hash_mode`
// into `oid`. `hash_mode` must be one of the `kOtcryptoMldsaSignModeHashMldsa*`
// values; never called for pure ML-DSA.
OT_WARN_UNUSED_RESULT
static status_t mldsa_prehash_oid(otcrypto_mldsa_sign_mode_t hash_mode,
                                  uint8_t oid[kMldsaPreHashOidBytes]) {
  static const uint8_t kOidSha2_256[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01};
  static const uint8_t kOidSha2_384[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02};
  static const uint8_t kOidSha2_512[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03};
  static const uint8_t kOidSha3_224[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x07};
  static const uint8_t kOidSha3_256[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x08};
  static const uint8_t kOidSha3_384[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x09};
  static const uint8_t kOidSha3_512[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0a};
  static const uint8_t kOidShake128[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0b};
  static const uint8_t kOidShake256[kMldsaPreHashOidBytes] = {
      0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0c};

  const uint8_t *src;
  switch (launder32(hash_mode)) {
    case kOtcryptoMldsaSignModeHashMldsaSha2_256:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha2_256);
      src = kOidSha2_256;
      break;
    case kOtcryptoMldsaSignModeHashMldsaSha2_384:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha2_384);
      src = kOidSha2_384;
      break;
    case kOtcryptoMldsaSignModeHashMldsaSha2_512:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha2_512);
      src = kOidSha2_512;
      break;
    case kOtcryptoMldsaSignModeHashMldsaSha3_224:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha3_224);
      src = kOidSha3_224;
      break;
    case kOtcryptoMldsaSignModeHashMldsaSha3_256:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha3_256);
      src = kOidSha3_256;
      break;
    case kOtcryptoMldsaSignModeHashMldsaSha3_384:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha3_384);
      src = kOidSha3_384;
      break;
    case kOtcryptoMldsaSignModeHashMldsaSha3_512:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaSha3_512);
      src = kOidSha3_512;
      break;
    case kOtcryptoMldsaSignModeHashMldsaShake128:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaShake128);
      src = kOidShake128;
      break;
    case kOtcryptoMldsaSignModeHashMldsaShake256:
      HARDENED_CHECK_EQ(hash_mode, kOtcryptoMldsaSignModeHashMldsaShake256);
      src = kOidShake256;
      break;
    default:
      return OTCRYPTO_BAD_ARGS;
  }
  memcpy(oid, src, kMldsaPreHashOidBytes);
  return OTCRYPTO_OK;
}

// mu = SHAKE256(tr || domain_sep || ctxlen || ctx || [oid ||] msg, 64),
// computed in software. `domain_sep`/`oid` are 0x00/NULL for pure ML-DSA, or
// 0x01/the hash OID for HashML-DSA (`msg` is then the pre-hashed message).
OT_WARN_UNUSED_RESULT
static status_t mldsa_compute_mu(
    const uint32_t *tr, const uint8_t *ctx, size_t ctx_bytes,
    const uint8_t *oid, const uint8_t *msg, size_t msg_bytes,
    uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)]) {
  uint8_t domain_sep = 0;
  if (oid != NULL) {
    domain_sep = 1;
  }
  uint8_t prefix[2] = {domain_sep, (uint8_t)ctx_bytes};
  HARDENED_TRY(kmac_shake256_begin());
  HARDENED_TRY(kmac_absorb((const uint8_t *)tr, kMldsaTrBytes));
  HARDENED_TRY(kmac_absorb(prefix, sizeof(prefix)));
  if (ctx_bytes > 0) {
    HARDENED_TRY(kmac_absorb(ctx, ctx_bytes));
  }
  if (oid != NULL) {
    HARDENED_TRY(kmac_absorb(oid, kMldsaPreHashOidBytes));
  }
  if (msg_bytes > 0) {
    HARDENED_TRY(kmac_absorb(msg, msg_bytes));
  }
  kmac_process();
  return kmac_squeeze_end(kMldsaMuBytes / sizeof(uint32_t), kHardenedBoolFalse,
                          mu, NULL);
}

// tr = SHAKE256(pk, 64), computed in software.
OT_WARN_UNUSED_RESULT
static status_t mldsa_compute_tr(
    const uint32_t *pk, size_t pk_bytes,
    uint32_t tr[kMldsaTrBytes / sizeof(uint32_t)]) {
  HARDENED_TRY(kmac_shake256_begin());
  HARDENED_TRY(kmac_absorb((const uint8_t *)pk, pk_bytes));
  kmac_process();
  return kmac_squeeze_end(kMldsaTrBytes / sizeof(uint32_t), kHardenedBoolFalse,
                          tr, NULL);
}

#ifndef ACC_MLDSA_HARDENED
OT_WARN_UNUSED_RESULT
static status_t mldsa_keygen(uint32_t mode, uint32_t min_insn_count,
                             uint32_t max_insn_count, const uint32_t *zeta,
                             uint32_t *pk, size_t pk_bytes, uint32_t *sk,
                             size_t sk_bytes) {
  HARDENED_TRY(acc_load_app(kAccAppMldsa));
  HARDENED_TRY(acc_dmem_write(kAccMldsaModeWords, &mode, kAccVarMode));
  HARDENED_TRY(acc_dmem_write(ceil_div(kMldsaSeedBytes, sizeof(uint32_t)), zeta,
                              kAccVarZeta));
  HARDENED_TRY(acc_execute());
  HARDENED_TRY(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(ceil_div(pk_bytes, sizeof(uint32_t)), kAccVarPk, pk));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(ceil_div(sk_bytes, sizeof(uint32_t)), kAccVarSk, sk));
  return acc_dmem_sec_wipe();
}
#endif  // !ACC_MLDSA_HARDENED

// Runs the ACC sign kernel given a precomputed mu (external-mu mode).
OT_WARN_UNUSED_RESULT
static status_t mldsa_sign_with_mu(
    uint32_t mode, uint32_t min_insn_count, uint32_t max_insn_count,
    const uint32_t *sk, size_t sk_bytes,
    const uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)], const uint32_t *rnd,
    uint32_t *sig, size_t sig_bytes) {
  HARDENED_TRY(acc_load_app(kAccAppMldsa));
  HARDENED_TRY(acc_dmem_write(kAccMldsaModeWords, &mode, kAccVarMode));
  HARDENED_TRY(
      acc_dmem_write(ceil_div(sk_bytes, sizeof(uint32_t)), sk, kAccVarSk));
  HARDENED_TRY(acc_dmem_write(kMldsaMuBytes / sizeof(uint32_t), mu, kAccVarMu));
  HARDENED_TRY(acc_dmem_write(ceil_div(kMldsaRndBytes, sizeof(uint32_t)), rnd,
                              kAccVarRnd));
  HARDENED_TRY(acc_execute());
  HARDENED_TRY(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(ceil_div(sig_bytes, sizeof(uint32_t)), kAccVarSig, sig));
  return acc_dmem_sec_wipe();
}

OT_WARN_UNUSED_RESULT
static status_t mldsa_sign(uint32_t mode, uint32_t min_insn_count,
                           uint32_t max_insn_count, const uint32_t *sk,
                           size_t sk_bytes, const uint8_t *msg,
                           size_t msg_bytes, const uint8_t *ctx,
                           size_t ctx_bytes, const uint32_t *rnd, uint32_t *sig,
                           size_t sig_bytes) {
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  // External mu: tr = sk[64:128]; hash the message in SW, pass only mu.
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(sk + kMldsaSkTrOffset / sizeof(uint32_t), ctx,
                                ctx_bytes, NULL, msg, msg_bytes, mu));
  return mldsa_sign_with_mu(mode, min_insn_count, max_insn_count, sk, sk_bytes,
                            mu, rnd, sig, sig_bytes);
}

OT_WARN_UNUSED_RESULT
static status_t mldsa_sign_pre_hash(
    uint32_t mode, uint32_t min_insn_count, uint32_t max_insn_count,
    const uint32_t *sk, size_t sk_bytes, const uint8_t *ph, size_t ph_bytes,
    const uint8_t *ctx, size_t ctx_bytes, otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t *rnd, uint32_t *sig, size_t sig_bytes) {
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  uint8_t oid[kMldsaPreHashOidBytes];
  HARDENED_TRY(mldsa_prehash_oid(hash_mode, oid));

  // External mu: tr = sk[64:128]; hash the message in SW, pass only mu.
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(sk + kMldsaSkTrOffset / sizeof(uint32_t), ctx,
                                ctx_bytes, oid, ph, ph_bytes, mu));
  return mldsa_sign_with_mu(mode, min_insn_count, max_insn_count, sk, sk_bytes,
                            mu, rnd, sig, sig_bytes);
}

// Runs the ACC verify kernel given a precomputed mu (external-mu mode).
OT_WARN_UNUSED_RESULT
static status_t mldsa_verify_with_mu(
    uint32_t mode, uint32_t min_insn_count, uint32_t max_insn_count,
    const uint32_t *pk, size_t pk_bytes,
    const uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)], const uint32_t *sig,
    size_t sig_bytes, hardened_bool_t *verification_result) {
  HARDENED_TRY(acc_load_app(kAccAppMldsa));
  HARDENED_TRY(acc_dmem_write(kAccMldsaModeWords, &mode, kAccVarMode));
  HARDENED_TRY(
      acc_dmem_write(ceil_div(pk_bytes, sizeof(uint32_t)), pk, kAccVarPk));
  HARDENED_TRY(mldsa_dmem_write_padded(sig_bytes, sig, kAccVarSig));
  HARDENED_TRY(acc_dmem_write(kMldsaMuBytes / sizeof(uint32_t), mu, kAccVarMu));
  HARDENED_TRY(acc_execute());
  HARDENED_TRY(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);

  uint32_t result = 0;
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kAccMldsaResultWords, kAccVarResult, &result));
  HARDENED_TRY(acc_dmem_sec_wipe());
  if (launder32(result) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(result, kHardenedBoolTrue);
    *verification_result = kHardenedBoolTrue;
  }
  return OTCRYPTO_OK;
}

OT_WARN_UNUSED_RESULT
static status_t mldsa_verify(uint32_t mode, uint32_t min_insn_count,
                             uint32_t max_insn_count, const uint32_t *pk,
                             size_t pk_bytes, const uint8_t *msg,
                             size_t msg_bytes, const uint8_t *ctx,
                             size_t ctx_bytes, const uint32_t *sig,
                             size_t sig_bytes,
                             hardened_bool_t *verification_result) {
  *verification_result = kHardenedBoolFalse;
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }

  // External mu: tr = SHAKE256(pk), then mu, both in SW; the ACC gets only mu.
  uint32_t tr[kMldsaTrBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_tr(pk, pk_bytes, tr));
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(tr, ctx, ctx_bytes, NULL, msg, msg_bytes, mu));
  return mldsa_verify_with_mu(mode, min_insn_count, max_insn_count, pk,
                              pk_bytes, mu, sig, sig_bytes,
                              verification_result);
}

OT_WARN_UNUSED_RESULT
static status_t mldsa_verify_pre_hash(uint32_t mode, uint32_t min_insn_count,
                                      uint32_t max_insn_count,
                                      const uint32_t *pk, size_t pk_bytes,
                                      const uint8_t *ph, size_t ph_bytes,
                                      const uint8_t *ctx, size_t ctx_bytes,
                                      otcrypto_mldsa_sign_mode_t hash_mode,
                                      const uint32_t *sig, size_t sig_bytes,
                                      hardened_bool_t *verification_result) {
  *verification_result = kHardenedBoolFalse;
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  uint8_t oid[kMldsaPreHashOidBytes];
  HARDENED_TRY(mldsa_prehash_oid(hash_mode, oid));

  // External mu: tr = SHAKE256(pk), then mu, both in SW; the ACC gets only mu.
  uint32_t tr[kMldsaTrBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_tr(pk, pk_bytes, tr));
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(tr, ctx, ctx_bytes, oid, ph, ph_bytes, mu));
  return mldsa_verify_with_mu(mode, min_insn_count, max_insn_count, pk,
                              pk_bytes, mu, sig, sig_bytes,
                              verification_result);
}

#ifndef ACC_MLDSA_HARDENED
status_t mldsa_acc_44_keygen(const uint32_t zeta[kMldsaSeedWords],
                             uint32_t pk[kMldsa44PublicKeyWords],
                             uint32_t sk[kMldsa44SecretKeyWords]) {
  return mldsa_keygen(kAccMldsaModeKeygen44, kMldsa44KeygenMinInstructionCount,
                      kMldsa44KeygenMaxInstructionCount, zeta, pk,
                      kMldsa44PublicKeyBytes, sk, kMldsa44SecretKeyBytes);
}

status_t mldsa_acc_65_keygen(const uint32_t zeta[kMldsaSeedWords],
                             uint32_t pk[kMldsa65PublicKeyWords],
                             uint32_t sk[kMldsa65SecretKeyWords]) {
  return mldsa_keygen(kAccMldsaModeKeygen65, kMldsa65KeygenMinInstructionCount,
                      kMldsa65KeygenMaxInstructionCount, zeta, pk,
                      kMldsa65PublicKeyBytes, sk, kMldsa65SecretKeyBytes);
}

status_t mldsa_acc_87_keygen(const uint32_t zeta[kMldsaSeedWords],
                             uint32_t pk[kMldsa87PublicKeyWords],
                             uint32_t sk[kMldsa87SecretKeyWords]) {
  return mldsa_keygen(kAccMldsaModeKeygen87, kMldsa87KeygenMinInstructionCount,
                      kMldsa87KeygenMaxInstructionCount, zeta, pk,
                      kMldsa87PublicKeyBytes, sk, kMldsa87SecretKeyBytes);
}
#endif  // !ACC_MLDSA_HARDENED

status_t mldsa_acc_44_sign(const uint32_t sk[kMldsa44SecretKeyWords],
                           const uint8_t *msg, size_t msg_bytes,
                           const uint8_t *ctx, size_t ctx_bytes,
                           const uint32_t rnd[kMldsaRndWords],
                           uint32_t sig[kMldsa44SignatureWords]) {
  return mldsa_sign(kAccMldsaModeSign44, kMldsa44SignMinInstructionCount,
                    kMldsa44SignMaxInstructionCount, sk, kMldsa44SecretKeyBytes,
                    msg, msg_bytes, ctx, ctx_bytes, rnd, sig,
                    kMldsa44SignatureBytes);
}

status_t mldsa_acc_65_sign(const uint32_t sk[kMldsa65SecretKeyWords],
                           const uint8_t *msg, size_t msg_bytes,
                           const uint8_t *ctx, size_t ctx_bytes,
                           const uint32_t rnd[kMldsaRndWords],
                           uint32_t sig[kMldsa65SignatureWords]) {
  return mldsa_sign(kAccMldsaModeSign65, kMldsa65SignMinInstructionCount,
                    kMldsa65SignMaxInstructionCount, sk, kMldsa65SecretKeyBytes,
                    msg, msg_bytes, ctx, ctx_bytes, rnd, sig,
                    kMldsa65SignatureBytes);
}

status_t mldsa_acc_87_sign(const uint32_t sk[kMldsa87SecretKeyWords],
                           const uint8_t *msg, size_t msg_bytes,
                           const uint8_t *ctx, size_t ctx_bytes,
                           const uint32_t rnd[kMldsaRndWords],
                           uint32_t sig[kMldsa87SignatureWords]) {
  return mldsa_sign(kAccMldsaModeSign87, kMldsa87SignMinInstructionCount,
                    kMldsa87SignMaxInstructionCount, sk, kMldsa87SecretKeyBytes,
                    msg, msg_bytes, ctx, ctx_bytes, rnd, sig,
                    kMldsa87SignatureBytes);
}

status_t mldsa_acc_44_verify(const uint32_t pk[kMldsa44PublicKeyWords],
                             const uint8_t *msg, size_t msg_bytes,
                             const uint8_t *ctx, size_t ctx_bytes,
                             const uint32_t sig[kMldsa44SignatureWords],
                             hardened_bool_t *verification_result) {
  return mldsa_verify(kAccMldsaModeVerify44, kMldsa44VerifyMinInstructionCount,
                      kMldsa44VerifyMaxInstructionCount, pk,
                      kMldsa44PublicKeyBytes, msg, msg_bytes, ctx, ctx_bytes,
                      sig, kMldsa44SignatureBytes, verification_result);
}

status_t mldsa_acc_65_verify(const uint32_t pk[kMldsa65PublicKeyWords],
                             const uint8_t *msg, size_t msg_bytes,
                             const uint8_t *ctx, size_t ctx_bytes,
                             const uint32_t sig[kMldsa65SignatureWords],
                             hardened_bool_t *verification_result) {
  return mldsa_verify(kAccMldsaModeVerify65, kMldsa65VerifyMinInstructionCount,
                      kMldsa65VerifyMaxInstructionCount, pk,
                      kMldsa65PublicKeyBytes, msg, msg_bytes, ctx, ctx_bytes,
                      sig, kMldsa65SignatureBytes, verification_result);
}

status_t mldsa_acc_87_verify(const uint32_t pk[kMldsa87PublicKeyWords],
                             const uint8_t *msg, size_t msg_bytes,
                             const uint8_t *ctx, size_t ctx_bytes,
                             const uint32_t sig[kMldsa87SignatureWords],
                             hardened_bool_t *verification_result) {
  return mldsa_verify(kAccMldsaModeVerify87, kMldsa87VerifyMinInstructionCount,
                      kMldsa87VerifyMaxInstructionCount, pk,
                      kMldsa87PublicKeyBytes, msg, msg_bytes, ctx, ctx_bytes,
                      sig, kMldsa87SignatureBytes, verification_result);
}

status_t mldsa_acc_44_sign_mu(const uint32_t sk[kMldsa44SecretKeyWords],
                              const uint32_t mu[kMldsaMuWords],
                              const uint32_t rnd[kMldsaRndWords],
                              uint32_t sig[kMldsa44SignatureWords]) {
  return mldsa_sign_with_mu(
      kAccMldsaModeSign44, kMldsa44SignMinInstructionCount,
      kMldsa44SignMaxInstructionCount, sk, kMldsa44SecretKeyBytes, mu, rnd, sig,
      kMldsa44SignatureBytes);
}

status_t mldsa_acc_65_sign_mu(const uint32_t sk[kMldsa65SecretKeyWords],
                              const uint32_t mu[kMldsaMuWords],
                              const uint32_t rnd[kMldsaRndWords],
                              uint32_t sig[kMldsa65SignatureWords]) {
  return mldsa_sign_with_mu(
      kAccMldsaModeSign65, kMldsa65SignMinInstructionCount,
      kMldsa65SignMaxInstructionCount, sk, kMldsa65SecretKeyBytes, mu, rnd, sig,
      kMldsa65SignatureBytes);
}

status_t mldsa_acc_87_sign_mu(const uint32_t sk[kMldsa87SecretKeyWords],
                              const uint32_t mu[kMldsaMuWords],
                              const uint32_t rnd[kMldsaRndWords],
                              uint32_t sig[kMldsa87SignatureWords]) {
  return mldsa_sign_with_mu(
      kAccMldsaModeSign87, kMldsa87SignMinInstructionCount,
      kMldsa87SignMaxInstructionCount, sk, kMldsa87SecretKeyBytes, mu, rnd, sig,
      kMldsa87SignatureBytes);
}

status_t mldsa_acc_44_verify_mu(const uint32_t pk[kMldsa44PublicKeyWords],
                                const uint32_t mu[kMldsaMuWords],
                                const uint32_t sig[kMldsa44SignatureWords],
                                hardened_bool_t *verification_result) {
  *verification_result = kHardenedBoolFalse;
  return mldsa_verify_with_mu(
      kAccMldsaModeVerify44, kMldsa44VerifyMinInstructionCount,
      kMldsa44VerifyMaxInstructionCount, pk, kMldsa44PublicKeyBytes, mu, sig,
      kMldsa44SignatureBytes, verification_result);
}

status_t mldsa_acc_65_verify_mu(const uint32_t pk[kMldsa65PublicKeyWords],
                                const uint32_t mu[kMldsaMuWords],
                                const uint32_t sig[kMldsa65SignatureWords],
                                hardened_bool_t *verification_result) {
  *verification_result = kHardenedBoolFalse;
  return mldsa_verify_with_mu(
      kAccMldsaModeVerify65, kMldsa65VerifyMinInstructionCount,
      kMldsa65VerifyMaxInstructionCount, pk, kMldsa65PublicKeyBytes, mu, sig,
      kMldsa65SignatureBytes, verification_result);
}

status_t mldsa_acc_87_verify_mu(const uint32_t pk[kMldsa87PublicKeyWords],
                                const uint32_t mu[kMldsaMuWords],
                                const uint32_t sig[kMldsa87SignatureWords],
                                hardened_bool_t *verification_result) {
  *verification_result = kHardenedBoolFalse;
  return mldsa_verify_with_mu(
      kAccMldsaModeVerify87, kMldsa87VerifyMinInstructionCount,
      kMldsa87VerifyMaxInstructionCount, pk, kMldsa87PublicKeyBytes, mu, sig,
      kMldsa87SignatureBytes, verification_result);
}

status_t mldsa_acc_44_sign_pre_hash(const uint32_t sk[kMldsa44SecretKeyWords],
                                    const uint8_t *ph, size_t ph_bytes,
                                    const uint8_t *ctx, size_t ctx_bytes,
                                    otcrypto_mldsa_sign_mode_t hash_mode,
                                    const uint32_t rnd[kMldsaRndWords],
                                    uint32_t sig[kMldsa44SignatureWords]) {
  return mldsa_sign_pre_hash(
      kAccMldsaModeSign44, kMldsa44SignMinInstructionCount,
      kMldsa44SignMaxInstructionCount, sk, kMldsa44SecretKeyBytes, ph, ph_bytes,
      ctx, ctx_bytes, hash_mode, rnd, sig, kMldsa44SignatureBytes);
}

status_t mldsa_acc_65_sign_pre_hash(const uint32_t sk[kMldsa65SecretKeyWords],
                                    const uint8_t *ph, size_t ph_bytes,
                                    const uint8_t *ctx, size_t ctx_bytes,
                                    otcrypto_mldsa_sign_mode_t hash_mode,
                                    const uint32_t rnd[kMldsaRndWords],
                                    uint32_t sig[kMldsa65SignatureWords]) {
  return mldsa_sign_pre_hash(
      kAccMldsaModeSign65, kMldsa65SignMinInstructionCount,
      kMldsa65SignMaxInstructionCount, sk, kMldsa65SecretKeyBytes, ph, ph_bytes,
      ctx, ctx_bytes, hash_mode, rnd, sig, kMldsa65SignatureBytes);
}

status_t mldsa_acc_87_sign_pre_hash(const uint32_t sk[kMldsa87SecretKeyWords],
                                    const uint8_t *ph, size_t ph_bytes,
                                    const uint8_t *ctx, size_t ctx_bytes,
                                    otcrypto_mldsa_sign_mode_t hash_mode,
                                    const uint32_t rnd[kMldsaRndWords],
                                    uint32_t sig[kMldsa87SignatureWords]) {
  return mldsa_sign_pre_hash(
      kAccMldsaModeSign87, kMldsa87SignMinInstructionCount,
      kMldsa87SignMaxInstructionCount, sk, kMldsa87SecretKeyBytes, ph, ph_bytes,
      ctx, ctx_bytes, hash_mode, rnd, sig, kMldsa87SignatureBytes);
}

status_t mldsa_acc_44_verify_pre_hash(
    const uint32_t pk[kMldsa44PublicKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t sig[kMldsa44SignatureWords],
    hardened_bool_t *verification_result) {
  return mldsa_verify_pre_hash(
      kAccMldsaModeVerify44, kMldsa44VerifyMinInstructionCount,
      kMldsa44VerifyMaxInstructionCount, pk, kMldsa44PublicKeyBytes, ph,
      ph_bytes, ctx, ctx_bytes, hash_mode, sig, kMldsa44SignatureBytes,
      verification_result);
}

status_t mldsa_acc_65_verify_pre_hash(
    const uint32_t pk[kMldsa65PublicKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t sig[kMldsa65SignatureWords],
    hardened_bool_t *verification_result) {
  return mldsa_verify_pre_hash(
      kAccMldsaModeVerify65, kMldsa65VerifyMinInstructionCount,
      kMldsa65VerifyMaxInstructionCount, pk, kMldsa65PublicKeyBytes, ph,
      ph_bytes, ctx, ctx_bytes, hash_mode, sig, kMldsa65SignatureBytes,
      verification_result);
}

status_t mldsa_acc_87_verify_pre_hash(
    const uint32_t pk[kMldsa87PublicKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode,
    const uint32_t sig[kMldsa87SignatureWords],
    hardened_bool_t *verification_result) {
  return mldsa_verify_pre_hash(
      kAccMldsaModeVerify87, kMldsa87VerifyMinInstructionCount,
      kMldsa87VerifyMaxInstructionCount, pk, kMldsa87PublicKeyBytes, ph,
      ph_bytes, ctx, ctx_bytes, hash_mode, sig, kMldsa87SignatureBytes,
      verification_result);
}

#ifdef ACC_MLDSA_HARDENED

// Masked secret-key keyblob = the ACC key layout verbatim (see mldsa.h): the
// three ACC DMEM regions concatenated, DMAed straight to/from the ACC.
//   sk (acc_sk)  = rho(32) || K-slot(32, zeroed) || tr(64) || t0(K*416)
//   s1s2_shares  = per eta poly [share0|share1], each polyeta bytes (L+K polys)
//   K_shares     = K_share0(32) || K_share1(32)

enum {
  kMldsaRhoBytes = 32,
  kMldsaKBytes = 32,
  // ACC `sk` header before t0: rho(32) || K-slot(32) || tr(64).
  kMldsaSkPubBytes = 128,
};

OT_WARN_UNUSED_RESULT
static status_t mldsa_keygen_hardened(uint32_t mode, uint32_t min_insn_count,
                                      uint32_t max_insn_count,
                                      const uint32_t *zeta_share0,
                                      const uint32_t *zeta_share1, uint32_t *pk,
                                      size_t pk_bytes, uint32_t *sk, size_t k,
                                      size_t num_eta_polys, size_t polyeta) {
  size_t acc_sk_words =
      (kMldsaSkPubBytes + k * kMldsaPolyT0PackedBytes) / sizeof(uint32_t);
  size_t s1s2_words = 2 * num_eta_polys * polyeta / sizeof(uint32_t);

  HARDENED_TRY(acc_load_app(kAccAppMldsa));
  HARDENED_TRY(acc_dmem_write(kAccMldsaModeWords, &mode, kAccVarMode));
  HARDENED_TRY(acc_dmem_write(kMldsaSeedWords, zeta_share0, kAccVarZetaShares));
  HARDENED_TRY(acc_dmem_write(kMldsaSeedWords, zeta_share1,
                              kAccVarZetaShares + kMldsaSeedBytes));
  HARDENED_TRY(acc_execute());
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(ceil_div(pk_bytes, sizeof(uint32_t)), kAccVarPk, pk));
  // Read the three ACC regions straight into the component-major keyblob.
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kMldsaRhoBytes / sizeof(uint32_t), kAccVarSk, sk));
  memset((uint8_t *)sk + kMldsaRhoBytes, 0, kMldsaKBytes);
  ACC_WIPE_IF_ERROR(acc_dmem_read(
      acc_sk_words - kMldsaSkTrOffset / sizeof(uint32_t),
      kAccVarSk + kMldsaSkTrOffset, sk + kMldsaSkTrOffset / sizeof(uint32_t)));
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(s1s2_words, kAccVarS1s2Shares, sk + acc_sk_words));
  ACC_WIPE_IF_ERROR(acc_dmem_read(2 * kMldsaKBytes / sizeof(uint32_t),
                                  kAccVarKShares,
                                  sk + acc_sk_words + s1s2_words));
  return acc_dmem_sec_wipe();
}

// Runs the ACC masked-sign kernel given a precomputed mu (external-mu mode).
OT_WARN_UNUSED_RESULT
static status_t mldsa_sign_hardened_with_mu(
    uint32_t mode, uint32_t min_insn_count, uint32_t max_insn_count,
    const uint32_t *sk, size_t k, size_t num_eta_polys, size_t polyeta,
    const uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)], const uint32_t *rnd,
    uint32_t *sig, size_t sig_bytes) {
  size_t acc_sk_words =
      (kMldsaSkPubBytes + k * kMldsaPolyT0PackedBytes) / sizeof(uint32_t);
  size_t s1s2_words = 2 * num_eta_polys * polyeta / sizeof(uint32_t);

  HARDENED_TRY(acc_load_app(kAccAppMldsa));
  HARDENED_TRY(acc_dmem_write(kAccMldsaModeWords, &mode, kAccVarMode));
  HARDENED_TRY(acc_dmem_write(acc_sk_words, sk, kAccVarSk));
  HARDENED_TRY(
      acc_dmem_write(s1s2_words, sk + acc_sk_words, kAccVarS1s2Shares));
  HARDENED_TRY(acc_dmem_write(2 * kMldsaKBytes / sizeof(uint32_t),
                              sk + acc_sk_words + s1s2_words, kAccVarKShares));
  HARDENED_TRY(acc_dmem_write(kMldsaMuBytes / sizeof(uint32_t), mu, kAccVarMu));
  HARDENED_TRY(acc_dmem_write(ceil_div(kMldsaRndBytes, sizeof(uint32_t)), rnd,
                              kAccVarRnd));
  HARDENED_TRY(acc_execute());
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(ceil_div(sig_bytes, sizeof(uint32_t)), kAccVarSig, sig));
  return acc_dmem_sec_wipe();
}

OT_WARN_UNUSED_RESULT
static status_t mldsa_sign_hardened(uint32_t mode, uint32_t min_insn_count,
                                    uint32_t max_insn_count, const uint32_t *sk,
                                    size_t k, size_t num_eta_polys,
                                    size_t polyeta, const uint8_t *msg,
                                    size_t msg_bytes, const uint8_t *ctx,
                                    size_t ctx_bytes, const uint32_t *rnd,
                                    uint32_t *sig, size_t sig_bytes) {
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  // tr lives at byte 64 of the masked keyblob.
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(sk + kMldsaSkTrOffset / sizeof(uint32_t), ctx,
                                ctx_bytes, NULL, msg, msg_bytes, mu));
  return mldsa_sign_hardened_with_mu(mode, min_insn_count, max_insn_count, sk,
                                     k, num_eta_polys, polyeta, mu, rnd, sig,
                                     sig_bytes);
}

OT_WARN_UNUSED_RESULT
static status_t mldsa_sign_pre_hash_hardened(
    uint32_t mode, uint32_t min_insn_count, uint32_t max_insn_count,
    const uint32_t *sk, size_t k, size_t num_eta_polys, size_t polyeta,
    const uint8_t *ph, size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t *rnd, uint32_t *sig,
    size_t sig_bytes) {
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  uint8_t oid[kMldsaPreHashOidBytes];
  HARDENED_TRY(mldsa_prehash_oid(hash_mode, oid));

  // tr lives at byte 64 of the masked keyblob.
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(sk + kMldsaSkTrOffset / sizeof(uint32_t), ctx,
                                ctx_bytes, oid, ph, ph_bytes, mu));
  return mldsa_sign_hardened_with_mu(mode, min_insn_count, max_insn_count, sk,
                                     k, num_eta_polys, polyeta, mu, rnd, sig,
                                     sig_bytes);
}

status_t mldsa_acc_44_keygen_hardened(
    const uint32_t zeta_share0[kMldsaSeedWords],
    const uint32_t zeta_share1[kMldsaSeedWords],
    uint32_t pk[kMldsa44PublicKeyWords],
    uint32_t sk[kMldsa44MaskedSecretKeyWords]) {
  return mldsa_keygen_hardened(kAccMldsaModeKeygen44,
                               kMldsa44KeygenMinInstructionCount,
                               kMldsa44KeygenMaxInstructionCount, zeta_share0,
                               zeta_share1, pk, kMldsa44PublicKeyBytes, sk, 4,
                               /*num_eta_polys=*/8, /*polyeta=*/96);
}

status_t mldsa_acc_65_keygen_hardened(
    const uint32_t zeta_share0[kMldsaSeedWords],
    const uint32_t zeta_share1[kMldsaSeedWords],
    uint32_t pk[kMldsa65PublicKeyWords],
    uint32_t sk[kMldsa65MaskedSecretKeyWords]) {
  return mldsa_keygen_hardened(kAccMldsaModeKeygen65,
                               kMldsa65KeygenMinInstructionCount,
                               kMldsa65KeygenMaxInstructionCount, zeta_share0,
                               zeta_share1, pk, kMldsa65PublicKeyBytes, sk, 6,
                               /*num_eta_polys=*/11, /*polyeta=*/128);
}

status_t mldsa_acc_87_keygen_hardened(
    const uint32_t zeta_share0[kMldsaSeedWords],
    const uint32_t zeta_share1[kMldsaSeedWords],
    uint32_t pk[kMldsa87PublicKeyWords],
    uint32_t sk[kMldsa87MaskedSecretKeyWords]) {
  return mldsa_keygen_hardened(kAccMldsaModeKeygen87,
                               kMldsa87KeygenMinInstructionCount,
                               kMldsa87KeygenMaxInstructionCount, zeta_share0,
                               zeta_share1, pk, kMldsa87PublicKeyBytes, sk, 8,
                               /*num_eta_polys=*/15, /*polyeta=*/96);
}

status_t mldsa_acc_44_sign_hardened(
    const uint32_t sk[kMldsa44MaskedSecretKeyWords], const uint8_t *msg,
    size_t msg_bytes, const uint8_t *ctx, size_t ctx_bytes,
    const uint32_t rnd[kMldsaRndWords], uint32_t sig[kMldsa44SignatureWords]) {
  return mldsa_sign_hardened(
      kAccMldsaModeSign44, kMldsa44SignMinInstructionCount,
      kMldsa44SignMaxInstructionCount, sk, 4,
      /*num_eta_polys=*/8, /*polyeta=*/96, msg, msg_bytes, ctx, ctx_bytes, rnd,
      sig, kMldsa44SignatureBytes);
}

status_t mldsa_acc_65_sign_hardened(
    const uint32_t sk[kMldsa65MaskedSecretKeyWords], const uint8_t *msg,
    size_t msg_bytes, const uint8_t *ctx, size_t ctx_bytes,
    const uint32_t rnd[kMldsaRndWords], uint32_t sig[kMldsa65SignatureWords]) {
  return mldsa_sign_hardened(
      kAccMldsaModeSign65, kMldsa65SignMinInstructionCount,
      kMldsa65SignMaxInstructionCount, sk, 6,
      /*num_eta_polys=*/11, /*polyeta=*/128, msg, msg_bytes, ctx, ctx_bytes,
      rnd, sig, kMldsa65SignatureBytes);
}

status_t mldsa_acc_87_sign_hardened(
    const uint32_t sk[kMldsa87MaskedSecretKeyWords], const uint8_t *msg,
    size_t msg_bytes, const uint8_t *ctx, size_t ctx_bytes,
    const uint32_t rnd[kMldsaRndWords], uint32_t sig[kMldsa87SignatureWords]) {
  return mldsa_sign_hardened(
      kAccMldsaModeSign87, kMldsa87SignMinInstructionCount,
      kMldsa87SignMaxInstructionCount, sk, 8,
      /*num_eta_polys=*/15, /*polyeta=*/96, msg, msg_bytes, ctx, ctx_bytes, rnd,
      sig, kMldsa87SignatureBytes);
}

status_t mldsa_acc_44_sign_mu_hardened(
    const uint32_t sk[kMldsa44MaskedSecretKeyWords],
    const uint32_t mu[kMldsaMuWords], const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa44SignatureWords]) {
  return mldsa_sign_hardened_with_mu(kAccMldsaModeSign44,
                                     kMldsa44SignMinInstructionCount,
                                     kMldsa44SignMaxInstructionCount, sk, 4,
                                     /*num_eta_polys=*/8, /*polyeta=*/96, mu,
                                     rnd, sig, kMldsa44SignatureBytes);
}

status_t mldsa_acc_65_sign_mu_hardened(
    const uint32_t sk[kMldsa65MaskedSecretKeyWords],
    const uint32_t mu[kMldsaMuWords], const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa65SignatureWords]) {
  return mldsa_sign_hardened_with_mu(kAccMldsaModeSign65,
                                     kMldsa65SignMinInstructionCount,
                                     kMldsa65SignMaxInstructionCount, sk, 6,
                                     /*num_eta_polys=*/11, /*polyeta=*/128, mu,
                                     rnd, sig, kMldsa65SignatureBytes);
}

status_t mldsa_acc_87_sign_mu_hardened(
    const uint32_t sk[kMldsa87MaskedSecretKeyWords],
    const uint32_t mu[kMldsaMuWords], const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa87SignatureWords]) {
  return mldsa_sign_hardened_with_mu(kAccMldsaModeSign87,
                                     kMldsa87SignMinInstructionCount,
                                     kMldsa87SignMaxInstructionCount, sk, 8,
                                     /*num_eta_polys=*/15, /*polyeta=*/96, mu,
                                     rnd, sig, kMldsa87SignatureBytes);
}

status_t mldsa_acc_44_sign_pre_hash_hardened(
    const uint32_t sk[kMldsa44MaskedSecretKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa44SignatureWords]) {
  return mldsa_sign_pre_hash_hardened(
      kAccMldsaModeSign44, kMldsa44SignMinInstructionCount,
      kMldsa44SignMaxInstructionCount, sk, 4,
      /*num_eta_polys=*/8, /*polyeta=*/96, ph, ph_bytes, ctx, ctx_bytes,
      hash_mode, rnd, sig, kMldsa44SignatureBytes);
}

status_t mldsa_acc_65_sign_pre_hash_hardened(
    const uint32_t sk[kMldsa65MaskedSecretKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa65SignatureWords]) {
  return mldsa_sign_pre_hash_hardened(
      kAccMldsaModeSign65, kMldsa65SignMinInstructionCount,
      kMldsa65SignMaxInstructionCount, sk, 6,
      /*num_eta_polys=*/11, /*polyeta=*/128, ph, ph_bytes, ctx, ctx_bytes,
      hash_mode, rnd, sig, kMldsa65SignatureBytes);
}

status_t mldsa_acc_87_sign_pre_hash_hardened(
    const uint32_t sk[kMldsa87MaskedSecretKeyWords], const uint8_t *ph,
    size_t ph_bytes, const uint8_t *ctx, size_t ctx_bytes,
    otcrypto_mldsa_sign_mode_t hash_mode, const uint32_t rnd[kMldsaRndWords],
    uint32_t sig[kMldsa87SignatureWords]) {
  return mldsa_sign_pre_hash_hardened(
      kAccMldsaModeSign87, kMldsa87SignMinInstructionCount,
      kMldsa87SignMaxInstructionCount, sk, 8,
      /*num_eta_polys=*/15, /*polyeta=*/96, ph, ph_bytes, ctx, ctx_bytes,
      hash_mode, rnd, sig, kMldsa87SignatureBytes);
}

#endif  // ACC_MLDSA_HARDENED
