// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module dma_cov_bind;
  bind dma dma_cov_if u_dma_cov_if (
    .clk               (clk_i),
    .rst_n             (rst_ni),
    .reg2hw            (reg2hw),
    .ctrl_state_q      (ctrl_state_q),
    .read_issue        (rd_issue),
    .write_issue       (wr_issue),
    .cross_port        (src_port_idx != dst_port_idx),
    .rd_done_q         (ctrl_state_q == DmaSendWrite),
    .sha2_consumed_q   (sha2_consumed_q),
    .use_inline_hashing(use_inline_hashing),
    .do_read           (do_read),
    .do_write          (do_write),
    .digest_sel        (digest_sel),
    .set_error_code    (set_error_code),
    .next_error        (next_error),
    .remaining_bytes   (remaining_bytes),
    // Abort/outstanding-response visibility, for abort-quiesce coverage.
    .cfg_abort_en      (cfg_abort_en),
    .dma_drained       (dma_drained)
  );
endmodule
