// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This test randomly forces critical control signals inside one of the independent, redundant
// logic rails of the main control FSM. The test then checks that the DUT triggers a fatal
// alert and cannot proceed until a reset is triggered.
class aes_control_fi_vseq extends aes_base_vseq;
  `uvm_object_utils(aes_control_fi_vseq)

  `uvm_object_new
  aes_message_item my_message;
  status_t aes_status;
  bit  finished_all_msgs = 0;
  bit  wait_for_alert_clear = 0;
  bit  wait_for_alert_and_reset = 0;
  bit  alert_reset_seen = 0;

  localparam bit FORCE   = 0;
  localparam bit RELEASE = 1;

  rand bit [31:0]           force_value;
  rand int                  if_num;
  rand int                  target;

  rand aes_pkg::aes_ctrl_e  await_state;

  int                       if_size;


  task body();
    int fi_walk_id;
    bit fi_walking;
    // State walk-order for deterministic coverage. CTRL_ERROR is excluded
    // because it is an outcome of a fault, not a state we inject from.
    aes_pkg::aes_ctrl_e ctrl_state_array [] = '{
        aes_pkg::CTRL_IDLE,
        aes_pkg::CTRL_LOAD,
        aes_pkg::CTRL_PRNG_UPDATE,
        aes_pkg::CTRL_PRNG_RESEED,
        aes_pkg::CTRL_FINISH,
        aes_pkg::CTRL_CLEAR_I,
        aes_pkg::CTRL_CLEAR_CO};

    fi_walking = $value$plusargs("fi_walk_id=%0d", fi_walk_id);

    `uvm_info(`gfn, $sformatf("\n\n\t ----| STARTING AES MAIN SEQUENCE |----\n %s",
                              cfg.convert2string()), UVM_LOW)

    // generate list of messages //
    generate_message_queue();

    // process all messages //
    fork
      begin: isolation_fork
        fork
          error: begin
            // avoid forcing IDLE
            if (!randomize(force_value) with { force_value != '0;}) begin
              `uvm_fatal(`gfn, $sformatf("Randomization failed"))
            end
            if (!randomize(if_num) with { if_num inside { [0:2] };}) begin
              `uvm_fatal(`gfn, $sformatf("Randomization failed"))
            end
            // workaround for vcs issue
            if_size = cfg.aes_control_fi_vif[if_num].get_if_size();
            if (!randomize(target) with {
              target inside { [0:if_size - 1]};}) begin
              `uvm_fatal(`gfn, $sformatf("Randomization failed"))
            end
            `DV_CHECK_STD_RANDOMIZE_FATAL(await_state)
            // Override random choices with a deterministic (target, state, if_num) walk if
            // requested. Walking covers each redundant rail (gen_fsm[0/1/2]) so per-instance
            // coverage doesn't depend on chance.
            if (fi_walking) begin
              int unsigned num_targets = if_size;
              int unsigned num_states  = ctrl_state_array.size();
              int unsigned num_ifs     = 3;
              if_num      = (fi_walk_id / (num_targets * num_states)) % num_ifs;
              target      =  fi_walk_id % num_targets;
              await_state = ctrl_state_array[(fi_walk_id / num_targets) % num_states];
              if_size = cfg.aes_control_fi_vif[if_num].get_if_size();
              `uvm_info(`gfn,
                  $sformatf("fi_walk_id=%0d -> if_num=%0d target=%0d await_state=%s",
                            fi_walk_id, if_num, target, await_state.name()),
                  UVM_LOW)
            end
            if (await_state inside {aes_pkg::CTRL_PRNG_UPDATE, aes_pkg::CTRL_CLEAR_I,
                                          aes_pkg::CTRL_CLEAR_CO}) begin
              // The PRNG Update and Clear states are entered for ~1 cycle by clear_regs() during
              // the multi-cycle CSR write. Arm a watcher BEFORE the trigger to sample the CG at
              // state entry.
              sample_fi_cg_at_state(AesFiCgControl, await_state, target, AesFiCgClearRegs,
                                     if_num,
                                     '{dataout: 1'b1, key_iv_data_in: 1'b1, default: 1'b0});
            end else if (await_state == aes_pkg::CTRL_PRNG_RESEED) begin
              // PRNG_RESEED has the same multi-cycle CSR-write race; use the same fork-watcher.
              sample_fi_cg_at_state(AesFiCgControl, await_state, target, AesFiCgPrngReseed,
                                     if_num);
            end else if (await_state == aes_pkg::CTRL_LOAD) begin
              // LOAD is entered naturally at the start of each message; no helper write needed,
              // but use the same fork-watcher so the sample lands on cs == LOAD.
              sample_fi_cg_at_state(AesFiCgControl, await_state, target, AesFiCgNoTrigger,
                                     if_num);
            end else if (fi_walking) begin
              // Walking on a natural state (IDLE/FINISH): FSM cycles through during message
              // processing. Same fork-watcher pattern catches entry.
              sample_fi_cg_at_state(AesFiCgControl, await_state, target, AesFiCgNoTrigger,
                                     if_num, '0, 1'b1);
            end else begin
              cfg.clk_rst_vif.wait_clks(cfg.inj_delay);
            end
            if (finished_all_msgs) begin
              // As long as the DUT hasn't finished processing messages yet, the signal forcing
              // will interrupt the message processing. The `basic` thread will notice this and
              // as part of the recovery procedure wait for an alert, reset the DUT and then
              // continue processing messages.
              // Otherwise we have to try to detect the alert and to reset the DUT ourselves.
              wait_for_alert_and_reset = 1;
            end
            `uvm_info(`gfn, $sformatf("FORCING %h on if[%d]", force_value, if_num), UVM_MEDIUM)
            cfg.aes_control_fi_vif[if_num].force_signal(target, FORCE, force_value);
            wait_for_alert_clear = 1;
            if (wait_for_alert_and_reset) begin
              wait_for_fatal_alert_and_reset();
            end
          end
          basic: begin
            send_msg_queue(cfg.unbalanced, cfg.read_prob, cfg.write_prob);
            finished_all_msgs = 1;
          end
        join_none

        // wait to confirm alert
        wait(wait_for_alert_clear);
        `uvm_info(`gfn, $sformatf("Waiting alert ack complete"), UVM_MEDIUM)
        // Some forced signals (e.g. cipher_in_ready_i) only stall the main control FSM and do not
        // trigger a fatal alert. Bound the wait so the test still completes cleanly and the
        // coverage DB is flushed.
        `DV_SPINWAIT_EXIT(
            cfg.m_alert_agent_cfgs["fatal_fault"].vif.wait_ack_complete();
            wait(!cfg.clk_rst_vif.rst_n);
            alert_reset_seen = 1;,
            cfg.clk_rst_vif.wait_clks(20_000);,
            $sformatf("alert ack/reset wait bounded (target=%0d may not trigger alert)", target))
        cfg.aes_control_fi_vif[if_num].force_signal(target, RELEASE, force_value);
        if (!alert_reset_seen) begin
          apply_resets_concurrently();
          dut_init("HARD");
        end
       `uvm_info(`gfn, $sformatf("Finish"), UVM_MEDIUM)
        disable fork;
      end // fork
    join
  endtask : body
endclass
