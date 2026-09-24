// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module dma_bind;

  // Bind assertion module to config interface
  bind dma tlul_assert #(
    .EndpointType("Device")
  ) tlul_assert_device (
    .clk_i,
    .rst_ni,
    .h2d  (tl_d_i),
    .d2h  (tl_d_o)
  );

  // Bind CSR assertion module on config interface
  bind dma dma_csr_assert_fpv dma_csr_assert (
    .clk_i,
    .rst_ni,
    .h2d    (tl_d_i),
    .d2h    (tl_d_o)
  );

  // Bind a TL-UL protocol assertion to each present 32-bit host port.
  // The generate loop lives inside the bound wrapper so VCS does not see a
  // genvar-indexed bind (which it rejects with V2KGVIU).
  bind dma dma_tlul_assert_host32_bind #(
    .NumPorts(dma_pkg::dma_max1(NumTlul32))
  ) u_tlul_assert_host32_bind (
    .clk_i,
    .rst_ni,
    .h2d  (host32_tl_h_o),
    .d2h  (host32_tl_h_i)
  );

  // NOTE: host64 ports have no bound TL-UL protocol assertion. The stock `tlul_assert` handles
  // only the 32-bit `tl_h2d_t`, and there is no 64-bit `dma_tl_h2d_t`-aware equivalent, so the wide
  // ports are protocol-checked by the scoreboard/agent rather than by a bound assertion.

  // Bind the memset/verify no-traffic and no-deadlock assertions.
  bind dma dma_memset_verify_sva u_dma_memset_verify_sva (
    .clk_i,
    .rst_ni,
    .gated_clk    (gated_clk),
    .ctrl_state_q (ctrl_state_q),
    .do_read      (do_read),
    .do_write     (do_write),
    .read_issue   (rd_issue),
    .write_issue  (wr_issue)
  );

endmodule
