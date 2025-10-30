// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class flash_macro_item extends uvm_sequence_item;

  `uvm_object_utils_begin(flash_macro_item)
  `uvm_object_utils_end

  flash_phy_macro_bank_req_t req;
  flash_phy_macro_bank_rsp_t rsp;

  fdata_q_t fq;
  `uvm_object_new

endclass
