// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Random vseq: unlocks the policy / key-version-error / OTP-randomization knobs
// that keymgr_dpe_smoke_vseq pins, and chains randomized advance / generate / erase
// operations across all slots.
//
// Coverage targets unlocked relative to smoke:
//   - state_and_op_cg.op_status_cp::OpDoneFail (allow_child=0 leaf-advance failures)
//   - key_version_compare_cg::CompareOpGt
//   - err_code_cg::ErrInvalidIn / ErrInvalidOp
//   - retain_parent=0 self-overwrite path
//   - exportable=1 paths (visibility depends on the policy_cg added later)
class keymgr_dpe_random_vseq extends keymgr_dpe_base_vseq;
  `uvm_object_utils(keymgr_dpe_random_vseq)
  `uvm_object_new

  rand int unsigned num_iters;

  constraint num_iters_c {
    num_iters inside {[20:40]};
  }

  // Override base: weighted to favor good ops (so chains progress) while still hitting
  // the >max_key_version path with non-trivial probability.
  constraint is_key_version_err_c {
    is_key_version_err dist {0 :/ 4, 1 :/ 1};
  }

  // Override base: randomize OTP key data so sw_input_cg_wrap bins covering
  // OTP-derived inputs get exercised. The fully-invalid OTP root path is owned
  // by keymgr_dpe_hwsw_invalid_input_vseq, so leave do_invalid_otp_key off here.
  constraint otp_key_c {
    do_rand_otp_key dist {0 :/ 1, 1 :/ 3};
    do_invalid_otp_key == 0;
  }

  // Randomize all three policy bits each iteration. Bias allow_child toward 1 so
  // advance chains can make progress; both other bits are uniform.
  constraint set_policy_c {
    policy.allow_child   dist {1 :/ 4, 0 :/ 1};
    policy.retain_parent dist {0 :/ 1, 1 :/ 1};
    policy.exportable    dist {0 :/ 1, 1 :/ 1};
  }

  // Shuffle-and-write all sw_binding/salt CSR instances plus max_key_ver_shadowed
  // and (occasionally) reseed_interval_shadowed. Drives the per-instance score on
  // sw_input_cg_wrap (only index 0 is exercised by the base advance/generate tasks)
  // and fills the missing reseed_interval_cg bins. Modelled on
  // keymgr_random_vseq::write_random_sw_content.
  virtual task write_random_sw_content();
    uvm_reg csr_q[$];
    foreach (ral.sw_binding[i]) begin
      `DV_CHECK_RANDOMIZE_FATAL(ral.sw_binding[i])
      csr_q.push_back(ral.sw_binding[i]);
    end
    foreach (ral.salt[i]) begin
      `DV_CHECK_RANDOMIZE_FATAL(ral.salt[i])
      csr_q.push_back(ral.salt[i]);
    end
    `DV_CHECK_RANDOMIZE_FATAL(ral.max_key_ver_shadowed)
    csr_q.push_back(ral.max_key_ver_shadowed);
    // The base keymgr_dpe_generate's update_key_version constrains key_version[0]
    // relative to max_key_ver (typically 0-4), so the upper bits never toggle.
    // Drive a full 32-bit random value here so sw_input_cg_wrap["key_version_0"]
    // per-instance can climb past its constrained-value ceiling.
    foreach (ral.key_version[i]) begin
      `DV_CHECK_RANDOMIZE_FATAL(ral.key_version[i])
      csr_q.push_back(ral.key_version[i]);
    end
    csr_q.shuffle();
    foreach (csr_q[i]) csr_update(csr_q[i]);
    // Note: reseed_interval_shadowed is intentionally not rewritten here. Doing so
    // mid-test trips keymgr_dpe_if.CheckEdn1stReq because the interval reference the
    // SVA compares against changes while the EDN request counter is mid-window. The
    // existing init flow sets a randomized reseed_interval per simulation, which is
    // enough to reach 37/37 in reseed_interval_cg.
  endtask : write_random_sw_content

  task body();
    `uvm_info(`gfn, $sformatf("keymgr_dpe_random_vseq start, num_iters=%0d",
                              num_iters), UVM_LOW)

    // Initial OTP latch into slot 0. Must succeed, so force a permissive policy and
    // src==dst for this single advance regardless of the class-level constraints.
    src_slot = 0;
    dst_slot = 0;
    policy.allow_child   = 1'b1;
    policy.retain_parent = 1'b1;
    policy.exportable    = 1'b0;
    keymgr_dpe_advance();
    otp_latched = 1'b1;

    // Random op loop. Each iteration re-randomizes policy, key-version-error, slots,
    // gen-op type and key destination, then issues a weighted-random op. Disable is
    // excluded: once the DUT is disabled, further ops are no-ops, which would make
    // the rest of the iteration count uninteresting.
    repeat (num_iters) begin
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(policy)
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(is_key_version_err)
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(src_slot)
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(dst_slot)
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(gen_operation)
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(key_dest)

      // ~1/3 of iterations rewrite all sw_binding/salt indices and max_key_ver so
      // sw_input_cg_wrap per-instance scores climb beyond their base ~10%.
      if ($urandom_range(0, 2) == 0) write_random_sw_content();

      randcase
        4: keymgr_dpe_advance();
        4: begin
             update_key_version();
             keymgr_dpe_generate(.operation(gen_operation), .key_dest(key_dest));
             if ($urandom_range(0, 1)) keymgr_dpe_rd_clr();
           end
        1: begin
             // keymgr_dpe_erase issues an erase against dst_slot, then chains
             // num_adv_op / num_gen_op follow-ups. Keep those at 0 here so the loop
             // controls the op mix directly.
             keymgr_dpe_erase(.num_gen_op(0), .num_adv_op(0));
           end
      endcase
    end

    // Optionally end with disable so the disabled-state covergroup bins are also
    // exercised within this single test.
    if ($urandom_range(0, 1)) begin
      keymgr_dpe_disable(.num_gen_op($urandom_range(0, 2)),
                         .num_adv_op($urandom_range(0, 2)));
    end

    `uvm_info(`gfn, "keymgr_dpe_random_vseq done", UVM_LOW)
  endtask : body

endclass : keymgr_dpe_random_vseq
