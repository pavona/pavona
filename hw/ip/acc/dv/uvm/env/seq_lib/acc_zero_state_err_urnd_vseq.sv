// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class acc_zero_state_err_urnd_vseq extends acc_single_vseq;
  `uvm_object_utils(acc_zero_state_err_urnd_vseq)
  `uvm_object_new

  task body();
    // Disable some assertions in the RTL which assert that the base registers don't get
    // secure-wiped to zero. Of course, they do in this test, so we need to disable the assertions.
    //
    // Note that we can't disable them more specifically because there is at least one assertion for
    // each register and you can't use a "for" loop because $assertoff() expects a hierarchical
    // identifier for the assertion to control, rather than just an expression.
    $assertoff(0, "tb.dut");

    do_end_addr_check = 0;
    fork
      begin
        super.body();
      end
      begin
        bit [31:0] err_val = 32'd1 << 20;
        string prng_path = "tb.dut.u_acc_core.u_acc_rnd.u_xoshiro256pp.xoshiro_q";

        cfg.clk_rst_vif.wait_clks($urandom_range(10, 1000));
        `DV_CHECK_FATAL(uvm_hdl_force(prng_path, 'b0) == 1);
        `uvm_info(`gfn,"injecting zero state error into ISS", UVM_HIGH)
        cfg.model_agent_cfg.vif.send_err_escalation(err_val);
        cfg.clk_rst_vif.wait_clks(1);
        cfg.model_agent_cfg.vif.acc_set_no_sec_wipe_chk();
        `DV_CHECK_FATAL(uvm_hdl_release(prng_path) == 1);
        `uvm_info(`gfn,"string released", UVM_HIGH)
        wait (cfg.model_agent_cfg.vif.status == acc_pkg::StatusLocked);
        reset_if_locked();
      end
    join

  endtask : body

endclass : acc_zero_state_err_urnd_vseq
