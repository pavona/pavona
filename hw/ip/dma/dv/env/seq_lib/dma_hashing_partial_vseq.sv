// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed test for the inline-hashing deferred-wait corner.
//
// Performs SHA transfers whose final beat is partial (total size not a multiple of 4B) and feeds
// the SHA engine as fast as possible (zero access/response delays) to provoke SHA back-pressure in
// the serial per-beat region: a captured beat stalls the write side until the SHA
// engine consumes it. The digest check in the scoreboard catches any byte-enable corruption around
// the partial final beat. See dma_fsm_cg.cp_sha_backpressure for the matching cover point.
class dma_hashing_partial_vseq extends dma_memory_vseq;
  `uvm_object_utils(dma_hashing_partial_vseq)
  `uvm_object_new

  constraint iters_c {num_iters == 1;}
  // Several short transfers per run so back-pressure lands at varying offsets from the final beat.
  constraint transactions_c {num_txns == 32;}

  // Valid configurations only.
  virtual function bit pick_if_config_valid();
    return 1'b1;
  endfunction

  virtual function void randomize_item(ref dma_seq_item dma_config);
    dma_config.valid_dma_config = 1;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(
      dma_config,
      handshake == 1'b0;                                 // memory-to-memory
      opcode inside {OpcSha256, OpcSha384, OpcSha512};   // inline hashing
      per_transfer_width == DmaXfer4BperTxn;             // SHA requires 4B transfers
      (total_data_size % 4) != 0;                        // force a partial final beat
      total_data_size inside {[8:1024]};)               // multiple beats
    `uvm_info(`gfn, $sformatf("DMA: Randomized a new transaction:%s",
                              dma_config.convert2string()), UVM_HIGH)
  endfunction

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting hashing partial-beat Sequence", UVM_LOW)
    // Feed the SHA engine as fast as possible to provoke SHA back-pressure in the serial path.
    set_access_delays(0, 0);
    set_response_delays(0, 0);
    super.body();
    `uvm_info(`gfn, "DMA: Completed hashing partial-beat Sequence", UVM_LOW)
  endtask : body
endclass
