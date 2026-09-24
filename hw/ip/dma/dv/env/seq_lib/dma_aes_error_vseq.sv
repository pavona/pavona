// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Directed negative test for the inline-AES legal-combination checks. Each case programs an
// otherwise-plausible AES transfer with exactly one illegal aspect and checks that the DMA reports
// the expected ERROR_CODE bit and STATUS.error (and never STATUS.done). Scoreboard AES prediction
// stays disabled (these never move data); this sequence self-checks.
class dma_aes_error_vseq extends dma_base_vseq;
  `uvm_object_utils(dma_aes_error_vseq)
  `uvm_object_new

  localparam bit [63:0] SrcAddr   = 64'h0000_1000;
  localparam bit [63:0] DstAddr   = 64'h0000_2000;
  localparam bit [31:0] RangeBase = 32'h0000_0000;
  localparam bit [31:0] RangeLim  = 32'h0000_FFFF;

  // Program one (possibly illegal) AES config and check the expected error bit.
  // aes_op_raw: 1=Enc, 2=Dec, 3=reserved(invalid). exp_err_bit: dma_error_e index.
  task run_case(string name, bit [1:0] aes_op_raw, bit aes_mode,
                dma_transfer_width_e width, bit [31:0] total, bit [31:0] chunk,
                bit [1:0] digest, bit handshake, bit [3:0] aad_blocks, int exp_err_bit);
    uvm_reg_data_t d = 0;
    bit [31:0] ec, st;
    `uvm_info(`gfn, $sformatf("AES error case: %s", name), UVM_LOW)

    // Addresses / sizes / range / AES params (key/iv content is irrelevant for the rejection).
    set_src_addr(SrcAddr); set_dst_addr(DstAddr);
    set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
    set_addr_space_id(OtInternalAddr, OtInternalAddr);
    set_total_size(total); set_chunk_data_size(chunk);
    set_transfer_width(width);
    set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
    ral.aes_ctrl.key_len.set(3'b001);
    ral.aes_ctrl.sideload.set(1'b0);
    ral.aes_ctrl.prng_reseed_rate.set(3'd1);
    ral.aes_ctrl.aad_blocks.set(aad_blocks);
    csr_update(ral.aes_ctrl);

    // Hardware handshake stays in idle until an enabled LSIO trigger fires; enable a trigger source
    // so the FSM advances to the legal-combination check.
    if (handshake) begin
      csr_wr(ral.clear_intr_src, '0);
      ral.handshake_intr_enable.set('1);
      csr_update(ral.handshake_intr_enable);
    end

    // CONTROL with the (possibly illegal) fields; read_en=write_en=1.
    d = get_csr_val_with_updated_field(ral.control.read_en, d, 1'b1);
    d = get_csr_val_with_updated_field(ral.control.write_en, d, 1'b1);
    d = get_csr_val_with_updated_field(ral.control.aes_op, d, aes_op_raw);
    d = get_csr_val_with_updated_field(ral.control.aes_mode, d, aes_mode);
    d = get_csr_val_with_updated_field(ral.control.digest, d, digest);
    d = get_csr_val_with_updated_field(ral.control.hardware_handshake_enable, d, handshake);
    d = get_csr_val_with_updated_field(ral.control.initial_transfer, d, 1'b1);
    csr_wr(ral.control, d);
    d = get_csr_val_with_updated_field(ral.control.go, d, 1'b1);
    csr_wr(ral.control, d);

    // Assert the LSIO trigger so a handshake config is actually evaluated (and rejected).
    if (handshake) set_hardware_handshake_intr('1);

    // The config is rejected before any data movement; wait for STATUS.error.
    `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!st[3]);,
                 $sformatf("%s: timed out waiting for STATUS.error", name))
    `DV_CHECK_EQ(st[1], 1'b0, $sformatf("%s: STATUS.done set on an illegal config", name))
    csr_rd(ral.error_code, ec);
    `DV_CHECK_EQ(ec[exp_err_bit], 1'b1, $sformatf("%s: ERROR_CODE bit %0d not set", name, exp_err_bit))
    if (handshake) release_hardware_handshake_intr();
    // Clear the error (RW1C STATUS.error) before the next case.
    csr_wr(ral.status, 32'h0000_0008);
  endtask

  virtual task body();
    `uvm_info(`gfn, "DMA: Starting inline-AES error (legal-combo) sequence", UVM_LOW)
    init_model();
    // name              aes_op mode width            total  chunk  dig hs aad  exp_err
    run_case("non_16B_total", 2'd1, 1'b0, DmaXfer4BperTxn, 32'd24, 32'd24, 2'd0, 1'b0, 4'd0,
             DmaSizeErr);
    run_case("non_16B_chunk", 2'd1, 1'b1, DmaXfer4BperTxn, 32'd64, 32'd24, 2'd0, 1'b0, 4'd0,
             DmaSizeErr);
    run_case("with_digest",   2'd1, 1'b0, DmaXfer4BperTxn, 32'd64, 32'd64, 2'd1, 1'b0, 4'd0,
             DmaOpcodeErr);
    // Invalid block sizes must also be rejected after a hardware trigger.
    run_case("handshake_non_16B_chunk", 2'd1, 1'b0, DmaXfer4BperTxn,
             32'd64, 32'd24, 2'd0, 1'b1, 4'd0, DmaSizeErr);
    run_case("not_4B_width",  2'd1, 1'b0, DmaXfer2BperTxn, 32'd64, 32'd64, 2'd0, 1'b0, 4'd0,
             DmaSizeErr);
    run_case("reserved_aes_op",2'd3,1'b0, DmaXfer4BperTxn, 32'd64, 32'd64, 2'd0, 1'b0, 4'd0,
             DmaOpcodeErr);
    run_case("aad_too_many",  2'd1, 1'b1, DmaXfer4BperTxn, 32'd64, 32'd64, 2'd0, 1'b0, 4'd3,
             DmaSizeErr);
    // GCM text-block count must fit the 13-bit `text_blocks` field (<= 8191 blocks = 0x1_FFF0
    // bytes). 0x2_0000 bytes = 8192 blocks overflows it; the wrapper's GHASH length / phase count
    // would diverge from the gather/scatter FSM, so the config must be rejected up front. Both
    // endpoints are OT-internal, so the (single-endpoint) range check is skipped and only the
    // size check fires.
    run_case("gcm_blocks_overflow", 2'd1, 1'b1, DmaXfer4BperTxn, 32'h0002_0000, 32'h0002_0000,
             2'd0, 1'b0, 4'd0, DmaSizeErr);

    // Reject every unconfigured encoding on source, destination and interrupt-clear targets.
    // Includes reserved codewords, zero/all-ones and every single-bit corruption of a valid ID.
    for (int value = 0; value < 256; value++) begin
      if (dma_asid_configured(asid_encoding_e'(value))) continue;
      for (int target = 0; target < 3; target++) begin
        uvm_reg_data_t d = 0;
        bit [31:0] st, ec;
        `uvm_info(`gfn, "AES error case: invalid_asid", UVM_LOW)
        set_src_addr(SrcAddr); set_dst_addr(DstAddr);
        set_src_config(1'b0, 1'b1); set_dst_config(1'b0, 1'b1);
        ral.addr_space_id.src_asid.set(target == 0 ? value : int'(OtInternalAddr));
        ral.addr_space_id.dst_asid.set(target == 1 ? value : int'(OtInternalAddr));
        csr_update(ral.addr_space_id);
        csr_wr(ral.clear_intr_src, target == 2 ? 1 : 0);
        csr_wr(ral.clear_intr_asid[0], value);
        csr_wr(ral.handshake_intr_enable, 1);
        set_total_size(64); set_chunk_data_size(64);
        set_transfer_width(DmaXfer4BperTxn);
        set_dma_enabled_memory_range(RangeBase, RangeLim, 1'b1, MuBi4True);
        d = get_csr_val_with_updated_field(ral.control.read_en, d, 1'b1);
        d = get_csr_val_with_updated_field(ral.control.write_en, d, 1'b1);
        d = get_csr_val_with_updated_field(ral.control.initial_transfer, d, 1'b1);
        d = get_csr_val_with_updated_field(ral.control.hardware_handshake_enable, d, target == 2);
        csr_wr(ral.control, d);
        d = get_csr_val_with_updated_field(ral.control.go, d, 1'b1);
        csr_wr(ral.control, d);
        if (target == 2) set_hardware_handshake_intr(1);
        `DV_SPINWAIT(do begin csr_rd(ral.status, st); end while (!st[3]);,
                     "invalid_asid: timed out waiting for STATUS.error")
        `DV_CHECK_EQ(st[1], 1'b0, "invalid_asid: STATUS.done set on illegal config")
        csr_rd(ral.error_code, ec);
        `DV_CHECK_EQ(ec[DmaAsidErr], 1'b1, "invalid_asid: ERROR_CODE.asid_error not set")
        `DV_CHECK_EQ(cfg.scoreboard_h.num_bytes_read, 0)
        `DV_CHECK_EQ(cfg.scoreboard_h.num_bytes_transferred, 0)
        release_hardware_handshake_intr();
        ral.status.error.set(1'b1);
        csr_update(ral.status);
      end
    end

    `uvm_info(`gfn, "DMA: Completed inline-AES error sequence", UVM_LOW)
  endtask : body
endclass
