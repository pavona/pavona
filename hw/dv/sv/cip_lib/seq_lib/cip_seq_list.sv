// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// customized tl_seq_item for cmd integrity
`include "cip_tl_seq_item.sv"

// customized tl sequences to address integrity
`include "cip_tl_host_single_seq.sv"
`include "cip_tl_device_seq.sv"
`include "cip_tl_access_errors_seq.sv"
`include "cip_mem_partial_access_seq.sv"

// vseqs
`include "cip_base_vseq.sv"
`include "cip_rand_rst_safe_base_vseq.sv"
`include "cip_rst_safe_tl_errors_vseq.sv"
`include "cip_rst_safe_csr_vseq.sv"
`include "cip_rst_safe_mem_partial_access_vseq.sv"
`include "cip_rst_safe_tl_intg_err_vseq.sv"
`include "cip_rst_safe_csr_with_rand_reset_vseq.sv"
`include "cip_rst_safe_csr_mem_vseq.sv"
`include "cip_rst_safe_csr_mem_with_rand_reset_vseq.sv"
`include "cip_rst_safe_stress_all_vseq.sv"
