// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed cross-port overlap test.
//
// Forces source and destination onto different host ports (OtInternalAddr vs SocControlAddr map to
// distinct DmaPortDesc entries), so src_port_idx != dst_port_idx and the read of beat i+1 overlaps
// the write of beat i. Plain memory-to-memory copy, 4B transfers, zero delays so the overlap region
// (DmaRunPipe) is exercised back-to-back. Data/address correctness is checked by the scoreboard.
class dma_overlap_vseq extends dma_memory_vseq;
  `uvm_object_utils(dma_overlap_vseq)
  `uvm_object_new

  constraint iters_c {num_iters == 1;}
  constraint transactions_c {num_txns == 16;}

  // Valid configurations only.
  virtual function bit pick_if_config_valid();
    return 1'b1;
  endfunction

  virtual function void randomize_item(ref dma_seq_item dma_config);
    dma_config.valid_dma_config = 1;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(
      dma_config,
      handshake == 1'b0;                          // memory-to-memory
      opcode == OpcCopy;                          // plain copy, no inline op
      per_transfer_width == DmaXfer4BperTxn;      // 4B transfers
      total_data_size % 4 == 0;                   // whole beats only
      total_data_size inside {[64:512]};          // moderate, multi-beat
      // Force different host ports so the cross-port overlap path runs.
      src_asid == OtInternalAddr;
      dst_asid == SocControlAddr;)
    `uvm_info(`gfn, $sformatf("DMA: Randomized a new transaction:%s",
                              dma_config.convert2string()), UVM_HIGH)
  endfunction

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting cross-port overlap Sequence", UVM_LOW)
    // Zero delays so reads and writes overlap on the two ports back-to-back.
    set_access_delays(0, 0);
    set_response_delays(0, 0);
    super.body();
    `uvm_info(`gfn, "DMA: Completed cross-port overlap Sequence", UVM_LOW)
  endtask : body
endclass
