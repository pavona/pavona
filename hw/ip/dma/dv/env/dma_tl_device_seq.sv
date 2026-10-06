// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide (64-bit) device-responder sequence for the DMA host64 SoC System port: the 64-bit
// counterpart of `dma_pull_seq`. Drains `dma_tl_seq_item` requests from `dma_tl_monitor`
// and produces randomized d2h responses via `dma_tl_device_driver`. The full 64-bit
// address is read directly from `dma_tl_seq_item::a_addr_full` (no base-address window).
class dma_tl_device_seq extends dv_base_seq #(
    .REQ        (tl_seq_item),
    .CFG_T      (dma_tl_agent_cfg),
    .SEQUENCER_T(dma_tl_sequencer));

  localparam int AddrWidth = dma_tlul_pkg::DmaTlAw;

  // Response delays (cycles).
  int min_rsp_delay = 0;
  int max_rsp_delay = 4;
  // Chance to set d_error (percentage).
  int d_error_pct = 0;

  // Backing store for the 64-bit SoC System device.
  mem_model_pkg::mem_model#(.AddrWidth(AddrWidth)) mem;

  // FIFO enable bits.
  bit read_fifo_en;
  bit write_fifo_en;
  // FIFO instances for destination and source (64-bit addresses).
  dma_handshake_mode_fifo #(AddrWidth) dst_fifo;
  dma_handshake_mode_fifo #(AddrWidth) src_fifo;

  // 'Clear Interrupt' register handling (same as dma_pull_seq).
  bit fifo_reg_clear_en;
  bit [31:0] fifo_intr_clear_reg[bit [31:0]];

  // Bytes/transaction; needed because `tlul_adapter_host` always fetches entire bus words.
  uint txn_bytes;

  // Byte counters.
  uint bytes_read;
  uint bytes_written;

  // Pending request queue and stop flag.
  tl_seq_item req_q[$];
  protected bit stop;

  // If enabled, a rsp will be aborted if it is not accepted after the given valid length. Mirrors
  // stock `tl_device_seq`; off by default (rsp_abort_pct == 0) because the single-outstanding SoC
  // System port does not currently exercise out-of-order / aborted responses.
  rand bit rsp_abort_after_d_valid_len;
  // Chance (percent) to abort a rsp.
  int      rsp_abort_pct = 0;

  constraint en_req_abort_after_d_valid_len_c {
    rsp_abort_after_d_valid_len dist {
      1 :/ rsp_abort_pct,
      0 :/ 100 - rsp_abort_pct
    };
  }

  `uvm_object_utils(dma_tl_device_seq)

  function new (string name = "");
    super.new(name);
    min_rsp_delay = 0;
    max_rsp_delay = 4;
    bytes_read = 0;
    bytes_written = 0;
  endfunction : new

  // ---- Public API (matches dma_pull_seq, used by dma_base_vseq) -----------------------------
  virtual function void set_txn_bytes(uint bytes);
    `DV_CHECK(bytes inside {1, 2, 4}, $sformatf("Invalid txn_bytes 0x%x", bytes))
    txn_bytes = bytes;
  endfunction

  virtual function void set_fifo_clear(bit en);
    fifo_reg_clear_en = en;
    bytes_read = 0;
    bytes_written = 0;
  endfunction

  virtual function void add_fifo_reg(bit [31:0] addr, bit [31:0] data);
    `uvm_info(`gfn, $sformatf("Add FIFO addr: 0x%0x wr_val: 0x%0x", addr, data), UVM_DEBUG)
    fifo_intr_clear_reg[addr] = data;
  endfunction

  virtual function void enable_bus_errors(int pct);
    d_error_pct = pct;
  endfunction

  // ---- Sequence body (mirrors tl_device_seq) -----------------------------------------------
  virtual task body();
    fork
      begin: isolation_thread
        fork
          collect_request_thread();
          send_response_thread();
        join_any
        wait (req_q.size() == 0);
        disable fork;
      end
    join
    stop = 0;
  endtask

  protected virtual task get_a_chan_req(output tl_seq_item req);
    fork
      begin: isolation_thread
        fork
          begin
            tl_seq_item item;
            p_sequencer.a_chan_req_fifo.get(item);
            req = item;
          end
          wait (stop);
        join_any
        #0;
        disable fork;
      end
    join
  endtask

  protected virtual task collect_request_thread();
    int req_cnt;
    forever begin
      tl_seq_item req;
      get_a_chan_req(req);
      if (req != null) begin
        req_q.push_back(req);
        `uvm_info(`gfn, $sformatf("Received req[%0d] : %0s",
                                  req_cnt, req.convert2string()), UVM_HIGH)
        req_cnt++;
      end
      if (stop) break;
    end
  endtask

  protected virtual task send_response_thread();
    int rsp_cnt;
    forever begin
      tl_seq_item     req;
      dma_tl_seq_item rsp;
      // Wake on a pending request OR on stop, so teardown does not block here. Mirrors the
      // teardown contract of stock `tl_device_seq`: `body()` waits for `req_q` to drain after the
      // forked threads end, and this thread must not be parked in an unconditional `wait` while
      // `stop` is asserted.
      wait(req_q.size > 0 || stop);
      if (stop) break;

      // peek at the front of the queue, but don't pop it.
      req = req_q[0];
      `downcast(rsp, req.clone())

      randomize_rsp(rsp);
      post_randomize_rsp(rsp);
      update_mem(rsp);
      start_item(rsp);
      finish_item(rsp);
      // get_response() expects the base REQ type (tl_seq_item); use a temporary.
      begin
        tl_seq_item rsp_base;
        get_response(rsp_base);
        `downcast(rsp, rsp_base)
      end

      if (rsp.rsp_completed) begin
        void'(req_q.pop_front());
        `uvm_info(`gfn, $sformatf("Sent rsp[%0d] : %0s", rsp_cnt, rsp.convert2string()), UVM_HIGH)
        rsp_cnt++;
      end
    end
  endtask

  // ---- Response generation (reused from dma_pull_seq, full 64-bit address) ------------------
  virtual function void update_mem(dma_tl_seq_item rsp);
    bit [AddrWidth-1:0] a_addr = rsp.get_a_addr_full();

    if (mem != null) begin
      if (rsp.a_opcode inside {PutFullData, PutPartialData}) begin
        bit [tl_agent_pkg::DataWidth-1:0] data;
        data = rsp.a_data;
        // First series of writes will be to clear FIFO interrupts.
        if (fifo_reg_clear_en && fifo_intr_clear_reg.exists(a_addr[31:0])) begin
          `DV_CHECK(fifo_intr_clear_reg.exists(a_addr[31:0]),
                    $sformatf("Invalid FIFO reg addr: 0x%0x detected", a_addr))
          `DV_CHECK_EQ(fifo_intr_clear_reg[a_addr[31:0]], rsp.a_data,
                       "Invalid FIFO reg value detected")
        end else begin
          for (int i = 0; i < $bits(rsp.a_mask); i++) begin
            if (rsp.a_mask[i]) begin
              bytes_written++;
              if (write_fifo_en) begin
                dst_fifo.write_byte(a_addr + i, data[7:0]);
              end else begin
                mem.write_byte(a_addr + i, data[7:0]);
              end
            end
            data = data >> 8;
          end
        end
      end else begin
        // Collect data from source model.
        if (read_fifo_en) begin
          rsp.d_data = src_fifo.read_word_tlul(a_addr, rsp.a_mask);
        end else begin
          for (int i = 0; i < $bits(rsp.a_mask); i++) begin
            rsp.d_data = rsp.d_data >> 8;
            if (rsp.a_mask[i]) begin
              rsp.d_data[tl_agent_pkg::DataWidth-1 -: 8] = mem.read_byte(a_addr+i);
            end
          end
        end
        bytes_read += txn_bytes;
      end
    end
    // Recompute data integrity bits because the code above changed `d_data`.
    rsp.d_user[6:0] = prim_secded_pkg::prim_secded_inv_39_32_enc(rsp.d_data) >> 32;
  endfunction : update_mem

  virtual function void randomize_rsp(dma_tl_seq_item rsp);
    rsp.disable_a_chan_randomization();

    if (d_error_pct > 0) rsp.no_d_error_c.constraint_mode(0);

    `DV_CHECK_RANDOMIZE_WITH_FATAL(rsp,
      rsp.d_valid_delay inside {[min_rsp_delay : max_rsp_delay]};
      if (rsp.a_opcode == tlul_pkg::Get) {
        rsp.d_opcode == tlul_pkg::AccessAckData;
      } else {
        rsp.d_opcode == tlul_pkg::AccessAck;
      }
      rsp.d_size == rsp.a_size;
      rsp.d_source == rsp.a_source;
      d_error dist {0 :/ (100 - d_error_pct), 1 :/ d_error_pct};
    )
    // Compute integrity bits because the code above randomized all response fields.
    rsp.d_user[13:7] = prim_secded_pkg::prim_secded_inv_64_57_enc({51'b0,
                                                                   rsp.d_opcode,
                                                                   rsp.d_size,
                                                                   rsp.d_error}) >> 57;
    rsp.d_user[6:0] = prim_secded_pkg::prim_secded_inv_39_32_enc(rsp.d_data) >> 32;
    `uvm_info(`gfn,
              $sformatf("[check][d_chan] : a_address=0x%016h d_valid_delay=%0d",
                        rsp.get_a_addr_full(), rsp.d_valid_delay),
              UVM_HIGH)
  endfunction

  // Callback after `randomize_rsp`, mirroring stock `tl_device_seq::post_randomize_rsp`. Restores
  // the non-rand `rsp_abort_after_d_valid_len` plumbing so the driver's D-valid abort path is fed a
  // defined value (the driver reads `rsp.rsp_abort_after_d_valid_len`); with `rsp_abort_pct == 0`
  // this resolves to 0, leaving the abort path inactive but no longer a dead / undefined feature.
  virtual function void post_randomize_rsp(dma_tl_seq_item rsp);
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(rsp_abort_after_d_valid_len)
    rsp.rsp_abort_after_d_valid_len = rsp_abort_after_d_valid_len;
  endfunction

  // Stop running this seq and wait until it has finished gracefully.
  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask

endclass : dma_tl_device_seq
