// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Register one block test for shared CSR, memory, and TL workloads. Keep the existing block
// configuration, including its RAL and alert settings; CIP selects and runs each sequence.
class ac_range_check_rst_safe_common_test extends cip_rst_safe_common_test #(
    .RAL_T(ac_range_check_reg_block),
    .CFG_T(ac_range_check_env_cfg),
    .ENV_T(ac_range_check_rst_safe_common_env)
  );
  `uvm_component_utils(ac_range_check_rst_safe_common_test)
  `uvm_component_new
endclass : ac_range_check_rst_safe_common_test
