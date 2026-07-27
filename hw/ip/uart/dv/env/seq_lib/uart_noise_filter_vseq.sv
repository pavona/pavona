// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// test small glitch that can be filtered when noise filter is enabled
class uart_noise_filter_vseq extends uart_tx_rx_vseq;
  `uvm_object_utils(uart_noise_filter_vseq)

  `uvm_object_new

  string cdc_en_path = {"tb.dut.uart_core.sync_rx.u_prim_cdc_rand_delay",
                        ".gen_enable.cdc_instrumentation_enabled"};

  virtual task dut_init(string reset_kind = "HARD");
    super.dut_init(reset_kind);
    if (cfg.en_dv_cdc) begin
      // A stale path must fail loudly instead of silently
      // leaving CDC randomization on and making the noise filter look broken.
      `DV_CHECK_FATAL(uvm_hdl_check_path(cdc_en_path),
                      $sformatf("HDL path does not exist: %0s", cdc_en_path))
      `DV_CHECK(uvm_hdl_force(cdc_en_path, 1'b0))
    end
  endtask

  virtual task dut_shutdown();
    super.dut_shutdown();
    // Re-enable CDC randomization on rx_sync.
    if (cfg.en_dv_cdc) begin
      `DV_CHECK(uvm_hdl_release(cdc_en_path))
    end
  endtask

  // add noise before sending rx byte
  // check rxidle should be high after adding noise
  virtual task send_rx_byte(byte data);
    int core_clk_period_ps = cfg.clk_rst_vif.clk_period_ps;

    // monitor doesn't filter glitch less than 1 core cycle, need to disable it
    cfg.m_uart_agent_cfg.en_rx_monitor = 0;
    if (en_noise_filter) begin
      // uart clk is much slower than core clk
      // need large number to check if the glitch has no impact to uart
      repeat ($urandom_range(1, 10_000)) begin
        cfg.m_uart_agent_cfg.vif.drive_uart_rx_glitch(
            .max_glitch_ps(core_clk_period_ps), // 1 core clk
            // need 3 core clk cycles to push out the glitch before next drive
            .stable_ps_after_glitch(core_clk_period_ps * 3));
      end
      csr_rd_check(.ptr(ral.status.rxidle), .compare_value(1));
    end
    cfg.m_uart_agent_cfg.en_rx_monitor = 1;
    super.send_rx_byte(data);
  endtask

endclass : uart_noise_filter_vseq
