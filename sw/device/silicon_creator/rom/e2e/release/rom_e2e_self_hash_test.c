// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>

#include "hw/top/dt/rom_ctrl.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/silicon_creator/lib/chip_info.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"

OTTF_DEFINE_TEST_CONFIG(.silence_console_prints = true);

enum {
  // Hash size.
  kSha256HashSizeInBits = 256,
  kSha256HashSizeInBytes = kSha256HashSizeInBits / 8,
  kSha256HashSizeIn32BitWords = kSha256HashSizeInBytes / 4,
};

/**
 * The golden ROM size and hashes expected below are generated using the
 * following instructions. If the ROM is updated, these values must also be
 * updated to prevent CI failures.
 *
 * 1. Build the ROM and query the ROM hashes:
 *    bazel build //sw/device/silicon_creator/rom:rom_hashes
 *    cat bazel-bin/sw/device/silicon_creator/rom/rom_hashes.txt
 *
 * 2. Update the size and golden ROM hashes below (`k*GoldenRomHash`) by
 *    copying the little-endian-32 value arrays from the `rom_hashes.txt`
 *    report.
 */

#ifdef OPENTITAN_IS_EGRET
const size_t kGoldenRom0SizeBytes = TOP_EGRET_ROM_CTRL0_ROM_SIZE_BYTES - 116 - sizeof(chip_info_t);
const uint32_t kSimDvGoldenRom0Hash[kSha256HashSizeIn32BitWords] = {
    0xc16e04d6, 0x2e94b881, 0x0759b405, 0xd0a28cde,
    0xa8c900f3, 0x57b8c7f6, 0xacc910b0, 0x43000c0a,
};
const uint32_t kFpgaCw310GoldenRom0Hash[kSha256HashSizeIn32BitWords] = {
    0xf3508c51, 0xef65a542, 0xc20e55d9, 0xada4c934,
    0x8015bbca, 0xa863db5a, 0xd1ead827, 0x968d94cb,
};
const uint32_t kSiliconGoldenRom0Hash[kSha256HashSizeIn32BitWords] = {
    0x43b60e89, 0xbfa80347, 0xeeceb60a, 0x356bc7f1,
    0xbd023b8a, 0xe5a4ddfc, 0xf66b45b5, 0x5b2ba0ba,
};
#elif OPENTITAN_IS_DRAGONFLY
#define HAS_ROM_CTRL1

const size_t kGoldenRom0SizeBytes = TOP_DRAGONFLY_ROM_CTRL0_ROM_SIZE_BYTES - 116 - sizeof(chip_info_t);
const size_t kGoldenRom1SizeBytes = TOP_DRAGONFLY_ROM_CTRL1_ROM_SIZE_BYTES - 116 - sizeof(chip_info_t);
const uint32_t kSimDvGoldenRom0Hash[kSha256HashSizeIn32BitWords] = {
    0xc16e04d6, 0x2e94b881, 0x0759b405, 0xd0a28cde,
    0xa8c900f3, 0x57b8c7f6, 0xacc910b0, 0x43000c0a,
};
const uint32_t kFpgaCw310GoldenRom0Hash[kSha256HashSizeIn32BitWords] = {
    0xf3508c51, 0xef65a542, 0xc20e55d9, 0xada4c934,
    0x8015bbca, 0xa863db5a, 0xd1ead827, 0x968d94cb,
};
const uint32_t kSiliconGoldenRom0Hash[kSha256HashSizeIn32BitWords] = {
    0x43b60e89, 0xbfa80347, 0xeeceb60a, 0x356bc7f1,
    0xbd023b8a, 0xe5a4ddfc, 0xf66b45b5, 0x5b2ba0ba,
};
const uint32_t kSimDvGoldenRom1Hash[kSha256HashSizeIn32BitWords] = {
    0xc16e04d6, 0x2e94b881, 0x0759b405, 0xd0a28cde,
    0xa8c900f3, 0x57b8c7f6, 0xacc910b0, 0x43000c0a,
};
const uint32_t kFpgaCw310GoldenRom1Hash[kSha256HashSizeIn32BitWords] = {
    0xf3508c51, 0xef65a542, 0xc20e55d9, 0xada4c934,
    0x8015bbca, 0xa863db5a, 0xd1ead827, 0x968d94cb,
};
const uint32_t kSiliconGoldenRom1Hash[kSha256HashSizeIn32BitWords] = {
    0x43b60e89, 0xbfa80347, 0xeeceb60a, 0x356bc7f1,
    0xbd023b8a, 0xe5a4ddfc, 0xf66b45b5, 0x5b2ba0ba,
};
#endif

#ifdef HAS_ROM_CTRL1
extern const char _rom0_chip_info_start[];
extern const char _rom1_chip_info_start[];

uint32_t rom0_base_addr(void) {
  return dt_rom_ctrl_memory_base(kDtRomCtrl0, kDtRomCtrlMemoryRom);
}
uint32_t rom1_base_addr(void) {
  return dt_rom_ctrl_memory_base(kDtRomCtrl1, kDtRomCtrlMemoryRom);
}
#else
extern const char _rom_chip_info_start[];

uint32_t rom0_base_addr(void) {
  return dt_rom_ctrl_memory_base(kDtRomCtrl, kDtRomCtrlMemoryRom);
}
#endif

