// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Register one block test for shared CSR, memory, and TL workloads. Keep the existing block
// configuration, including its RAL and alert settings; CIP selects and runs each sequence.
class ${module_instance_name}_rst_safe_common_test extends cip_rst_safe_common_test #(
    .RAL_T(${module_instance_name}_reg_block),
    .CFG_T(${module_instance_name}_env_cfg),
    .ENV_T(${module_instance_name}_rst_safe_common_env)
  );
  `uvm_component_utils(${module_instance_name}_rst_safe_common_test)
  `uvm_component_new
endclass : ${module_instance_name}_rst_safe_common_test
