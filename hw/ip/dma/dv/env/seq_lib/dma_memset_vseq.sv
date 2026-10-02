// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed test for the memset operation (read_en=0, write_en=1, digest=none).
//
// The DMA performs no source reads; the destination is filled with the pattern held in
// SRC_ADDR_LO, dst-keyed and replicated per the transfer width. Exercises 1B/2B/4B transfers,
// multi-beat and (optionally) multi-chunk transfers. The scoreboard checks that no source read
// traffic is generated and that the destination memory holds the replicated fill pattern; the
// no-source-traffic SVA backs this up.
class dma_memset_vseq extends dma_memory_vseq;
  `uvm_object_utils(dma_memset_vseq)
  `uvm_object_new

  constraint iters_c {num_iters == 1;}
  constraint transactions_c {num_txns == 16;}

  // Valid configurations only.
  virtual function bit pick_if_config_valid();
    return 1'b1;
  endfunction

  virtual function void randomize_item(ref dma_seq_item dma_config);
    dma_config.valid_dma_config = 1;
    // The base opcode_dist_c excludes OpcMemset; disable it so we can pin it.
    dma_config.opcode_dist_c.constraint_mode(0);
    `DV_CHECK_RANDOMIZE_WITH_FATAL(
      dma_config,
      opcode == OpcMemset;                                              // read_en=0, write_en=1
      handshake == 1'b0;                                               // memset cannot handshake
      per_transfer_width inside {DmaXfer1BperTxn, DmaXfer2BperTxn, DmaXfer4BperTxn};
      total_data_size inside {[1:1024]};)                              // multi-beat sizes
    dma_config.opcode_dist_c.constraint_mode(1);
    `uvm_info(`gfn, $sformatf("DMA: Randomized a new transaction:%s",
                              dma_config.convert2string()), UVM_HIGH)
  endfunction

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting memset Sequence", UVM_LOW)
    super.body();
    `uvm_info(`gfn, "DMA: Completed memset Sequence", UVM_LOW)
  endtask : body
endclass
