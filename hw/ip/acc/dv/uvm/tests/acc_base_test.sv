// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_base_test extends cip_base_test #(
    .CFG_T(acc_env_cfg),
    .ENV_T(acc_env)
  );

  `uvm_component_utils(acc_base_test)
  `uvm_component_new

  // the base class dv_base_test creates the following instances:
  // acc_env_cfg: cfg
  // acc_env:     env

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!$value$plusargs("acc_elf_dir=%0s", cfg.acc_elf_dir)) begin
      `uvm_fatal(`gfn, "Missing required plusarg: acc_elf_dir.")
    end
  endfunction

endclass : acc_base_test
