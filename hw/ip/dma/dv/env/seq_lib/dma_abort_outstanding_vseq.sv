// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed legacy-environment reproducer for aborting a DMA operation after
// its source request has been accepted but before the response is returned.
//
// A TL request cannot be withdrawn after its A-channel handshake. The target
// still owes the DMA a D-channel response, and the DMA must retain ownership of
// that response before permitting the interface to be reused. STATUS.aborted
// is documented as being set once the aborted operation drains, so it must not
// become set while this accepted Host request is still waiting for its response.
//
// Keep this sequence on the legacy dma_base_vseq path so the reproducer is
// independent of the reset-safe migration. Response latency is controlled by
// the existing TL device-agent delay setting, and request/response boundaries
// are observed through the responder's monitor-fed transaction queue. The
// sequence does not sample TL interface signals.
class dma_abort_outstanding_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_abort_outstanding_vseq)
  `uvm_object_new

  // Leave enough time after request acceptance to issue the abort and read
  // STATUS before the held response is presented by the TL device driver.
  localparam int unsigned HeldResponseDelayClks = 200;
  localparam int unsigned TransactionTimeoutClks = HeldResponseDelayClks + 100;

  // Build one valid four-byte Host-to-CTN operation. The Host path is used for
  // the held source response because the abort contract explicitly guarantees
  // completion of secure-side internal transactions.
  virtual function void configure_operation();
    dma_config.valid_dma_config  = 1'b1;
    dma_config.src_addr_in_range = 1'b1;
    dma_config.dst_addr_in_range = 1'b1;
    // dma_seq_item enables its multi-chunk constraint by default even though
    // this reproducer needs exactly one accepted source request. Disable only
    // that inherited stimulus constraint; the architectural validity checks
    // remain enabled.
    dma_config.multi_chunk_c.constraint_mode(1'b0);

    `DV_CHECK_RANDOMIZE_WITH_FATAL(dma_config,
                                   opcode == OpcCopy;
      handshake == 1'b0;
      per_transfer_width == DmaXfer4BperTxn;
      src_asid == OtInternalAddr;
      dst_asid == SocControlAddr;
      src_addr == 64'h0000_0000_0000_1000;
      dst_addr == 64'h0000_0000_0000_2000;
      src_addr_inc == 1'b1;
      dst_addr_inc == 1'b1;
      src_chunk_wrap == 1'b0;
      dst_chunk_wrap == 1'b0;
      mem_range_valid == 1'b1;
      range_regwen == MuBi4True;
      mem_range_base == 32'h0000_1000;
      mem_range_limit == 32'h0000_1fff;
      total_data_size == 4;
      chunk_data_size == 4;
      clear_intr_src == '0;)

    `DV_CHECK(dma_config.is_valid_config,
              "Directed abort-with-outstanding-response configuration must be valid")
    `uvm_info(`gfn, $sformatf("DMA: Directed abort configuration:%s", dma_config.convert2string()),
              UVM_MEDIUM)
  endfunction : configure_operation

  // dma_pull_seq increments bytes_read only after consuming the monitor's
  // accepted A-channel transaction. Waiting on that transaction-derived count
  // makes the abort boundary deterministic without sampling interface signals.
  virtual task wait_for_host_request(int unsigned expected_bytes);
    int unsigned timeout = TransactionTimeoutClks;

    while (seq_host.bytes_read < expected_bytes && timeout > 0) begin
      delay(1);
      timeout--;
    end
    `DV_CHECK_EQ(seq_host.bytes_read, expected_bytes,
                 "Timed out waiting for the accepted Host source request")
    `DV_CHECK_EQ(seq_host.req_q.size(), 1, "Host request was not held pending its delayed response")
  endtask : wait_for_host_request

  // The responder removes the request from req_q only after the driver reports
  // that its D-channel response completed. This is the transaction-level drain
  // boundary required before STATUS.aborted may be reported.
  virtual task wait_for_host_response();
    int unsigned timeout = TransactionTimeoutClks;

    while (seq_host.req_q.size() != 0 && timeout > 0) begin
      delay(1);
      timeout--;
    end
    `DV_CHECK_EQ(seq_host.req_q.size(), 0,
                 "Timed out draining the accepted Host response after abort")
    // Permit the response monitor and DUT status update to retire in their
    // normal clocked order before reading STATUS.
    delay(2);
  endtask : wait_for_host_response

  // Each interface sequencer has exactly one responder sequence. Once every
  // responder queue is empty, no sequence or driver owns a transaction and the
  // sequencers can be stopped without abandoning interface traffic. Keep this
  // cleanup local: the shared legacy graceful-stop helper is not reliable for
  // an idle responder blocked waiting for its next request.
  virtual task stop_devices_after_drain();
    `DV_CHECK_EQ(seq_host.req_q.size(), 0,
                 "Host responder still owns a request at end of test")
    `DV_CHECK_EQ(seq_ctn.req_q.size(), 0,
                 "CTN responder still owns a request at end of test")
    `DV_CHECK_EQ(seq_sys.req_q.size(), 0,
                 "System responder still owns a request at end of test")

    p_sequencer.tl_sequencer_dma_host_h.stop_sequences();
    p_sequencer.tl_sequencer_dma_ctn_h.stop_sequences();
    p_sequencer.tl_sequencer_dma_sys_h.stop_sequences();
  endtask : stop_devices_after_drain

  virtual task body();
    uvm_reg_data_t status;
    status_t       completion_status;

    `uvm_info(`gfn, "DMA: Starting abort outstanding-response reproducer", UVM_LOW)
    super.body();
    configure_operation();

    // Use deterministic acceptance and response timing. These helpers are the
    // established legacy mechanism for controlling the TL device agents.
    set_access_delays(0, 0);
    set_response_delays(HeldResponseDelayClks, HeldResponseDelayClks);

    run_common_config(dma_config);
    start_device(dma_config);
    start_chunk(dma_config, 1'b1);
    wait_for_host_request(dma_config.txn_bytes());

    // Abort only after the Host request has been accepted. Until its delayed
    // response completes, the operation has not drained and the interface is
    // not safe for another one-outstanding request.
    abort();
    csr_rd(ral.status, status);
    `DV_CHECK_EQ(get_field_val(ral.status.busy, status), 1'b1,
                     "STATUS.busy cleared before the accepted Host response drained")
    `DV_CHECK_EQ(get_field_val(ral.status.aborted, status), 1'b0,
                     "STATUS.aborted set before the accepted Host response drained")

    wait_for_host_response();
    csr_rd(ral.status, status);
    `DV_CHECK_EQ(get_field_val(ral.status.busy, status), 1'b0,
                     "STATUS.busy remained set after the accepted Host response drained")
    `DV_CHECK_EQ(get_field_val(ral.status.aborted, status), 1'b1,
                     "STATUS.aborted was not set after the accepted Host response drained")
    clear_aborted();

    // Prove that the same interface remains usable once the old response has
    // drained. Reconfigure through the normal CSR path and complete one more
    // operation with ordinary zero-delay responses.
    set_response_delays(0, 0);
    run_common_config(dma_config);
    start_chunk(dma_config, 1'b1);
    wait_for_completion(1'b0, completion_status);
    `DV_CHECK_EQ(completion_status, status_t'(1 << StatusDone),
                 "Post-abort Host recovery operation did not complete normally")
    clear_done();

    stop_devices_after_drain();
    `uvm_info(`gfn, "DMA: Completed abort outstanding-response reproducer", UVM_LOW)
  endtask : body
endclass : dma_abort_outstanding_vseq
