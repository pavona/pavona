// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed test for the verify operation (read_en=1, write_en=0, digest=sha256/384/512).
//
// The DMA reads the source and computes an inline digest but performs no destination writes;
// completion is read-driven. Exercises 4B transfers (required by inline hashing), multi-beat and
// (optionally) multi-chunk transfers. The scoreboard checks the digest against the DPI reference
// over the read bytes and that no destination write traffic is generated; the no-destination-traffic
// SVA backs this up.
class dma_verify_vseq extends dma_memory_vseq;
  `uvm_object_utils(dma_verify_vseq)
  `uvm_object_new

  constraint iters_c {num_iters == 1;}
  constraint transactions_c {num_txns == 16;}

  // Valid configurations only.
  virtual function bit pick_if_config_valid();
    return 1'b1;
  endfunction

  virtual function void randomize_item(ref dma_seq_item dma_config);
    dma_config.valid_dma_config = 1;
    // The base opcode_dist_c excludes OpcVerify*; disable it so we can pin it.
    dma_config.opcode_dist_c.constraint_mode(0);
    `DV_CHECK_RANDOMIZE_WITH_FATAL(
      dma_config,
      opcode inside {OpcVerifySha256, OpcVerifySha384, OpcVerifySha512};  // read_en=1, write_en=0
      handshake == 1'b0;                                                 // verify cannot handshake
      per_transfer_width == DmaXfer4BperTxn;                            // inline hashing is 4B only
      total_data_size inside {[4:1024]};)                              // multi-beat sizes
    dma_config.opcode_dist_c.constraint_mode(1);
    `uvm_info(`gfn, $sformatf("DMA: Randomized a new transaction:%s",
                              dma_config.convert2string()), UVM_HIGH)
  endfunction

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting verify Sequence", UVM_LOW)
    super.body();
    `uvm_info(`gfn, "DMA: Completed verify Sequence", UVM_LOW)
  endtask : body
endclass
