// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base class providing common methods required for DMA testing
class dma_base_vseq extends cip_base_vseq #(
  .RAL_T              (dma_reg_block),
  .CFG_T              (dma_env_cfg),
  .COV_T              (dma_env_cov),
  .VIRTUAL_SEQUENCER_T(dma_virtual_sequencer)
);

  `uvm_object_utils(dma_base_vseq)

  // Device responder sequences keyed by GLOBAL port index `p`, one per present host port: 32-bit
  // ports use `dma_pull_seq` on a `tl_sequencer`, 64-bit ports use `dma_tl_device_seq` on a
  // `dma_tl_sequencer`. A uniform 64-bit address width lets both share handle types. Keyed by `p`
  // (not ASID) so two ports may share an ASID without overwriting each other's responder handle.
  localparam int unsigned DevAddrWidth = dma_pkg::DMA_ADDR_WIDTH;

  dma_pull_seq #(.AddrWidth(DevAddrWidth)) seq32[int];
  dma_tl_device_seq                        seq64[int];

  // DMA configuration item
  dma_seq_item dma_config;

  // Access to CONTROL register
  semaphore sem_control;

  // Remember whether we have a pending Abort request?
  // (we cannot rely upon the RAL layer to retain this information because the CONTROL.abort field
  //  is Write Only to software)
  bit abort_pending;

  function new (string name = "");
    super.new(name);
    dma_config = dma_seq_item::type_id::create("dma_config");

    // Build one responder sequence per present host port, with its own source/destination FIFO and
    // memory model, keyed by global port index `p` and derived from the descriptor.
    foreach (dma_pkg::DmaPortDesc[p]) begin
      string sfx = $sformatf("p%0d", p);
      if (dma_pkg::DmaPortDesc[p].cls == dma_pkg::PortTlul32) begin
        dma_pull_seq #(.AddrWidth(DevAddrWidth)) s;
        s = dma_pull_seq #(.AddrWidth(DevAddrWidth))::type_id::create({"seq_", sfx});
        s.dst_fifo = dma_handshake_mode_fifo#(
                       .AddrWidth(DevAddrWidth))::type_id::create({"fifo_dst_", sfx});
        s.src_fifo = dma_handshake_mode_fifo#(
                       .AddrWidth(DevAddrWidth))::type_id::create({"fifo_src_", sfx});
        s.mem = mem_model#(.AddrWidth(DevAddrWidth),
                           .DataWidth(HOST_DATA_WIDTH))::type_id::create({"mem_", sfx});
        seq32[p] = s;
      end else begin
        dma_tl_device_seq s;
        s = dma_tl_device_seq::type_id::create({"seq_", sfx});
        s.dst_fifo = dma_handshake_mode_fifo#(
                       .AddrWidth(DevAddrWidth))::type_id::create({"fifo_dst_", sfx});
        s.src_fifo = dma_handshake_mode_fifo#(
                       .AddrWidth(DevAddrWidth))::type_id::create({"fifo_src_", sfx});
        s.mem = mem_model#(.AddrWidth(DevAddrWidth),
                           .DataWidth(HOST_DATA_WIDTH))::type_id::create({"mem_", sfx});
        seq64[p] = s;
      end
    end

    // Mutual exclusion of CONTROL register accesses.
    sem_control = new(1);
  endfunction : new

  // The responder maps are keyed by global port index `p`, but the public test-facing API selects
  // a responder by logical ASID (the DMA's src/dst address space). These helpers translate an ASID
  // to the present port index of the matching class. They return the FIRST matching port; with the
  // default descriptor (unique ASIDs) this is exact. -1 means "no such port".
  function int port32_for_asid(asid_encoding_e asid);
    foreach (seq32[p]) if (dma_pkg::DmaPortDesc[p].asid == asid) return p;
    return -1;
  endfunction
  function int port64_for_asid(asid_encoding_e asid);
    foreach (seq64[p]) if (dma_pkg::DmaPortDesc[p].asid == asid) return p;
    return -1;
  endfunction

  // Convenience: does the given ASID have a present 32-bit / 64-bit port?
  function bit has_seq32(asid_encoding_e asid); return port32_for_asid(asid) >= 0; endfunction
  function bit has_seq64(asid_encoding_e asid); return port64_for_asid(asid) >= 0; endfunction

  function void init_model();
    // Publish each present port's memory/FIFO models into the cfg (keyed by ASID for scoreboard
    // routing) and initialize them. The responder maps are keyed by port index `p`; derive the ASID
    // from the descriptor.
    foreach (seq32[p]) begin
      asid_encoding_e asid = dma_pkg::DmaPortDesc[p].asid;
      cfg.mems[asid]     = seq32[p].mem;
      cfg.fifo_dst[asid] = seq32[p].dst_fifo;
      cfg.fifo_src[asid] = seq32[p].src_fifo;
    end
    foreach (seq64[p]) begin
      asid_encoding_e asid = dma_pkg::DmaPortDesc[p].asid;
      cfg.mems[asid]     = seq64[p].mem;
      cfg.fifo_dst[asid] = seq64[p].dst_fifo;
      cfg.fifo_src[asid] = seq64[p].src_fifo;
    end
    // Initialize memory and FIFO models for every present port.
    foreach (cfg.mems[asid])     cfg.mems[asid].init();
    foreach (cfg.fifo_dst[asid]) cfg.fifo_dst[asid].init();
    foreach (cfg.fifo_src[asid]) cfg.fifo_src[asid].init();
  endfunction

  // The SoC System bus is modelled by `dma_tl_device_seq`, which gets the full 64-bit
  // address from the `dma_tl_agent` monitor: no base-address window programming needed.

  // Randomization of DMA configuration and transfer properties; to be overridden in those
  // derived classes where further constraints are required.
  virtual function void randomize_item(ref dma_seq_item dma_config);
    `DV_CHECK_RANDOMIZE_FATAL(dma_config)
    `uvm_info(`gfn, $sformatf("DMA: Randomized a new transaction:%s",
                              dma_config.convert2string()), UVM_HIGH)
  endfunction

  // Set up randomized source data for the transfer
  function void randomize_src_data(bit [31:0] total_data_size);
    bit [31:0] offset;
    cfg.src_data = new[total_data_size];
    for (offset = 32'b0; offset < total_data_size; offset++) begin
      cfg.src_data[offset] = $urandom_range(0, 255);
      `uvm_info(`gfn, $sformatf("%0x: %0x", offset, cfg.src_data[offset]), UVM_DEBUG)
    end
  endfunction

  // Function to populate source memory model with pre-randomized, known source data for the current
  // chunk of the transfer
  function void populate_src_mem(asid_encoding_e asid, bit [63:0] start_addr,
                                 ref bit [7:0] src_data[],
                                 input bit [31:0] offset, input bit [31:0] size);
    // TODO: we should perhaps not be assuming a 32-bit data bus here.
    bit [63:0] end_addr = (start_addr + size + 3) & ~64'd3;
    bit [63:0] addr = {start_addr[63:2], 2'd0};
    // Guard against 64-bit wrap-around: populate by byte count instead of address comparison.
    int unsigned num_bytes = ((size + 3) & ~32'd3) + (start_addr[1:0] != 0 ? 4 : 0);
    `uvm_info(`gfn, $sformatf("Populating ASID 0x%x address range [0x%0x,+0x%0x)",
                              asid, addr, num_bytes), UVM_MEDIUM)

    if (!cfg.mems.exists(asid)) begin
      `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
      return;
    end

    // Alas we must ensure that the first bus word is fully-defined because TL-UL host adapter
    // fetches only complete bus words and there are assertion checks on the TL-UL bus.
    // Use byte index `i` instead of address comparison to avoid 64-bit wrap-around issues.
    begin
      int unsigned start_off = start_addr[1:0]; // padding bytes before valid data
      for (int unsigned i = 0; i < num_bytes; i++) begin
        bit [7:0] data = 32'hBAAD_F00D >> {addr[1:0], 3'd0};
        if (i >= start_off && (i - start_off) < size) begin
          data = src_data[offset];
          offset++;
        end
        cfg.mems[asid].write_byte(addr, data);
        addr++;
      end
    end
  endfunction

  // Function to populate FIFO with pre-randomized, known source data
  function void populate_src_fifo(asid_encoding_e asid, ref bit [7:0] src_data[],
                                  input bit [31:0] offset, input bit [31:0] size);
    if (!cfg.fifo_src.exists(asid)) begin
      `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
      return;
    end
    cfg.fifo_src[asid].populate_fifo(src_data, offset, size);
  endfunction

  function void supply_data(ref dma_seq_item dma_config, bit [31:0] offset, bit [31:0] size);
    `uvm_info(`gfn, $sformatf("Supplying bytes [0x%0x,0x%0x) of 0x%0x-byte transfer",
                    offset, offset + size, dma_config.total_data_size), UVM_MEDIUM)

    // Configure Source model
    if (dma_config.get_read_fifo_en()) begin
      // Supply a block of data for this transfer
      populate_src_fifo(dma_config.src_asid, cfg.src_data, offset, size);
    end else begin
      // The source address depends upon the configuration; chunks may overlap each other.
      bit [63:0] src_addr = dma_config.src_addr;
      if (!dma_config.src_chunk_wrap) begin
        src_addr += offset;
      end else begin
        src_addr += offset % dma_config.chunk_data_size;
      end

      // Randomise mem_model data
      populate_src_mem(dma_config.src_asid, src_addr, cfg.src_data, offset, size);
    end
  endfunction

  // Function to set the transfer properties for a source FIFO.
  function void set_model_src_fifo_mode(asid_encoding_e asid, bit [63:0] start_addr,
                                        dma_transfer_width_e per_transfer_width,
                                        bit [31:0] chunk_size, bit wrap, bit [31:0] offset,
                                        bit [31:0] max_size);
    start_addr[1:0] = 2'd0; // Address generated by DMA is 4B aligned
    if (!cfg.fifo_src.exists(asid)) begin
      `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
      return;
    end
    cfg.fifo_src[asid].enable_fifo(.fifo_base(start_addr),
                                   .per_transfer_width(per_transfer_width),
                                   .chunk_size(chunk_size), .wrap(wrap), .offset(offset),
                                   .max_size(max_size));
  endfunction

  // Function to set the transfer properties for a destination FIFO.
  function void set_model_dst_fifo_mode(asid_encoding_e asid, bit [63:0] start_addr,
                                        dma_transfer_width_e per_transfer_width,
                                        bit [31:0] chunk_size, bit wrap, bit [31:0] offset,
                                        bit [31:0] max_size);
    start_addr[1:0] = 2'd0; // Address generated by DMA is 4B aligned
    if (!cfg.fifo_dst.exists(asid)) begin
      `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
      return;
    end
    cfg.fifo_dst[asid].enable_fifo(.fifo_base(start_addr),
                                   .per_transfer_width(per_transfer_width),
                                   .chunk_size(chunk_size), .wrap(wrap), .offset(offset),
                                   .max_size(max_size));
  endfunction

  // Configure the source and destination models (memory models or FIFOs) appropriately for the
  // current chunk of the DMA transfer, starting at the given byte offset.
  // Returns the byte offset of the next chunk to be transferred, if any.
  function bit [31:0] configure_mem_model(ref dma_seq_item dma_config, input bit [31:0] offset);
    // Decide how many bytes of data to supply in this chunk
    bit [31:0] chunk_size = dma_config.total_data_size - offset;
    if (chunk_size > dma_config.chunk_data_size) begin
      chunk_size = dma_config.chunk_data_size;
    end

    // Empty source and destination memories of data from any previous chunks transferred.
    clear_memory();
    clear_fifo();

    // Configure Source model
    if (dma_config.get_read_fifo_en()) begin
      // Enable read FIFO mode in models
      // When addr_inc=0 (fixed address), force wrap=1 so the FIFO model keeps exp_addr fixed.
      set_model_src_fifo_mode(dma_config.src_asid, dma_config.src_addr,
                              dma_config.per_transfer_width, dma_config.chunk_data_size,
                              dma_config.src_chunk_wrap | !dma_config.src_addr_inc,
                              offset, chunk_size);
    end else begin
      // The source address depends upon the configuration; chunks may overlap each other.
      bit [63:0] src_addr = dma_config.src_addr;
      if (!dma_config.src_chunk_wrap) begin
        src_addr += offset;
      end
    end

    // Supply the next chunk of data for this transfer
    supply_data(dma_config, offset, chunk_size);

    // Configure Destination model
    if (dma_config.get_write_fifo_en()) begin
      // TODO: Presently there is no way to intervene and check per-chunk data, so gather it all
      // into a single large FIFO and the scoreboard will check it all at the end of the transfer.
      bit [31:0] max_size = chunk_size;
      if (dma_config.handshake) begin
        max_size = dma_config.total_data_size;
      end

      // Enable write FIFO mode in models
      // When addr_inc=0 (fixed address), force wrap=1 so the FIFO model keeps exp_addr fixed
      // rather than advancing it by chunk_size each chunk.
      set_model_dst_fifo_mode(dma_config.dst_asid, dma_config.dst_addr,
                              dma_config.per_transfer_width, dma_config.chunk_data_size,
                              dma_config.dst_chunk_wrap | !dma_config.dst_addr_inc,
                              offset, max_size);
    end

    // Return the updated byte offset within the transfer
    return offset + chunk_size;
  endfunction

  // Set hardware handshake interrupt bits based on randomized class item
  function void set_hardware_handshake_intr(
    bit [dma_reg_pkg::NumIntClearSources-1:0] handshake_value);
    cfg.dma_vif.handshake_i = handshake_value;
  endfunction

  function void release_hardware_handshake_intr();
    cfg.dma_vif.handshake_i = '0;
  endfunction

  // Task: Write to Source Address CSR
  task set_src_addr(bit [63:0] src_addr);
    `uvm_info(`gfn, $sformatf("DMA: Source Address = 0x%016h", src_addr), UVM_HIGH)
    csr_wr(ral.src_addr_lo, src_addr[31:0]);
    csr_wr(ral.src_addr_hi, src_addr[63:32]);
  endtask : set_src_addr

  // Task: Write to Destination Address CSR
  task set_dst_addr(bit [63:0] dst_addr);
    csr_wr(ral.dst_addr_lo, dst_addr[31:0]);
    csr_wr(ral.dst_addr_hi, dst_addr[63:32]);
    `uvm_info(`gfn, $sformatf("DMA: Destination Address = 0x%016h", dst_addr), UVM_HIGH)
  endtask : set_dst_addr

  // Task: Write to Source Configuration
  task set_src_config(bit chunk_wrap, bit addr_inc);
    ral.src_config.wrap.set(chunk_wrap);
    ral.src_config.increment.set(addr_inc);
    csr_update(ral.src_config);
  endtask : set_src_config

  // Task: Write to Destination Configuration
  task set_dst_config(bit chunk_wrap, bit addr_inc);
    ral.dst_config.wrap.set(chunk_wrap);
    ral.dst_config.increment.set(addr_inc);
    csr_update(ral.dst_config);
  endtask : set_dst_config

  // Task: Set DMA Enabled Memory base and limit
  task set_dma_enabled_memory_range(bit [32:0] base, bit [31:0] limit, bit valid, mubi4_t lock);
    csr_wr(ral.enabled_memory_range_base, base);
    `uvm_info(`gfn, $sformatf("DMA: DMA Enabled Memory base = %0x08h", base), UVM_HIGH)
    csr_wr(ral.enabled_memory_range_limit, limit);
    `uvm_info(`gfn, $sformatf("DMA: DMA Enabled Memory limit = %0x08h", limit), UVM_HIGH)
    csr_wr(ral.range_valid, valid);
    `uvm_info(`gfn, $sformatf("DMA: DMA Enabled Memory Range valid = %0d", valid), UVM_HIGH)
    if (lock != MuBi4True) begin
      csr_wr(ral.range_regwen, int'(lock));
      `uvm_info(`gfn, $sformatf("DMA: DMA Enabled Memory lock = %s", lock.name()), UVM_HIGH)
    end
  endtask : set_dma_enabled_memory_range

  // Task: Write to Source and Destination Address Space ID (ASID)
  task set_addr_space_id(asid_encoding_e src_asid, asid_encoding_e dst_asid);
    ral.addr_space_id.src_asid.set(int'(src_asid));
    ral.addr_space_id.dst_asid.set(int'(dst_asid));
    csr_update(.csr(ral.addr_space_id));
    `uvm_info(`gfn, $sformatf("DMA: Source ASID = %d", src_asid), UVM_HIGH)
    `uvm_info(`gfn, $sformatf("DMA: Destination ASID = %d", dst_asid), UVM_HIGH)
  endtask : set_addr_space_id

  // Task: Set number of bytes to transfer
  task set_total_size(bit [31:0] total_data_size);
    csr_wr(ral.total_data_size, total_data_size);
    `uvm_info(`gfn, $sformatf("DMA: Total Data Size = %d", total_data_size), UVM_HIGH)
  endtask : set_total_size

  // Task: Set number of bytes per chunk to transfer
  task set_chunk_data_size(bit [31:0] chunk_data_size);
    csr_wr(ral.chunk_data_size, chunk_data_size);
    `uvm_info(`gfn, $sformatf("DMA: Chunk Data Size = %d", chunk_data_size), UVM_HIGH)
  endtask : set_chunk_data_size

  // Task: Set Byte size of each transfer (0:1B, 1:2B, 2:3B, 3:4B)
  task set_transfer_width(dma_transfer_width_e transfer_width);
    csr_wr(ral.transfer_width, transfer_width);
    `uvm_info(`gfn, $sformatf("DMA: Transfer Byte Size = %s",
                              transfer_width.name()), UVM_HIGH)
  endtask : set_transfer_width

  // Program the inline-AES key/IV/AAD CSRs and AES_CTRL. key_len is the one-hot aes_pkg::key_len_e
  // value (4 = AES-256, 1 = AES-128); sideload selects the keymgr key (0 = CSR key shares).
  task program_aes_config(bit [31:0] key0[8], bit [31:0] key1[8], bit [31:0] iv[4],
                          bit [31:0] aad[8], int aad_blocks, bit [2:0] key_len, bit sideload,
                          bit [2:0] reseed_rate = 3'b001 /* PER_1 */);
    foreach (key0[i]) csr_wr(ral.key_share0[i], key0[i]);
    foreach (key1[i]) csr_wr(ral.key_share1[i], key1[i]);
    foreach (iv[i])   csr_wr(ral.iv[i], iv[i]);
    for (int i = 0; i < aad_blocks * 4; i++) begin
      csr_wr(ral.aad[i], aad[i]);
    end
    ral.aes_ctrl.key_len.set(key_len);
    ral.aes_ctrl.sideload.set(sideload);
    ral.aes_ctrl.prng_reseed_rate.set(reseed_rate);
    ral.aes_ctrl.aad_blocks.set(aad_blocks[3:0]);
    csr_update(ral.aes_ctrl);
  endtask : program_aes_config

  // Program the expected GCM tag for a decrypt (TAG_IN, write-only).
  task program_aes_tag_in(bit [31:0] tag[4]);
    foreach (tag[i]) csr_wr(ral.tag_in[i], tag[i]);
  endtask : program_aes_tag_in

  // Task: Set handshake interrupt register
  task set_handshake_intr_regs(ref dma_seq_item dma_config);
    `uvm_info(`gfn, "Set DMA Handshake mode interrupt registers", UVM_HIGH)
    csr_wr(ral.clear_intr_src, dma_config.clear_intr_src);
    foreach (dma_config.clear_intr_asid[i])
      csr_wr(ral.clear_intr_asid[i], dma_config.clear_intr_asid[i]);
    foreach (dma_config.intr_src_addr[i]) begin
      csr_wr(ral.intr_src_addr[i], dma_config.intr_src_addr[i]);
      csr_wr(ral.intr_src_wr_val[i], dma_config.intr_src_wr_val[i]);
    end
    ral.handshake_intr_enable.set(dma_config.handshake_intr_en);
    csr_update(ral.handshake_intr_enable);
  endtask : set_handshake_intr_regs

  // Task: Configure DMA controller to perform a transfer
  // (common to both 'memory-to-memory' and 'hardware handshaking' modes of operation)
  task run_common_config(ref dma_seq_item dma_config);
    `uvm_info(`gfn, "DMA: Start Common Configuration", UVM_HIGH)
    // Not yet requested an Abort during this transaction.
    abort_pending = 1'b0;
    set_src_addr(dma_config.src_addr);
    set_dst_addr(dma_config.dst_addr);
    set_src_config(dma_config.src_chunk_wrap, dma_config.src_addr_inc);
    set_dst_config(dma_config.dst_chunk_wrap, dma_config.dst_addr_inc);
    set_addr_space_id(dma_config.src_asid, dma_config.dst_asid);
    set_total_size(dma_config.total_data_size);
    set_chunk_data_size(dma_config.chunk_data_size);
    set_transfer_width(dma_config.per_transfer_width);
    randomize_src_data(dma_config.total_data_size);
    void'(configure_mem_model(dma_config, 32'd0));
    set_handshake_intr_regs(dma_config);
    set_dma_enabled_memory_range(dma_config.mem_range_base,
                                 dma_config.mem_range_limit,
                                 dma_config.mem_range_valid,
                                 dma_config.range_regwen);
    // SoC System bus is full 64-bit (`dma_tl_device_seq`): no base-address window setup needed.
  endtask : run_common_config

  // Task: Enable/Disable Interrupt(s)
  task enable_interrupts(bit [31:0] interrupts = 32'hFFFF_FFFF, bit enable = 1'b1);
    string action;
    action = enable ? "Enable" : "Disable";
    `uvm_info(`gfn, $sformatf("DMA: %s interrupt(s) 0x%0x", action, interrupts), UVM_HIGH)
    cfg_interrupts(interrupts, enable);
  endtask : enable_interrupts

  // Task: Enable Handshake Interrupt Enable
  task enable_handshake_interrupt();
    `uvm_info(`gfn, "DMA: Assert Interrupt Enable", UVM_HIGH)
    csr_wr(ral.handshake_intr_enable, 32'd1);
  endtask : enable_handshake_interrupt

  // Enable/disable errors on TL-UL buses with the given percentage probability/word, on every
  // present port.
  function void enable_bus_errors(int pct);
    foreach (seq32[p]) seq32[p].enable_bus_errors(pct);
    foreach (seq64[p]) seq64[p].enable_bus_errors(pct);
  endfunction

  // Set the minimum and maximum grant delays on the TL-UL buses (every present port).
  // Note: the TL-UL agent shall normally produce randomized grant delays; this function is to be
  //       used only in those sequences where there is a specific reason to control them tightly.
  function void set_access_delays(int min, int max);
    foreach (cfg.m_tl32_cfg[p]) begin
      cfg.m_tl32_cfg[p].a_ready_delay_min = min;
      cfg.m_tl32_cfg[p].a_ready_delay_max = max;
    end
    foreach (cfg.m_tl64_cfg[p]) begin
      cfg.m_tl64_cfg[p].a_ready_delay_min = min;
      cfg.m_tl64_cfg[p].a_ready_delay_max = max;
    end
  endfunction

  // Set the minimum and maximum response delays of the TL-UL devices (every present port).
  // Note: the TL-UL agent shall normally produce randomized responses delays; this function is to
  //       be used only in those sequences where there is a specific reason to control them tightly.
  function void set_response_delays(int min, int max);
    foreach (cfg.m_tl32_cfg[p]) begin
      cfg.m_tl32_cfg[p].use_seq_item_d_valid_delay = 1'b0;
      cfg.m_tl32_cfg[p].d_valid_delay_min = min;
      cfg.m_tl32_cfg[p].d_valid_delay_max = max;
    end
    foreach (cfg.m_tl64_cfg[p]) begin
      cfg.m_tl64_cfg[p].use_seq_item_d_valid_delay = 1'b0;
      cfg.m_tl64_cfg[p].d_valid_delay_min = min;
      cfg.m_tl64_cfg[p].d_valid_delay_max = max;
    end
  endfunction

  // Enable/disable the wide (host64) monitor's command-integrity check on every present 64-bit
  // port. Command-integrity fault-injection (negative) tests must clear this so the monitor does
  // not `uvm_error` on the intentionally-corrupted `a_user.cmd_intg`.
  function void set_check_cmd_intg(bit en);
    foreach (cfg.m_tl64_cfg[p]) cfg.m_tl64_cfg[p].check_cmd_intg = en;
  endfunction

  // Enable/disable read-FIFO mode on the responder for the given ASID.
  function void set_seq_fifo_read_mode(asid_encoding_e asid, bit read_fifo_en);
    int p32 = port32_for_asid(asid);
    int p64 = port64_for_asid(asid);
    if (p32 >= 0) begin
      seq32[p32].read_fifo_en = read_fifo_en;
      `uvm_info(`gfn, $sformatf("set %s read_fifo_en = %0b", asid.name(), read_fifo_en), UVM_HIGH)
    end else if (p64 >= 0) begin
      seq64[p64].read_fifo_en = read_fifo_en;
      `uvm_info(`gfn, $sformatf("set %s read_fifo_en = %0b", asid.name(), read_fifo_en), UVM_HIGH)
    end else begin
      `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
    end
  endfunction

  // Enable/disable write-FIFO mode on the responder for the given ASID.
  function void set_seq_fifo_write_mode(asid_encoding_e asid, bit write_fifo_en);
    int p32 = port32_for_asid(asid);
    int p64 = port64_for_asid(asid);
    if (p32 >= 0) begin
      seq32[p32].write_fifo_en = write_fifo_en;
      `uvm_info(`gfn, $sformatf("set %s write_fifo_en = %0b", asid.name(), write_fifo_en), UVM_HIGH)
    end else if (p64 >= 0) begin
      seq64[p64].write_fifo_en = write_fifo_en;
      `uvm_info(`gfn, $sformatf("set %s write_fifo_en = %0b", asid.name(), write_fifo_en), UVM_HIGH)
    end else begin
      `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
    end
  endfunction

  // Set the bytes/transaction on every present responder.
  function void set_all_txn_bytes(uint bytes);
    foreach (seq32[p]) seq32[p].set_txn_bytes(bytes);
    foreach (seq64[p]) seq64[p].set_txn_bytes(bytes);
  endfunction

  // Register a 'Clear Interrupt' FIFO write on the responder for the given ASID.
  function void add_fifo_reg_for_asid(asid_encoding_e asid, bit [31:0] addr, bit [31:0] data);
    int p32 = port32_for_asid(asid);
    int p64 = port64_for_asid(asid);
    if (p32 >= 0)      seq32[p32].add_fifo_reg(addr, data);
    else if (p64 >= 0) seq64[p64].add_fifo_reg(addr, data);
    else `uvm_error(`gfn, $sformatf("Clear-interrupt bus ASID %s not present", asid.name()))
  endfunction

  // Enable 'Clear Interrupt' FIFO write handling on the responder for the given ASID.
  function void set_fifo_clear_for_asid(asid_encoding_e asid, bit en);
    int p32 = port32_for_asid(asid);
    int p64 = port64_for_asid(asid);
    if (p32 >= 0)      seq32[p32].set_fifo_clear(en);
    else if (p64 >= 0) seq64[p64].set_fifo_clear(en);
    // Silently ignore if the ASID is not present; nothing to clear.
  endfunction

  // Task: Start TLUL Sequences
  virtual task start_device(ref dma_seq_item dma_config);
    // Set fifo enable bit; the FIFO is used whenever address incrementing does not occur
    // after each (partial-)word transfer; the normal memory model would not cope with that
    // and would be continually losing data.
    set_seq_fifo_read_mode(dma_config.src_asid, dma_config.get_read_fifo_en());
    set_seq_fifo_write_mode(dma_config.dst_asid, dma_config.get_write_fifo_en());

    if (dma_config.handshake) begin
      // Will the test sequence generate any interrupts?
      bit [31:0] fifo_interrupt_mask;
      fifo_interrupt_mask = dma_config.handshake_intr_en &  // Any handshaking interrupts enabled
                            dma_config.lsio_trigger_i;      // .. and being driven by test seq?
      `DV_CHECK_EQ(|fifo_interrupt_mask, 1'b1, "Handshake test has no enabled interrupt sources")

      `uvm_info(`gfn, $sformatf("FIFO interrupt enable mask = %0x ", fifo_interrupt_mask),
                UVM_HIGH)

      // TODO: there may be some merit at some point to starting handshaking transfers when
      // interrupts cannot occur, but only if we're expecting to abort transfers, for example.
      if (|fifo_interrupt_mask) begin
        for (int i = 0; i < dma_reg_pkg::NumIntClearSources; i++) begin
          // Instruct memory/FIFO models on the appropriate bus(es) to expect 'Clear Interrupt'
          // writes, so that they may be excluded from normal traffic.
          if (dma_config.clear_intr_src[i]) begin
            asid_encoding_e bus_asid =
                dma_config.clear_intr_asid[i];
            `uvm_info(`gfn, $sformatf("Clear Interrupt writes expected for source %d on bus %d", i,
                                      dma_config.clear_intr_asid[i]), UVM_HIGH)
            add_fifo_reg_for_asid(bus_asid, dma_config.intr_src_addr[i],
                                  dma_config.intr_src_wr_val[i]);
            set_fifo_clear_for_asid(bus_asid, 1'b1);
          end
        end
      end
    end

    // Each of the sequences must be told the bytes/transaction in order to count the bytes read
    set_all_txn_bytes(dma_config.txn_bytes());

    `uvm_info(`gfn, "DMA: Starting Devices", UVM_HIGH)
    // Start a responder per present port on its per-port (port-index-keyed) sequencer.
    fork
      begin
        foreach (seq32[p]) begin
          automatic int pp = p;
          fork
            seq32[pp].start(p_sequencer.tl32_sequencer_h[pp]);
          join_none
        end
        foreach (seq64[p]) begin
          automatic int pp = p;
          fork
            seq64[pp].start(p_sequencer.tl64_sequencer_h[pp]);
          join_none
        end
      end
    join_none
  endtask : start_device

  // Method to terminate sequences gracefully
  virtual task stop_device();
    `uvm_info(`gfn, "DMA: Stopping Devices", UVM_HIGH)
    fork
      begin
        foreach (seq32[p]) begin
          automatic int pp = p;
          fork seq32[pp].seq_stop(); join_none
        end
        foreach (seq64[p]) begin
          automatic int pp = p;
          fork seq64[pp].seq_stop(); join_none
        end
        wait fork;
      end
    join
    // Clear FIFO mode enable bits on every present port.
    foreach (seq32[p]) begin
      seq32[p].read_fifo_en  = 0;
      seq32[p].write_fifo_en = 0;
      seq32[p].set_fifo_clear(0);
    end
    foreach (seq64[p]) begin
      seq64[p].read_fifo_en  = 0;
      seq64[p].write_fifo_en = 0;
      seq64[p].set_fifo_clear(0);
    end
    // Disable destination FIFOs.
    foreach (cfg.fifo_dst[asid]) cfg.fifo_dst[asid].disable_fifo();
  endtask

  // Method to clear memory models of any content
  function void clear_memory();
    `uvm_info(`gfn, $sformatf("Clearing memory contents"), UVM_MEDIUM)
    foreach (cfg.mems[asid]) cfg.mems[asid].init();
  endfunction

  // Method to clear FIFO models of any content
  function void clear_fifo();
    `uvm_info(`gfn, $sformatf("Clearing FIFO contents"), UVM_MEDIUM)
    foreach (cfg.fifo_dst[asid]) cfg.fifo_dst[asid].init();
    foreach (cfg.fifo_src[asid]) cfg.fifo_src[asid].init();
  endfunction

  // Task: Set the CONTROL register, optionally commencing a transfer.
  task set_control(opcode_e opcode,
                   bit initial_transfer,
                   bit handshake,
                   bit go);   // Commence transfer?
    uvm_reg_data_t data = 0;
    string action;

    action = go ? "Executing" : "Setting";
    `uvm_info(`gfn, $sformatf("DMA: %s CONTROL OpC=%d Initial=%d Handshake=%d",
                              action, opcode, initial_transfer, handshake), UVM_HIGH)

    // Exclusive access to CONTROL register
    // Note: a parallel thread may be attempting to Abort transfers using the CONTROL register.
    sem_control.get(1);

    // Configure all fields except GO bit which shall initially be clear
    // Note: Importantly we must perform this whilst we have exclusive access and we must preserve
    // the state of the 'abort' bit, so that we do not remove a requested Abort.

    // The CONTROL register now carries orthogonal read_en/write_en/digest fields; decode the
    // DV-side operation selector into them.
    data = get_csr_val_with_updated_field(ral.control.read_en, data, opcode_read_en(opcode));
    data = get_csr_val_with_updated_field(ral.control.write_en, data, opcode_write_en(opcode));
    data = get_csr_val_with_updated_field(ral.control.digest, data, opcode_digest(opcode));
    data = get_csr_val_with_updated_field(ral.control.aes_op, data, opcode_aes_op(opcode));
    data = get_csr_val_with_updated_field(ral.control.aes_mode, data, opcode_aes_mode(opcode));
    data = get_csr_val_with_updated_field(ral.control.initial_transfer, data, initial_transfer);
    data = get_csr_val_with_updated_field(ral.control.hardware_handshake_enable, data, handshake);
    data = get_csr_val_with_updated_field(ral.control.abort, data, abort_pending);
    data = get_csr_val_with_updated_field(ral.control.go, data, 1'b0);

    csr_wr(ral.control, data);
    // Set GO bit to start operation (chunk/transfer)?
    if (go) begin
      data = get_csr_val_with_updated_field(ral.control.go, data, 1'b1);
      csr_wr(ral.control, data);
    end

    sem_control.put(1);
  endtask : set_control

  // Start the transfer of a chunk of data.
  task start_chunk(ref dma_seq_item dma_config,
                   input bit initial_transfer);  // Is this the first chunk of the transfer?
    set_control(dma_config.opcode,
                initial_transfer,
                dma_config.handshake,
                1'b1); // Go
  endtask

  // Clear 'STATUS.abort' field after an Abort request has been actioned.
  task clear_aborted();
    `uvm_info(`gfn, "DMA: Clear STATUS.abort", UVM_HIGH)
    ral.status.aborted.set(1'b1);
    csr_update(.csr(ral.status));
  endtask : clear_aborted

  // Clear 'STATUS.done' field after a transfer has completed.
  task clear_done();
    `uvm_info(`gfn, "DMA: Clear STATUS.done", UVM_HIGH)
    ral.status.done.set(1'b1);
    csr_update(.csr(ral.status));
  endtask : clear_done

  // Clear 'STATUS.chunk_done' field after a chunk transfer has completed.
  task clear_chunk_done();
    `uvm_info(`gfn, "DMA: Clear STATUS.chunk_done", UVM_HIGH)
    ral.status.chunk_done.set(1'b1);
    csr_update(.csr(ral.status));
  endtask : clear_chunk_done

  // Task: Abort the current transaction
  task abort();
    uvm_reg_data_t data = 0;

    `uvm_info(`gfn, "Aborting transfer", UVM_MEDIUM)

    // Exclusive access to CONTROL register
    // Note: may be called by a thread that is parallel to the main vseq.
    sem_control.get(1);
    // Remember that we have requested an abort, so that we do not clear it in `set_control.`
    abort_pending = 1'b1;

    data = get_csr_val_with_updated_field(ral.control.abort, data, 1'b1);
    csr_wr(ral.control, data);

    sem_control.put(1);
  endtask : abort

  // Task: Wait for Completion
  task wait_for_completion(bit intr_driven, output status_t status);
    int timeout = 10000;
    status = 0;
    fork
      // Timeout condition due to inactivity.
      // Note: we rely upon the build/simulation to time out in the event that the controller
      //       somehow enters an interminable loop transferring repeatedly, rather than trying to
      //       detect unproductive activity.
      begin
        uint prev_written = 0;
        uint prev_read = 0;
        int elapsed = 0;
        do begin
          uint now_written;
          uint now_read;
          // Delay for a while; this process will be terminated if a parallel process detects a
          // significant event.
          delay(1000);
          elapsed += 1000;
          // There is no progress/activity indicator in the FW/DV-visible CSRs, so we rely
          // upon monitoring the source/destination for recent activity.
          now_written = get_bytes_written(dma_config);
          now_read    = get_bytes_read(dma_config);
          if (now_written != prev_written || now_read != prev_read) begin
            prev_written = now_written;
            prev_read = now_read;
            elapsed = 0;
          end
        end while (elapsed < timeout);
        `uvm_fatal(`gfn, $sformatf("ERROR: Timeout Condition Reached at %d cycles", timeout))
      end
      // Completion detection when interrupt driven
      await_interrupt(intr_driven, status);
      // Completion signaling when we're just polling CSRs
      // Note: this thread is the only one that completes, which is important because terminating
      // the CSR polling may leave the RAL locked.
      poll_status(intr_driven, status);
    join_any
    disable fork;

    // Presently, since the scoreboard is substantially updated by reads of the STATUS register,
    // we need to ensure that at least one such read occurs.
    if (intr_driven) begin
      poll_status(1'b0, status, 0);
    end
  endtask : wait_for_completion

  // Await the receipt of an interrupt from the DMA controller.
  task await_interrupt(bit intr_driven, ref status_t status);
    if (intr_driven) begin
      forever begin
        delay(1);
        if (cfg.intr_vif.pins[IntrDmaDone])      status[StatusDone]      = 1'b1;
        if (cfg.intr_vif.pins[IntrDmaChunkDone]) status[StatusChunkDone] = 1'b1;
        if (cfg.intr_vif.pins[IntrDmaError])     status[StatusError]     = 1'b1;
      end
    end else begin
      // Rely upon the CSR reading in `poll_status` to detect completion.
      forever delay(100);
    end
  endtask : await_interrupt

  // Task: Continuously poll status until completion every N cycles
  task poll_status(bit intr_driven, ref status_t status, input int pollrate = 10);
    bit [31:0] v;

    `uvm_info(`gfn, "DMA: Polling DMA Status", UVM_HIGH)
    do begin
      csr_rd(ral.status, v);
      // Collect some STATUS bit that do not generate interrupts, and inform parallel threads
      // if (v[0]) ->e_busy;
      if (v[2]) status[StatusAborted] = 1'b1;
      // Respond to STATUS.chunk_done even if we're interrupt driven because the interrupt may not
      // have been enabled; we guarantee in the body of `dma_generic_vseq` only to enable the
      // interrupts that signal conclusion of the full transfer operation.
      if (v[5]) status[StatusChunkDone] = 1'b1;
      // Respond to the STATUS.done and STATUS.error bits only if we're not insisting upon
      // interrupt-driven completion.
      if (!intr_driven) begin
        if (v[1]) status[StatusDone]  = 1'b1;
        if (v[3]) status[StatusError] = 1'b1;
      end
      // Note: sha2_digest_valid is not a completion event
      // v[12]
      delay(pollrate);
    end while (~|status);
  endtask : poll_status

  // Task: Simulate a clock delay
  virtual task delay(int num = 1);
    cfg.clk_rst_vif.wait_clks(num);
  endtask : delay

  // Task to wait for the transfer of a specified number of bytes.
  //
  // The `stop` signal may be set by a parallel task that monitors the completion of chunks,
  // to ensure the tidy exit of this task. (In a multi-chunk transfer the generation of
  // LSIO triggers is decoupled from the transfers.)
  task wait_num_bytes_transfer(uint num_bytes, ref bit stop);
    while (!stop) begin
      if (get_bytes_written(dma_config) >= num_bytes) begin
        `uvm_info(`gfn, $sformatf("Got %d", num_bytes), UVM_DEBUG)
        break;
      end else begin
        delay(1);
      end
    end
  endtask

  // Task to read out the SHA digest
  task read_sha2_digest(input opcode_e op, output logic [511:0] digest);
    int sha_digest_size; // in 32-bit words
    string sha_mode;
    digest = '0;
    `uvm_info(`gfn, "DMA: Read SHA2 digest", UVM_MEDIUM)
    case (op)
      OpcSha256, OpcVerifySha256: begin
        sha_digest_size = 8;
        sha_mode = "SHA2-256";
      end
      OpcSha384, OpcVerifySha384: begin
        sha_digest_size = 12;
        sha_mode = "SHA2-384";
      end
      OpcSha512, OpcVerifySha512: begin
        sha_digest_size = 16;
        sha_mode = "SHA2-512";
      end
      default: begin
        `uvm_error(`gfn, $sformatf("Unsupported SHA2 opcode %d", op))
      end
    endcase

    for(int i = 0; i < sha_digest_size; ++i) begin
      csr_rd(ral.sha2_digest[i],  digest[i*32 +: 32]);
    end
    `uvm_info(`gfn, $sformatf("DMA: %s digest: %x", sha_mode, digest), UVM_MEDIUM)
  endtask

  // Return number of bytes read from the responder corresponding to the source ASID.
  virtual function uint get_bytes_read(ref dma_seq_item dma_config);
    asid_encoding_e asid = dma_config.src_asid;
    int p32 = port32_for_asid(asid);
    int p64 = port64_for_asid(asid);
    if (p32 >= 0)      return seq32[p32].bytes_read;
    else if (p64 >= 0) return seq64[p64].bytes_read;
    `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
    return 0;
  endfunction

  // Return number of bytes written to the responder corresponding to the destination ASID.
  virtual function uint get_bytes_written(ref dma_seq_item dma_config);
    asid_encoding_e asid = dma_config.dst_asid;
    int p32 = port32_for_asid(asid);
    int p64 = port64_for_asid(asid);
    if (p32 >= 0)      return seq32[p32].bytes_written;
    else if (p64 >= 0) return seq64[p64].bytes_written;
    `uvm_error(`gfn, $sformatf("Unsupported Address space ID %s (port not present)", asid.name()))
    return 0;
  endfunction

  // Body: Need to override for inherited tests
  task body();
    init_model();
    enable_interrupts();
  endtask : body
endclass
