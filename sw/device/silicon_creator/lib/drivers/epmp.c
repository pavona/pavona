// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/drivers/epmp.h"

#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/csr.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/silicon_creator/lib/epmp_state.h"

#define EPMP_SET(cfg_reg, addr_reg, mask, cfg, addr) \
  CSR_CLEAR_BITS(CSR_REG_PMPCFG##cfg_reg, mask);     \
  CSR_WRITE(CSR_REG_PMPADDR##addr_reg, pmpaddr);     \
  CSR_SET_BITS(CSR_REG_PMPCFG##cfg_reg, cfg);

void epmp_set(uint8_t entry, uint32_t pmpcfg, uint32_t pmpaddr) {
  uint32_t shift = 8 * (entry % 4);
  uint32_t mask = 0xFFu << shift;
  uint32_t cfg = (pmpcfg & 0xFFu) << shift;
  HARDENED_CHECK_LT(entry, 16);
  switch (entry) {
      // clang-format off
    case  0: EPMP_SET(0,  0, mask, cfg, pmpaddr); break;
    case  1: EPMP_SET(0,  1, mask, cfg, pmpaddr); break;
    case  2: EPMP_SET(0,  2, mask, cfg, pmpaddr); break;
    case  3: EPMP_SET(0,  3, mask, cfg, pmpaddr); break;
    case  4: EPMP_SET(1,  4, mask, cfg, pmpaddr); break;
    case  5: EPMP_SET(1,  5, mask, cfg, pmpaddr); break;
    case  6: EPMP_SET(1,  6, mask, cfg, pmpaddr); break;
    case  7: EPMP_SET(1,  7, mask, cfg, pmpaddr); break;
    case  8: EPMP_SET(2,  8, mask, cfg, pmpaddr); break;
    case  9: EPMP_SET(2,  9, mask, cfg, pmpaddr); break;
    case 10: EPMP_SET(2, 10, mask, cfg, pmpaddr); break;
    case 11: EPMP_SET(2, 11, mask, cfg, pmpaddr); break;
    case 12: EPMP_SET(3, 12, mask, cfg, pmpaddr); break;
    case 13: EPMP_SET(3, 13, mask, cfg, pmpaddr); break;
    case 14: EPMP_SET(3, 14, mask, cfg, pmpaddr); break;
    case 15: EPMP_SET(3, 15, mask, cfg, pmpaddr); break;
    // clang-format on
    default:
      // should be impossible to get here because of HARDENED_CHECK_LT above.
      HARDENED_TRAP();
  }
  uint32_t cfgent = entry / 4;
  epmp_state.pmpcfg[cfgent] = (epmp_state.pmpcfg[cfgent] & ~mask) | cfg;
  epmp_state.pmpaddr[entry] = pmpaddr;
}

void epmp_clear(uint8_t entry) { epmp_set(entry, kEpmpModeOff, 0); }

void epmp_clear_lock_bits(void) {
  const uint32_t mask =
      ((uint32_t)EPMP_CFG_L << 0 * 8) | ((uint32_t)EPMP_CFG_L << 1 * 8) |
      ((uint32_t)EPMP_CFG_L << 2 * 8) | ((uint32_t)EPMP_CFG_L << 3 * 8);
  CSR_CLEAR_BITS(CSR_REG_PMPCFG0, mask);
  CSR_CLEAR_BITS(CSR_REG_PMPCFG1, mask);
  CSR_CLEAR_BITS(CSR_REG_PMPCFG2, mask);
  CSR_CLEAR_BITS(CSR_REG_PMPCFG3, mask);
  for (int cfgent = 0; cfgent < 4; ++cfgent) {
    epmp_state.pmpcfg[cfgent] &= ~mask;
  }
}

void epmp_set_lock_bits(void) {
  const uint32_t mask =
      ((uint32_t)EPMP_CFG_L << 0 * 8) | ((uint32_t)EPMP_CFG_L << 1 * 8) |
      ((uint32_t)EPMP_CFG_L << 2 * 8) | ((uint32_t)EPMP_CFG_L << 3 * 8);
  CSR_SET_BITS(CSR_REG_PMPCFG0, mask);
  CSR_SET_BITS(CSR_REG_PMPCFG1, mask);
  CSR_SET_BITS(CSR_REG_PMPCFG2, mask);
  CSR_SET_BITS(CSR_REG_PMPCFG3, mask);
  for (int cfgent = 0; cfgent < 4; ++cfgent) {
    epmp_state.pmpcfg[cfgent] |= mask;
  }
}

uint32_t epmp_encode_napot(epmp_region_t region) {
  const uint32_t length = region.end - region.start;
  // The length must be 4 or more.
  HARDENED_CHECK_GE(length, 4);
  // The length must be a power of 2.
  HARDENED_CHECK_EQ(bitfield_popcount32(length), 1);
  // The start address must be naturally aligned with length.
  HARDENED_CHECK_EQ(region.start & (length - 1), 0);
  return (region.start >> 2) | ((length - 1) >> 3);
}

epmp_region_t epmp_decode_napot(uint32_t pmpaddr) {
  HARDENED_CHECK_NE(pmpaddr, UINT32_MAX);
  uint32_t size = 1u << bitfield_count_trailing_zeroes32(~pmpaddr);
  pmpaddr = (pmpaddr & ~(size - 1)) << 2;
  size <<= 3;
  return (epmp_region_t){.start = pmpaddr, .end = pmpaddr + size};
}

void epmp_set_napot(uint8_t entry, epmp_region_t region, epmp_perm_t perm) {
  uint32_t addr = epmp_encode_napot(region);
  epmp_mode_t mode =
      region.end - region.start == 4 ? kEpmpModeNa4 : kEpmpModeNapot;
  epmp_set(entry, (uint32_t)mode | (uint32_t)perm, addr);
}

void epmp_set_tor(uint8_t entry, epmp_region_t region, epmp_perm_t perm) {
  uint32_t start = region.start >> 2;
  uint32_t end = ((region.end + 3u) & ~3u) >> 2;
  epmp_set(entry, kEpmpModeOff, start);
  epmp_set(entry + 1, (uint32_t)kEpmpModeTor | (uint32_t)perm, end);
}

void epmp_clear_rlb(void) {
  const uint32_t kMask = EPMP_MSECCFG_RLB;
  epmp_state.mseccfg &= ~kMask;
  CSR_CLEAR_BITS(CSR_REG_MSECCFG, kMask);
}

/* Helpers for managing ePMP across boot stages. */

/**
 * Updates the ePMP permissions to revoke access rights to the previous boot
 * stage, overwriting its slots with the configuration for the current boot
 * stage, in preparation for the next `epmp_prepare_boot_stage`, which will
 * overwrite the slots previously used by the current boot stage (as set by the
 * previous boot stage calling `epmp_prepare_boot_stage`).
 */
void epmp_advance_boot_stage(void) {
  // Shift the slots for the current boot stage (slots 3-5) into slots 0-2,
  // revoking access to the previous boot stage.
  uint32_t rx_lo, rx_hi, r;
  CSR_READ(CSR_REG_PMPADDR3, &rx_lo);
  CSR_READ(CSR_REG_PMPADDR4, &rx_hi);
  CSR_READ(CSR_REG_PMPADDR5, &r);
  uint32_t r_pmpcfg;
  if (r == 0) {
    HARDENED_CHECK_EQ(r, 0);
    r_pmpcfg = kEpmpModeOff;
  } else {
    HARDENED_CHECK_NE(r, 0);
    r_pmpcfg = kEpmpModeNapot | kEpmpPermLockedReadOnly;
  }
  epmp_set(0, kEpmpModeOff, rx_lo);
  epmp_set(1, kEpmpModeTor | kEpmpPermLockedReadExecute, rx_hi);
  epmp_set(2, r_pmpcfg, r);
  epmp_set(3, kEpmpModeOff, 0);
  epmp_set(4, kEpmpModeOff, 0);
  epmp_set(5, kEpmpModeOff, 0);
}

/**
 * Prepares ePMP to execute the next boot stage by configuring the slots
 * previously vacated by the current boot stage in `epmp_advance_boot_stage` to
 * permit access to the next boot stage.
 *
 * @param tor_region_rx The TOR region covering the executable portion of the
 * current boot stage.
 * @param napot_region_rx The NAPOT region covering the entire current boot
 * stage.
 */
inline void epmp_prepare_boot_stage(epmp_region_t tor_region_rx,
                                    epmp_region_t napot_region_r) {
  // Configure the next boot stage in slots 3-5.
  epmp_set_tor(3, tor_region_rx, kEpmpPermLockedReadExecute);
  epmp_set_napot(5, napot_region_r, kEpmpPermLockedReadOnly);
}

/**
 * Prepares ePMP to execute the next boot stage by configuring the slots
 * previously vacated by the current boot stage in `epmp_advance_boot_stage` to
 * permit access to the next boot stage. Unlike `epmp_prepare_boot_stage`, this
 * function only accepts a read-execute TOR region, and the slot used for the
 * read-only NAPOT region is cleared instead.
 *
 * @param tor_region_rx The TOR region covering the current boot stage.
 */
inline void epmp_prepare_boot_stage_rx(epmp_region_t tor_region_rx) {
  // Configure the next boot stage in slots 3-4.
  epmp_set_tor(3, tor_region_rx, kEpmpPermLockedReadExecute);
}
