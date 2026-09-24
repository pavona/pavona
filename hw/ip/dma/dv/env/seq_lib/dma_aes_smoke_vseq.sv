// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed inline-AES smoke sequence (NIST known-answer-test vectors).
//
// For each KAT vector this self-checks:
//   - encrypt: preload the source with the plaintext, run, and check the destination equals the
//     KAT ciphertext; for GCM also read TAG_OUT and check it against the KAT tag + STATUS.tag_valid.
//   - decrypt (good): preload the source with the ciphertext (GCM: program TAG_IN with the KAT
//     tag), run, and check the destination equals the plaintext, with no error / no tag_failed.
//   - decrypt (tamper, GCM only): flip one ciphertext byte and check STATUS.error + STATUS.tag_failed
//     + ERROR_CODE.aes_tag_error, and that STATUS.done is NOT set.
//
// The data/tag are checked here (the scoreboard skips its copy comparison for AES); the scoreboard
// still tracks completion/interrupts.
class dma_aes_smoke_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_aes_smoke_vseq)
  `uvm_object_new

  // Fixed OT-internal memory map for the directed transfers (within the enabled range below).
  localparam bit [63:0] SrcAddr   = 64'h0000_1000;
  localparam bit [63:0] DstAddr   = 64'h0000_2000;
  localparam bit [31:0] RangeBase = 32'h0000_0000;
  localparam bit [31:0] RangeLim  = 32'h0000_FFFF;

  // Write a register-native word array into the destination ASID's memory model.
  function void preload_words(asid_encoding_e asid, bit [63:0] addr, bit [31:0] words[], int n);
    for (int w = 0; w < n; w++) begin
      for (int b = 0; b < 4; b++) begin
        cfg.mems[asid].write_byte(addr + w*4 + b, words[w][b*8 +: 8]);
      end
    end
  endfunction

  // Poison a region so a missing/short DMA write is caught (check_words would see the poison).
  function void poison_words(asid_encoding_e asid, bit [63:0] addr, int n);
    for (int w = 0; w < n; w++) begin
      for (int b = 0; b < 4; b++) cfg.mems[asid].write_byte(addr + w*4 + b, 8'hA5);
    end
  endfunction

  // Clear the RW1C STATUS completion bits (done/aborted/error/chunk_done) and the corresponding
  // INTR_STATE bits before a new pass, so stale state cannot confuse poll_status or the scoreboard.
  task clear_dma_status();
    csr_wr(ral.status, 32'h0000_002E); // bits 1,2,3,5
    csr_wr(ral.intr_state, (1 << IntrDmaDone) | (1 << IntrDmaChunkDone) | (1 << IntrDmaError));
  endtask

  // Read an n-word region from the memory model and compare against expected register-native words.
  function void check_words(asid_encoding_e asid, bit [63:0] addr, bit [31:0] exp[], int n,
                            string tag);
    for (int w = 0; w < n; w++) begin
      bit [31:0] got;
      for (int b = 0; b < 4; b++) got[b*8 +: 8] = cfg.mems[asid].read_byte(addr + w*4 + b);
      `DV_CHECK_EQ(got, exp[w], $sformatf("%s word %0d mismatch", tag, w))
    end
  endfunction

  // Configure + launch one AES transfer (memory-to-memory, OT-internal, 4-byte beats, single chunk).
  // The caller must call stop_device() after poll_status() returns before starting the next transfer.
  task run_aes_transfer(opcode_e opcode, bit [63:0] src, bit [63:0] dst, int n_blocks,
                        aes_kat_t k);
    dma_seq_item dma_config;
    dma_config = dma_seq_item::type_id::create("dma_config");
    dma_config.src_addr        = src;
    dma_config.dst_addr        = dst;
    dma_config.src_asid        = OtInternalAddr;
    dma_config.dst_asid        = OtInternalAddr;
    dma_config.src_addr_inc    = 1'b1;
    dma_config.dst_addr_inc    = 1'b1;
    dma_config.src_chunk_wrap  = 1'b0;
    dma_config.dst_chunk_wrap  = 1'b0;
    dma_config.handshake       = 1'b0;
    dma_config.total_data_size = n_blocks * 16;
    dma_config.chunk_data_size = n_blocks * 16; // single chunk
    dma_config.per_transfer_width = DmaXfer4BperTxn;

    set_src_addr(src);
    set_dst_addr(dst);
    set_src_config(1'b0, 1'b1);
    set_dst_config(1'b0, 1'b1);
    set_addr_space_id(OtInternalAddr, OtInternalAddr);
    set_total_size(dma_config.total_data_size);
    set_chunk_data_size(dma_config.chunk_data_size);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
    // AES-128 (key_len one-hot = 1), CSR key path (sideload=0).
    program_aes_config(k.key, '{default: 0}, k.iv, k.aad, k.aad_blocks, 3'd1, 1'b0);
    if (opcode_aes_mode(opcode) && opcode_aes_decrypt(opcode)) begin
      program_aes_tag_in(k.tag);
    end

    start_device(dma_config);
    set_control(opcode, .initial_transfer(1'b1), .handshake(1'b0), .go(1'b1));
  endtask : run_aes_transfer

  virtual task body();
    aes_kat_t kats[$];
    status_t  status;
    bit [31:0] tag_out;
    bit [31:0] err_code;

    `uvm_info(`gfn, "DMA: Starting inline-AES smoke (KAT) sequence", UVM_LOW)
    init_model();
    get_aes_kats(kats);

    foreach (kats[i]) begin
      aes_kat_t k = kats[i];
      opcode_e  enc_op = k.gcm ? OpcAesGcmEnc : OpcAesCtrEnc;
      opcode_e  dec_op = k.gcm ? OpcAesGcmDec : OpcAesCtrDec;
      int       n      = k.n_blocks;

      // ---------------- encrypt ----------------
      `uvm_info(`gfn, $sformatf("AES KAT '%s': encrypt", k.name), UVM_LOW)
      preload_words(OtInternalAddr, SrcAddr, k.pt, n*4);
      poison_words(OtInternalAddr, DstAddr, n*4);
      clear_dma_status();
      status = '0;
      run_aes_transfer(enc_op, SrcAddr, DstAddr, n, k);
      poll_status(.intr_driven(1'b0), .status(status));
      stop_device();
      `DV_CHECK_EQ(status[StatusError], 1'b0, "encrypt unexpectedly errored")
      check_words(OtInternalAddr, DstAddr, k.ct, n*4, "encrypt ciphertext");
      if (k.gcm) begin
        bit [31:0] exp_tag[4] = k.tag;
        for (int w = 0; w < 4; w++) begin
          csr_rd(ral.tag_out[w], tag_out);
          `DV_CHECK_EQ(tag_out, exp_tag[w], $sformatf("encrypt TAG_OUT word %0d", w))
        end
        csr_rd(ral.status, err_code);
        `DV_CHECK_EQ(err_code[6], 1'b1, "encrypt STATUS.tag_valid not set") // bit 6 = tag_valid
      end

      // ---------------- decrypt (good) ----------------
      `uvm_info(`gfn, $sformatf("AES KAT '%s': decrypt", k.name), UVM_LOW)
      preload_words(OtInternalAddr, SrcAddr, k.ct, n*4);
      poison_words(OtInternalAddr, DstAddr, n*4);
      clear_dma_status();
      status = '0;
      run_aes_transfer(dec_op, SrcAddr, DstAddr, n, k);
      poll_status(.intr_driven(1'b0), .status(status));
      stop_device();
      `DV_CHECK_EQ(status[StatusError], 1'b0, "decrypt (good) unexpectedly errored")
      check_words(OtInternalAddr, DstAddr, k.pt, n*4, "decrypt plaintext");

      // ---------------- decrypt (tamper, GCM only) ----------------
      if (k.gcm) begin
        bit [7:0] orig;
        `uvm_info(`gfn, $sformatf("AES KAT '%s': decrypt tamper", k.name), UVM_LOW)
        preload_words(OtInternalAddr, SrcAddr, k.ct, n*4);
        // Flip one ciphertext byte.
        orig = cfg.mems[OtInternalAddr].read_byte(SrcAddr);
        cfg.mems[OtInternalAddr].write_byte(SrcAddr, orig ^ 8'h01);
        poison_words(OtInternalAddr, DstAddr, n*4);
        clear_dma_status();
        status = '0;
        // The tag mismatch fires the recov_fault alert; tell the scoreboard to expect it.
        // Large max_delay: the alert fires after the entire 4-block GCM decrypt + tag check,
        // which can take tens of thousands of cycles after this point.
        cfg.scoreboard_h.set_exp_alert("recov_fault", .is_fatal(0), .max_delay(50_000));
        run_aes_transfer(dec_op, SrcAddr, DstAddr, n, k);
        poll_status(.intr_driven(1'b0), .status(status));
        stop_device();
        `DV_CHECK_EQ(status[StatusError], 1'b1, "tamper did not raise STATUS.error")
        `DV_CHECK_EQ(status[StatusDone],  1'b0, "tamper unexpectedly set STATUS.done")
        csr_rd(ral.status, err_code);
        `DV_CHECK_EQ(err_code[7], 1'b1, "tamper did not set STATUS.tag_failed") // bit 7
        csr_rd(ral.error_code, err_code);
        `DV_CHECK_EQ(err_code[8], 1'b1, "tamper did not set ERROR_CODE.aes_tag_error") // bit 8
        // Clear the error (RW1C STATUS.error + INTR_STATE) before the next vector.
        csr_wr(ral.status, 32'h0000_0008);
        csr_wr(ral.intr_state, (1 << IntrDmaError));
      end
    end
    // Final cleanup: clear any residual STATUS/INTR_STATE bits so the scoreboard's check_phase
    // does not see a stale `intr_state_hw` vs actual INTR_STATE mismatch.
    clear_dma_status();
    `uvm_info(`gfn, "DMA: Completed inline-AES smoke (KAT) sequence", UVM_LOW)
  endtask : body
endclass
