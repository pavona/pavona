// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dma_env_cfg extends cip_base_env_cfg #(.RAL_T(dma_reg_block));
  // ASID-keyed TL host port config, generic over `dma_pkg::DmaPortDesc`. Per-port DV
  // state (agent cfg, mem model, FIFO models, fifo-name strings) is held in associative
  // arrays keyed by ASID, populated by looping over the descriptor in `initialize()`.

  // Per-port TL agent configuration objects, keyed by the GLOBAL port index `p` (the same key
  // used for the agent instance name `tl_agent_dma_p<p>` and the tb config_db path). 32-bit ports
  // use `tl_agent_cfg`, 64-bit ports use `dma_tl_agent_cfg`. Keying by `p` (not ASID) lets two
  // ports share an ASID without overwriting each other's cfg.
  tl_agent_cfg     m_tl32_cfg[int];
  dma_tl_agent_cfg m_tl64_cfg[int];

  // Interfaces
  dma_vif               dma_vif;
  virtual clk_rst_if    clk_rst_vif;

  // Scoreboard
  dma_scoreboard        scoreboard_h;

  // Per-port interface names (derived from `DmaPortDesc`); the scoreboard spawns one
  // `process_tl_txn` per name. `dma_{a,d,dir}_fifo` map each name to its analysis-FIFO name.
  string fifo_names[];
  // Names of a_channel_fifo
  string dma_a_fifo[string];
  // Names of d_channel_fifo
  string dma_d_fifo[string];
  // Names of dir_channel_fifo
  string dma_dir_fifo[string];

  // Source data for the entire transfer; this must be presented in chunks via the memory model
  // or FIFO because chunks overlap each other when auto-increment is not being used with the
  // memory address.
  bit [7:0] src_data[];

  // Inline-AES reference model selector for aes_model_dpi (0 = C model, 1 = OpenSSL/BoringSSL).
  bit ref_model = 1;

  // Inline-AES configuration the vseq programmed for the current transfer, published here so the
  // scoreboard can predict the result via the AES model DPI (the key/IV/AAD CSRs are write-only).
  bit [31:0] aes_key0[8];
  bit [31:0] aes_key1[8];
  bit [31:0] aes_iv[4];
  bit [31:0] aes_aad[8];
  bit [31:0] aes_tag_in[4];         // expected tag for a decrypt (TAG_IN)
  bit [2:0]  aes_key_len = 3'b001;  // one-hot 128/192/256
  bit [2:0]  aes_reseed_rate = 3'b001;  // one-hot PER_1/PER_64/PER_8K
  bit [3:0]  aes_aad_blocks;
  bit        aes_mode_gcm;          // 0 = CTR, 1 = GCM
  bit        aes_decrypt;
  bit        aes_sideload;          // 1 = key from the keymgr sideload interface
  // Enables the scoreboard's AES reference prediction + data check. The randomized AES vseq sets
  // this (and publishes the config above); the directed KAT smoke leaves it 0 and self-checks.
  bit        aes_scb_predict;
  // Current decrypt is an intentional GCM tamper: expect a reference tag mismatch (res < 0) and a
  // DUT error (tag_failed, no DONE). With this clear, a negative reference result is a model bug.
  bit        aes_expect_tag_fail;


  // Per-port (ASID-keyed) mem_model and source/destination `dma_handshake_mode_fifo`
  // models emulating memory or a FIFO depending on handshake_mode_en (data compared in
  // the scoreboard). A uniform 64-bit address width lets 32-bit and 64-bit ports share types.
  dma_handshake_mode_fifo#(.AddrWidth(dma_pkg::DMA_ADDR_WIDTH)) fifo_dst[asid_encoding_e];
  // Each interface requires separate source and destination FIFO to handle the case where the
  // read traffic and the write traffic both occur on the same interface and neither is using
  // incrementing addressing.
  dma_handshake_mode_fifo#(.AddrWidth(dma_pkg::DMA_ADDR_WIDTH)) fifo_src[asid_encoding_e];
  // Memory models may be used for typical transfers where addresses are incremented.
  mem_model#(.AddrWidth(dma_pkg::DMA_ADDR_WIDTH), .DataWidth(HOST_DATA_WIDTH)) mems[asid_encoding_e];

  // Mapping of ASID encoding to interface name (textual output; scoreboard ASID<->name conversion).
  string asid_names[asid_encoding_e];

  `uvm_object_utils_begin(dma_env_cfg)
  `uvm_object_utils_end
  `uvm_object_new

  // Return the per-port interface name for a given global port index.
  static function string port_if_name(int unsigned p);
    return $sformatf("p%0d", p);
  endfunction

  // Function for Initialization
  virtual function void initialize();
    list_of_alerts = dma_env_pkg::LIST_OF_ALERTS;

    // Build the per-port name maps and ASID<->name mapping from the descriptor.
    fifo_names = new[dma_pkg::NumPortsDefault];
    foreach (dma_pkg::DmaPortDesc[p]) begin
      asid_encoding_e asid = dma_pkg::DmaPortDesc[p].asid;
      string nm = port_if_name(p);
      fifo_names[p] = nm;
      asid_names[asid] = nm;
      dma_a_fifo[nm]   = $sformatf("tl_a_%s_fifo", nm);
      dma_d_fifo[nm]   = $sformatf("tl_d_%s_fifo", nm);
      dma_dir_fifo[nm] = $sformatf("tl_dir_%s_fifo", nm);
    end

    // Initialize cip_base_env_cfg
    super.initialize();

    // Interrupt count
    num_interrupts = ral.intr_state.get_n_used_bits();

    // Per-port TL Agent Configuration objects (non-RAL), created by class from the descriptor and
    // keyed by global port index `p`.
    foreach (dma_pkg::DmaPortDesc[p]) begin
      if (dma_pkg::DmaPortDesc[p].cls == dma_pkg::PortTlul32) begin
        tl_agent_cfg c;
        `uvm_create_obj(tl_agent_cfg, c)
        c.max_outstanding_req        = dma_pkg::NUM_MAX_OUTSTANDING_REQS;
        c.if_mode                    = dv_utils_pkg::Device;
        // The DMA controller must be able to handle combinational devices too, i.e. those with a
        // combinational path from `a_valid` to `d_valid` on the TL-UL bus.
        c.device_can_rsp_on_same_cycle = 1'b1;
        m_tl32_cfg[p] = c;
      end else begin
        dma_tl_agent_cfg c;
        `uvm_create_obj(dma_tl_agent_cfg, c)
        c.max_outstanding_req        = dma_pkg::NUM_MAX_OUTSTANDING_REQS;
        c.if_mode                    = dv_utils_pkg::Device;
        c.device_can_rsp_on_same_cycle = 1'b1;
        m_tl64_cfg[p] = c;
      end
    end

    // TL Agent Configuration - RAL based
    m_tl_agent_cfg.max_outstanding_req = 1;
  endfunction: initialize

endclass
