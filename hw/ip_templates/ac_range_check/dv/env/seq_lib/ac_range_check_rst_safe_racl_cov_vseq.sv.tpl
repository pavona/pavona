// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Closes every index, role, access-type, and RACL decision cross.
class ${module_instance_name}_rst_safe_racl_cov_vseq
    extends ${module_instance_name}_rst_safe_cov_base_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_racl_cov_vseq)

  extern function new(string name = "");
  extern virtual task main_thread();
endclass : ${module_instance_name}_rst_safe_racl_cov_vseq

function ${module_instance_name}_rst_safe_racl_cov_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ${module_instance_name}_rst_safe_racl_cov_vseq::main_thread();
  initialize_directed_inputs();
  start_filtered_responder();

  for (int unsigned idx = 0; idx < NUM_RANGES; idx++) begin
    configure_fixed_range(idx);
  end

  for (int unsigned decision = 0; decision < 2; decision++) begin
    for (int unsigned idx = 0; idx < NUM_RANGES; idx++) begin
      bit [15:0] permissions = decision ? 16'hffff : 16'h0000;
      write_racl_policy(idx, permissions, permissions);
      for (int unsigned role = 0; role < NUM_ROLES; role++) begin
        send_access(idx, Read, role);
        send_access(idx, Write, role);
        send_access(idx, Execute, role);
      end
    end
  end
endtask : main_thread
