// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Hardware-paced AES KATs with independent fixed, wrapping and linear endpoints.
class dma_aes_fifo_vseq extends dma_aes_smoke_vseq;
  `uvm_object_utils(dma_aes_fifo_vseq)
  `uvm_object_new

  task run_fifo(aes_kat_t k, bit dec, int src_mode, int dst_mode, int chunk,
                bit bad_tag = 0, int fault = 0);
    dma_seq_item c = dma_seq_item::type_id::create("fifo_config");
    bit [7:0] input_bytes[];
    bit [31:0] st, value;
    opcode_e op = k.gcm ? (dec ? OpcAesGcmDec : OpcAesGcmEnc)
                        : (dec ? OpcAesCtrDec : OpcAesCtrEnc);
    c.src_addr = SrcAddr;
    c.dst_addr = DstAddr;
    c.src_asid = (src_mode + dst_mode) % 2 ? SocControlAddr : OtInternalAddr;
    c.dst_asid = c.src_asid == OtInternalAddr ? SocControlAddr : OtInternalAddr;
    c.src_addr_inc = src_mode[1];
    c.src_chunk_wrap = src_mode[0];
    c.dst_addr_inc = dst_mode[1];
    c.dst_chunk_wrap = dst_mode[0];
    c.handshake = 1;
    c.handshake_intr_en = 1;
    c.lsio_trigger_i = 1;
    c.clear_intr_src = 0;
    c.total_data_size = k.n_blocks * 16;
    c.chunk_data_size = chunk;
    c.per_transfer_width = DmaXfer4BperTxn;
    input_bytes = new[c.total_data_size];
    foreach (input_bytes[b]) input_bytes[b] = dec ? k.ct[b/4][(b%4)*8 +: 8]
                                                : k.pt[b/4][(b%4)*8 +: 8];
    clear_dma_status();
    enable_bus_errors(0);
    `DV_SPINWAIT(do begin csr_rd(ral.cfg_regwen, value); end while (value != MuBi4True);,
                 "AES FIFO: configuration did not unlock")
    release_hardware_handshake_intr();
    csr_wr(ral.clear_intr_src, 0);
    csr_wr(ral.handshake_intr_enable, 1);
    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(c.src_chunk_wrap, c.src_addr_inc);
    set_dst_config(c.dst_chunk_wrap, c.dst_addr_inc);
    set_addr_space_id(c.src_asid, c.dst_asid);
    set_total_size(c.total_data_size); set_chunk_data_size(chunk);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
    program_aes_config(k.key, '{default: 0}, k.iv, k.aad, k.aad_blocks, 3'd1, 1'b0);
    if (dec && k.gcm) begin
      bit [31:0] tag[4] = k.tag;
      if (bad_tag) tag[0] ^= 1;
      program_aes_tag_in(tag);
    end
    cfg.aes_expect_tag_fail = bad_tag;
    if (bad_tag) cfg.scoreboard_h.set_exp_alert("recov_fault", .is_fatal(0),
                                              .max_delay(50_000));
    start_device(c);
    set_control(op, .initial_transfer(1'b1), .handshake(1'b1), .go(1'b1));

    for (int offset = 0; offset < c.total_data_size; offset += chunk) begin
      int count = c.chunk_size(offset);
      bit [63:0] src = SrcAddr + ((c.src_addr_inc && !c.src_chunk_wrap) ? offset : 0);
      bit [63:0] dst = DstAddr + ((c.dst_addr_inc && !c.dst_chunk_wrap) ? offset : 0);
      if (offset != 0 && fault != 0) begin
        if (fault == 1) begin
          abort();
        end else begin
          // Fail the first read after resuming a FIFO-backed crypto session.
          enable_bus_errors(100);
          set_hardware_handshake_intr(1);
          cfg.clk_rst_vif.wait_clks(2);
          release_hardware_handshake_intr();
        end
        `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[2] || st[3]));,
                     "AES FIFO: fault did not terminate the message")
        `DV_CHECK_EQ(st[1], 0)
        `DV_CHECK_EQ(st[2], fault == 1)
        `DV_CHECK_EQ(st[3], fault == 2)
        if (fault == 1) begin
          abort_pending = 0;
          clear_aborted();
        end else begin
          csr_rd(ral.error_code, value);
          `DV_CHECK_EQ(value[DmaBusErr], 1)
        end
        enable_bus_errors(0);
        stop_device();
        clear_dma_status();
        return;
      end
      if (!c.src_addr_inc) begin
        set_model_src_fifo_mode(c.src_asid, SrcAddr, DmaXfer4BperTxn, chunk, 1, 0, count);
        populate_src_fifo(c.src_asid, input_bytes, offset, count);
      end else begin
        for (int b = 0; b < count; b++)
          cfg.mems[c.src_asid].write_byte(src + b, input_bytes[offset + b]);
      end
      if (!c.dst_addr_inc) begin
        cfg.fifo_dst[c.dst_asid].init();
        set_model_dst_fifo_mode(c.dst_asid, DstAddr, DmaXfer4BperTxn, chunk, 1, 0, count);
      end else begin
        for (int b = 0; b < count; b++) cfg.mems[c.dst_asid].write_byte(dst + b, 8'hA5);
      end
      // The device makes one chunk available (or reserves room for it) before triggering.
      set_hardware_handshake_intr(1);
      cfg.clk_rst_vif.wait_clks(2);
      release_hardware_handshake_intr();
      `DV_SPINWAIT(begin
        wait (cfg.scoreboard_h.num_bytes_transferred >= offset + count &&
              cfg.scoreboard_h.dst_queue.size() == 0);
      end, "AES FIFO: chunk did not drain")
      cfg.clk_rst_vif.wait_clks(2);

      if (offset + count < c.total_data_size) begin
        csr_rd(ral.status, st);
        `DV_CHECK_EQ(st[7:0], 1, "FIFO chunk completed or authenticated the message early")
        csr_rd(ral.cfg_regwen, value);
        `DV_CHECK_EQ(value, MuBi4False)
        csr_rd(ral.control, value);
        `DV_CHECK_EQ(value[31], 1)
        // Trigger is low: no source pops or destination pushes may continue during the pause.
        delay(30);
        `DV_CHECK_EQ(cfg.scoreboard_h.num_bytes_read, offset + count)
        `DV_CHECK_EQ(cfg.scoreboard_h.num_bytes_transferred, offset + count)
      end else begin
        `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[1] || st[3]));,
                     "AES FIFO: message did not complete")
        `DV_CHECK_EQ(st[3], bad_tag)
        `DV_CHECK_EQ(st[1], !bad_tag)
        if (k.gcm) begin
          `DV_CHECK_EQ(st[6], !bad_tag)
          `DV_CHECK_EQ(st[7], bad_tag)
          if (!dec) for (int w = 0; w < 4; w++) begin
            csr_rd(ral.tag_out[w], value);
            `DV_CHECK_EQ(value, k.tag[w])
          end
        end
      end
      // Drain/check the output before the next chunk overwrites a wrapping window.
      for (int b = 0; b < count; b++) begin
        bit [7:0] expected_byte = dec ? k.pt[(offset+b)/4][((offset+b)%4)*8 +: 8]
                                     : k.ct[(offset+b)/4][((offset+b)%4)*8 +: 8];
        bit [7:0] actual_byte = c.dst_addr_inc ? cfg.mems[c.dst_asid].read_byte(dst + b)
                                              : cfg.fifo_dst[c.dst_asid].read_byte(DstAddr);
        `DV_CHECK_EQ(actual_byte, expected_byte, "AES FIFO byte mismatch")
      end
      if (!c.src_addr_inc) `DV_CHECK_EQ(cfg.fifo_src[c.src_asid].count_bytes_in_queue(), 0)
      if (!c.dst_addr_inc) `DV_CHECK_EQ(cfg.fifo_dst[c.dst_asid].count_bytes_in_queue(), 0)
      if (!bad_tag || offset + count < c.total_data_size) begin
        csr_rd(ral.src_addr_lo, value);
        `DV_CHECK_EQ(value, SrcAddr +
                     ((c.src_addr_inc && !c.src_chunk_wrap) ? offset + count : 0))
        csr_rd(ral.dst_addr_lo, value);
        `DV_CHECK_EQ(value, DstAddr +
                     ((c.dst_addr_inc && !c.dst_chunk_wrap) ? offset + count : 0))
      end
    end
    stop_device();
    clear_dma_status();
  endtask

  virtual task body();
    aes_kat_t kats[$];
    init_model();
    cfg.aes_scb_predict = 0; // This sequence checks every output byte against the KAT.
    get_aes_kats(kats);
    foreach (kats[k]) begin
      for (int src = 0; src < 4; src++) begin
        for (int dst = 0; dst < 4; dst++) begin
          for (int chunk = 16; chunk <= 80; chunk += 16) begin
            run_fifo(kats[k], 0, src, dst, chunk);
            run_fifo(kats[k], 1, src, dst, chunk);
          end
        end
      end
      if (kats[k].gcm) run_fifo(kats[k], 1, 1, 1, 16, 1);
      run_fifo(kats[k], 0, 1, 1, 16, .fault(1));
      run_fifo(kats[k], 0, 3, 3, 16, .fault(2));
      run_fifo(kats[k], 0, 1, 1, 16); // Recovery after FIFO abort/error.
    end
  endtask
endclass
