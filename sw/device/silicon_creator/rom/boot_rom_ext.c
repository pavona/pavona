// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/acc_boot_services.h"
#include "sw/device/silicon_creator/lib/base/boot_measurements.h"
#include "sw/device/silicon_creator/lib/base/sec_mmio.h"
#include "sw/device/silicon_creator/lib/base/util.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/boot_log.h"
#include "sw/device/silicon_creator/lib/cfi.h"
#include "sw/device/silicon_creator/lib/drivers/alert.h"
#include "sw/device/silicon_creator/lib/drivers/epmp.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/otp.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"
#include "sw/device/silicon_creator/lib/drivers/rnd.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/manifest.h"
#include "sw/device/silicon_creator/lib/shutdown.h"
#include "sw/device/silicon_creator/lib/sigverify/sigverify.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"
#include "sw/device/silicon_creator/rom/boot_policy.h"
#include "sw/device/silicon_creator/rom/boot_policy_ptrs.h"
#include "sw/device/silicon_creator/rom/rom_cfi.h"
#include "sw/device/silicon_creator/rom/rom_epmp.h"
#include "sw/device/silicon_creator/rom/sigverify_keys_ecdsa_p256.h"
#include "sw/device/silicon_creator/rom/sigverify_keys_spx.h"
#include "sw/device/silicon_creator/rom/sigverify_otp_keys.h"

#ifdef HAS_FLASH_CTRL
#include "sw/device/silicon_creator/lib/drivers/flash_ctrl.h"
#endif

#ifdef HAS_KEYMGR_DPE
#include "sw/device/silicon_creator/lib/drivers/keymgr_dpe.h"
#else
#include "sw/device/silicon_creator/lib/drivers/keymgr.h"
#endif

// Boot data from flash.
boot_data_t boot_data = {0};

// First stage (ROM-->ROM_EXT) secure boot keys loaded from OTP.
static sigverify_otp_key_ctx_t sigverify_ctx;

/* These symbols are defined in
 * `opentitan/sw/device/silicon_creator/rom/rom.ld`, and describes the
 * location of the flash header.
 */
extern char _rom_ext_virtual_start_address[];
extern char _rom_ext_virtual_size[];

