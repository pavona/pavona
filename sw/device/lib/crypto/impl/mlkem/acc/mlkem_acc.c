// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/mlkem/acc/mlkem_acc.h"

#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/math.h"
#include "sw/device/lib/crypto/drivers/acc.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/mlkem/acc/mlkem_insn_counts.h"

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('m', 'a', 'c')

// Declare the ACC app.
ACC_DECLARE_APP_SYMBOLS(run_mlkem);
static const acc_app_t kAccAppMlkem = ACC_APP_T_INIT(run_mlkem);

// Declare offsets for input and output buffers.
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, mode);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, coins);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, dk);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, ek);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, ct);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, ss);

static const acc_addr_t kAccVarMode = ACC_ADDR_T_INIT(run_mlkem, mode);
static const acc_addr_t kAccVarCoins = ACC_ADDR_T_INIT(run_mlkem, coins);
static const acc_addr_t kAccVarDk = ACC_ADDR_T_INIT(run_mlkem, dk);
static const acc_addr_t kAccVarEk = ACC_ADDR_T_INIT(run_mlkem, ek);
static const acc_addr_t kAccVarCt = ACC_ADDR_T_INIT(run_mlkem, ct);
static const acc_addr_t kAccVarSs = ACC_ADDR_T_INIT(run_mlkem, ss);

// Declare mode constants.
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_KEYGEN_512);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_KEYGEN_768);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_KEYGEN_1024);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_ENCAP_512);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_ENCAP_768);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_ENCAP_1024);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_DECAP_512);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_DECAP_768);
ACC_DECLARE_SYMBOL_ADDR(run_mlkem, MODE_DECAP_1024);
static const uint32_t kAccMlkemModeKeygen512 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_KEYGEN_512);
static const uint32_t kAccMlkemModeKeygen768 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_KEYGEN_768);
static const uint32_t kAccMlkemModeKeygen1024 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_KEYGEN_1024);
static const uint32_t kAccMlkemModeEncap512 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_ENCAP_512);
static const uint32_t kAccMlkemModeEncap768 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_ENCAP_768);
static const uint32_t kAccMlkemModeEncap1024 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_ENCAP_1024);
static const uint32_t kAccMlkemModeDecap512 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_DECAP_512);
static const uint32_t kAccMlkemModeDecap768 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_DECAP_768);
static const uint32_t kAccMlkemModeDecap1024 =
    ACC_ADDR_T_INIT(run_mlkem, MODE_DECAP_1024);

enum {
  kAccMlkemModeWords = 1,
};

OT_WARN_UNUSED_RESULT
static status_t mlkem_keygen(uint32_t mode, uint32_t min_insn_count,
                             uint32_t max_insn_count,
                             const uint32_t coins[kMlkemKeygenSeedWords],
                             uint32_t *pk, size_t pk_words, uint32_t *sk,
                             size_t sk_words) {
  HARDENED_TRY(acc_load_app(kAccAppMlkem));
  HARDENED_TRY(acc_dmem_write(kAccMlkemModeWords, &mode, kAccVarMode));
  HARDENED_TRY(acc_dmem_write(kMlkemKeygenSeedWords, coins, kAccVarCoins));
  HARDENED_TRY(acc_execute());
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(acc_dmem_read(pk_words, kAccVarEk, pk));
  ACC_WIPE_IF_ERROR(acc_dmem_read(sk_words, kAccVarDk, sk));
  return acc_dmem_sec_wipe();
}

OT_WARN_UNUSED_RESULT
static status_t mlkem_encap(uint32_t mode, uint32_t min_insn_count,
                            uint32_t max_insn_count,
                            const uint32_t coins[kMlkemEncapSeedWords],
                            const uint32_t *pk, size_t pk_words, uint32_t *ct,
                            size_t ct_words,
                            uint32_t ss[kMlkemSharedSecretWords]) {
  HARDENED_TRY(acc_load_app(kAccAppMlkem));
  HARDENED_TRY(acc_dmem_write(kAccMlkemModeWords, &mode, kAccVarMode));
  HARDENED_TRY(acc_dmem_write(kMlkemEncapSeedWords, coins, kAccVarCoins));
  HARDENED_TRY(acc_dmem_write(pk_words, pk, kAccVarEk));
  HARDENED_TRY(acc_execute());
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(acc_dmem_read(ct_words, kAccVarCt, ct));
  ACC_WIPE_IF_ERROR(acc_dmem_read(kMlkemSharedSecretWords, kAccVarSs, ss));
  return acc_dmem_sec_wipe();
}

OT_WARN_UNUSED_RESULT
static status_t mlkem_decap(uint32_t mode, uint32_t min_insn_count,
                            uint32_t max_insn_count, const uint32_t *ct,
                            size_t ct_words, const uint32_t *sk,
                            size_t sk_words,
                            uint32_t ss[kMlkemSharedSecretWords]) {
  HARDENED_TRY(acc_load_app(kAccAppMlkem));
  HARDENED_TRY(acc_dmem_write(kAccMlkemModeWords, &mode, kAccVarMode));
  HARDENED_TRY(acc_dmem_write(ct_words, ct, kAccVarCt));
  HARDENED_TRY(acc_dmem_write(sk_words, sk, kAccVarDk));
  HARDENED_TRY(acc_execute());
  ACC_WIPE_IF_ERROR(acc_busy_wait_for_done());
  ACC_CHECK_INSN_COUNT(min_insn_count, max_insn_count);
  ACC_WIPE_IF_ERROR(acc_dmem_read(kMlkemSharedSecretWords, kAccVarSs, ss));
  return acc_dmem_sec_wipe();
}

