// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module acc_bind;

  bind acc tlul_assert #(
    .EndpointType("Device")
  ) tlul_checker (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .h2d    (tl_i),
    .d2h    (tl_o)
  );

  bind acc acc_csr_assert_fpv csr_checker (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .h2d    (tl_i),
    .d2h    (tl_o)
  );

  bind acc acc_idle_checker idle_checker (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .reg2hw   (reg2hw),
    .hw2reg   (hw2reg),
    .done_i   (done),
    .idle_o_i (idle_o),

    .acc_dmem_scramble_key_req_busy_i(acc_dmem_scramble_key_req_busy),
    .acc_imem_scramble_key_req_busy_i(acc_imem_scramble_key_req_busy),

    .status_q_i(status_q),
    .busy_secure_wipe,

    .imem_rdata_bus(imem_rdata_bus),
    .dmem_rdata_bus(dmem_rdata_bus)
  );

endmodule
