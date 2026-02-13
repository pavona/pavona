// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A sequence that injects a spurious acknowledge to URND requests.

class acc_urnd_err_vseq extends acc_base_vseq;
  `uvm_object_utils(acc_urnd_err_vseq)

  `uvm_object_new

  task body();
    // Inject error on signal after `prim_edn_req`, which may at some point implement its own
    // countermeasure against spurious ACKs.
    string err_path = "tb.dut.edn_urnd_ack";
    bit skip_err_injection = 1'b0;
    bit while_executing;

    // Wait for deassertion of reset.
    cfg.clk_rst_vif.wait_for_reset(.wait_negedge(1'b0), .wait_posedge(1'b1));

    `DV_CHECK_STD_RANDOMIZE_FATAL(while_executing)

    if (while_executing) begin
      // Inject spurious URND acknowledge while ACC is executing.

      // The ACC controller requests a secure wipe from the start-stop controller at the end of
      // execution.  To reach that point, we must first execute a binary.
      string elf_path = pick_elf_path();
      load_elf(elf_path, 1'b1);
      `uvm_info(`gfn, $sformatf("Executing ACC binary `%0s'.", elf_path), UVM_LOW)
      start_running_acc(.check_end_addr(1'b0));

      if (!(cfg.model_agent_cfg.vif.status inside {acc_pkg::StatusBusyExecute,
                                                   acc_pkg::StatusBusySecWipeInt})) begin
        // If ACC is no longer executing, we have missed the opportunity (the
        // `start_running_acc()` function does not guarantee that it returns while ACC is still
        // running).  So we cannot inject the error anymore.
        skip_err_injection = 1'b1;
      end else begin
        // ACC does an URND request when it starts executing as well as between secure wipes.  We
        // must wait for that request to complete before we can inject a spurious acknowledge.
        logic urnd_req;
        string path = "tb.dut.edn_urnd_req";
        `DV_SPINWAIT(
          do begin
            @(cfg.clk_rst_vif.cbn); // Align to clock.
            `DV_CHECK_FATAL(uvm_hdl_read(path, urnd_req))
          end while (urnd_req);,
          "Timeout while waiting for URND request",
          100_000_000 /* timeout in ns */)
      end

      if (skip_err_injection) begin
        `uvm_info(`gfn, "Skipping error injection.", UVM_LOW)
      end else begin
        // Inject error.
        `uvm_info(`gfn, "Injecting error by force.", UVM_LOW)
        `DV_CHECK_FATAL(uvm_hdl_force(err_path, 1'b1) == 1)
        `uvm_info(`gfn, "Locking model immediately.", UVM_LOW)
        cfg.model_agent_cfg.vif.lock_immediately(32'd1 << 20);

        // Wait one clock cycle to have force applied during one cycle.
        @(cfg.clk_rst_vif.cbn);
      end

    end else begin
      // Inject spurious URND acknowledge while ACC is idle.
      `DV_WAIT(cfg.model_agent_cfg.vif.status == acc_pkg::StatusIdle)
      @(cfg.clk_rst_vif.cbn);

      if (skip_err_injection) begin
        `uvm_info(`gfn, "Skipping error injection.", UVM_LOW)
      end else begin
        // Inject error.
        `uvm_info(`gfn, "Injecting error by force.", UVM_LOW)
        `DV_CHECK_FATAL(uvm_hdl_force(err_path, 1'b1) == 1)

        // Let model escalate in same clock cycle.
        cfg.model_agent_cfg.vif.send_err_escalation(32'd1 << 20);

        // Wait one clock cycle to have force applied during one cycle.
        @(cfg.clk_rst_vif.cbn);
      end
    end

    if (!skip_err_injection) begin
      `uvm_info(`gfn, "Releasing force.", UVM_LOW)
      `DV_CHECK_FATAL(uvm_hdl_release(err_path) == 1)

      `uvm_info(`gfn, "Waiting for ACC to lock up.", UVM_LOW)
      `DV_WAIT(cfg.model_agent_cfg.vif.status == acc_pkg::StatusLocked)
    end

    reset_if_locked();
  endtask

endclass