status_t mlkem_acc_512_keygen(const uint32_t coins[kMlkemKeygenSeedWords],
                              uint32_t pk[kMlkem512PublicKeyWords],
                              uint32_t sk[kMlkem512SecretKeyWords]) {
  return mlkem_keygen(kAccMlkemModeKeygen512,
                      kMlkem512KeygenMinInstructionCount,
                      kMlkem512KeygenMaxInstructionCount, coins, pk,
                      kMlkem512PublicKeyWords, sk, kMlkem512SecretKeyWords);
}

status_t mlkem_acc_768_keygen(const uint32_t coins[kMlkemKeygenSeedWords],
                              uint32_t pk[kMlkem768PublicKeyWords],
                              uint32_t sk[kMlkem768SecretKeyWords]) {
  return mlkem_keygen(kAccMlkemModeKeygen768,
                      kMlkem768KeygenMinInstructionCount,
                      kMlkem768KeygenMaxInstructionCount, coins, pk,
                      kMlkem768PublicKeyWords, sk, kMlkem768SecretKeyWords);
}

status_t mlkem_acc_1024_keygen(const uint32_t coins[kMlkemKeygenSeedWords],
                               uint32_t pk[kMlkem1024PublicKeyWords],
                               uint32_t sk[kMlkem1024SecretKeyWords]) {
  return mlkem_keygen(kAccMlkemModeKeygen1024,
                      kMlkem1024KeygenMinInstructionCount,
                      kMlkem1024KeygenMaxInstructionCount, coins, pk,
                      kMlkem1024PublicKeyWords, sk, kMlkem1024SecretKeyWords);
}

status_t mlkem_acc_512_encap(const uint32_t coins[kMlkemEncapSeedWords],
                             const uint32_t pk[kMlkem512PublicKeyWords],
                             uint32_t ct[kMlkem512CiphertextWords],
                             uint32_t ss[kMlkemSharedSecretWords]) {
  return mlkem_encap(kAccMlkemModeEncap512, kMlkem512EncapMinInstructionCount,
                     kMlkem512EncapMaxInstructionCount, coins, pk,
                     kMlkem512PublicKeyWords, ct, kMlkem512CiphertextWords, ss);
}

status_t mlkem_acc_768_encap(const uint32_t coins[kMlkemEncapSeedWords],
                             const uint32_t pk[kMlkem768PublicKeyWords],
                             uint32_t ct[kMlkem768CiphertextWords],
                             uint32_t ss[kMlkemSharedSecretWords]) {
  return mlkem_encap(kAccMlkemModeEncap768, kMlkem768EncapMinInstructionCount,
                     kMlkem768EncapMaxInstructionCount, coins, pk,
                     kMlkem768PublicKeyWords, ct, kMlkem768CiphertextWords, ss);
}

status_t mlkem_acc_1024_encap(const uint32_t coins[kMlkemEncapSeedWords],
                              const uint32_t pk[kMlkem1024PublicKeyWords],
                              uint32_t ct[kMlkem1024CiphertextWords],
                              uint32_t ss[kMlkemSharedSecretWords]) {
  return mlkem_encap(kAccMlkemModeEncap1024, kMlkem1024EncapMinInstructionCount,
                     kMlkem1024EncapMaxInstructionCount, coins, pk,
                     kMlkem1024PublicKeyWords, ct, kMlkem1024CiphertextWords,
                     ss);
}

status_t mlkem_acc_512_decap(const uint32_t ct[kMlkem512CiphertextWords],
                             const uint32_t sk[kMlkem512SecretKeyWords],
                             uint32_t ss[kMlkemSharedSecretWords]) {
  return mlkem_decap(kAccMlkemModeDecap512, kMlkem512DecapMinInstructionCount,
                     kMlkem512DecapMaxInstructionCount, ct,
                     kMlkem512CiphertextWords, sk, kMlkem512SecretKeyWords, ss);
}

status_t mlkem_acc_768_decap(const uint32_t ct[kMlkem768CiphertextWords],
                             const uint32_t sk[kMlkem768SecretKeyWords],
                             uint32_t ss[kMlkemSharedSecretWords]) {
  return mlkem_decap(kAccMlkemModeDecap768, kMlkem768DecapMinInstructionCount,
                     kMlkem768DecapMaxInstructionCount, ct,
                     kMlkem768CiphertextWords, sk, kMlkem768SecretKeyWords, ss);
}

status_t mlkem_acc_1024_decap(const uint32_t ct[kMlkem1024CiphertextWords],
                              const uint32_t sk[kMlkem1024SecretKeyWords],
                              uint32_t ss[kMlkemSharedSecretWords]) {
  return mlkem_decap(kAccMlkemModeDecap1024, kMlkem1024DecapMinInstructionCount,
                     kMlkem1024DecapMaxInstructionCount, ct,
                     kMlkem1024CiphertextWords, sk, kMlkem1024SecretKeyWords,
                     ss);
}