/**
 * Verifies a ROM_EXT.
 *
 * This function performs bounds checks on the fields of the manifest, checks
 * its `identifier` and `security_version` fields, and verifies its signature.
 *
 * @param Manifest of the ROM_EXT to be verified.
 * @param[out] flash_exec Value to write to the flash_ctrl EXEC register.
 * @return Result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t rom_verify(const manifest_t *manifest,
                              const boot_data_t boot_data,
                              const lifecycle_state_t lc_state,
                              sigverify_otp_key_ctx_t *sigverify_ctx,
                              uint32_t *flash_exec) {
  const uint32_t *anti_rollback = NULL;
  size_t anti_rollback_len = 0;
  // Check security version and manifest constraints.
  //
  // The poisoning work (`anti_rollback`) invalidates signatures if the
  // security version of the manifest is smaller than the minimum required
  // security version.
  const uint32_t extra_word = UINT32_MAX;
  if (launder32(manifest->security_version) <
      boot_data.min_security_version_rom_ext) {
    anti_rollback = &extra_word;
    anti_rollback_len = sizeof(extra_word);
  }
  *flash_exec = 0;
  HARDENED_RETURN_IF_ERROR(boot_policy_manifest_check(manifest, &boot_data));

  // Load ACC boot services app.
  //
  // This will be reused by later boot stages.
  HARDENED_RETURN_IF_ERROR(acc_boot_app_load());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomVerifyRomExt, 1);

  // Load secure boot keys from OTP into RAM.
  HARDENED_RETURN_IF_ERROR(sigverify_otp_keys_init(sigverify_ctx));
  // ECDSA key.
  const ecdsa_p256_public_key_t *ecdsa_key = NULL;
  HARDENED_RETURN_IF_ERROR(sigverify_ecdsa_p256_key_get(
      sigverify_ctx,
      sigverify_ecdsa_p256_key_id_get(&manifest->ecdsa_public_key), lc_state,
      &ecdsa_key));
  // SPX+ key.
  const sigverify_spx_key_t *spx_key = NULL;
  sigverify_spx_config_id_t spx_config = 0;
  const sigverify_spx_signature_t *spx_signature = NULL;
  uint32_t sigverify_spx_en = sigverify_spx_verify_enabled(lc_state);
  if (launder32(sigverify_spx_en) != kSigverifySpxDisabledOtp) {
    const manifest_ext_spx_key_t *ext_spx_key;
    HARDENED_RETURN_IF_ERROR(manifest_ext_get_spx_key(manifest, &ext_spx_key));
    HARDENED_RETURN_IF_ERROR(sigverify_spx_key_get(
        sigverify_ctx, sigverify_spx_key_id_get(&ext_spx_key->key), lc_state,
        &spx_key, &spx_config));
    const manifest_ext_spx_signature_t *ext_spx_signature;
    HARDENED_RETURN_IF_ERROR(
        manifest_ext_get_spx_signature(manifest, &ext_spx_signature));
    spx_signature = &ext_spx_signature->signature;
  } else {
    HARDENED_CHECK_EQ(sigverify_spx_en, kSigverifySpxDisabledOtp);
  }
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomVerifyRomExt, 2);

  // Measure ROM_EXT and portions of manifest via SHA256 digest.
  // Initialize ROM_EXT measurement in .static_critical with garbage.
  memset(boot_measurements.rom_ext.data, (int)rnd_uint32(),
         sizeof(boot_measurements.rom_ext.data));
  // Add anti-rollback poisoning word to measurement.
  hmac_sha256_init();
  hmac_sha256_update(anti_rollback, anti_rollback_len);
  HARDENED_CHECK_GE(manifest->security_version,
                    boot_data.min_security_version_rom_ext);
  // Add manifest usage constraints to the measurement.
  manifest_usage_constraints_t usage_constraints_from_hw;
  sigverify_usage_constraints_get(manifest->usage_constraints.selector_bits,
                                  &usage_constraints_from_hw);
  hmac_sha256_update(&usage_constraints_from_hw,
                     sizeof(usage_constraints_from_hw));
  // Add remaining part of manifest / ROM_EXT image to the measurement.
  manifest_digest_region_t digest_region = manifest_digest_region_get(manifest);
  // Add remaining part of manifest / ROM_EXT image to the measurement.
  hmac_sha256_update(digest_region.start, digest_region.length);
  hmac_sha256_process();
  // The ECDSA verify function expects the digest in reverse order, which
  // is what hmac_sha256_final produces.
  hmac_digest_t rev_digest;
  hmac_sha256_final(&rev_digest);
  // The SPHINCS+ verify function expects the digest in the natural order,
  // so we copy and reverse the bytes.
  hmac_digest_t fwd_digest = rev_digest;
  util_reverse_bytes(&fwd_digest, sizeof(fwd_digest));
  // Copy the ROM_EXT measurement to the .static_critical section.
  static_assert(sizeof(boot_measurements.rom_ext) == sizeof(rev_digest),
                "Unexpected ROM_EXT digest size.");
  memcpy(&boot_measurements.rom_ext, &rev_digest,
         sizeof(boot_measurements.rom_ext));

  /**
   * Verify the ECDSA/SPX+ signatures of ROM_EXT.
   *
   * We swap the order of signature verifications randomly.
   */
  *flash_exec = 0;
  if (rnd_uint32() < 0x80000000) {
    HARDENED_RETURN_IF_ERROR(sigverify_ecdsa_p256_verify(
        &manifest->ecdsa_signature, ecdsa_key, &rev_digest, flash_exec));

    CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomVerifyRomExt, 3);

    return sigverify_spx_verify(
        spx_signature, spx_key, spx_config, lc_state,
        &usage_constraints_from_hw, sizeof(usage_constraints_from_hw),
        anti_rollback, anti_rollback_len, digest_region.start,
        digest_region.length, &fwd_digest, flash_exec);
  } else {
    HARDENED_RETURN_IF_ERROR(sigverify_spx_verify(
        spx_signature, spx_key, spx_config, lc_state,
        &usage_constraints_from_hw, sizeof(usage_constraints_from_hw),
        anti_rollback, anti_rollback_len, digest_region.start,
        digest_region.length, &fwd_digest, flash_exec));

    CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomVerifyRomExt, 3);

    return sigverify_ecdsa_p256_verify(&manifest->ecdsa_signature, ecdsa_key,
                                       &rev_digest, flash_exec);
  }
}

