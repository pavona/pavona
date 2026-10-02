// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed test for the DMA-enabled memory-range check on a legal final partial chunk.
//
// DmaAddrSetup validates `addr + this_chunk_len - 1 <= limit`. The check must use the actual length
// of the current chunk, not the programmed chunk_data_size: the final chunk of a transfer whose
// total is not a multiple of chunk_data_size is shorter, so checking it as a full chunk rejects a
// legal access whose true end is within the (inclusive) range.
//
// The generic randomization cannot reach this case: the seq_item range constraints only require the
// full chunk and the whole transfer to fit from the *original* address and leave generous range
// slack, so the tight boundary where a full-chunk-rounded end crosses the limit is never generated.
// This sequence programs the registers directly: the enabled range ends exactly at the transfer's
// last byte (limit == base + total - 1) while chunk_data_size > total_data_size, so
// a full-chunk-rounded end (base + chunk - 1) overshoots the limit even though the true end
// (base + total - 1) sits on it. Run for both the source-checked (OT->SoC) and destination-checked
// (SoC->OT) directions. On the unfixed RTL this raises a spurious DmaSrcAddrErr/DmaDstAddrErr.
//
// This exercises both address-increment modes of the range check:
//  - run_boundary       : incrementing endpoints; final partial chunk ends on the inclusive limit.
//  - run_fixed_boundary : fixed (no-increment) endpoint, range tightened to one transfer word. A
//                         fixed address is a FIFO endpoint in DV that reuses one word, so the legal
//                         span is one word; the pre-fix check sized it from the remaining bytes.
class dma_range_partial_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_range_partial_vseq)
  `uvm_object_new

  localparam bit [63:0] OtAddr  = 64'h0000_1000; // range-checked (OT-internal) buffer
  localparam bit [63:0] SocAddr = 64'h0000_2000; // non-checked (SoC) buffer

  // Program and run one boundary copy, and check it is NOT spuriously rejected.
  //   dst_checked = 0 : source is the range-checked endpoint (OT -> SoC)
  //   dst_checked = 1 : destination is the range-checked endpoint (SoC -> OT)
  // `chunk` is intentionally > `total`, so the transfer is a single chunk whose full-chunk-rounded
  // end exceeds the tight limit.
  task run_boundary(bit dst_checked, int total, int chunk);
    asid_encoding_e src_asid = dst_checked ? SocControlAddr : OtInternalAddr;
    asid_encoding_e dst_asid = dst_checked ? OtInternalAddr  : SocControlAddr;
    bit [63:0]      src_addr = dst_checked ? SocAddr : OtAddr;
    bit [63:0]      dst_addr = dst_checked ? OtAddr  : SocAddr;
    bit [63:0]      ot_addr  = dst_checked ? dst_addr : src_addr; // the range-checked buffer
    bit [31:0]      range_base = ot_addr[31:0];
    bit [31:0]      range_lim  = ot_addr[31:0] + total - 1;       // inclusive: last byte == limit
    dma_seq_item    c = dma_seq_item::type_id::create("c");
    status_t        status = '0;
    bit [31:0]      ec;
    bit [7:0]       src_bytes[], dst_bytes[];
    string          ctx = $sformatf("range-partial %s total=%0d chunk=%0d",
                                     dst_checked ? "dst-checked" : "src-checked", total, chunk);

    // Source data, poisoned destination. Pad to word-align so the DUT's final full-word read
    // doesn't hit uninitialized memory model addresses. cfg.src_data is left empty: this test
    // self-checks via memory readback (lines below); the scoreboard skips its copy-data checks
    // when cfg.src_data is empty.
    src_bytes = new[total];
    foreach (src_bytes[b]) src_bytes[b] = $urandom;
    for (int i = 0; i < ((total + 3) & ~3); i++) begin
      bit [7:0] d = (i < total) ? src_bytes[i] : 8'h00;
      cfg.mems[src_asid].write_byte(src_addr + i, d);
    end
    for (int i = 0; i < total; i++) cfg.mems[dst_asid].write_byte(dst_addr + i, 8'hA5);

    c.src_asid = src_asid; c.dst_asid = dst_asid;
    c.src_addr = src_addr; c.dst_addr = dst_addr;
    c.src_addr_inc = 1'b1; c.dst_addr_inc = 1'b1;
    c.src_chunk_wrap = 1'b0; c.dst_chunk_wrap = 1'b0;
    c.handshake = 1'b0;
    c.total_data_size = total; c.chunk_data_size = chunk;
    c.per_transfer_width = DmaXfer4BperTxn;

    csr_wr(ral.status, 32'h0000_002E);
    set_src_addr(src_addr); set_dst_addr(dst_addr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(src_asid, dst_asid);
    set_total_size(total); set_chunk_data_size(chunk);
    set_transfer_width(DmaXfer4BperTxn);
    set_dma_enabled_memory_range(range_base, range_lim, 1'b1, MuBi4True);
    start_device(c);
    set_control(OpcCopy, .initial_transfer(1'b1), .handshake(1'b0), .go(1'b1));

    poll_status(.intr_driven(1'b0), .status(status));
    stop_device();

    // A legal final partial chunk must complete cleanly, with no address-range error.
    `DV_CHECK_EQ(status[StatusError], 1'b0, {ctx, ": transfer errored (spurious range error?)"})
    `DV_CHECK_EQ(status[StatusDone],  1'b1, {ctx, ": transfer did not complete"})
    csr_rd(ral.error_code, ec);
    `DV_CHECK_EQ(ec[0], 1'b0, {ctx, ": unexpected src_addr_error on legal final partial chunk"})
    `DV_CHECK_EQ(ec[1], 1'b0, {ctx, ": unexpected dst_addr_error on legal final partial chunk"})

    // Destination must hold the source data.
    dst_bytes = new[total];
    for (int i = 0; i < total; i++) dst_bytes[i] = cfg.mems[dst_asid].read_byte(dst_addr + i);
    foreach (dst_bytes[i]) begin
      `DV_CHECK_EQ(dst_bytes[i], src_bytes[i], $sformatf("%s: data mismatch at byte %0d", ctx, i))
    end

    csr_wr(ral.status, 32'h0000_002E);
    csr_wr(ral.intr_state, '1);
  endtask

  // Run one fixed-address (no-increment) boundary copy; it must not be spuriously rejected. A
  // fixed address is a FIFO endpoint in DV, so this uses the standard flow (`run_common_config` ->
  // `configure_mem_model`): a FIFO for the fixed endpoint, memory for the incrementing one. The
  // scoreboard checks the streamed data.
  //   dst_fixed = 0 : fixed source       (OT FIFO -> SoC memory)
  //   dst_fixed = 1 : fixed destination  (SoC memory -> OT FIFO)
  // The OT range is tightened to one transfer word; `chunk` > `total` keeps it a single chunk (the
  // FIFO model's expected address stays pinned at the base, matching the no-increment endpoint).
  task run_fixed_boundary(bit dst_fixed, int total, int chunk);
    asid_encoding_e src_asid   = dst_fixed ? SocControlAddr : OtInternalAddr;
    asid_encoding_e dst_asid   = dst_fixed ? OtInternalAddr  : SocControlAddr;
    bit [63:0]      src_addr   = dst_fixed ? SocAddr : OtAddr;
    bit [63:0]      dst_addr   = dst_fixed ? OtAddr  : SocAddr;
    bit [63:0]      ot_addr    = dst_fixed ? dst_addr : src_addr; // range-checked, fixed endpoint
    int unsigned    word_bytes = 4;                               // one DmaXfer4BperTxn word
    dma_seq_item    c = dma_seq_item::type_id::create("c");
    status_t        status = '0;
    bit [31:0]      ec;
    string          ctx = $sformatf("range-fixed %s total=%0d",
                                     dst_fixed ? "dst-fixed" : "src-fixed", total);

    c.src_asid = src_asid; c.dst_asid = dst_asid;
    c.src_addr = src_addr; c.dst_addr = dst_addr;
    c.src_addr_inc = dst_fixed ? 1'b1 : 1'b0; // the fixed endpoint does not increment its address
    c.dst_addr_inc = dst_fixed ? 1'b0 : 1'b1;
    c.src_chunk_wrap = 1'b0; c.dst_chunk_wrap = 1'b0;
    c.handshake = 1'b0;
    c.total_data_size = total; c.chunk_data_size = chunk; // chunk > total => single chunk
    c.per_transfer_width = DmaXfer4BperTxn;
    c.mem_range_valid = 1'b1;
    c.mem_range_base  = ot_addr[31:0];
    c.mem_range_limit = ot_addr[31:0] + word_bytes - 1; // tight: exactly one transfer word
    c.range_regwen    = MuBi4True;

    csr_wr(ral.status, 32'h0000_002E);
    // Programs all CSRs from `c`, randomizes cfg.src_data, and sets up the FIFO/memory models.
    run_common_config(c);
    start_device(c);
    start_chunk(c, .initial_transfer(1'b1));

    poll_status(.intr_driven(1'b0), .status(status));
    stop_device();

    // The fixed-address access fits the one-word range; it must complete with no range error.
    `DV_CHECK_EQ(status[StatusError], 1'b0, {ctx, ": transfer errored (spurious range error?)"})
    `DV_CHECK_EQ(status[StatusDone],  1'b1, {ctx, ": transfer did not complete"})
    csr_rd(ral.error_code, ec);
    `DV_CHECK_EQ(ec[0], 1'b0, {ctx, ": unexpected src_addr_error on fixed-address access"})
    `DV_CHECK_EQ(ec[1], 1'b0, {ctx, ": unexpected dst_addr_error on fixed-address access"})

    // Data: fixed-source streams into incrementing memory, so dst_mem[i] == src_data[i] (checked
    // here). Fixed-destination is a FIFO checked by the scoreboard; STATUS.done covers it.
    if (!dst_fixed) begin
      for (int i = 0; i < total; i++) begin
        bit [7:0] got = cfg.mems[dst_asid].read_byte(dst_addr + i);
        `DV_CHECK_EQ(got, cfg.src_data[i], $sformatf("%s: data mismatch at byte %0d", ctx, i))
      end
    end

    csr_wr(ral.status, 32'h0000_002E);
    csr_wr(ral.intr_state, '1);
  endtask

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting range-boundary partial-chunk sequence", UVM_LOW)
    init_model();
    // For each range-checked side, run single-chunk transfers whose chunk_data_size exceeds the
    // total (full-chunk-rounded end overshoots the tight limit). Totals are non-width-multiples
    // so the final beat is partial too. The transfer still ends exactly on the inclusive limit.
    for (int d = 0; d < 2; d++) begin
      run_boundary(.dst_checked(d[0]), .total(98), .chunk(128));
      run_boundary(.dst_checked(d[0]), .total(34), .chunk(64));
      run_boundary(.dst_checked(d[0]), .total(4),  .chunk(64));
    end
    // Fixed-address (no-increment) path: the range is tightened to a single transfer word while the
    // fixed endpoint reuses that word for the whole transfer. Run for both the fixed-source
    // (OT -> SoC) and fixed-destination (SoC -> OT) directions.
    for (int f = 0; f < 2; f++) begin
      run_fixed_boundary(.dst_fixed(f[0]), .total(16), .chunk(64));
      run_fixed_boundary(.dst_fixed(f[0]), .total(8),  .chunk(64));
    end
    `uvm_info(`gfn, "DMA: Completed range-boundary partial-chunk sequence", UVM_LOW)
  endtask : body
endclass
