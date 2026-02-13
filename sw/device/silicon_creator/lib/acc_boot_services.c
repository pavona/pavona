// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/acc_boot_services.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/attestation.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/base/util.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/flash_ctrl.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"
#include "sw/device/silicon_creator/lib/drivers/keymgr.h"
#include "sw/device/silicon_creator/lib/drivers/acc.h"

#include "hw/top/acc_regs.h"  // Generated.

static_assert(kAttestationSeedWords <= 16,
              "Additional attestation seed needs must be <= 516 bits.");

ACC_DECLARE_APP_SYMBOLS(boot);        // The ACC boot-services app.
ACC_DECLARE_SYMBOL_ADDR(boot, mode);  // Application mode.
ACC_DECLARE_SYMBOL_ADDR(boot, msg);   // ECDSA message digest.
ACC_DECLARE_SYMBOL_ADDR(boot, x);     // ECDSA public key x-coordinate.
ACC_DECLARE_SYMBOL_ADDR(boot, y);     // ECDSA public key y-coordinate.
ACC_DECLARE_SYMBOL_ADDR(boot, r);     // ECDSA signature component r.
ACC_DECLARE_SYMBOL_ADDR(boot, s);     // ECDSA signature component s.
ACC_DECLARE_SYMBOL_ADDR(boot, x_r);   // ECDSA verification result.
ACC_DECLARE_SYMBOL_ADDR(boot, ok);    // ECDSA verification status.
ACC_DECLARE_SYMBOL_ADDR(
    boot, attestation_additional_seed);  // Additional seed for ECDSA keygen.

static const sc_acc_app_t kAccAppBoot = ACC_APP_T_INIT(boot);
static const sc_acc_addr_t kAccVarBootMode = ACC_ADDR_T_INIT(boot, mode);
static const sc_acc_addr_t kAccVarBootMsg = ACC_ADDR_T_INIT(boot, msg);
static const sc_acc_addr_t kAccVarBootX = ACC_ADDR_T_INIT(boot, x);
static const sc_acc_addr_t kAccVarBootY = ACC_ADDR_T_INIT(boot, y);
static const sc_acc_addr_t kAccVarBootR = ACC_ADDR_T_INIT(boot, r);
static const sc_acc_addr_t kAccVarBootS = ACC_ADDR_T_INIT(boot, s);
static const sc_acc_addr_t kAccVarBootXr = ACC_ADDR_T_INIT(boot, x_r);
static const sc_acc_addr_t kAccVarBootOk = ACC_ADDR_T_INIT(boot, ok);
static const sc_acc_addr_t kAccVarBootAttestationAdditionalSeed =
    ACC_ADDR_T_INIT(boot, attestation_additional_seed);

enum {
  /*
   * Mode is represented by a single word.
   */
  kAccBootModeWords = 1,
  /*
   * Mode to run signature verification.
   *
   * Value taken from `boot.s`.
   */
  kAccBootModeSigverify = 0x7d3,
  /*
   * Mode to generate an attestation keypair.
   *
   * Value taken from `boot.s`.
   */
  kAccBootModeAttestationKeygen = 0x2bf,
  /*
   * Mode to endorse a message with a saved private key.
   *
   * Value taken from `boot.s`.
   */
  kAccBootModeAttestationEndorse = 0x5e8,
  /*
   * Mode to save an attesation private key.
   *
   * Value taken from `boot.s`.
   */
  kAccBootModeAttestationKeySave = 0x64d,
  /* Size of the ACC attestation seed buffer in 32-bit words (rounding the
     attestation seed size up to the next ACC wide word). */
  kAccAttestationSeedBufferWords =
      ((kAttestationSeedWords + kScAccWideWordNumWords - 1) /
       kScAccWideWordNumWords) *
      kScAccWideWordNumWords,
};

OT_WARN_UNUSED_RESULT
static rom_error_t load_attestation_keygen_seed(uint32_t additional_seed_idx,
                                                uint32_t *seed) {
  // Read seed from flash info page.
  uint32_t seed_flash_offset =
      0 + (additional_seed_idx * kAttestationSeedBytes);
  rom_error_t err =
      flash_ctrl_info_read(&kFlashCtrlInfoPageAttestationKeySeeds,
                           seed_flash_offset, kAttestationSeedWords, seed);

  if (err != kErrorOk) {
    flash_ctrl_error_code_t flash_ctrl_err_code;
    flash_ctrl_error_code_get(&flash_ctrl_err_code);
    if (flash_ctrl_err_code.rd_err) {
      // If we encountered a read error, this means the attestation seed page
      // has not been provisioned yet. In this case, we clear the seed and
      // continue, which will simply result in generating an invalid identity.
      memset(seed, 0, kAttestationSeedBytes);
      return kErrorOk;
    }
    return err;
  }

  return kErrorOk;
}