/**
 * Compute the virtual address corresponding to the physical address `lma_addr`.
 *
 * @param manifest Pointer to the current manifest.
 * @param lma_addr Load address or physical address.
 * @return the computed virtual address.
 */
OT_WARN_UNUSED_RESULT
static uintptr_t rom_ext_vma_get(const manifest_t *manifest,
                                 uintptr_t lma_addr) {
  return (lma_addr - (uintptr_t)manifest +
          (uintptr_t)_rom_ext_virtual_start_address);
}

/**
 * Performs consistency checks before booting a ROM_EXT.
 *
 * All of the checks in this function are expected to pass and any failures
 * result in shutdown.
 */
static void rom_pre_boot_check(const boot_data_t boot_data,
                               const lifecycle_state_t lc_state) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 1);

  // Check the alert_handler configuration.
  SHUTDOWN_IF_ERROR(alert_config_check(lc_state));
  SHUTDOWN_IF_ERROR(rnd_health_config_check(lc_state));
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 2);

  // Check cached life cycle state against the value reported by hardware.
  lifecycle_state_t lc_state_check = lifecycle_state_get();
  if (launder32(lc_state_check) != lc_state) {
    HARDENED_TRAP();
  }
  HARDENED_CHECK_EQ(lc_state_check, lc_state);

  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 3);

  // Check cached boot data.
  rom_error_t boot_data_ok = boot_data_check(&boot_data);
  if (launder32(boot_data_ok) != kErrorOk) {
    HARDENED_TRAP();
  }
  HARDENED_CHECK_EQ(boot_data_ok, kErrorOk);
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 4);

  // Check the ePMP state
  SHUTDOWN_IF_ERROR(epmp_state_check());
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 5);

  // Check the cpuctrl CSR.
  uint32_t cpuctrl_csr;
  uint32_t cpuctrl_otp =
      otp_read32(OTP_CTRL_PARAM_CREATOR_SW_CFG_CPUCTRL_OFFSET);
  CSR_READ(CSR_REG_CPUCTRL, &cpuctrl_csr);
  // We only mask the 8th bit (`ic_scr_key_valid`) to include exception flags
  // (bits 6 and 7) in the check.
  cpuctrl_csr = bitfield_bit32_write(cpuctrl_csr, 8, false);
  if (launder32(cpuctrl_csr) != cpuctrl_otp) {
    HARDENED_TRAP();
  }
  HARDENED_CHECK_EQ(cpuctrl_csr, cpuctrl_otp);
  // Check rstmgr alert and cpu info collection configuration.
  SHUTDOWN_IF_ERROR(
      rstmgr_info_en_check(retention_sram_get()->creator.reset_reasons));
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 6);

  sec_mmio_check_counters(/*expected_check_count=*/3);
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomPreBootCheck, 7);
}

/**
 * Measures the combination of software configuration OTP digests and the digest
 * of the secure boot keys.
 *
 * @param measurement Pointer to the measurement of the partitions.
 * @return rom_error_t Result of the operation.
 */
