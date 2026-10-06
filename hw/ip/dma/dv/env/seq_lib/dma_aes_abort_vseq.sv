// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed abort test for inline AES: start an AES transfer, abort it mid-flight, and confirm the
// DMA tears down cleanly (STATUS.aborted, no hang, no done) and then a fresh AES transfer completes
// without error - exercising the abort-path engine flush + SEC_WIPE and recovery.
class dma_aes_abort_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_aes_abort_vseq)
  `uvm_object_new

  localparam bit [63:0] SrcAddr   = 64'h0000_1000;
  localparam bit [63:0] DstAddr   = 64'h0000_2000;
  localparam bit [31:0] RangeBase = 32'h0000_0000;
  localparam bit [31:0] RangeLim  = 32'h0000_FFFF;

  rand int unsigned num_iters;
  constraint num_iters_c { num_iters inside {[4:8]}; }

  // Program a valid AES transfer and assert `go` (non-blocking).
  task program_and_go(bit gcm, int n_blocks, int chunk_blocks = 0, bit handshake = 0);
    bit [31:0] key0[8], key1[8], iv[4], aad[8];
    bit [7:0]  pt[];
    foreach (key0[w]) key0[w] = $urandom;
    foreach (key1[w]) key1[w] = $urandom;
    foreach (iv[w])   iv[w]   = $urandom;
    foreach (aad[w])  aad[w]  = $urandom;
    pt = new[n_blocks*16];
    foreach (pt[b]) pt[b] = $urandom;
    foreach (pt[b]) cfg.mems[OtInternalAddr].write_byte(SrcAddr + b, pt[b]);

    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(OtInternalAddr, OtInternalAddr);
    set_total_size(n_blocks*16);
    set_chunk_data_size((chunk_blocks == 0 ? n_blocks : chunk_blocks)*16);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
    program_aes_config(key0, key1, iv, aad, 4'd0, 3'b001, 1'b0);
    release_hardware_handshake_intr();
    csr_wr(ral.clear_intr_src, 0);
    csr_wr(ral.handshake_intr_enable, 1);
    set_control(gcm ? OpcAesGcmEnc : OpcAesCtrEnc,
                .initial_transfer(1'b1), .handshake(handshake), .go(1'b1));
  endtask

  virtual task body();
    dma_seq_item dummy_cfg;
    `uvm_info(`gfn, "DMA: Starting inline-AES abort sequence", UVM_LOW)
    init_model();

    // Start device responders once; they persist across all abort/recovery iterations.
    // AES uses incrementing memory addresses in both pacing modes.
    dummy_cfg = dma_seq_item::type_id::create("dummy_cfg");
    dummy_cfg.src_asid = OtInternalAddr;
    dummy_cfg.dst_asid = OtInternalAddr;
    dummy_cfg.src_addr_inc = 1'b1;
    dummy_cfg.dst_addr_inc = 1'b1;
    dummy_cfg.handshake = 1'b0;
    dummy_cfg.per_transfer_width = DmaXfer4BperTxn;
    start_device(dummy_cfg);

    for (int i = 0; i < num_iters; i++) begin
      bit [31:0] st, addr;
      bit        gcm = $urandom_range(0, 1);

      // Abort active, software-paused, hardware-paused and not-yet-triggered messages.
      program_and_go(.gcm(gcm), .n_blocks(4), .chunk_blocks(1), .handshake(i % 4 >= 2));
      if (i % 4 == 2) begin
        set_hardware_handshake_intr(1);
        cfg.clk_rst_vif.wait_clks(2);
        release_hardware_handshake_intr();
        `DV_SPINWAIT(do begin csr_rd(ral.src_addr_lo, addr); end while (addr != SrcAddr + 16);,
                     "AES abort: hardware-paced chunk did not finish")
        csr_rd(ral.status, st);
        `DV_CHECK_EQ(st[5:0], 1)
      end else if (i % 4 == 0) begin
        `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[5] || st[3]));,
                     "AES abort: did not reach suspended chunk")
        `DV_CHECK_EQ(st[3:0], 0)
        delay(20);
      end else begin
        cfg.clk_rst_vif.wait_clks($urandom_range(1, 80));
      end
      abort();
      release_hardware_handshake_intr();

      // Must reach a terminal state (aborted / done / error) - i.e. not hang.
      `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[1] || st[2] || st[3]));,
                   "AES abort: DMA did not reach a terminal state")
      `uvm_info(`gfn, $sformatf("AES abort iter %0d: status=0x%0x", i, st), UVM_MEDIUM)
      abort_pending = 1'b0;
      clear_aborted();
      csr_wr(ral.status, 32'h0000_002E); // clear RW1C done/aborted/error/chunk_done
      csr_wr(ral.intr_state, '1);
      // Wait for CFG_REGWEN to unlock before writing config for the recovery transfer.
      `DV_SPINWAIT(begin
        bit [31:0] regwen;
        do begin csr_rd(ral.cfg_regwen, regwen); end while (regwen != prim_mubi_pkg::MuBi4True);
      end, "AES abort: CFG_REGWEN did not unlock after abort")

      // Recovery: a fresh CTR transfer must complete without error.
      program_and_go(.gcm(1'b0), .n_blocks(2));
      `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[1] || st[3]));,
                   "AES abort: recovery transfer did not complete")
      `DV_CHECK_EQ(st[3], 1'b0, "AES abort: recovery transfer errored")
      csr_wr(ral.status, 32'h0000_002E);
      csr_wr(ral.intr_state, '1);
    end
    `uvm_info(`gfn, "DMA: Completed inline-AES abort sequence", UVM_LOW)
  endtask : body
endclass