rom_error_t acc_boot_app_load(void) { return sc_acc_load_app(kAccAppBoot); }

rom_error_t acc_boot_attestation_keygen(
    uint32_t additional_seed_idx, sc_keymgr_key_type_t key_type,
    sc_keymgr_diversification_t diversification,
    ecdsa_p256_public_key_t *public_key) {
  // Trigger key manager to sideload the attestation key into ACC.
  HARDENED_RETURN_IF_ERROR(
      sc_keymgr_generate_key_acc(key_type, diversification));

  // Write the mode.
  uint32_t mode = kAccBootModeAttestationKeygen;
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kAccBootModeWords, &mode, kAccVarBootMode));

  // Load the additional seed from flash info.
  uint32_t seed[kAttestationSeedWords];
  HARDENED_RETURN_IF_ERROR(
      load_attestation_keygen_seed(additional_seed_idx, seed));

  // Write the additional seed to ACC DMEM.
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_write(
      kAttestationSeedWords, seed, kAccVarBootAttestationAdditionalSeed));
  // Pad remaining DMEM field with zeros to prevent a DMEM integrity error
  // (since data is aligned to 256-bit words).
  uint32_t zero_buf[kAccAttestationSeedBufferWords - kAttestationSeedWords] = {
      0};
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_write(
      ARRAYSIZE(zero_buf), zero_buf,
      kAccVarBootAttestationAdditionalSeed + kAttestationSeedBytes));

  // Run the ACC program (blocks until ACC is done).
  HARDENED_RETURN_IF_ERROR(sc_acc_execute());
  SEC_MMIO_WRITE_INCREMENT(kScAccSecMmioExecute);

  // TODO(#20023): Check the instruction count register (see `mod_exp_acc`).

  // Retrieve the public key.
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_read(kEcdsaP256PublicKeyCoordWords,
                                             kAccVarBootX, public_key->x));
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_read(kEcdsaP256PublicKeyCoordWords,
                                             kAccVarBootY, public_key->y));

  return kErrorOk;
}

/**
 * Helper function to convert an ECC P256 public key from little to big endian
 * in place.
 */
static void pubkey_le_to_be_convert(ecdsa_p256_public_key_t *pubkey) {
  util_reverse_bytes(pubkey->x, kEcdsaP256PublicKeyCoordBytes);
  util_reverse_bytes(pubkey->y, kEcdsaP256PublicKeyCoordBytes);
}

rom_error_t acc_boot_cert_ecc_p256_keygen(sc_keymgr_ecc_key_t key,
                                           hmac_digest_t *pubkey_id,
                                           ecdsa_p256_public_key_t *pubkey) {
  HARDENED_RETURN_IF_ERROR(sc_keymgr_state_check(key.required_keymgr_state));

  // Generate / sideload key material into ACC, and generate the ECC keypair.
  HARDENED_RETURN_IF_ERROR(acc_boot_attestation_keygen(
      key.keygen_seed_idx, key.type, *key.keymgr_diversifier, pubkey));

  // Keys are represented in certificates in big endian format, but the key is
  // output from ACC in little endian format, so we convert the key to
  // big endian format.
  pubkey_le_to_be_convert(pubkey);

  // Generate the key ID.
  //
  // Note: the certificate generation functions expect the digest to be in big
  // endian form, but the HMAC driver returns the digest in little endian, so we
  // re-format it.
  hmac_sha256(pubkey, sizeof(*pubkey), pubkey_id);
  util_reverse_bytes(pubkey_id, sizeof(*pubkey_id));

  return kErrorOk;
}

rom_error_t acc_boot_attestation_key_save(
    uint32_t additional_seed_idx, sc_keymgr_key_type_t key_type,
    sc_keymgr_diversification_t diversification) {
  // Trigger key manager to sideload the attestation key into ACC.
  HARDENED_RETURN_IF_ERROR(
      sc_keymgr_generate_key_acc(key_type, diversification));

  // Write the mode.
  uint32_t mode = kAccBootModeAttestationKeySave;
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kAccBootModeWords, &mode, kAccVarBootMode));

  // Load the additional seed from flash info.
  uint32_t seed[kAttestationSeedWords];
  HARDENED_RETURN_IF_ERROR(
      load_attestation_keygen_seed(additional_seed_idx, seed));
  // Pad remaining DMEM field with zeros to prevent a DMEM integrity error
  // (since data is aligned to 256-bit words).
  uint32_t zero_buf[kAccAttestationSeedBufferWords - kAttestationSeedWords] = {
      0};
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_write(
      ARRAYSIZE(zero_buf), zero_buf,
      kAccVarBootAttestationAdditionalSeed + kAttestationSeedBytes));

  // Write the additional seed to ACC DMEM.
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_write(
      kAttestationSeedWords, seed, kAccVarBootAttestationAdditionalSeed));

  // Run the ACC program (blocks until ACC is done).
  HARDENED_RETURN_IF_ERROR(sc_acc_execute());
  SEC_MMIO_WRITE_INCREMENT(kScAccSecMmioExecute);

  // TODO(#20023): Check the instruction count register (see `mod_exp_acc`).

  return kErrorOk;
}