static rom_error_t rom_measure_otp_partitions(
    sigverify_otp_key_ctx_t *sigverify_ctx,
    keymgr_binding_value_t *measurement) {
  memset(measurement, (int)rnd_uint32(), sizeof(keymgr_binding_value_t));
  // These is no need to harden these data copies as any poisoning of the OTP
  // measurements will result in the derivation of a different UDS identity
  // which will not be endorsed. Hence we sa-ve the cycles of using sec_mmio.
  hmac_sha256_init();
  static_assert(
      (OTP_CTRL_CREATOR_SW_CFG_DIGEST_CREATOR_SW_CFG_DIGEST_FIELD_WIDTH *
       OTP_CTRL_CREATOR_SW_CFG_DIGEST_MULTIREG_COUNT / 8) == sizeof(uint64_t),
      "CreatorSwCfg OTP partition digest no longer 64 bits.");
  static_assert(
      (OTP_CTRL_OWNER_SW_CFG_DIGEST_OWNER_SW_CFG_DIGEST_FIELD_WIDTH *
       OTP_CTRL_OWNER_SW_CFG_DIGEST_MULTIREG_COUNT / 8) == sizeof(uint64_t),
      "OwnerSwCfg OTP partition digest no longer 64 bits.");
  hmac_sha256_update(
      (unsigned char *)(dt_otp_ctrl_reg_block(kDtOtpCtrl,
                                              kDtOtpCtrlRegBlockCore),
                        OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET +
                            OTP_CTRL_PARAM_CREATOR_SW_CFG_DIGEST_OFFSET),
      sizeof(uint64_t));
  hmac_sha256_update(
      (unsigned char *)(dt_otp_ctrl_reg_block(kDtOtpCtrl,
                                              kDtOtpCtrlRegBlockCore),
                        OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET +
                            OTP_CTRL_PARAM_OWNER_SW_CFG_DIGEST_OFFSET),
      sizeof(uint64_t));
#ifdef DISCRETE_OTP_MAP
  hmac_sha256_update(sigverify_ctx->keys.integrity_measurement.digest,
                     kHmacDigestNumBytes);
#endif
  hmac_sha256_process();
  hmac_digest_t otp_measurement;
  hmac_sha256_final(&otp_measurement);
  memcpy(measurement->data, otp_measurement.digest, kHmacDigestNumBytes);
  return kErrorOk;
}

/**
 * Attempts to boot the ROM_EXT.
 *
 * Note: This function should not return under normal conditions. Any returns
 * from this function must result in shutdown.
 *
 * @param manifest Manifest of the ROM_EXT to boot.
 * @param flash_exec Value to write to the flash_ctrl EXEC register.
 * @return rom_error_t Result of the operation.
 */
OT_WARN_UNUSED_RESULT
static rom_error_t rom_boot_rom_ext(const manifest_t *manifest,
                                    const lifecycle_state_t lc_state,
                                    uintptr_t imm_section_entry_point,
                                    uint32_t flash_exec) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootRomExt, 1);
  HARDENED_RETURN_IF_ERROR(sc_keymgr_state_check(kScKeymgrStateReset));

  boot_log_t *boot_log = &retention_sram_get()->creator.boot_log;
  boot_log->rom_ext_slot =
      manifest == boot_policy_manifest_get(kSlotA) ? kBootSlotA : kBootSlotB;
  boot_log_digest_update(boot_log);

  keymgr_binding_value_t otp_measurement;
  const keymgr_binding_value_t *attestation_measurement =
      &manifest->binding_value;
  uint32_t use_otp_measurement =
      otp_read32(OTP_CTRL_PARAM_OWNER_SW_CFG_ROM_KEYMGR_OTP_MEAS_EN_OFFSET);
  if (launder32(use_otp_measurement) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(use_otp_measurement, kHardenedBoolTrue);
    rom_measure_otp_partitions(&sigverify_ctx, &otp_measurement);
    attestation_measurement = &otp_measurement;
  } else {
    HARDENED_CHECK_NE(use_otp_measurement, kHardenedBoolTrue);
  }
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootRomExt, 2);
#ifdef HAS_KEYMGR_DPE
  sc_keymgr_sw_binding_set(attestation_measurement);
  sc_keymgr_max_ver_set(manifest->max_key_version);
  SEC_MMIO_WRITE_INCREMENT(kScKeymgrSecMmioSwBindingSet +
                           kScKeymgrSecMmioMaxVerSet);
