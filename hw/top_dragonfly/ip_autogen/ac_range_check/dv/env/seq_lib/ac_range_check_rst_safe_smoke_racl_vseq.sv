// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// RACL-focused reset-safe smoke variant. All enabled range attributes permit read, write, and
// execute accesses, while the read and write RACL policy masks are randomized across their full
// range. This isolates RACL permission decisions from ordinary range-attribute denials while the
// inherited smoke sequence supplies randomized live TLUL traffic and checking.

class ac_range_check_smoke_racl_config_parameters
    extends ac_range_check_smoke_config_parameters;
  `uvm_object_utils(ac_range_check_smoke_racl_config_parameters)

  constraint range_attr_c {
    foreach (dut_cfg.range_base[i]) {
      // Keep ordinary range permissions open so a denial is attributable to RACL policy.
      dut_cfg.range_attr[i].execute_access == 1;
      dut_cfg.range_attr[i].write_access   == 1;
      dut_cfg.range_attr[i].read_access    == 1;
      dut_cfg.range_attr[i].enable dist {
        0 :/ 1,
        1 :/ 2
      };
    }
  }

  constraint range_racl_policy_c {
    foreach (dut_cfg.range_racl_policy[i]) {
      // Exercise every possible set of permitted RACL roles.
      dut_cfg.range_racl_policy[i].write_perm inside {[16'h0000:16'hFFFF]};
      dut_cfg.range_racl_policy[i].read_perm  inside {[16'h0000:16'hFFFF]};
    }
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : ac_range_check_smoke_racl_config_parameters

class ac_range_check_rst_safe_smoke_racl_vseq
    extends ac_range_check_rst_safe_smoke_vseq;
  `uvm_object_utils(ac_range_check_rst_safe_smoke_racl_vseq)

  extern function new(string name = "");
  extern virtual task body();
endclass : ac_range_check_rst_safe_smoke_racl_vseq

function ac_range_check_rst_safe_smoke_racl_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ac_range_check_rst_safe_smoke_racl_vseq::body();
  if (config_params == null) begin
    config_params =
        ac_range_check_smoke_racl_config_parameters::type_id::create("config_params");
  end
  super.body();
endtask : body
