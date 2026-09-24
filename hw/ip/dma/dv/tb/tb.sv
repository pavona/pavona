// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module tb;
  // Dependencies - Packages and Macros
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import top_pkg::*;
  import tlul_pkg::*;
  import dma_pkg::*;
  import dma_tlul_pkg::*;
  import dma_env_pkg::*;
  import dma_test_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"
  `include "cip_macros.svh"

  // Common Interface - Clock and Reset
  wire clk;
  wire rst_n;
  clk_rst_if clk_rst_if(.clk(clk), .rst_n(rst_n));

  // Common wire - Handshake/Interrupt Inputs
  wire [dma_reg_pkg::NumIntClearSources - 1 : 0] handshake_i;
  dma_if dma_intf();
  assign handshake_i = dma_intf.handshake_i;

  // Common Interface - Interrupt Outputs
  wire [NUM_MAX_INTERRUPTS - 1 : 0] interrupts;
  pins_if #(NUM_MAX_INTERRUPTS) intr_if(interrupts);

  // CSR (device) TL interface - the RAL/register block port.
  tl_if tl_if (.clk(clk), .rst_n(rst_n)); // Ingress Port from System Fabric *Primary*

  // Generic, descriptor-driven host port boundary: the DUT exposes 32-bit (`host32_*`)
  // and wide 64-bit (`host64_*`) host vectors sized by `dma_pkg::DmaPortDesc`. The env
  // binds one agent per port by its per-class sub-index (`dma_pkg::dma_class_subidx`).
  // Vectors are sized with `dma_max1()` so a zero count yields a single tied-off placeholder.

  // 32-bit TLUL host port vector connecting to the DUT's host32 vector.
  tlul_pkg::tl_h2d_t [dma_pkg::dma_max1(dma_pkg::NumTlul32Default)-1:0] host32_tl_h_o;
  tlul_pkg::tl_d2h_t [dma_pkg::dma_max1(dma_pkg::NumTlul32Default)-1:0] host32_tl_h_i;
  // 64-bit SoC System host port vector connecting to the DUT's wide host64 vector.
  dma_tlul_pkg::dma_tl_h2d_t [dma_pkg::dma_max1(dma_pkg::NumTlul64Default)-1:0] host64_h2d_o;
  tlul_pkg::tl_d2h_t         [dma_pkg::dma_max1(dma_pkg::NumTlul64Default)-1:0] host64_d2h_i;

  // One 32-bit `tl_if` per 32-bit host port and one wide `dma_tl_if` per 64-bit host port
  // (sized with `dma_max1()`; the zero-count placeholder is never connected to an agent).
  tl_if     host32_if [dma_pkg::dma_max1(dma_pkg::NumTlul32Default)] (.clk(clk), .rst_n(rst_n));
  dma_tl_if host64_if [dma_pkg::dma_max1(dma_pkg::NumTlul64Default)] (.clk(clk), .rst_n(rst_n));

  // Wire each 32-bit host port to its `tl_if` (DMA drives h2d, agent drives d2h).
  for (genvar i = 0; i < int'(dma_pkg::NumTlul32Default); i++) begin : gen_host32_conn
    assign host32_if[i].h2d = host32_tl_h_o[i];
    assign host32_tl_h_i[i] = host32_if[i].d2h;
  end : gen_host32_conn

  // Wire each 64-bit host port to its wide `dma_tl_if`.
  for (genvar i = 0; i < int'(dma_pkg::NumTlul64Default); i++) begin : gen_host64_conn
    assign host64_if[i].h2d = host64_h2d_o[i];
    assign host64_d2h_i[i]  = host64_if[i].d2h;
  end : gen_host64_conn

  // Tie off the placeholder boundary input when a class count is zero.
  if (dma_pkg::NumTlul32Default == 0) begin : gen_host32_tieoff
    assign host32_tl_h_i[0] = '0;
  end : gen_host32_tieoff
  if (dma_pkg::NumTlul64Default == 0) begin : gen_host64_tieoff
    assign host64_d2h_i[0] = '0;
  end : gen_host64_tieoff

  // Note: no protocol assertion on host64 yet (stock `tlul_assert` is 32-bit only; see dma_bind.sv).

  `DV_ALERT_IF_CONNECT()

  // ---- Inline-AES inter-signals ----
  // EDN runs on the main clock for DV (the wrapper's clk_edn CDC is still exercised).
  wire clk_edn   = clk;
  wire rst_edn_n = rst_n;
  edn_pkg::edn_req_t aes_edn_req;
  edn_pkg::edn_rsp_t aes_edn_rsp;
  // Always-grant entropy stub: ack follows req with a one-cycle delay so the prim_sync_reqack_data
  // NRZ handshake protocol sees clean edges (combinational ack creates issues with the two-phase
  // NRZ FSM). The data advances each cycle so the masking PRNG gets varied entropy.
  logic [edn_pkg::ENDPOINT_BUS_WIDTH-1:0] edn_bus_q;
  logic edn_ack_q;
  always_ff @(posedge clk_edn or negedge rst_edn_n) begin
    if (!rst_edn_n) begin
      edn_bus_q <= 32'h1234_5678;
      edn_ack_q <= 1'b0;
    end else begin
      edn_bus_q <= edn_bus_q + 32'h9e37_79b9;
      edn_ack_q <= aes_edn_req.edn_req;
    end
  end
  assign aes_edn_rsp.edn_ack  = edn_ack_q;
  assign aes_edn_rsp.edn_fips = 1'b1;
  assign aes_edn_rsp.edn_bus  = edn_bus_q;

  // Known keymgr sideload key (shared with the env via dma_env_pkg for prediction).
  keymgr_pkg::hw_key_req_t aes_keymgr_key;
  assign aes_keymgr_key.valid  = 1'b1;
  assign aes_keymgr_key.key[0] = dma_env_pkg::DmaSideloadKeyShare0;
  assign aes_keymgr_key.key[1] = dma_env_pkg::DmaSideloadKeyShare1;

  // Instantiate DUT
  dma #(
    .EnableDataIntgGen (1),
    .SecAllowForcingMasks (1)
  ) dut (
    .clk_i (clk),
    .rst_ni (rst_n),
    .scanmode_i (prim_mubi_pkg::MuBi4False),
    .lsio_trigger_i (handshake_i),
    .intr_dma_done_o (interrupts[IntrDmaDone]),
    .intr_dma_chunk_done_o (interrupts[IntrDmaChunkDone]),
    .intr_dma_error_o (interrupts[IntrDmaError]),
    .alert_rx_i (alert_rx),
    .alert_tx_o (alert_tx),
    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    // TL Interface for CSR (device)
    .tl_d_o (tl_if.d2h),
    .tl_d_i (tl_if.h2d),
    // Descriptor-sized 32-bit and 64-bit host port vectors.
    .host32_tl_h_o (host32_tl_h_o),
    .host32_tl_h_i (host32_tl_h_i),
    .host64_h2d_o (host64_h2d_o),
    .host64_d2h_i (host64_d2h_i),
    // Inline-AES inter-signals.
    .clk_edn_i (clk_edn),
    .rst_edn_ni (rst_edn_n),
    .edn_o (aes_edn_req),
    .edn_i (aes_edn_rsp),
    .keymgr_key_i (aes_keymgr_key),
    .lc_escalate_en_i (lc_ctrl_pkg::Off)
  );

  // Publish each host-port interface keyed by global port index `p`, matching the agent
  // instance name `tl_agent_dma_p<p>` created by `dma_env`.
  initial begin
    clk_rst_if.set_active();
    dma_intf.init();

    // The EDN stub uses clk_edn = clk (same clock domain). Disable the CDC timing assertions
    // in the prim_sync_reqack_data instance on the EDN path, which assumes asynchronous clocks.
    $assertoff(0, dut.u_dma_aes.u_prim_sync_reqack_data);

    // CSR (RAL) agent and common interfaces.
    uvm_config_db#(virtual tl_if)::set(null, "*.env.m_tl_agent_dma_reg_block*", "vif", tl_if);
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif", clk_rst_if);
    uvm_config_db#(virtual dma_if)::set(null, "*.env", "dma_vif", dma_intf);
    uvm_config_db#(intr_vif)::set(null, "*.env", "intr_vif", intr_if);

    // Per-port host interface registration, keyed by global port index. The agent instance name is
    // exactly `tl_agent_dma_p<p>` (no children consume `vif`), so anchor the scope at that name
    // with a trailing `.` delimiter. A bare `*tl_agent_dma_p<p>*` glob would also match `p10`,
    // `p11`, ... when NumPorts > 10 (e.g. the `p1` glob captures `p10`); the trailing `.` prevents
    // that prefix collision.
    //
    // VCS does not allow non-constant indices into interface arrays in cross-module references
    // (Error IIXMR), so each port is registered in a generate block where the class sub-index
    // is a constant elaboration-time expression.
  end

  for (genvar p = 0; p < int'(dma_pkg::NumPortsDefault); p++) begin : gen_port_cfg
    localparam int unsigned Sub = dma_pkg::dma_class_subidx(p);
    if (dma_pkg::DmaPortDesc[p].cls == dma_pkg::PortTlul32) begin : gen_tl32
      initial
        uvm_config_db#(virtual tl_if)::set(
            null, $sformatf("*.env.tl_agent_dma_p%0d", p), "vif", host32_if[Sub]);
    end else begin : gen_tl64
      initial
        uvm_config_db#(virtual dma_tl_if)::set(
            null, $sformatf("*.env.tl_agent_dma_p%0d", p), "vif", host64_if[Sub]);
    end
  end : gen_port_cfg

  initial begin
    $timeformat(-12, 0, "ps", 12);
    run_test();
  end

endmodule
