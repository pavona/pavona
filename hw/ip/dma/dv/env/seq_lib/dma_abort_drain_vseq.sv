// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed abort/drain stress for the bus-quiescence corner that escaped the random abort test:
// abort a transfer while reads/writes are still outstanding on the bus, and immediately try to
// reprogram the port-selecting CSRs. The DMA must keep STATUS.busy asserted through the drain (so
// the CSRs stay locked), must never report STATUS.done for an aborted transfer, must complete the
// abort, and a subsequent clean transfer must move correct data (no stale-response corruption).
//
// The hard checks live in the RTL SVAs (AbortNoBusReq_A, AbortBusyHeld_A, DrainBeforeIdle_A,
// AbortEventuallyCompletes_A) and the dma_abort_cg coverage; this sequence drives the stimulus
// (sweeping the abort timing so it lands while requests are in flight under the 0-4 cycle device
// response latency) and self-checks status + post-abort data integrity.
class dma_abort_drain_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_abort_drain_vseq)
  `uvm_object_new

  localparam bit [63:0] SrcAddr = 64'h0000_1000;
  localparam bit [63:0] DstAddr = 64'h0000_3000; // disjoint from src so overlap can't mask issues
  localparam int        Total   = 256;           // many beats, so reads/writes stay outstanding

  // Program a multi-beat OT-internal copy.
  function void program_copy(dma_seq_item c);
    c.src_asid = OtInternalAddr; c.dst_asid = OtInternalAddr;
    c.src_addr = SrcAddr; c.dst_addr = DstAddr;
    c.src_addr_inc = 1'b1; c.dst_addr_inc = 1'b1;
    c.src_chunk_wrap = 1'b0; c.dst_chunk_wrap = 1'b0;
    c.handshake = 1'b0;
    c.total_data_size = Total; c.chunk_data_size = Total;
    c.per_transfer_width = DmaXfer4BperTxn;
    c.mem_range_valid = 1'b1;
    c.mem_range_base  = SrcAddr[31:0];
    c.mem_range_limit = DstAddr[31:0] + Total - 1;
    c.range_regwen    = MuBi4True;
  endfunction

  // Abort `delay` cycles into a multi-beat copy (while requests are outstanding), then immediately
  // attempt to reprogram the ASIDs. The reprogram must be ignored (busy holds the CSRs locked); the
  // SVAs verify the bus quiesces before the abort is reported.
  task run_abort(int delay);
    dma_seq_item c = dma_seq_item::type_id::create("c");
    status_t     status = '0;
    bit [7:0]    src[];
    src = new[Total];
    foreach (src[b]) src[b] = $urandom;
    foreach (src[b]) cfg.mems[OtInternalAddr].write_byte(SrcAddr + b, src[b]);
    for (int i = 0; i < Total; i++) cfg.mems[OtInternalAddr].write_byte(DstAddr + i, 8'hA5);

    program_copy(c);
    csr_wr(ral.status, 32'h0000_002E);
    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(OtInternalAddr, OtInternalAddr);
    set_total_size(Total); set_chunk_data_size(Total);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(SrcAddr[31:0], DstAddr[31:0] + Total - 1, 1'b1, MuBi4True);
    set_control(OpcCopy, .initial_transfer(1'b1), .handshake(1'b0), .go(1'b1));

    cfg.clk_rst_vif.wait_clks(delay);
    abort();
    // Reprogram the port-selecting CSR mid-drain: must be locked out (busy still asserted). If the
    // DMA wrongly went not-busy, AbortBusyHeld_A fails; the drain must not key off this new value.
    set_addr_space_id(SocControlAddr, SocControlAddr);

    // Use poll_status directly (not wait_for_completion) because the ASID was reprogrammed
    // mid-drain and the progress monitor in wait_for_completion would query the wrong port.
    `DV_SPINWAIT(poll_status(.intr_driven(1'b0), .status(status));,
                 "abort_drain: DMA did not reach a terminal state")
    `DV_CHECK_EQ(status[StatusDone], 1'b0,
                 $sformatf("abort delay=%0d: aborted transfer wrongly reported done", delay))
    abort_pending = 1'b0;
    clear_aborted();
    csr_wr(ral.status, 32'h0000_002E);
    csr_wr(ral.intr_state, '1);
  endtask

  // After all those aborts, a clean copy must complete with correct data: a stale response from an
  // aborted transfer must not have aliased into it.
  task run_clean_check();
    dma_seq_item c = dma_seq_item::type_id::create("c");
    status_t     status = '0;
    bit [7:0]    src[], dst[];
    src = new[Total];
    foreach (src[b]) src[b] = $urandom;
    foreach (src[b]) cfg.mems[OtInternalAddr].write_byte(SrcAddr + b, src[b]);
    for (int i = 0; i < Total; i++) cfg.mems[OtInternalAddr].write_byte(DstAddr + i, 8'hA5);

    program_copy(c);
    csr_wr(ral.status, 32'h0000_002E);
    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(OtInternalAddr, OtInternalAddr);
    set_total_size(Total); set_chunk_data_size(Total);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(SrcAddr[31:0], DstAddr[31:0] + Total - 1, 1'b1, MuBi4True);
    set_control(OpcCopy, .initial_transfer(1'b1), .handshake(1'b0), .go(1'b1));
    poll_status(.intr_driven(1'b0), .status(status));
    `DV_CHECK_EQ(status[StatusError], 1'b0, "clean post-abort transfer errored")
    `DV_CHECK_EQ(status[StatusDone],  1'b1, "clean post-abort transfer did not complete")
    dst = new[Total];
    for (int i = 0; i < Total; i++) dst[i] = cfg.mems[OtInternalAddr].read_byte(DstAddr + i);
    foreach (dst[i]) `DV_CHECK_EQ(dst[i], src[i],
                                  $sformatf("post-abort data mismatch at byte %0d", i))
    csr_wr(ral.status, 32'h0000_002E);
    csr_wr(ral.intr_state, '1);
  endtask

  virtual task body();
    dma_seq_item dummy_cfg;
    `uvm_info(`gfn, "DMA: Starting abort/drain directed sequence", UVM_LOW)
    init_model();
    // Start device responders once; they persist across all abort/recovery iterations.
    dummy_cfg = dma_seq_item::type_id::create("dummy_cfg");
    dummy_cfg.src_asid = OtInternalAddr;
    dummy_cfg.dst_asid = OtInternalAddr;
    dummy_cfg.src_addr_inc = 1'b1;
    dummy_cfg.dst_addr_inc = 1'b1;
    dummy_cfg.handshake = 1'b0;
    dummy_cfg.per_transfer_width = DmaXfer4BperTxn;
    start_device(dummy_cfg);
    // Sweep the abort point across the early beats so it lands while reads/writes are outstanding
    // under the randomized 0-4 cycle device response latency.
    for (int d = 1; d <= 10; d++) run_abort(.delay(d));
    run_clean_check();
    `uvm_info(`gfn, "DMA: Completed abort/drain directed sequence", UVM_LOW)
  endtask : body
endclass
