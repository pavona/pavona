// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "${module_instance_name}_base_vseq.sv"
`include "${module_instance_name}_smoke_vseq.sv"
`include "${module_instance_name}_smoke_racl_vseq.sv"
`include "${module_instance_name}_smoke_high_threshold_vseq.sv"
`include "${module_instance_name}_bypass_vseq.sv"
`include "${module_instance_name}_lock_range_vseq.sv"
`include "${module_instance_name}_common_vseq.sv"
`include "${module_instance_name}_stress_all_vseq.sv"

`include "${module_instance_name}_rand_rst_safe_base_vseq.sv"
`include "${module_instance_name}_rst_safe_cov_base_vseq.sv"
`include "${module_instance_name}_rst_safe_smoke_vseq.sv"
`include "${module_instance_name}_rst_safe_smoke_racl_vseq.sv"
`include "${module_instance_name}_rst_safe_smoke_high_threshold_vseq.sv"
`include "${module_instance_name}_rst_safe_bypass_vseq.sv"
`include "${module_instance_name}_rst_safe_lock_range_with_rand_reset_vseq.sv"
`include "${module_instance_name}_rst_safe_smoke_with_rand_reset_vseq.sv"
`include "${module_instance_name}_rst_safe_stress_all_vseq.sv"
`include "${module_instance_name}_rst_safe_stress_all_with_rand_reset_vseq.sv"
`include "${module_instance_name}_rst_safe_racl_cov_vseq.sv"
`include "${module_instance_name}_rst_safe_attr_cov_vseq.sv"
`include "${module_instance_name}_rst_safe_log_intr_cov_vseq.sv"
`include "${module_instance_name}_rst_safe_lock_cov_vseq.sv"
`include "${module_instance_name}_rst_safe_mubi_cov_vseq.sv"
`include "${module_instance_name}_rst_safe_tl_cov_vseq.sv"
