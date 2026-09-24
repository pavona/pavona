// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Randomized inline-AES sequence with an OpenSSL reference (aes_model_dpi). For each random message
// it runs a round-trip: encrypt -> decrypt-good -> (a fraction) decrypt-tamper. The config is
// published into `cfg` so the scoreboard predicts and checks the destination data; this sequence
// checks the GCM tag (TAG_OUT) and the tag-fail/done status. A KAT DPI self-check runs first to
// validate the byte/word packing before any random stimulus is trusted.
class dma_aes_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_aes_vseq)
  `uvm_object_new

  localparam bit [63:0] SrcAddr   = 64'h0000_1000;
  localparam bit [63:0] DstAddr   = 64'h0000_2000;
  localparam bit [31:0] RangeBase = 32'h0000_0000;
  localparam bit [31:0] RangeLim  = 32'h0000_FFFF;

  rand int unsigned num_msgs;
  constraint num_msgs_c { num_msgs inside {[12:16]}; }

  // Source/destination host ports for the current message. The source is always the range-checked
  // OT-internal port; a fraction of messages route the destination to a different host port
  // (SocControlAddr) so the cross-port AES datapath (gather on one port, scatter on another) runs.
  asid_encoding_e src_asid_sel = OtInternalAddr;
  asid_encoding_e dst_asid_sel = OtInternalAddr;
  int unsigned chunk_blocks;
  bit hardware_handshake;

  task trigger_chunk();
    set_hardware_handshake_intr(1);
    cfg.clk_rst_vif.wait_clks(2);
    release_hardware_handshake_intr();
  endtask

  // ---- byte/word helpers ----
  function void words_to_bytes(input bit [31:0] words[], output bit [7:0] bytes[]);
    bytes = new[words.size()*4];
    foreach (words[w]) for (int b = 0; b < 4; b++) bytes[w*4+b] = words[w][b*8 +: 8];
  endfunction

  function void mem_preload(asid_encoding_e asid, bit [63:0] addr, ref bit [7:0] data[]);
    foreach (data[i]) cfg.mems[asid].write_byte(addr + i, data[i]);
  endfunction

  function void mem_read(asid_encoding_e asid, bit [63:0] addr, int n, output bit [7:0] data[]);
    data = new[n];
    for (int i = 0; i < n; i++) data[i] = cfg.mems[asid].read_byte(addr + i);
  endfunction

  function void mem_poison(asid_encoding_e asid, bit [63:0] addr, int n);
    for (int i = 0; i < n; i++) cfg.mems[asid].write_byte(addr + i, 8'hA5);
  endfunction

  task clear_status();
    bit [31:0] regwen;
    csr_wr(ral.status, 32'h0000_002E);
    csr_wr(ral.intr_state, (1 << IntrDmaDone) | (1 << IntrDmaChunkDone) | (1 << IntrDmaError));
    `DV_SPINWAIT(do begin csr_rd(ral.cfg_regwen, regwen); end
                 while (regwen != prim_mubi_pkg::MuBi4True);,
                 "AES session did not release configuration")
  endtask

  // ---- DPI packing self-check against the NIST KAT (gates trusting the model) ----
  task kat_selfcheck();
    aes_kat_t kats[$];
    get_aes_kats(kats);
    foreach (kats[i]) begin
      aes_kat_t k = kats[i];
      bit [7:0][31:0] key; bit [3:0][31:0] iv, tin, tout, ktag; int res;
      bit [7:0] pt_b[], ct_b[], aad_b[], out_b[];
      int nb = k.n_blocks*16, ab = k.aad_blocks*16;
      for (int w=0;w<8;w++) key[w] = k.key[w];
      for (int w=0;w<4;w++) begin iv[w]=k.iv[w]; ktag[w]=k.tag[w]; end
      pt_b=new[nb]; ct_b=new[nb]; aad_b=new[ab];
      for (int b=0;b<nb;b++) pt_b[b]=k.pt[b/4][(b%4)*8 +: 8];
      for (int b=0;b<nb;b++) ct_b[b]=k.ct[b/4][(b%4)*8 +: 8];
      for (int b=0;b<ab;b++) aad_b[b]=k.aad[b/4][(b%4)*8 +: 8];
      // Encrypt.
      dma_aes_predict(cfg.ref_model, 1'b0, (k.gcm?AES_GCM:AES_CTR), key, 3'b001, iv,
                      pt_b, aad_b, '0, out_b, tout, res);
      foreach (out_b[b]) `DV_CHECK_EQ(out_b[b], ct_b[b], $sformatf("KAT %s enc byte %0d", k.name, b))
      if (k.gcm) `DV_CHECK_EQ(tout, ktag, $sformatf("KAT %s enc tag", k.name))
      // Decrypt (correct tag).
      tin = k.gcm ? ktag : '0;
      dma_aes_predict(cfg.ref_model, 1'b1, (k.gcm?AES_GCM:AES_CTR), key, 3'b001, iv,
                      ct_b, aad_b, tin, out_b, tout, res);
      foreach (out_b[b]) `DV_CHECK_EQ(out_b[b], pt_b[b], $sformatf("KAT %s dec byte %0d", k.name, b))
      if (k.gcm) `DV_CHECK(res >= 0, $sformatf("KAT %s dec tag should match", k.name))
    end
    `uvm_info(`gfn, "AES DPI KAT self-check passed", UVM_LOW)
  endtask

  // ---- one transfer (config already published into cfg) ----
  task run_one(bit dec, int n_blocks, ref bit [7:0] src_bytes[]);
    dma_seq_item c = dma_seq_item::type_id::create("c");
    opcode_e op = cfg.aes_mode_gcm ? (dec ? OpcAesGcmDec : OpcAesGcmEnc)
                                   : (dec ? OpcAesCtrDec : OpcAesCtrEnc);
    c.src_asid = src_asid_sel; c.dst_asid = dst_asid_sel;
    c.src_addr = SrcAddr; c.dst_addr = DstAddr;
    c.src_addr_inc = 1'b1; c.dst_addr_inc = 1'b1;   // memory mode (not FIFO)
    c.src_chunk_wrap = 1'b0; c.dst_chunk_wrap = 1'b0;
    c.handshake = hardware_handshake;
    c.handshake_intr_en = 1;
    c.lsio_trigger_i = 1;
    c.clear_intr_src = '0;
    c.total_data_size = n_blocks*16;
    c.chunk_data_size = (chunk_blocks == 0 ? n_blocks : chunk_blocks)*16;
    c.per_transfer_width = DmaXfer4BperTxn;
    cfg.src_data = src_bytes;            // scoreboard predicts from this
    cfg.aes_decrypt = dec;

    mem_preload(src_asid_sel, SrcAddr, src_bytes);
    mem_poison(dst_asid_sel, DstAddr, n_blocks*16);
    clear_status();
    release_hardware_handshake_intr();
    csr_wr(ral.clear_intr_src, 0);
    csr_wr(ral.handshake_intr_enable, 1);
    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(src_asid_sel, dst_asid_sel);
    set_total_size(n_blocks*16); set_chunk_data_size(c.chunk_data_size);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
    program_aes_config(cfg.aes_key0, cfg.aes_key1, cfg.aes_iv, cfg.aes_aad,
                       cfg.aes_aad_blocks, cfg.aes_key_len, cfg.aes_sideload, cfg.aes_reseed_rate);
    if (dec) program_aes_tag_in(cfg.aes_tag_in);
    start_device(c);
    set_control(op, .initial_transfer(1'b1), .handshake(hardware_handshake), .go(1'b1));
    if (hardware_handshake) begin
      bit [31:0] st;
      // A disabled source must not start the first chunk.
      set_hardware_handshake_intr(2);
      delay(20);
      csr_rd(ral.status, st);
      `DV_CHECK_EQ(st[7:0], 0, "AES started early or retained stale authentication status")
      for (int b = 0; b < n_blocks*16; b++) begin
        `DV_CHECK_EQ(cfg.mems[dst_asid_sel].read_byte(DstAddr + b), 8'hA5)
      end
      release_hardware_handshake_intr();
      trigger_chunk();
    end
    for (int moved = c.chunk_data_size; moved < n_blocks*16; moved += c.chunk_data_size) begin
      bit [31:0] st, value;
      if (hardware_handshake) begin
        // Handshake mode signals no chunk_done; address write-back marks the boundary.
        `DV_SPINWAIT(do begin csr_rd(ral.src_addr_lo, value); end
                     while (value != SrcAddr + moved);,
                     "AES handshake did not finish its chunk")
        csr_rd(ral.status, st);
        `DV_CHECK_EQ(st[5], 0, "Hardware handshake raised chunk_done")
        csr_rd(ral.control, value);
        `DV_CHECK_EQ(value[31], 1, "Hardware handshake cleared GO between chunks")
      end else begin
        `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[5] || st[3]));,
                     "AES did not reach chunk boundary")
      end
      `DV_CHECK_EQ(st[7:6], 2'b00, "Authentication completed before the final chunk")
      `DV_CHECK_EQ(st[3:0], hardware_handshake ? 4'b0001 : 4'b0000,
                   "Unexpected intermediate busy/done/abort/error")
      csr_rd(ral.cfg_regwen, value);
      `DV_CHECK_EQ(value, prim_mubi_pkg::MuBi4False, "Suspended AES configuration unlocked")
      // These writes must be ignored while the retained crypto state is live.
      csr_wr(ral.total_data_size, 16);
      csr_wr(ral.chunk_data_size, 16);
      csr_wr(ral.aes_ctrl, 0);
      csr_wr(ral.key_share0[0], 0);
      csr_wr(ral.tag_in[0], 0);
      csr_rd(ral.total_data_size, value);
      `DV_CHECK_EQ(value, n_blocks*16)
      csr_rd(ral.chunk_data_size, value);
      `DV_CHECK_EQ(value, c.chunk_data_size)
      csr_rd(ral.src_addr_lo, value);
      `DV_CHECK_EQ(value, SrcAddr + moved, "AES source chunk write-back")
      csr_rd(ral.dst_addr_lo, value);
      `DV_CHECK_EQ(value, DstAddr + moved, "AES destination chunk write-back")
      delay($urandom_range(20, 100));
      for (int b = moved; b < n_blocks*16; b++) begin
        `DV_CHECK_EQ(cfg.mems[dst_asid_sel].read_byte(DstAddr + b), 8'hA5,
                     "AES wrote beyond the suspended chunk")
      end
      csr_wr(ral.status, 32'h20);
      csr_wr(ral.intr_state, 1 << IntrDmaChunkDone);
      if (hardware_handshake) trigger_chunk();
      else set_control(op, .initial_transfer(1'b0), .handshake(1'b0), .go(1'b1));
    end
  endtask

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting randomized inline-AES sequence", UVM_LOW)
    init_model();
    cfg.aes_scb_predict = 1'b1;          // enable the scoreboard AES predictor for this sequence
    cfg.ref_model       = 1'b1;          // OpenSSL/BoringSSL
    kat_selfcheck();

    for (int m = 0; m < num_msgs; m++) begin
      status_t   status;
      bit        gcm        = $urandom_range(0, 1);
      // Exercise a range of block counts so the GCM block counter / multi-block GHASH are covered,
      // not just 1..4. ~10% of messages use a larger burst (still bounded by the SrcAddr/DstAddr
      // 0x1000-byte gap = 256 blocks, so they never overlap). The 13-bit overflow boundary itself is
      // covered by the directed `gcm_blocks_overflow` case in dma_aes_error_vseq.
      int        n_blocks   = ($urandom_range(0, 9) == 0) ? $urandom_range(9, 64)
                                                          : $urandom_range(1, 8);
      bit [3:0]  aad_blocks = gcm ? $urandom_range(0, 2) : 4'd0;
      bit [7:0]  pt_b[], ct_b[], pred_pt[], aad_b[];
      bit [3:0][31:0] pred_tag; int res; bit [7:0][31:0] key;
      bit [31:0] tag_word;

      // Exercise both pacing modes with short final, equal-sized and oversized chunks.
      hardware_handshake = m < 12 ? m >= 6 : $urandom_range(0, 1);
      if (m < 12) begin
        gcm = (m % 2) != 0;
        n_blocks = 5;
        chunk_blocks = (m % 6) < 2 ? 2 : ((m % 6) < 4 ? 5 : 7);
        aad_blocks = gcm ? 2 : 0;
      end else begin
        chunk_blocks = $urandom_range(1, n_blocks + 2);
      end

      // Randomize the config and publish it. key_len: AES-128/192/256 (one-hot).
      cfg.aes_key_len = (1 << $urandom_range(0, 2));
      cfg.aes_sideload = $urandom_range(0, 1);
      // PRNG reseed rate: one-hot PER_1/PER_64/PER_8K, exercised so reseed timing varies.
      cfg.aes_reseed_rate = (1 << $urandom_range(0, 2));
      if (cfg.aes_sideload) begin
        // Sideload: the effective key is the keymgr key driven by the tb; mirror it into cfg so the
        // scoreboard predicts with the same key. The CSR shares are written but ignored by the DUT.
        for (int w = 0; w < 8; w++) begin
          cfg.aes_key0[w] = DmaSideloadKeyShare0[w*32 +: 32];
          cfg.aes_key1[w] = DmaSideloadKeyShare1[w*32 +: 32];
        end
      end else begin
        foreach (cfg.aes_key0[w]) cfg.aes_key0[w] = $urandom;
        foreach (cfg.aes_key1[w]) cfg.aes_key1[w] = $urandom;
      end
      foreach (cfg.aes_iv[w])   cfg.aes_iv[w]   = $urandom;
      // GCM: the AES core ignores the software-supplied IV[3] (counter word) and initializes it
      // internally during GCM_INIT. Zero it so the prediction matches the DUT.
      if (gcm) cfg.aes_iv[3] = 32'h0;
      foreach (cfg.aes_aad[w])  cfg.aes_aad[w]  = $urandom;
      cfg.aes_aad_blocks = aad_blocks;
      cfg.aes_mode_gcm  = gcm;
      cfg.aes_tag_in    = '{default:0};

      // Route ~1/3 of messages cross-port (OT-internal gather -> SoC scatter); the rest stay on the
      // OT-internal port. Source stays OT-internal (the range-checked endpoint).
      src_asid_sel = OtInternalAddr;
      dst_asid_sel = ($urandom_range(0, 2) == 0) ? SocControlAddr : OtInternalAddr;

      // AAD bytes for the reference (the active AAD blocks).
      aad_b = new[aad_blocks*16];
      foreach (aad_b[b]) aad_b[b] = cfg.aes_aad[b/4][(b%4)*8 +: 8];

      // Random plaintext.
      pt_b = new[n_blocks*16];
      foreach (pt_b[b]) pt_b[b] = $urandom;

      // ---- encrypt ----
      status = '0;
      cfg.aes_expect_tag_fail = 1'b0; // good transfers: the reference must verify the tag
      run_one(.dec(1'b0), .n_blocks(n_blocks), .src_bytes(pt_b));
      poll_status(.intr_driven(1'b0), .status(status));
      stop_device();
      `DV_CHECK_EQ(status[StatusError], 1'b0, "AES encrypt errored")
      mem_read(dst_asid_sel, DstAddr, n_blocks*16, ct_b);   // ciphertext for the round-trip

      if (gcm) begin
        // Check TAG_OUT against the reference, and capture it for the decrypt.
        bit [3:0][31:0] iv_p, tin_p;
        for (int w=0;w<8;w++) key[w] = cfg.aes_key0[w] ^ cfg.aes_key1[w];
        for (int w=0;w<4;w++) iv_p[w] = cfg.aes_iv[w];
        tin_p = '0;
        dma_aes_predict(cfg.ref_model, 1'b0, AES_GCM, key, cfg.aes_key_len, iv_p,
                        pt_b, aad_b, tin_p, pred_pt, pred_tag, res);
        for (int w=0;w<4;w++) begin
          csr_rd(ral.tag_out[w], tag_word);
          `DV_CHECK_EQ(tag_word, pred_tag[w], $sformatf("msg %0d TAG_OUT word %0d", m, w))
          cfg.aes_tag_in[w] = tag_word;       // feed the (verified) tag back for decrypt
        end
      end

      // ---- decrypt-good (round trip) ----
      status = '0;
      cfg.aes_expect_tag_fail = 1'b0; // round-trip ciphertext: the tag must verify
      run_one(.dec(1'b1), .n_blocks(n_blocks), .src_bytes(ct_b));
      poll_status(.intr_driven(1'b0), .status(status));
      stop_device();
      `DV_CHECK_EQ(status[StatusError], 1'b0, "AES decrypt (good) errored")

      // ---- decrypt-tamper (GCM, ~1/3 of messages) ----
      if (gcm && ($urandom_range(0, 2) == 0)) begin
        bit [7:0] tct[] = new[ct_b.size()];
        bit [31:0] ec;
        foreach (ct_b[b]) tct[b] = ct_b[b];
        tct[0] ^= 8'h01;
        status = '0;
        cfg.aes_expect_tag_fail = 1'b1; // intentional tamper: expect tag mismatch + error, no done
        cfg.scoreboard_h.set_exp_alert("recov_fault", .is_fatal(0), .max_delay(50_000));
        run_one(.dec(1'b1), .n_blocks(n_blocks), .src_bytes(tct));
        poll_status(.intr_driven(1'b0), .status(status));
        stop_device();
        `DV_CHECK_EQ(status[StatusError], 1'b1, "AES tamper did not error")
        `DV_CHECK_EQ(status[StatusDone],  1'b0, "AES tamper set done")
        csr_rd(ral.status, ec);     `DV_CHECK_EQ(ec[7], 1'b1, "tamper: no tag_failed")
        csr_rd(ral.error_code, ec); `DV_CHECK_EQ(ec[8], 1'b1, "tamper: no aes_tag_error")
        clear_status();
        cfg.aes_expect_tag_fail = 1'b0;
      end

      // Clear status/interrupts between messages.
      clear_status();
    end
    `uvm_info(`gfn, "DMA: Completed randomized inline-AES sequence", UVM_LOW)
  endtask : body
endclass