#else
  sc_keymgr_sw_binding_set(&manifest->binding_value, attestation_measurement);
  sc_keymgr_creator_max_ver_set(manifest->max_key_version);
  SEC_MMIO_WRITE_INCREMENT(kScKeymgrSecMmioSwBindingSet +
                           kScKeymgrSecMmioCreatorMaxVerSet);
#endif

  sec_mmio_check_counters(/*expected_check_count=*/2);

  // Configure address translation, compute the epmp regions and the entry
  // point for the virtual address in case the address translation is enabled.
  // Otherwise, compute the epmp regions and the entry point for the load
  // address.
  epmp_region_t text_region = manifest_code_region_get(manifest);
  uintptr_t _entry_point = manifest_entry_point_get(manifest);
  switch (launder32(manifest->address_translation)) {
    case kHardenedBoolTrue:
      HARDENED_CHECK_EQ(manifest->address_translation, kHardenedBoolTrue);
      ibex_addr_remap_set(0, (uintptr_t)_rom_ext_virtual_start_address,
                          (uintptr_t)manifest, (size_t)_rom_ext_virtual_size);
      SEC_MMIO_WRITE_INCREMENT(kAddressTranslationSecMmioConfigure);

      // Unlock read-execute for the text region and read-only for the whole
      // ROM_EXT virtual memory.
      HARDENED_RETURN_IF_ERROR(epmp_state_check());
      // Update the text region to point to the virtual addresses instead of the
      // physical ones.
      text_region.start = rom_ext_vma_get(manifest, text_region.start);
      text_region.end = rom_ext_vma_get(manifest, text_region.end);
      epmp_region_t rom_ext_virtual_region = {
          .start = (uintptr_t)_rom_ext_virtual_start_address,
          .end = (uintptr_t)_rom_ext_virtual_start_address +
                 (uintptr_t)_rom_ext_virtual_size,
      };
      epmp_prepare_boot_stage(text_region, rom_ext_virtual_region);
      // Move the ROM_EXT execution section from the load address to the virtual
      // address.
      text_region.start = rom_ext_vma_get(manifest, text_region.start);
      text_region.end = rom_ext_vma_get(manifest, text_region.end);
      _entry_point = rom_ext_vma_get(manifest, _entry_point);
      break;
    case kHardenedBoolFalse:
      HARDENED_CHECK_EQ(manifest->address_translation, kHardenedBoolFalse);
      // Unlock execution of ROM_EXT executable code (text) sections.
      HARDENED_RETURN_IF_ERROR(epmp_state_check());
      epmp_prepare_boot_stage_rx(text_region);
      break;
    default:
      HARDENED_TRAP();
  }
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootRomExt, 3);

  // Perfrom pre-boot checks.
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomBootRomExt, 4,
                            kCfiRomPreBootCheck);
  rom_pre_boot_check(boot_data, lc_state);
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootRomExt, 6);
  CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomPreBootCheck, 8);

#ifdef HAS_FLASH_CTRL
  // Enable execution of code from flash if signature is verified.
  flash_ctrl_exec_set(flash_exec);
  SEC_MMIO_WRITE_INCREMENT(kFlashCtrlSecMmioExecSet);
  sec_mmio_check_values(rnd_uint32());
  sec_mmio_check_counters(/*expected_check_count=*/5);
