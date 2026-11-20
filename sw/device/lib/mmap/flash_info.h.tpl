// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
<%
import textwrap
import topgen.lib as lib
%>\

#include "hw/top/dt/flash_ctrl.h"
#include "hw/top/flash_ctrl_regs.h"
#include "sw/device/lib/mmap/flash_info_types.h"

#ifndef OPENTITAN_SW_DEVICE_LIB_MMAP_FLASH_INFO_H_
#define OPENTITAN_SW_DEVICE_LIB_MMAP_FLASH_INFO_H_

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

% for bank_num, type_num, page_num, only_in_type, page in flash_info_mmap.all_pages():
<%
reg_page_num = "" if only_in_type else "_" + str(page_num)
%>
static const flash_ctrl_info_page_t FLASH_CTRL_INFO_PAGE_${page["name"]} = {
  .base_addr = ${bank_num} * FLASH_CTRL_PARAM_BYTES_PER_BANK +
               ((FLASH_CTRL_PARAM_INFOS${type_num}_OFFSET + ${page_num}) *
               FLASH_CTRL_PARAM_BYTES_PER_PAGE),
  .cfg_wen_offset =
      FLASH_CTRL_BANK${bank_num}_INFO${type_num}_REGWEN${reg_page_num}_REG_OFFSET,
  .cfg_offset =
      FLASH_CTRL_BANK${bank_num}_INFO${type_num}_PAGE_CFG${reg_page_num}_REG_OFFSET,
};

% endfor

// Header Extern Guard
#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // OPENTITAN_SW_DEVICE_LIB_MMAP_FLASH_INFO_H_
