// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class chip_sw_rv_dm_access_after_wakeup_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_rv_dm_access_after_wakeup_vseq)

  `uvm_object_new

  // The software drives the first eight GPIOs and wakes on the ninth.
  localparam int unsigned GpiosTested = 8;
  // Pinmux DIO index of the wakeup pad, which is what the wakeup detector selects.
  localparam int unsigned WakeupDioIdx = top_dragonfly_pkg::DioGpioGpio8;

  task activate_jtag_dmi();
    // Dragonfly reaches the debug module over DMI, so there is no TAP to select.
    csr_wr(.ptr(cfg.jtag_dmi_ral.dmcontrol.dmactive), .value(1), .blocking(1), .predict(1));
    cfg.clk_rst_vif.wait_clks(5);
  endtask : activate_jtag_dmi

  virtual task body();
    uint           timeout_long       = 10_000_000;
    uint           timeout_short      = 1_000_000;
    bit [7:0]      software_barrier[] = '{0};
    uvm_reg_data_t exp_data = $urandom();

    super.body();

    `DV_SPINWAIT(wait(cfg.sw_logger_vif.printed_log == "Software Setup.");,
                 "Timed out waiting for software setup.", timeout_long)

    activate_jtag_dmi();
    csr_wr(
      .ptr(cfg.jtag_dmi_ral.progbuf[0]),
      .value(exp_data),
      .path(UVM_FRONTDOOR));
    csr_rd_check(
      .ptr(cfg.jtag_dmi_ral.progbuf[0]),
      .compare_value(exp_data),
      .path(UVM_FRONTDOOR),
      .err_msg("straight after write."));

    cfg.chip_vif.dios_if.drive_pin(DioToDioPadMap[WakeupDioIdx], 0);

    // The software drives the tested GPIOs, so stop the testbench driving them.
    cfg.chip_vif.gpios_if.pins_oe[GpiosTested-1:0] = '0;

    sw_symbol_backdoor_read("kSoftwareBarrier", software_barrier);
    software_barrier[0] = 1;
    sw_symbol_backdoor_overwrite("kSoftwareBarrier", software_barrier);

    // The GPIO value the software reports here is not checked against the pads yet.
    `DV_SPINWAIT(
      string printed_log = "";
      string log = "Chosen GPIO value:";
      while (printed_log.substr(0, log.len() - 1) != log) begin
        @(cfg.sw_logger_vif.printed_log_event);
        printed_log = string'(cfg.sw_logger_vif.printed_log);
      end)

    `DV_SPINWAIT(wait(cfg.sw_logger_vif.printed_log == "Entering normal sleep.");,
                 "Timed out waiting for device to enter normal sleep.", timeout_short)

    // Hold the JTAG agent idle while the chip is powered down. Driving DMI
    // across low power stalls the simulation.
    cfg.m_jtag_riscv_agent_cfg.in_reset = 1;

    // Keep the pin high until the chip is awake. Releasing it while the chip
    // is still powering up takes the wakeup stimulus away.
    wakeup_action();

    `DV_SPINWAIT(wait(cfg.sw_logger_vif.printed_log == "Waking up from normal sleep.");,
                 "Timed out waiting for device to wakeup from normal sleep.", timeout_long)

    release_action();

    cfg.m_jtag_riscv_agent_cfg.in_reset = 0;
    cfg.clk_rst_vif.wait_clks(5);

    // The program buffer must keep its value across a normal sleep.
    csr_rd_check(
      .ptr(cfg.jtag_dmi_ral.progbuf[0]),
      .compare_value(exp_data),
      .path(UVM_FRONTDOOR),
      .err_msg("after normal sleep."));

    // Dragonfly has no deep sleep, so the software ends once this is released.
    software_barrier[0] = 2;
    sw_symbol_backdoor_overwrite("kSoftwareBarrier", software_barrier);
  endtask : body

  task wakeup_action();
    // The software logs that it is going to sleep before the chip is actually
    // powered down. Driving the pin on that log alone races the power down and
    // the edge is missed, so wait for pwrmgr to report low power first.
    `DV_WAIT(cfg.chip_vif.pwrmgr_low_power_if.low_power == 1)
    repeat (10) @(posedge cfg.ast_supply_vif.clk);
    cfg.chip_vif.dios_if.drive_pin(DioToDioPadMap[WakeupDioIdx], 1);
  endtask : wakeup_action

  task release_action();
    repeat (10) @(posedge cfg.ast_supply_vif.clk);
    cfg.chip_vif.dios_if.drive_pin(DioToDioPadMap[WakeupDioIdx], 0);
  endtask : release_action

endclass : chip_sw_rv_dm_access_after_wakeup_vseq