#endif

  // Jump to ROM_EXT entry point.
  enum {
    /**
     * Expected value of the `kCfiRomTryBootRomExt` counter when jumping to the
     * first ROM_EXT image.
     */
    kCfiRomTryBootRomExtManifest0Val =
        3 * kCfiIncrement + kCfiRomTryBootRomExtVal0,
    /**
     * Expected value of the `kCfiRomTryBootRomExt` counter when jumping to the
     * second ROM_EXT image.
     */
    kCfiRomTryBootRomExtManifest1Val =
        10 * kCfiIncrement + kCfiRomTryBootRomExtVal0,
  };
  const manifest_t *manifest_check = NULL;
  switch (launder32(rom_counters[kCfiRomTryBootRomExt])) {
    case kCfiRomTryBootRomExtManifest0Val:
      HARDENED_CHECK_EQ(rom_counters[kCfiRomTryBootRomExt],
                        kCfiRomTryBootRomExtManifest0Val);
      manifest_check = boot_policy_manifests_get().ordered[0];
      break;
    case kCfiRomTryBootRomExtManifest1Val:
      HARDENED_CHECK_EQ(rom_counters[kCfiRomTryBootRomExt],
                        kCfiRomTryBootRomExtManifest1Val);
      manifest_check = boot_policy_manifests_get().ordered[1];
      break;
    default:
      HARDENED_TRAP();
  }
  HARDENED_CHECK_EQ(manifest, manifest_check);

#if OT_BUILD_FOR_STATIC_ANALYZER
  assert(manifest_check != NULL);
#endif

  if (launder32(manifest_check->address_translation) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(manifest_check->address_translation, kHardenedBoolTrue);
    HARDENED_CHECK_EQ(rom_ext_vma_get(manifest_check,
                                      manifest_entry_point_get(manifest_check)),
                      _entry_point);
  } else {
    HARDENED_CHECK_EQ(manifest_check->address_translation, kHardenedBoolFalse);
    HARDENED_CHECK_EQ(manifest_entry_point_get(manifest_check), _entry_point);
  }
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomBootRomExt, 7);

  // In a normal build, this function inlines to nothing.
  stack_utilization_print();

  if (imm_section_entry_point != kHardenedBoolFalse) {
    ((entry_point *)imm_section_entry_point)();
  }
  // Jump to ROM_EXT.
  ((entry_point *)_entry_point)();
  return kErrorRomBootFailed;
}

#ifdef DISCRETE_OTP_MAP
rom_error_t rom_verify_immutable_section(rom_error_t verify_result,
                                         const manifest_t *manifest,
                                         uintptr_t *imm_section_entry_point) {
  *imm_section_entry_point = kHardenedBoolFalse;
  // Verify the immutable ROM_EXT section.
  uint32_t rom_ext_immutable_section_enabled =
      otp_read32(OTP_CTRL_PARAM_CREATOR_SW_CFG_IMMUTABLE_ROM_EXT_EN_OFFSET);
  if (launder32(rom_ext_immutable_section_enabled) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(rom_ext_immutable_section_enabled, kHardenedBoolTrue);
    // Get offset and length of immutable ROM_EXT code partition.
    uintptr_t immutable_rom_ext_start_offset = (uintptr_t)otp_read32(
        OTP_CTRL_PARAM_CREATOR_SW_CFG_IMMUTABLE_ROM_EXT_START_OFFSET_OFFSET);
    size_t immutable_rom_ext_length = (size_t)otp_read32(
        OTP_CTRL_PARAM_CREATOR_SW_CFG_IMMUTABLE_ROM_EXT_LENGTH_OFFSET);
    uintptr_t immutable_rom_ext_entry_point =
        (uintptr_t)manifest + immutable_rom_ext_start_offset;

    // Compute a hash of the code section.
    // Include the start offset and the length of the section in the hash.
    hmac_sha256_init();
    hmac_sha256_update(&immutable_rom_ext_start_offset,
                       /*len=*/sizeof(uintptr_t));
    hmac_sha256_update(&immutable_rom_ext_length, /*len=*/sizeof(size_t));
    hmac_sha256_update((const void *)immutable_rom_ext_entry_point,
                       immutable_rom_ext_length);
    hmac_sha256_process();
    hmac_digest_t actual_immutable_section_digest;
    hmac_sha256_final(&actual_immutable_section_digest);

    // Validate the hash matches that in OTP, and if so execute the code.
    // Otherwise, trigger shutdown via hardened check fail.
    hmac_digest_t immutable_rom_ext_hash;
    otp_read(OTP_CTRL_PARAM_CREATOR_SW_CFG_IMMUTABLE_ROM_EXT_SHA256_HASH_OFFSET,
             immutable_rom_ext_hash.digest, kHmacDigestNumWords);
    for (size_t i = 0; i < kHmacDigestNumWords; ++i) {
      if (immutable_rom_ext_hash.digest[i] !=
          actual_immutable_section_digest.digest[i]) {
        verify_result = kErrorRomImmSection;
      }
    }
    // If address translation is enabled, adjust the entry_point.
    if (launder32(manifest->address_translation) == kHardenedBoolTrue) {
      HARDENED_CHECK_EQ(manifest->address_translation, kHardenedBoolTrue);
      immutable_rom_ext_entry_point =
          rom_ext_vma_get(manifest, immutable_rom_ext_entry_point);
    } else {
      HARDENED_CHECK_NE(manifest->address_translation, kHardenedBoolTrue);
    }
    if (verify_result == kErrorOk) {
      *imm_section_entry_point = immutable_rom_ext_entry_point;
    }
  } else {
    HARDENED_CHECK_NE(rom_ext_immutable_section_enabled, kHardenedBoolTrue);
  }
  return verify_result;
}
#endif

