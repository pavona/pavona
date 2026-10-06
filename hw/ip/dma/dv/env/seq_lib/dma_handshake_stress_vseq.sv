// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Stress 'hardware handshaking' DMA transfers
class dma_handshake_stress_vseq extends dma_handshake_vseq;
  `uvm_object_utils(dma_handshake_stress_vseq)
  `uvm_object_new

  // Handshake mode primarily services peripheral FIFOs (I2C, SPI) at 1-byte granularity,
  // so we must not exclude DmaXfer1BperTxn. However, 1-byte transfers through the overlapped
  // FSM with full handshake protocol overhead (LSIO trigger, interrupt clear, status poll)
  // are expensive in wall-clock simulation time. Keep the iteration and transaction counts
  // lower than the generic stress sequence to stay within the job timeout.
  constraint transactions_c {num_txns inside {[5:15]};}
  constraint num_iters_c {num_iters inside {[3:8]};}

  // The functionality of this vseq is implemented in `dma_generic_vseq` and restricted
  // to 'hardware handshaking' transfers in `dma_handshake_vseq`
  virtual task body();
    `uvm_info(`gfn, "DMA: Starting handshake stress Sequence", UVM_LOW)
    super.body();
    `uvm_info(`gfn, "DMA: Completed handshake stress Sequence", UVM_LOW)
  endtask : body
endclass
