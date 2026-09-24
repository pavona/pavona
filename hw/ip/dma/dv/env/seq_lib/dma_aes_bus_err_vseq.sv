// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed bus-error test for inline AES: start a valid AES transfer while the TL-UL device agents
// inject random `d_error` responses, and confirm the DMA reports the error cleanly. When the gather
// (read) or scatter (write) of an AES block hits a bus error the controller must surface
// ERROR_CODE.bus_error + STATUS.error and never STATUS.done. A subsequent error-free transfer must
// then complete normally - exercising recovery of the AES datapath out of the bus-error path.
//
// Scoreboard AES prediction stays disabled (injected errors corrupt the moved data); the generic
// scoreboard still predicts/checks the DmaBusErr response, and this sequence self-checks STATUS.
class dma_aes_bus_err_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_aes_bus_err_vseq)
  `uvm_object_new

  localparam bit [63:0] SrcAddr   = 64'h0000_1000;
  localparam bit [63:0] DstAddr   = 64'h0000_2000;
  localparam bit [31:0] RangeBase = 32'h0000_0000;
  localparam bit [31:0] RangeLim  = 32'h0000_FFFF;

  rand int unsigned num_iters;
  constraint num_iters_c { num_iters inside {[6:12]}; }

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
    `uvm_info(`gfn, "DMA: Starting inline-AES bus-error sequence", UVM_LOW)
    init_model();

    // Start memory responders once; they persist across both pacing modes.
    dummy_cfg = dma_seq_item::type_id::create("dummy_cfg");
    dummy_cfg.src_asid = OtInternalAddr;
    dummy_cfg.dst_asid = OtInternalAddr;
    dummy_cfg.src_addr_inc = 1'b1;
    dummy_cfg.dst_addr_inc = 1'b1;
    dummy_cfg.handshake = 1'b0;
    dummy_cfg.per_transfer_width = DmaXfer4BperTxn;
    start_device(dummy_cfg);

    for (int i = 0; i < num_iters; i++) begin
      bit [31:0] st, ec, addr;
      bit        gcm = $urandom_range(0, 1);
      bit        handshake = (i % 2) != 0;

      // Finish a clean chunk before injecting an error into the resumed message.
      enable_bus_errors(0);
      program_and_go(.gcm(gcm), .n_blocks(4), .chunk_blocks(1), .handshake(handshake));
      if (handshake) begin
        set_hardware_handshake_intr(1);
        cfg.clk_rst_vif.wait_clks(2);
        release_hardware_handshake_intr();
        `DV_SPINWAIT(do begin csr_rd(ral.src_addr_lo, addr); end while (addr != SrcAddr + 16);,
                     "AES bus-error: hardware-paced chunk did not finish")
        csr_rd(ral.status, st);
        `DV_CHECK_EQ(st[5:0], 1)
      end else begin
        `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[5] || st[3]));,
                     "AES bus-error: first chunk did not finish")
      end
      `DV_CHECK_EQ(st[3], 0)
      csr_wr(ral.status, 32'h20);
      // Force an error after resuming a retained crypto session.
      enable_bus_errors(100);
      if (handshake) begin
        set_hardware_handshake_intr(1);
        cfg.clk_rst_vif.wait_clks(2);
        release_hardware_handshake_intr();
      end else begin
        set_control(gcm ? OpcAesGcmEnc : OpcAesCtrEnc,
                    .initial_transfer(1'b0), .handshake(1'b0), .go(1'b1));
      end

      // Must reach a terminal state (done / error); a bus error must not hang the engine.
      `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[1] || st[3]));,
                   "AES bus-error: DMA did not reach a terminal state")
      `uvm_info(`gfn, $sformatf("AES bus-err iter %0d: status=0x%0x", i, st), UVM_MEDIUM)
      `DV_CHECK_EQ(st[3], 1'b1, "Resumed AES did not report the injected bus error")

      // If the transfer errored it must be flagged as a bus error (and never report done).
      if (st[3]) begin
        csr_rd(ral.error_code, ec);
        `DV_CHECK_EQ(ec[DmaBusErr], 1'b1, "AES bus-error: STATUS.error without ERROR_CODE.bus_error")
        `DV_CHECK_EQ(st[1], 1'b0, "AES bus-error: STATUS.done set alongside STATUS.error")
      end
      csr_wr(ral.status, 32'h0000_002E); // clear RW1C done/aborted/error/chunk_done
      csr_wr(ral.intr_state, '1);
      // Wait for CFG_REGWEN to unlock before reprogramming.
      `DV_SPINWAIT(begin
        bit [31:0] regwen;
        do begin csr_rd(ral.cfg_regwen, regwen); end while (regwen != prim_mubi_pkg::MuBi4True);
      end, "AES bus-error: CFG_REGWEN did not unlock")
    end

    // Recovery: with bus errors disabled a fresh CTR transfer must complete without error.
    begin
      bit [31:0] st;
      enable_bus_errors(0);
      // Wait for CFG_REGWEN to unlock after the last error iteration.
      `DV_SPINWAIT(begin
        bit [31:0] regwen;
        do begin csr_rd(ral.cfg_regwen, regwen); end while (regwen != prim_mubi_pkg::MuBi4True);
      end, "AES bus-error: CFG_REGWEN did not unlock before recovery")
      program_and_go(.gcm(1'b0), .n_blocks(2));
      `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!(st[1] || st[3]));,
                   "AES bus-error: recovery transfer did not complete")
      `DV_CHECK_EQ(st[3], 1'b0, "AES bus-error: recovery transfer errored")
      csr_wr(ral.status, 32'h0000_002E);
      csr_wr(ral.intr_state, '1);
    end
    `uvm_info(`gfn, "DMA: Completed inline-AES bus-error sequence", UVM_LOW)
  endtask : body
endclass
