// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


/**
 * This is a simple module to unmask the KMAC digest depending on the
 * AppIntf configuration. It exists as a standalone module to allow isolation
 * as this module should be considered a *do_not_touch* to stop any
 * optimizations for the mux and xor location to prevent leakage during
 * masked operations.
 */

module acc_digest_mux
  import acc_pkg::*;
(
  input  logic [DigestRegLen-1:0] digest_share0_i,
  input  logic [DigestRegLen-1:0] digest_share1_i,
  input  logic                    mask_digest_en_i,

  output logic [DigestRegLen-1:0] digest_share0_wsr_o
);

  logic [DigestRegLen-1:0] digest_share1_mux;
  logic [DigestRegLen-1:0] digest_share0_result;

  assign digest_share1_mux = mask_digest_en_i ? 256'b0 : digest_share1_i;
  assign digest_share0_result = digest_share0_i ^ digest_share1_mux;

  assign digest_share0_wsr_o = digest_share0_result;

endmodule