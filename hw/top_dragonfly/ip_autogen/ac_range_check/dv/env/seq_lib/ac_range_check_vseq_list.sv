// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "ac_range_check_base_vseq.sv"
`include "ac_range_check_smoke_vseq.sv"
`include "ac_range_check_smoke_racl_vseq.sv"
`include "ac_range_check_smoke_high_threshold_vseq.sv"
`include "ac_range_check_bypass_vseq.sv"
`include "ac_range_check_lock_range_vseq.sv"
`include "ac_range_check_common_vseq.sv"
`include "ac_range_check_stress_all_vseq.sv"

`include "ac_range_check_rand_rst_safe_base_vseq.sv"
`include "ac_range_check_rst_safe_cov_base_vseq.sv"
`include "ac_range_check_rst_safe_smoke_vseq.sv"
`include "ac_range_check_rst_safe_smoke_racl_vseq.sv"
`include "ac_range_check_rst_safe_smoke_high_threshold_vseq.sv"
`include "ac_range_check_rst_safe_bypass_vseq.sv"
`include "ac_range_check_rst_safe_lock_range_with_rand_reset_vseq.sv"
`include "ac_range_check_rst_safe_smoke_with_rand_reset_vseq.sv"
`include "ac_range_check_rst_safe_stress_all_vseq.sv"
`include "ac_range_check_rst_safe_stress_all_with_rand_reset_vseq.sv"
`include "ac_range_check_rst_safe_racl_cov_vseq.sv"
`include "ac_range_check_rst_safe_attr_cov_vseq.sv"
`include "ac_range_check_rst_safe_log_intr_cov_vseq.sv"
`include "ac_range_check_rst_safe_lock_cov_vseq.sv"
`include "ac_range_check_rst_safe_mubi_cov_vseq.sv"
`include "ac_range_check_rst_safe_tl_cov_vseq.sv"
