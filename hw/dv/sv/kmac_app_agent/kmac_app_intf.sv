// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// verilog_lint: waive interface-name-style
interface kmac_app_intf (input clk, input rst_n);

  import keymgr_pkg::*;

  dv_utils_pkg::if_mode_e if_mode; // interface mode - Host or Device

  // interface pins used to connect with DUT
  wire kmac_pkg::app_req_t kmac_data_req;
  wire kmac_pkg::app_rsp_t kmac_data_rsp;

  // interface pins used in driver/monitor
  push_pull_if #(.HostDataWidth(kmac_app_agent_pkg::KMAC_REQ_DATA_WIDTH))
      req_data_if(.clk(clk), .rst_n(rst_n));
  wire rsp_done;
  wire [kmac_pkg::AppDigestW-1:0] rsp_digest_share0;
  wire [kmac_pkg::AppDigestW-1:0] rsp_digest_share1;
  wire rsp_error;

  // The following signals and enum declaration are internal for driving the next/hold lines
  // Similar to the state machine these signals are not intended to be permanent and
  // should be removed following the restructure of KMAC driver/sequencer logic
  wire next_tmp;
  wire hold_tmp;
  logic next_d;
  logic hold_d;
  logic acc_start_d, acc_start;
  logic [3:0] per_ctr_d, per_ctr;
  logic [3:0] max_per;

  // The next and hold signals used for the AppIntf
  logic next;
  logic hold;

  typedef enum logic [1:0] {
    StIdle,
    StStart,
    StWait,
    StNext
  } acc_state_e;

  acc_state_e acc_state_d, acc_state;

  // all the host pins are handled by push_pull driver, only include clk and rst here
  clocking host_cb @(posedge clk);
    input  rst_n;
  endclocking

  clocking device_cb @(posedge clk);
    input  rst_n;
    output rsp_done;
    output rsp_digest_share0;
    output rsp_digest_share1;
    output rsp_error;
    output next;
    output hold;
  endclocking

  clocking mon_cb @(posedge clk);
    input rst_n;
    input rsp_done;
    input rsp_digest_share0;
    input rsp_digest_share1;
    input rsp_error;
    input next;
    input hold;
  endclocking

  always @(if_mode) req_data_if.if_mode = if_mode;

  assign kmac_data_req = (if_mode == dv_utils_pkg::Host) ?
                         {req_data_if.valid, hold, next, req_data_if.h_data} : 'z;
  assign {req_data_if.valid, hold_tmp, next_tmp, req_data_if.h_data} =
      (if_mode == dv_utils_pkg::Device) ? kmac_data_req : 'z;

  assign {req_data_if.ready, rsp_done, rsp_digest_share0, rsp_digest_share1, rsp_error} =
         (if_mode == dv_utils_pkg::Host) ? kmac_data_rsp : 'z;
  assign kmac_data_rsp = (if_mode == dv_utils_pkg::Device) ?
         {req_data_if.ready, rsp_done, rsp_digest_share0, rsp_digest_share1, rsp_error} : 'z;

  // The following fsm is temporary for driving next/hold in the interface
  // It should be removed once the restructuring of the sequencer/driver is complete
  // Hold is asserted 1'b1 at the start of the ACC app req and returns to 1'b0 after last rsp
  // Hold is asserted 1'b0 on the cycle immediately following last rsp_done
  // Combinational decode of the state
  always_comb begin
    acc_state_d = acc_state;
    acc_start_d = acc_start;

    // Set next/hold default
    hold_d = 1'b0;
    next_d = 1'b0;

    // Default the counters
    per_ctr_d = '0;

    unique case (acc_state)

      // Set hold at start of req
      StIdle: begin
        if (acc_start) begin
          acc_state_d = StWait;
          hold_d    = 1'b1;
        end
      end

      // Wait until first rsp to determine if more are needed
      // Counters are constrained in kmac_app_host_seq
      StWait: begin
        if (acc_start) begin
          hold_d    = 1'b1;
          per_ctr_d = per_ctr;
          if (rsp_done == 1'b1) begin
            acc_state_d = StNext;
            per_ctr_d = per_ctr + 1'b1;
            if ((per_ctr + 1) < max_per) begin
              next_d = 1'b1;
            end else begin
              hold_d = 1'b0;
            end
          end
        end
      end

      // Next should only be high for a single clock cycle
      // If response has reached total word len end FSM cycle
      StNext: begin
        if (acc_start) begin
          hold_d    = 1'b1;
          next_d    = 1'b0;
          per_ctr_d = per_ctr;
          if (per_ctr == max_per) begin
            acc_state_d = StIdle;
            acc_start_d = 1'b0;
            per_ctr_d    = '0;
            hold_d       = 1'b0;
          end else begin
            if (rsp_done == 1'b0) begin
              acc_state_d = StWait;
            end
          end
        end
      end
      default: begin
        // This case shouldn't be reachable
      end
    endcase
  end

  // Register the state
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      acc_state <= StIdle;
      hold       <= 1'b0;
      next       <= 1'b0;
      per_ctr    <= 1'b0;
      acc_start <= 1'b0;
    end else begin
      acc_state <= acc_state_d;
      hold       <= hold_d;
      next       <= next_d;
      per_ctr    <= per_ctr_d;
      acc_start <= acc_start_d;
    end
  end

  // The following assertions only apply to device mode.
  // strb should never be 0
  `ASSERT(StrbNotZero_A, kmac_data_req.valid |-> kmac_data_req.strb > 0,
          clk, !rst_n || if_mode == dv_utils_pkg::Host)

  // Check strb is aligned to LSB, for example: if strb[1]==0, strb[$:2] should be 0 too
  for (genvar k = 1; k < KmacDataIfWidth / 8 - 1; k++) begin : gen_strb_check
    `ASSERT(StrbAlignLSB_A, kmac_data_req.valid && kmac_data_req.strb[k] === 0 |->
                            kmac_data_req.strb[k+1] === 0,
                            clk, !rst_n || if_mode == dv_utils_pkg::Host)
  end

  // The following assertions apply for this interface for all modes.

  // Done should be asserted after last, before we start another request
  `ASSERT(DoneAssertAfterLast_A,
    (kmac_data_req.last && kmac_data_req.valid && kmac_data_rsp.ready) |=>
    !kmac_data_req.valid throughout rsp_done[->1], clk, !rst_n || rsp_error)

endinterface
