// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Closes every index, permission pattern, access-type, and access-decision cross.
class ac_range_check_rst_safe_attr_cov_vseq
    extends ac_range_check_rst_safe_cov_base_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_attr_cov_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
endclass : ac_range_check_rst_safe_attr_cov_vseq

function ac_range_check_rst_safe_attr_cov_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_attr_cov_vseq::main_thread();
  initialize_directed_inputs();
  start_filtered_responder();

  for (int unsigned idx = 0; idx < NUM_RANGES; idx++) begin
    configure_fixed_range(idx);
    for (int unsigned permissions = 0; permissions < 8; permissions++) begin
      write_range_attr_raw(idx,
                           MuBi4True,
                           mubi4_bool_to_mubi(permissions[0]),
                           mubi4_bool_to_mubi(permissions[1]),
                           mubi4_bool_to_mubi(permissions[2]),
                           MuBi4False);
      send_access(idx, Read);
      send_access(idx, Write);
      send_access(idx, Execute);
    end
  end
endtask : main_thread
