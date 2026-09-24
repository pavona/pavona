// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed memory-to-memory copies whose size is deliberately not a multiple of the chunk size
// and/or the transfer width, to exercise the end-of-transfer SRC_ADDR/DST_ADDR write-back on
// partial final chunks and partial final beats. The address registers must end at `base + total`,
// not rounded up to a whole chunk or a whole bus word. After each transfer this reads the address
// registers back (which the scoreboard now checks) and independently verifies the post-state here.
// (The enabled-memory-range check on partial final chunks is covered by dma_range_partial_vseq,
// which forces the tight range boundary that this generic flow's constraints do not generate.)
class dma_partial_size_vseq extends dma_memory_vseq;
  `uvm_object_utils(dma_partial_size_vseq)
  `uvm_object_new

  constraint iters_c        { num_iters == 2; }
  constraint transactions_c { num_txns  == 12; }

  // Only valid configurations.
  virtual function bit pick_if_config_valid();
    return 1'b1;
  endfunction

  // Constrain to plain memory copies (so both source and destination addresses are written back),
  // incrementing and non-wrapping, with a size that is partial at the chunk and/or the beat level.
  virtual function void randomize_item(ref dma_seq_item dma_config);
    dma_config.valid_dma_config = 1;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(
      dma_config,
      opcode == OpcCopy;
      handshake == 1'b0;
      per_transfer_width == DmaXfer4BperTxn;   // 4-byte beats: total % 4 != 0 -> partial last beat
      src_addr_inc == 1'b1; dst_addr_inc == 1'b1;
      src_chunk_wrap == 1'b0; dst_chunk_wrap == 1'b0;
      total_data_size inside {[1:256]};
      // Guarantee a non-trivial partiality each transaction: either the final beat is partial
      // (total is not a multiple of the 4-byte width) or the final chunk is partial (the chunk
      // size does not divide the total). The chunk size is already forced 4-byte-aligned by the
      // seq_item, so chunk < total with total % chunk != 0 yields a partial final chunk.
      (total_data_size % 4 != 0) ||
        (chunk_data_size < total_data_size && (total_data_size % chunk_data_size != 0));
    )
    `uvm_info(`gfn, $sformatf("DMA: partial-size txn total=%0d chunk=%0d",
                              dma_config.total_data_size, dma_config.chunk_data_size), UVM_MEDIUM)
  endfunction

  // After each clean transfer, read the auto-updated address registers and check they advanced by
  // exactly `total_data_size` (the scoreboard performs the same check; this is an independent guard).
  virtual task ending_txn(int unsigned txn, int unsigned num_txns, ref dma_seq_item dma_config,
                          status_t status);
    bit [31:0] s_lo, s_hi, d_lo, d_hi;
    bit [63:0] act_src, act_dst, exp_src, exp_dst;
    super.ending_txn(txn, num_txns, dma_config, status);

    // Only a clean completion leaves a predictable address post-state.
    if (status[StatusError] || status[StatusAborted] || !status[StatusDone]) return;

    csr_rd(ral.src_addr_lo, s_lo);
    csr_rd(ral.src_addr_hi, s_hi);
    csr_rd(ral.dst_addr_lo, d_lo);
    csr_rd(ral.dst_addr_hi, d_hi);
    act_src = {s_hi, s_lo};
    act_dst = {d_hi, d_lo};

    // base + total for an incrementing, non-wrapping side that actually accesses memory.
    exp_src = dma_config.src_addr +
        ((dma_config.op_reads()  && dma_config.src_addr_inc && !dma_config.src_chunk_wrap) ?
         64'(dma_config.total_data_size) : 64'd0);
    exp_dst = dma_config.dst_addr +
        ((dma_config.op_writes() && dma_config.dst_addr_inc && !dma_config.dst_chunk_wrap) ?
         64'(dma_config.total_data_size) : 64'd0);

    `DV_CHECK_EQ(act_src, exp_src,
        $sformatf("SRC_ADDR post-transfer wrong (total=%0d chunk=%0d): got 0x%0x exp 0x%0x",
                  dma_config.total_data_size, dma_config.chunk_data_size, act_src, exp_src))
    `DV_CHECK_EQ(act_dst, exp_dst,
        $sformatf("DST_ADDR post-transfer wrong (total=%0d chunk=%0d): got 0x%0x exp 0x%0x",
                  dma_config.total_data_size, dma_config.chunk_data_size, act_dst, exp_dst))
  endtask

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting partial-size address write-back sequence", UVM_LOW)
    super.body();
    `uvm_info(`gfn, "DMA: Completed partial-size address write-back sequence", UVM_LOW)
  endtask : body
endclass