rom_error_t acc_boot_attestation_key_clear(void) {
  // Trigger a full DMEM wipe.
  RETURN_IF_ERROR(sc_acc_dmem_sec_wipe());
  HARDENED_RETURN_IF_ERROR(sc_acc_busy_wait_for_done());

  // Re-load the data portion of the boot services app. This is like a
  // stripped-down version of `sc_acc_load_app`, where we skip the IMEM.
  if (kAccAppBoot.dmem_data_end < kAccAppBoot.dmem_data_start) {
    return kErrorAccInvalidArgument;
  }
  HARDENED_CHECK_GE(kAccAppBoot.dmem_data_end, kAccAppBoot.dmem_data_start);
  const size_t data_num_words =
      (size_t)(kAccAppBoot.dmem_data_end - kAccAppBoot.dmem_data_start);
  if (data_num_words > 0) {
    HARDENED_RETURN_IF_ERROR(
        sc_acc_dmem_write(data_num_words, kAccAppBoot.dmem_data_start,
                           kAccAppBoot.dmem_data_start_addr));
  }
  return kErrorOk;
}

rom_error_t acc_boot_attestation_endorse(const hmac_digest_t *digest,
                                          ecdsa_p256_signature_t *sig) {
  // Write the mode.
  uint32_t mode = kAccBootModeAttestationEndorse;
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kAccBootModeWords, &mode, kAccVarBootMode));

  // Write the message digest.
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kHmacDigestNumWords, digest->digest, kAccVarBootMsg));

  // Run the ACC program (blocks until ACC is done).
  HARDENED_RETURN_IF_ERROR(sc_acc_execute());
  SEC_MMIO_WRITE_INCREMENT(kScAccSecMmioExecute);

  // TODO(#20023): Check the instruction count register (see `mod_exp_acc`).

  // Retrieve the signature (in two parts, r and s).
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_read(kEcdsaP256SignatureComponentWords,
                                             kAccVarBootR, sig->r));
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_read(kEcdsaP256SignatureComponentWords,
                                             kAccVarBootS, sig->s));

  return kErrorOk;
}

rom_error_t acc_boot_sigverify(const ecdsa_p256_public_key_t *key,
                                const ecdsa_p256_signature_t *sig,
                                const hmac_digest_t *digest,
                                uint32_t *recovered_r) {
  // Write the mode.
  uint32_t mode = kAccBootModeSigverify;
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kAccBootModeWords, &mode, kAccVarBootMode));

  // Write the public key.
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kEcdsaP256PublicKeyCoordWords, key->x, kAccVarBootX));
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kEcdsaP256PublicKeyCoordWords, key->y, kAccVarBootY));

  // Write the message digest.
  HARDENED_RETURN_IF_ERROR(
      sc_acc_dmem_write(kHmacDigestNumWords, digest->digest, kAccVarBootMsg));

  // Write the signature.
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_write(kEcdsaP256SignatureComponentWords,
                                              sig->r, kAccVarBootR));
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_write(kEcdsaP256SignatureComponentWords,
                                              sig->s, kAccVarBootS));

  // Start the ACC routine.
  HARDENED_RETURN_IF_ERROR(sc_acc_execute());
  SEC_MMIO_WRITE_INCREMENT(kScAccSecMmioExecute);

  // Check if the signature passed basic checks.
  uint32_t ok;
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_read(1, kAccVarBootOk, &ok));
  if (launder32(ok) != kHardenedBoolTrue) {
    return kErrorSigverifyBadEcdsaSignature;
  }

  // Read the status value again as an extra hardening measure.
  HARDENED_RETURN_IF_ERROR(sc_acc_dmem_read(1, kAccVarBootOk, &ok));
  HARDENED_CHECK_EQ(ok, kHardenedBoolTrue);

  // TODO(#20023): Check the instruction count register (see `mod_exp_acc`).

  // Read the recovered `r` value from DMEM.
  return sc_acc_dmem_read(kEcdsaP256SignatureComponentWords, kAccVarBootXr,
                           recovered_r);
}