// We hash the ROM0 using the SHA256 algorithm and print the hash to the
// console.
status_t hash_rom0(void) {
  hmac_digest_t rom0_hash;
  hmac_sha256((void *)rom0_base_addr(), kGoldenRom0SizeBytes, &rom0_hash);
  // Use printf directly here instead of the `LOG()` macros which print extra
  // filenames and line numbers which bloat DV and GLS runtimes.
  // DO NOT MODIFY the printf immediately below without modifying the check in
  // `hw/top_egret/dv/env/seq_lib/chip_sw_rom_e2e_self_hash_gls_vseq.sv`
  base_printf("ROM Hash: 0x%08x%08x%08x%08x%08x%08x%08x%08x\r\n",
              rom0_hash.digest[7], rom0_hash.digest[6], rom0_hash.digest[5],
              rom0_hash.digest[4], rom0_hash.digest[3], rom0_hash.digest[2],
              rom0_hash.digest[1], rom0_hash.digest[0]);
#ifdef HAS_ROM_CTRL1
  chip_info_t *rom_chip_info = (chip_info_t *)_rom0_chip_info_start;
#else
  chip_info_t *rom_chip_info = (chip_info_t *)_rom_chip_info_start;
#endif
  LOG_INFO("rom0_chip_info @ %p:", rom_chip_info);
  LOG_INFO("scm_revision = %08x%08x",
           rom_chip_info->scm_revision.scm_revision_high,
           rom_chip_info->scm_revision.scm_revision_low);
  LOG_INFO("version = %08x", rom_chip_info->version);

  // TODO(#18868) Add checks for the chip_info values we expect to see in the
  // released ROM binary.

  if (kDeviceType == kDeviceSimDV) {
    TRY_CHECK_ARRAYS_EQ(rom0_hash.digest, kSimDvGoldenRom0Hash,
                        ARRAYSIZE(kSimDvGoldenRom0Hash));
  } else if (kDeviceType == kDeviceFpgaCw310) {
    TRY_CHECK_ARRAYS_EQ(rom0_hash.digest, kFpgaCw310GoldenRom0Hash,
                        ARRAYSIZE(kFpgaCw310GoldenRom0Hash));
  } else if (kDeviceType == kDeviceSilicon) {
    TRY_CHECK_ARRAYS_EQ(rom0_hash.digest, kSiliconGoldenRom0Hash,
                        ARRAYSIZE(kSiliconGoldenRom0Hash));
  } else {
    LOG_ERROR("ROM hash not self-checked for this device type: 0x%x",
              kDeviceType);
    return INTERNAL();
  }

  return OK_STATUS();
};

#ifdef HAS_ROM_CTRL1
// We hash the ROM1 using the SHA256 algorithm and print the hash to the
// console.
status_t hash_rom1(void) {
  hmac_digest_t rom1_hash;
  hmac_sha256((void *)rom0_base_addr(), kGoldenRom1SizeBytes, &rom1_hash);
  // Use printf directly here instead of the `LOG()` macros which print extra
  // filenames and line numbers which bloat DV and GLS runtimes.
  // DO NOT MODIFY the printf immediately below without modifying the check in
  // `hw/top_egret/dv/env/seq_lib/chip_sw_rom_e2e_self_hash_gls_vseq.sv`
  base_printf("ROM Hash: 0x%08x%08x%08x%08x%08x%08x%08x%08x\r\n",
              rom1_hash.digest[7], rom1_hash.digest[6], rom1_hash.digest[5],
              rom1_hash.digest[4], rom1_hash.digest[3], rom1_hash.digest[2],
              rom1_hash.digest[1], rom1_hash.digest[0]);
  chip_info_t *rom_chip_info = (chip_info_t *)_rom1_chip_info_start;
  LOG_INFO("rom1_chip_info @ %p:", rom_chip_info);
  LOG_INFO("scm_revision = %08x%08x",
           rom_chip_info->scm_revision.scm_revision_high,
           rom_chip_info->scm_revision.scm_revision_low);
  LOG_INFO("version = %08x", rom_chip_info->version);

  // TODO(#18868) Add checks for the chip_info values we expect to see in the
  // released ROM binary.

  if (kDeviceType == kDeviceSimDV) {
    TRY_CHECK_ARRAYS_EQ(rom1_hash.digest, kSimDvGoldenRom1Hash,
                        ARRAYSIZE(kSimDvGoldenRom0Hash));
  } else if (kDeviceType == kDeviceFpgaCw310) {
    TRY_CHECK_ARRAYS_EQ(rom1_hash.digest, kFpgaCw310GoldenRom1Hash,
                        ARRAYSIZE(kFpgaCw310GoldenRom1Hash));
  } else if (kDeviceType == kDeviceSilicon) {
    TRY_CHECK_ARRAYS_EQ(rom1_hash.digest, kSiliconGoldenRom1Hash,
                        ARRAYSIZE(kSiliconGoldenRom1Hash));
  } else {
    LOG_ERROR("ROM hash not self-checked for this device type: 0x%x",
              kDeviceType);
    return INTERNAL();
  }

  return OK_STATUS();
};
#endif

bool test_main(void) {
#ifdef HAS_ROM_CTRL1
  return status_ok(hash_rom0()) && status_ok(hash_rom1());
#else
  return status_ok(hash_rom0());
#endif
}
