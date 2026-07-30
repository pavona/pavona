// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ${module_instance_name}_smoke_high_threshold_config_parameters
    extends ${module_instance_name}_smoke_config_parameters;
  import ${module_instance_name}_reg_pkg::*;
  `uvm_object_utils(${module_instance_name}_smoke_high_threshold_config_parameters)

  constraint range_attr_c {
    foreach (dut_cfg.range_base[i]) {
      dut_cfg.range_attr[i].execute_access dist {
        0 :/ 9,
        1 :/ 1
      };
      dut_cfg.range_attr[i].write_access dist {
        0 :/ 9,
        1 :/ 1
      };
      dut_cfg.range_attr[i].read_access dist {
        0 :/ 9,
        1 :/ 1
      };
      dut_cfg.range_attr[i].enable dist {
        0 :/ 9,
        1 :/ 1
      };
    }
  }

  constraint deny_cnt_threshold_c {
    if (apply_deny_cnt_threshold_c) {
      deny_cnt_threshold inside {[(1 << DenyCountWidth)-6 : (1 << DenyCountWidth)-1]};
    } else {
      deny_cnt_threshold == fixed_deny_cnt_threshold;
    }
  }

  function new(string name = "");
    super.new(name);
  endfunction : new
endclass : ${module_instance_name}_smoke_high_threshold_config_parameters

class ${module_instance_name}_rst_safe_smoke_high_threshold_vseq
    extends ${module_instance_name}_rst_safe_smoke_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_smoke_high_threshold_vseq)

  extern function new(string name = "");
  extern virtual task body();
endclass : ${module_instance_name}_rst_safe_smoke_high_threshold_vseq

function ${module_instance_name}_rst_safe_smoke_high_threshold_vseq::new(string name = "");
  super.new(name);
endfunction : new

task ${module_instance_name}_rst_safe_smoke_high_threshold_vseq::body();
  if (config_params == null) begin
    config_params =
        ${module_instance_name}_smoke_high_threshold_config_parameters::type_id::create(
            "config_params");
  end
  super.body();
endtask : body
