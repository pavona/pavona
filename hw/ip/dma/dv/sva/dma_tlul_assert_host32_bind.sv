// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wrapper that instantiates one `tlul_assert` per 32-bit host port inside a
// generate loop.  Bound into `dma` from `dma_bind` so VCS never sees a
// genvar-indexed `bind` statement.

module dma_tlul_assert_host32_bind #(
  parameter int unsigned NumPorts = 1
) (
  input logic clk_i,
  input logic rst_ni,
  input tlul_pkg::tl_h2d_t [NumPorts-1:0] h2d,
  input tlul_pkg::tl_d2h_t [NumPorts-1:0] d2h
);

  for (genvar i = 0; i < NumPorts; i++) begin : gen_tlul_assert
    tlul_assert #(
      .EndpointType("Device")
    ) u_tlul_assert (
      .clk_i,
      .rst_ni,
      .h2d  (h2d[i]),
      .d2h  (d2h[i])
    );
  end

endmodule
