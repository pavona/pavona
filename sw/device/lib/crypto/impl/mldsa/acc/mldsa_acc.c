// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_acc.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/kmac.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/mldsa/acc/mldsa_insn_counts.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'd', 'a')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_mldsa);
static const acc_app_t kAccAppMldsa = ACC_APP_T_INIT(run_mldsa);

// Declare offsets for input and output buffers.
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

// Declare mode constants.
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

enum {
  kAccMldsaModeWords = 1,
  kAccMldsaLenWords = 1,
  kAccMldsaResultWords = 1,
  kMldsaMuBytes = 64,
  kMldsaTrBytes = 64,
  kMldsaSkTrOffset = 64,
};

// Write `num_bytes` from `src` to DMEM at `dest` and zero the rest of the
// final 32-byte word; ACC reads these inputs as full 256-bit words.
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

// mu = SHAKE256(tr || 0 || ctxlen || ctx || msg, 64), computed in software.
OT_WARN_UNUSED_RESULT
static status_t mldsa_compute_mu(
    const uint32_t *tr, const uint8_t *ctx, size_t ctx_bytes,
    const uint8_t *msg, size_t msg_bytes,
    uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)]) {
  uint8_t prefix[2] = {0, (uint8_t)ctx_bytes};
  HARDENED_TRY(kmac_shake256_begin());
  HARDENED_TRY(kmac_absorb((const uint8_t *)tr, kMldsaTrBytes));
  HARDENED_TRY(kmac_absorb(prefix, sizeof(prefix)));
  if (ctx_bytes > 0) {
    HARDENED_TRY(kmac_absorb(ctx, ctx_bytes));
  }
  if (msg_bytes > 0) {
    HARDENED_TRY(kmac_absorb(msg, msg_bytes));
  }
  kmac_process();
  return kmac_squeeze_end(kMldsaMuBytes / sizeof(uint32_t), kHardenedBoolFalse,
                          mu, NULL);
}

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
                                ctx_bytes, msg, msg_bytes, mu));

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
static status_t mldsa_verify(uint32_t mode, uint32_t min_insn_count,
                             uint32_t max_insn_count, const uint32_t *pk,
                             size_t pk_bytes, const uint8_t *msg,
                             size_t msg_bytes, const uint8_t *ctx,
                             size_t ctx_bytes, const uint32_t *sig,
                             size_t sig_bytes,
                             hardened_bool_t *verification_result) {
  if (ctx_bytes > kMldsaMaxContextBytes) {
    return OTCRYPTO_BAD_ARGS;
  }
  *verification_result = kHardenedBoolFalse;

  // External mu: tr = SHAKE256(pk), then mu, both in SW; ACC gets only mu.
  uint32_t tr[kMldsaTrBytes / sizeof(uint32_t)];
  HARDENED_TRY(kmac_shake256_begin());
  HARDENED_TRY(kmac_absorb((const uint8_t *)pk, pk_bytes));
  kmac_process();
  HARDENED_TRY(kmac_squeeze_end(kMldsaTrBytes / sizeof(uint32_t),
                                kHardenedBoolFalse, tr, NULL));
  uint32_t mu[kMldsaMuBytes / sizeof(uint32_t)];
  HARDENED_TRY(mldsa_compute_mu(tr, ctx, ctx_bytes, msg, msg_bytes, mu));

  HARDENED_TRY(acc_load_app(kAccAppMldsa));
  HARDENED_TRY(acc_dmem_write(kAccMldsaModeWords, &mode, kAccVarMode));
  HARDENED_TRY(
      acc_dmem_write(ceil_div(pk_bytes, sizeof(uint32_t)), pk, kAccVarPk));
  HARDENED_TRY(mldsa_dmem_write_padded(sig_bytes, sig, kAccVarSig));
  HARDENED_TRY(acc_dmem_write(kMldsaMuBytes / sizeof(uint32_t), mu, kAccVarMu));
  HARDENED_TRY(acc_execute());
  HARDENED_TRY(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);

  uint32_t result = kHardenedBoolFalse;
  ACC_WIPE_IF_ERROR(
      acc_dmem_read(kAccMldsaResultWords, kAccVarResult, &result));
  HARDENED_TRY(acc_dmem_sec_wipe());
  if (launder32(result) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(result, kHardenedBoolTrue);
    *verification_result = kHardenedBoolTrue;
  }
  return OTCRYPTO_OK;
}

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
