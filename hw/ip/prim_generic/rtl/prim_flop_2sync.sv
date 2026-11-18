// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Double-flop-based synchronizer

module prim_flop_2sync #(
  parameter int               Width      = 16,
  parameter logic [Width-1:0] ResetValue = '0,
  parameter bit               EnablePrimCdcRand = 1
) (
  input                    clk_i,
  input                    rst_ni,
  input        [Width-1:0] d_i,
  output logic [Width-1:0] q_o
);

  logic [Width-1:0] d_o;
  logic [Width-1:0] intq;
  logic [Width-1:0] ff2_in;
  logic [Width-1:0] race_through;

`ifdef SIMULATION

  prim_cdc_rand_delay #(
    .DataWidth(Width),
    .Enable(EnablePrimCdcRand)
  ) u_prim_cdc_rand_delay (
    .clk_i,
    .rst_ni,
    .src_data_i(d_i),
    .prev_data_i(intq),
    .dst_data_o(d_o),
    .race_through_o(race_through)
  );

  // Race-through bypass mux for the first synchronizer flop.
  //
  // When race_through is set for a bit, FF2 sees d_o (the input) instead of intq (FF1's
  // registered output), modeling the physical scenario where setup/hold violoation causes
  // the input to race through FF1 combinationally. See prim_cdc_rand_delay for details.
  //
  // Per bit synchronizer delay:
  //   D=1 Race-though:    race_through=1 -> ff2_in=d_o -> FF2 captures input directly.
  //   D=2 Normal capture: race_through=0 -> ff2_in=intq -> standard 2-flop path.
  //   D=3 Missed capture: race_through=0, d_o=intq -> ff2_in=intq, FF1 delayed by 1.
  assign ff2_in = (d_o & race_through) | (intq & ~race_through);

`else // !`ifdef SIMULATION
  logic unused_sig;
  assign unused_sig = EnablePrimCdcRand;
  always_comb d_o = d_i;
  assign ff2_in = intq;
  assign race_through = '0;
`endif // !`ifdef SIMULATION

  prim_flop #(
    .Width(Width),
    .ResetValue(ResetValue)
  ) u_sync_1 (
    .clk_i,
    .rst_ni,
    .d_i(d_o),
    .q_o(intq)
  );

  prim_flop #(
    .Width(Width),
    .ResetValue(ResetValue)
  ) u_sync_2 (
    .clk_i,
    .rst_ni,
    .d_i(ff2_in),
    .q_o
  );

endmodule : prim_flop_2sync