/**
 * Attempts to boot ROM_EXTs in the order given by the boot policy module. In
 * dual-ROM designs, this is invoked in the second-stage ROM.
 *
 * Note: This function should not return under normal conditions. Any returns
 * from this function must result in shutdown.
 *
 * @return Result of the last attempt.
 */
OT_WARN_UNUSED_RESULT
rom_error_t rom_try_boot_rom_ext(const lifecycle_state_t lc_state) {
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomTryBootRomExt, 1);

  boot_policy_manifests_t manifests = boot_policy_manifests_get();
  uint32_t flash_exec = 0;
  uintptr_t imm_section_entry_point = kHardenedBoolFalse;

  // Read boot data.
  HARDENED_RETURN_IF_ERROR(boot_data_read(lc_state, &boot_data));

  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomTryBootRomExt, 2,
                            kCfiRomVerifyRomExt);
  rom_error_t error = rom_verify(manifests.ordered[0], boot_data, lc_state,
                                 &sigverify_ctx, &flash_exec);
#ifdef DISCRETE_OTP_MAP
  error = rom_verify_immutable_section(error, manifests.ordered[0],
                                       &imm_section_entry_point);
#endif
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomTryBootRomExt, 4);

  if (launder32(error) == kErrorOk) {
    HARDENED_CHECK_EQ(error, kErrorOk);
    CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomVerifyRomExt, 4);
    CFI_FUNC_COUNTER_INIT(rom_counters, kCfiRomTryBootRomExt);
    CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomTryBootRomExt, 1,
                              kCfiRomBootRomExt);
    HARDENED_RETURN_IF_ERROR(rom_boot_rom_ext(
        manifests.ordered[0], lc_state, imm_section_entry_point, flash_exec));
    return kErrorRomBootFailed;
  }
  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomTryBootRomExt, 5,
                            kCfiRomVerifyRomExt);
  error = rom_verify(manifests.ordered[1], boot_data, lc_state, &sigverify_ctx,
                     &flash_exec);
#ifdef DISCRETE_OTP_MAP
  HARDENED_RETURN_IF_ERROR(rom_verify_immutable_section(
      error, manifests.ordered[1], &imm_section_entry_point));
#endif
  CFI_FUNC_COUNTER_INCREMENT(rom_counters, kCfiRomTryBootRomExt, 7);
  CFI_FUNC_COUNTER_CHECK(rom_counters, kCfiRomVerifyRomExt, 4);

  CFI_FUNC_COUNTER_PREPCALL(rom_counters, kCfiRomTryBootRomExt, 8,
                            kCfiRomBootRomExt);
  HARDENED_RETURN_IF_ERROR(rom_boot_rom_ext(
      manifests.ordered[1], lc_state, imm_section_entry_point, flash_exec));
  return kErrorRomBootFailed;
}
