// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_MMAP_FLASH_INFO_TYPES_H_
#define OPENTITAN_SW_DEVICE_LIB_MMAP_FLASH_INFO_TYPES_H_

/**
 * A struct for storing base, config write-enable register, and config register
 * addresses of an info page.
 */
typedef struct flash_ctrl_info_page {
  /**
   * Base address.
   */
  uint32_t base_addr;
  /**
   * Config write-enable register address (offset from register base).
   */
  uint32_t cfg_wen_offset;
  /**
   * Config register address (offset from register base).
   */
  uint32_t cfg_offset;
} flash_ctrl_info_page_t;

#endif  // OPENTITAN_SW_DEVICE_LIB_MMAP_FLASH_INFO_TYPES_H_
