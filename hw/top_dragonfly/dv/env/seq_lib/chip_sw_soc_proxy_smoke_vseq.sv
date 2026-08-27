// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class chip_sw_soc_proxy_smoke_vseq extends chip_sw_base_vseq;
  `uvm_object_utils(chip_sw_soc_proxy_smoke_vseq)

  `uvm_object_new

  // Duration of the external reset request. The filter in `soc_proxy` swallows anything shorter
  // than five AON clock cycles
  rand int unsigned rst_req_clks;

  constraint rst_req_clks_c {
    rst_req_clks inside {[5:18]};
  }

  virtual task body();
    super.body();

    // Wait until SW reaches the test state.
    `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest)
    `DV_WAIT(cfg.sw_logger_vif.printed_log == "External resets enabled.")

    // Fork background threads to ensure that most reset domains do *not* get reset.
    fork
      begin
        cfg.chip_vif.io_clk_rst_if.wait_for_reset(.wait_negedge(1), .wait_posedge(0));
        `dv_error("IO reset domain asserted when it should not!")
      end
      begin
        cfg.chip_vif.aon_clk_por_rst_if.wait_for_reset(.wait_negedge(1), .wait_posedge(0));
        `dv_error("POR reset domain asserted when it should not!")
      end
    join_none

    // Trigger the external reset request in the background
    fork
      begin
        `uvm_info(`gfn, $sformatf("Applying SoC reset request for %0d cycle(s)", rst_req_clks),
                  UVM_MEDIUM)
        apply_soc_reset_request(rst_req_clks);
      end
    join_none

    // Ensure that the desired reset domains get cycled now.
    `DV_SPINWAIT_EXIT(
      // Wait thread: wait until the CPU reset domain has been cycled.
      begin
        cfg.chip_vif.cpu_clk_rst_if.wait_for_reset();
        `uvm_info(`gfn, "CPU reset cycled.", UVM_LOW)
      end
      ,
      // Exit thread: the power manager holds the chip in reset until the external request has
      // been withdrawn and acknowledged, so the budget has to cover the request itself, the
      // filter and synchronizers on both of its edges, and the traversal of the fast FSM from
      // FastPwrStateActive back round to FastPwrStateReleaseLcRst
      cfg.chip_vif.aon_clk_por_rst_if.wait_clks(rst_req_clks + 64);
      `dv_error("Resets did not complete within required time!")
    )

  endtask

endclass
