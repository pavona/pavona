// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

interface otbn_app_intf (input clk, input rst_n);

  dv_utils_pkg::if_mode_e if_mode; // interface mode - Host or Device

  // interface pins used to connect with DUT
  wire kmac_pkg::app_req_t kmac_data_req;
  wire kmac_pkg::app_rsp_t kmac_data_rsp;

  // Signals for req
  wire req_next;
  wire req_hold;
  wire req_valid;
  wire [kmac_pkg::MsgWidth-1:0] req_data;
  wire [kmac_pkg::MsgStrbW-1:0] req_strb;
  wire req_last;

  // Signals for rsp
  wire rsp_ready;
  wire rsp_done;
  wire rsp_error;
  wire [kmac_pkg::AppDigestW-1:0] rsp_digest_share0;
  wire [kmac_pkg::AppDigestW-1:0] rsp_digest_share1;

  // host cb (rsp signals)
  clocking host_cb @(posedge clk);
    input rst_n;
    output rsp_done;
    output rsp_error;
    output rsp_digest_share0;
    output rsp_digest_share1;
    output rsp_ready;
  endclocking

  // device cb (req signals)
  clocking device_cb @(posedge clk);
    input rst_n;
    output req_next;
    output req_hold;
    output req_valid;
    output req_data;
    output req_strb;
    output req_last;
  endclocking

  // monitor cb for constructing sequence
  clocking mon_cb @(posedge clk);
    input rst_n;
    input req_next;
    input req_hold;
    input req_valid;
    input req_data;
    input req_strb;
    input req_last;
    input rsp_ready;
  endclocking

  // Split kmac_data_req signals
  assign {req_valid, req_hold, req_next, req_data, req_strb, req_last} = kmac_data_req;

  // Assemble kmac_data_rsp signals
  assign kmac_data_rsp = {rsp_ready, rsp_done, rsp_digest_share0, rsp_digest_share1, rsp_error};

  // strb should never be 0 when valid is 1
  `ASSERT(StrbNotZero_A, kmac_data_req.valid |-> kmac_data_req.strb > 0, clk, !rst_n)

  // strb sahould be aligned to LSB, for example: if strb[1]==0, strb[$:2] should be 0 too
  for (genvar k = 1; k < keymgr_pkg::KmacDataIfWidth / 8 - 1; k++) begin : gen_strb_check
    `ASSERT(StrbAlignLSB_A, kmac_data_req.valid && kmac_data_req.strb[k] === 0 |->
                            kmac_data_req.strb[k+1] === 0, clk, !rst_n)
  end

  // done should be asserted after last, before we start another request
  `ASSERT(DoneAssertAfterLast_A,
    (kmac_data_req.last && kmac_data_req.valid && kmac_data_rsp.ready) |=>
    !kmac_data_req.valid throughout kmac_data_rsp.done[->1],  clk, !rst_n || kmac_data_rsp.error)

  // next should never be 1 when hold is 0
  `ASSERT(NextWihtoutHold_A, kmac_data_req.next |-> kmac_data_req.hold > 0, clk, !rst_n)

  // first word at or after hold goes high must have strb == 0x01
  `ASSERT(FirstWordStrb_A,
    $rose(kmac_data_req.hold) |-> ##[0:$] (kmac_data_req.valid && kmac_data_req.strb == 8'h01),
    clk, !rst_n)

endinterface
