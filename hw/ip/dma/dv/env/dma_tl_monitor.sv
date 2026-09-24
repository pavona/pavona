// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide (64-bit) TileLink monitor for the DMA host64 SoC System port. Samples the wide
// `dma_tl_if` and builds `dma_tl_seq_item`s carrying the full 64-bit address and the
// command-integrity field. Ports:
//   * a_chan_port        - A-channel items
//   * d_chan_port        - D-channel responses
//   * channel_dir_port   - channel direction notifications (when synchronise_ports is set)
// Ports are typed for `tl_seq_item`; written items are `dma_tl_seq_item` (downcast on use).
class dma_tl_monitor extends dv_base_monitor#(
    .ITEM_T (tl_seq_item),
    .CFG_T  (dma_tl_agent_cfg),
    .COV_T  (tl_agent_cov)
  );

  tl_seq_item    pending_a_req[bit [SourceWidth - 1 : 0]];
  string         agent_name;

  uvm_analysis_port #(tl_channels_e) channel_dir_port;
  uvm_analysis_port #(tl_seq_item)   a_chan_port;
  uvm_analysis_port #(tl_seq_item)   d_chan_port;

  // Only used when cfg.device_can_rsp_on_same_cycle.
  uvm_analysis_port #(tl_seq_item) a_chan_same_cycle_rsp_port;

  `uvm_component_utils(dma_tl_monitor)

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (cfg.synchronise_ports) begin
      channel_dir_port = new("channel_dir_port", this);
    end

    a_chan_port = new("a_chan_port", this);
    d_chan_port = new("d_chan_port", this);

    if (cfg.device_can_rsp_on_same_cycle) begin
      a_chan_same_cycle_rsp_port = new("a_chan_same_cycle_rsp_port", this);
    end
  endfunction : build_phase

  // Watch the reset signal and maintain cfg.in_reset
  local task monitor_reset();
    cfg.in_reset = (cfg.dma_vif.rst_n !== 1'b1);
    wait(!$isunknown(cfg.dma_vif.rst_n));
    forever begin
      cfg.in_reset = !cfg.dma_vif.rst_n;
      wait(cfg.dma_vif.rst_n != !cfg.in_reset);
    end
  endtask

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork
      monitor_reset();
      ad_channels_thread();
    join
  endtask

  local task ad_channels_thread();
    forever begin
      wait(!cfg.in_reset);

      pending_a_req.delete();
      cfg.a_source_pend_q.delete();

      fork begin : isolation_fork
        fork
          ad_channels_thread_();
          wait(cfg.in_reset);
        join_any
        disable fork;
      end join

      if (cfg.en_cov) cov.m_pending_req_on_rst_cg.sample(pending_a_req.size() != 0);
    end
  endtask

  local task ad_channels_thread_();
    tl_seq_item a_chan_req_item;

    forever begin
      @(cfg.dma_vif.mon_cb);
      // Just after the clock edge: sample D then A.
      if (cfg.dma_vif.mon_cb.d2h.d_valid && cfg.dma_vif.mon_cb.h2d.d_ready)
        check_d_channel();

      if (!cfg.device_can_rsp_on_same_cycle) begin
        if (cfg.dma_vif.mon_cb.h2d.a_valid && cfg.dma_vif.mon_cb.d2h.a_ready)
          a_chan_req_item = check_a_channel(.immediate(1'b0));
      end
      if (a_chan_req_item != null) begin
        a_chan_port.write(a_chan_req_item);
        if (cfg.synchronise_ports) channel_dir_port.write(AddrChannel);
        a_chan_req_item = null;
      end

      if (cfg.device_can_rsp_on_same_cycle) begin
        `DV_SPINWAIT_EXIT(
            #(cfg.time_a_valid_avail_after_sample_edge);,
            @(cfg.dma_vif.mon_cb) `uvm_fatal(`gfn, $sformatf(
                "time_a_valid_avail_after_sample_edge (%0t) is over one cycle",
                cfg.time_a_valid_avail_after_sample_edge)))

        a_chan_req_item = check_a_channel(.immediate(1'b1));
        if (a_chan_req_item != null) begin
          a_chan_same_cycle_rsp_port.write(a_chan_req_item);
        end
      end
    end
  endtask

  // Check the A channel for a transaction. Captures the full 64-bit address.
  function tl_seq_item check_a_channel(bit immediate);
    logic a_valid = immediate ? cfg.dma_vif.h2d.a_valid : cfg.dma_vif.mon_cb.h2d.a_valid;
    logic a_ready = immediate ? cfg.dma_vif.d2h.a_ready : cfg.dma_vif.mon_cb.d2h.a_ready;

    if (a_valid && a_ready) begin
      dma_tl_seq_item req = dma_tl_seq_item::type_id::create("req");
      dma_tlul_pkg::dma_tl_h2d_t h2d = immediate ? cfg.dma_vif.h2d : cfg.dma_vif.mon_cb.h2d;

      req.set_a_addr_full(h2d.a_address); // full 64-bit address (also mirrors low bits to a_addr)
      req.a_opcode   = h2d.a_opcode;
      req.a_size     = h2d.a_size;
      req.a_param    = h2d.a_param;
      req.a_data     = h2d.a_data;
      req.a_mask     = h2d.a_mask;
      req.a_source   = h2d.a_source;
      // Copy only the shared a_user fields (widths differ from the wide type); the wide
      // command-integrity is kept separately in `a_cmd_intg`.
      // `req.a_user` is a flat bit-vector in tl_seq_item, so build a standard tl_a_user_t
      // struct and assign its packed value.
      begin
        tlul_pkg::tl_a_user_t a_user_struct = '0;
        a_user_struct.instr_type = h2d.a_user.instr_type;
        a_user_struct.data_intg  = h2d.a_user.data_intg;
        req.a_user = a_user_struct;
      end
      req.a_cmd_intg = h2d.a_user.cmd_intg;

      // Verify the host64 command integrity against the recomputed SECDED.
      if (cfg.check_cmd_intg) begin
        logic [dma_tlul_pkg::DmaH2DCmdIntgWidth-1:0] exp_cmd_intg =
            dma_tlul_pkg::dma_get_cmd_intg(h2d);
        if (exp_cmd_intg !== h2d.a_user.cmd_intg) begin
          `uvm_error(`gfn, $sformatf(
              "host64 A-channel command-integrity mismatch: expected 0x%0x, got 0x%0x (addr 0x%0x)",
              exp_cmd_intg, h2d.a_user.cmd_intg, h2d.a_address))
        end
      end
      `uvm_info(`gfn, $sformatf("[%0s][a_chan] : %0s", agent_name, req.convert2string()), UVM_HIGH)

      if (cfg.en_cov) sample_outstanding_cov(req);

      `DV_CHECK_EQ_FATAL(req.a_source >> cfg.valid_a_source_width, 0)
      `DV_CHECK_EQ_FATAL(pending_a_req.exists(req.a_source), 0)
      begin
        tl_seq_item cloned_req;
        `downcast(cloned_req, req.clone())
        pending_a_req[req.a_source] = cloned_req;
      end

      if (cfg.max_outstanding_req > 0 && cfg.dma_vif.rst_n === 1) begin
        if (pending_a_req.size() > cfg.max_outstanding_req) begin
          `uvm_error(`gfn,
                     $sformatf("Number of pending a_req exceeds limit %0d", pending_a_req.size()))
        end
        if (cfg.en_cov) cov.m_max_outstanding_cg.sample(pending_a_req.size());
      end
      return req;
    end

    return null;
  endfunction

  // Check the D channel for a transaction. d2h is the standard `tl_d2h_t`.
  function void check_d_channel();
    if (cfg.dma_vif.mon_cb.d2h.d_valid && cfg.dma_vif.mon_cb.h2d.d_ready) begin
      tl_seq_item rsp;

      if (!pending_a_req.exists(cfg.dma_vif.mon_cb.d2h.d_source)) begin
        `uvm_info(`gfn,
                  $sformatf("Ignoring TL response with no matching request (d_source 0x%0x)",
                            cfg.dma_vif.mon_cb.d2h.d_source),
                  UVM_HIGH)
        return;
      end

      rsp = pending_a_req[cfg.dma_vif.mon_cb.d2h.d_source];
      pending_a_req.delete(cfg.dma_vif.mon_cb.d2h.d_source);

      rsp.d_opcode = cfg.dma_vif.mon_cb.d2h.d_opcode;
      rsp.d_data   = cfg.dma_vif.mon_cb.d2h.d_data;
      rsp.d_source = cfg.dma_vif.mon_cb.d2h.d_source;
      rsp.d_param  = cfg.dma_vif.mon_cb.d2h.d_param;
      rsp.d_error  = cfg.dma_vif.mon_cb.d2h.d_error;
      rsp.d_sink   = cfg.dma_vif.mon_cb.d2h.d_sink;
      rsp.d_size   = cfg.dma_vif.mon_cb.d2h.d_size;
      rsp.d_user   = cfg.dma_vif.mon_cb.d2h.d_user;

      `uvm_info(`gfn, $sformatf("[%0s][d_chan] : %0s", agent_name, rsp.convert2string()), UVM_HIGH)

      d_chan_port.write(rsp);
      if (cfg.synchronise_ports) channel_dir_port.write(DataChannel);

      if (cfg.en_cov) cov.sample(rsp);
    end
  endfunction

  virtual task monitor_ready_to_end();
    forever begin
      ok_to_end = (pending_a_req.size() == 0);
      if (ok_to_end) wait(pending_a_req.size() > 0);
      else           wait(pending_a_req.size() == 0);
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    if (pending_a_req.size() > 0) begin
      `uvm_error(get_full_name(), $sformatf(
                 "%0d items left at the end of sim", pending_a_req.size()))
      foreach (pending_a_req[i]) begin
        `uvm_info(get_full_name(), $sformatf("pending_a_req[%0d] = %0s",
                  i, pending_a_req[i].convert2string()), UVM_LOW)
      end
    end
  endfunction : report_phase

  virtual function void sample_outstanding_cov(tl_seq_item item);
    bit is_outstanding_item_w_same_addr;

    foreach (pending_a_req[i]) begin
      if (pending_a_req[i].a_addr == item.a_addr) begin
        is_outstanding_item_w_same_addr = 1;
        break;
      end
    end

    if (cov.m_outstanding_item_w_same_addr_cov_obj != null) begin
      cov.m_outstanding_item_w_same_addr_cov_obj.sample(is_outstanding_item_w_same_addr);
    end
  endfunction : sample_outstanding_cov

endclass : dma_tl_monitor
