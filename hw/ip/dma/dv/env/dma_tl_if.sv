// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide (64-bit) TileLink interface for the DMA host64 SoC System port: wide h2d
// (`dma_tlul_pkg::dma_tl_h2d_t`) and standard `tlul_pkg::tl_d2h_t` d2h. The DMA is the
// HOST and the DV transactor is the DEVICE (memory responder).
interface dma_tl_if(input clk, input rst_n);

  wire dma_tlul_pkg::dma_tl_h2d_t h2d; // req (wide, driven by the DUT)
  wire tlul_pkg::tl_d2h_t         d2h; // rsp (driven by this DV device transactor)

  dma_tlul_pkg::dma_tl_h2d_t h2d_int; // req (internal, unused: DUT is the host)
  tlul_pkg::tl_d2h_t         d2h_int; // rsp (internal, driven by the device driver)

  dv_utils_pkg::if_mode_e if_mode; // interface mode - Host or Device

  modport dut_host_mp(output h2d_int, input d2h_int);
  modport dut_device_mp(input h2d_int, output d2h_int);

  clocking host_cb @(posedge clk);
    input  rst_n;
    output h2d = h2d_int;
    input  d2h;
  endclocking
  modport host_mp(clocking host_cb);

  clocking device_cb @(posedge clk);
    input  rst_n;
    input  h2d;
    output d2h = d2h_int;
  endclocking
  modport device_mp(clocking device_cb);

  clocking mon_cb @(posedge clk);
    input  rst_n;
    input  h2d;
    input  d2h;
  endclocking
  modport mon_mp(clocking mon_cb);

  // Transactor is always a Device, so it drives d2h; h2d is driven by the DUT host port.
  assign d2h = (if_mode == dv_utils_pkg::Device) ? d2h_int : 'z;

endinterface : dma_tl_if
