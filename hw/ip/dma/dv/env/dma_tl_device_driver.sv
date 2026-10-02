// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide (64-bit) TileLink device driver for the DMA host64 SoC System port. Drives only
// the d2h channel (standard `tlul_pkg::tl_d2h_t`) via the wide `cfg.dma_vif`. Response
// payloads come from `dma_tl_device_seq`.
class dma_tl_device_driver extends dv_base_driver#(.ITEM_T(tl_seq_item),
                                                   .CFG_T (dma_tl_agent_cfg));

  `uvm_component_utils(dma_tl_device_driver)
  `uvm_component_new

  // run_phase / reset_signals inherited from dv_base_driver (reset_signals() uses
  // cfg.in_reset, maintained by dma_tl_monitor); on_enter_reset() clears driven signals.
  virtual task get_and_drive();
    // Wait for initial reset to pass. If reset has already deasserted by the time
    // the driver starts, skip the wait-for-low phase.
    if (cfg.dma_vif.rst_n !== 1'b0) begin
      wait(cfg.dma_vif.rst_n === 1'b1);
    end else begin
      wait(cfg.dma_vif.rst_n === 1'b0);
      wait(cfg.dma_vif.rst_n === 1'b1);
    end
    fork
      a_channel_thread();
      d_channel_thread();
    join_none
  endtask

  task on_enter_reset();
    invalidate_d_channel();
    cfg.dma_vif.d2h_int.a_ready <= 1'b0;
    `DV_CHECK_EQ(seq_item_port.has_do_available(), 0);
  endtask

  // Drive the d2h `a_ready` handshake.
  //
  // The SoC System host64 bus is standard TLUL on the address channel (the d2h type carries
  // `a_ready`), so the device must drive `a_ready` exactly like stock `tl_device_driver`: a single
  // continuous driver, asserted once `a_ready_delay` cycles have elapsed and then held until a
  // beat is accepted. With `a_ready_delay == 0` (the default for this port, see
  // `dma_env.build_phase`) the device is *continuously* ready, which models a backpressure-free
  // SoC System bus. The earlier implementation pulsed `a_ready` high for a single cycle and then
  // low again, so even with delay 0 it was only ready every other cycle and the monitor (which
  // gates A-capture on `a_valid && a_ready`) silently dropped ~half the beats.
  //
  // All writes target `cfg.dma_vif.device_cb.d2h.a_ready`, which the clocking block binds to
  // `d2h_int.a_ready` (`output d2h = d2h_int`). The interface's single continuous
  // `assign d2h = (if_mode == Device) ? d2h_int : 'z;` is therefore the only physical driver of
  // `d2h.a_ready` -- no multi-driver. Reset clears it via `on_enter_reset` (`d2h_int.a_ready`),
  // the same net, so there is still exactly one source.
  virtual task a_channel_thread();
    // With a_ready_delay_min == a_ready_delay_max == 0 (the default for the host64 port),
    // a_ready is held continuously high — no per-cycle polling needed. For nonzero delay
    // configurations, fall back to the cycle-by-cycle handshake loop.
    if (cfg.a_ready_delay_min == 0 && cfg.a_ready_delay_max == 0) begin
      cfg.dma_vif.device_cb.d2h.a_ready <= 1'b1;
      // Just keep it high; on_enter_reset will clear it, and get_and_drive re-enters.
      forever begin
        wait(!cfg.dma_vif.rst_n);
        wait(cfg.dma_vif.rst_n === 1'b1);
        cfg.dma_vif.device_cb.d2h.a_ready <= 1'b1;
      end
    end else begin
      // Variable-delay handshake loop.
      int unsigned ready_delay;
      forever begin
        ready_delay = $urandom_range(cfg.a_ready_delay_min, cfg.a_ready_delay_max);
        cfg.dma_vif.device_cb.d2h.a_ready <= 1'b0;
        repeat (ready_delay) begin
          if (!cfg.dma_vif.rst_n) break;
          @(cfg.dma_vif.device_cb);
        end
        if (!cfg.dma_vif.rst_n) begin
          wait(cfg.dma_vif.rst_n === 1'b1);
          continue;
        end
        cfg.dma_vif.device_cb.d2h.a_ready <= 1'b1;
        do begin
          @(cfg.dma_vif.device_cb);
          if (!cfg.dma_vif.rst_n) break;
        end while (!(cfg.dma_vif.device_cb.h2d.a_valid && cfg.dma_vif.d2h_int.a_ready));
      end
    end
  endtask

  virtual task d_channel_thread();
    tl_seq_item rsp;

    forever begin
      int unsigned d_valid_delay, d_valid_len, d_valid_cnt;
      bit rsp_done, rsp_abort;
      seq_item_port.get_next_item(rsp);

      while (!rsp_done && !rsp_abort && cfg.dma_vif.rst_n) begin
        if (cfg.use_seq_item_d_valid_delay) begin
          d_valid_delay = rsp.d_valid_delay;
        end else begin
          d_valid_delay = $urandom_range(cfg.d_valid_delay_min, cfg.d_valid_delay_max);
        end

        if (cfg.allow_d_valid_drop_wo_d_ready || rsp.rsp_abort_after_d_valid_len) begin
          if (cfg.use_seq_item_d_valid_len) begin
            d_valid_len = rsp.d_valid_len;
          end else begin
            d_valid_len = $urandom_range(cfg.d_valid_len_min, cfg.d_valid_len_max);
          end
        end

        // break delay loop if reset asserted to release blocking
        repeat (d_valid_delay) begin
          if (!cfg.dma_vif.rst_n) break;
          else @(cfg.dma_vif.device_cb);
        end
        if (cfg.dma_vif.rst_n) begin
          cfg.dma_vif.d2h_int.d_valid  <= 1'b1;
          cfg.dma_vif.d2h_int.d_opcode <= tl_d_op_e'(rsp.d_opcode);
          cfg.dma_vif.d2h_int.d_data   <= rsp.d_data;
          cfg.dma_vif.d2h_int.d_source <= rsp.d_source;
          cfg.dma_vif.d2h_int.d_param  <= rsp.d_param;
          cfg.dma_vif.d2h_int.d_error  <= rsp.d_error;
          cfg.dma_vif.d2h_int.d_sink   <= rsp.d_sink;
          cfg.dma_vif.d2h_int.d_user   <= rsp.d_user;
          cfg.dma_vif.d2h_int.d_size   <= rsp.d_size;
        end

        // wait for ready or reaching d_valid_len
        d_valid_cnt = 0;
        while (cfg.dma_vif.rst_n) begin
          @(cfg.dma_vif.device_cb);
          d_valid_cnt++;
          if (cfg.dma_vif.device_cb.h2d.d_ready) begin
            rsp_done = 1;
            break;
          end else if ((cfg.allow_d_valid_drop_wo_d_ready || rsp.rsp_abort_after_d_valid_len)
                      && d_valid_cnt >= d_valid_len) begin
            if (rsp.rsp_abort_after_d_valid_len) rsp_abort = 1;
            invalidate_d_channel();
            if (!cfg.dma_vif.rst_n) @(cfg.dma_vif.device_cb);
            break;
          end
        end
      end
      invalidate_d_channel();
      rsp.rsp_completed = !rsp_abort;
      seq_item_port.item_done();
      seq_item_port.put_response(rsp);
    end
  endtask : d_channel_thread

  function void invalidate_d_channel();
    if (cfg.invalidate_d_x) begin
      cfg.dma_vif.d2h_int.d_opcode <= tlul_pkg::tl_d_op_e'('x);
      cfg.dma_vif.d2h_int.d_param  <= '{default:'x};
      cfg.dma_vif.d2h_int.d_size   <= '{default:'x};
      cfg.dma_vif.d2h_int.d_source <= '{default:'x};
      cfg.dma_vif.d2h_int.d_sink   <= '{default:'x};
      cfg.dma_vif.d2h_int.d_data   <= '{default:'x};
      cfg.dma_vif.d2h_int.d_user   <= '{default:'x};
      cfg.dma_vif.d2h_int.d_error  <= 1'bx;
      cfg.dma_vif.d2h_int.d_valid  <= 1'b0;
    end else begin
      tlul_pkg::tl_d2h_t d2h;
      `DV_CHECK_STD_RANDOMIZE_FATAL(d2h)
      d2h.d_valid = 1'b0;
      // Preserve a_ready — it is owned by a_channel_thread; clobbering it here
      // would create a multi-driver conflict and drop a_ready unexpectedly.
      d2h.a_ready = cfg.dma_vif.d2h_int.a_ready;
      cfg.dma_vif.d2h_int <= d2h;
    end
  endfunction : invalidate_d_channel

endclass : dma_tl_device_driver
