// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Format Version: 2
// ExclMode: default
//
// Egret has one policy with two permission bits, a one-bit role and a one-bit
// CTN UID. This file is only for the block testbench with EnableRacl=0 and
// policies tied to zero; do not reuse it for chip or RACL-enabled coverage.
// Module scope keeps module-definition and instance reports consistent for
// this build. Only constant address bits are excluded; [8:2] remain measured.
CHECKSUM: "2077898375 2795922920"
MODULE: rv_timer
ANNOTATION: "Egret RACL policies are tied to zero in the non-RACL RV Timer testbench."
Toggle racl_policies_i[0].read_perm "logic racl_policies_i[0].read_perm[1:0]"
ANNOTATION: "Egret RACL policies are tied to zero in the non-RACL RV Timer testbench."
Toggle racl_policies_i[0].write_perm "logic racl_policies_i[0].write_perm[1:0]"
ANNOTATION: "The TL register adapter word-aligns the address, holding bits [1:0] at zero."
Toggle 0to1 racl_error_o.request_address [1:0] "logic racl_error_o.request_address[31:0]"
Toggle 1to0 racl_error_o.request_address [1:0] "logic racl_error_o.request_address[31:0]"
ANNOTATION: "The nine-bit register address is zero-extended, holding bits [31:9] at zero."
Toggle 0to1 racl_error_o.request_address [31:9] "logic racl_error_o.request_address[31:0]"
Toggle 1to0 racl_error_o.request_address [31:9] "logic racl_error_o.request_address[31:0]"
ANNOTATION: "EnableRacl=0 ties the error-log read-access field to zero."
Toggle racl_error_o.read_access "logic racl_error_o.read_access"
ANNOTATION: "EnableRacl=0 ties the error-log CTN UID to zero."
Toggle racl_error_o.ctn_uid "logic racl_error_o.ctn_uid[0:0]"
ANNOTATION: "EnableRacl=0 ties the decoded RACL role to zero."
Toggle racl_error_o.racl_role "logic racl_error_o.racl_role[0:0]"
ANNOTATION: "The register block directly reports errors and ties its overflow output to zero."
Toggle racl_error_o.overflow "logic racl_error_o.overflow"
ANNOTATION: "EnableRacl=0 permits every decoded address, so no RACL violation can assert valid."
Toggle racl_error_o.valid "logic racl_error_o.valid"
