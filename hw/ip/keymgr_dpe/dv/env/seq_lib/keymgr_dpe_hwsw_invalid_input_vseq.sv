// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Drives HW invalid inputs (OTP root invalid, keymgr_dpe_div all-0s/all-1s,
// otp_device_id all-0s/all-1s, rom_digest data/valid corruption) interleaved with
// a randomised op stream. Targets:
//  - invalid_hw_input_cg (OtpRootKeyInvalid, LcStateInvalid, OtpDevIdInvalid,
//    RomDigestInvalid, RomDigestValidLow, OtpRootKeyValidLow)
//  - err_code_cg::ErrInvalidIn (via key_version > max_key_version)
//  - state_and_op_cg.op_status_cp::OpDoneFail
// Ported from keymgr_hwsw_invalid_input_vseq.
class keymgr_dpe_hwsw_invalid_input_vseq extends keymgr_dpe_random_vseq;
  `uvm_object_utils(keymgr_dpe_hwsw_invalid_input_vseq)
  `uvm_object_new

  rand uint num_invalid_hw_input;

  // 0/1/many invalid inputs each in roughly equal weight; 0 lets some ops succeed
  // so the test still progresses.
  constraint num_invalid_hw_input_c {
    num_invalid_hw_input dist {0     :/ 1,
                               1     :/ 1,
                               [2:6] :/ 1};
  }

  // Override the random_vseq's otp_key_c which pinned do_invalid_otp_key to 0.
  // Allow the OTP root path to be exercised invalid too.
  constraint otp_key_c {
    do_rand_otp_key      dist {0 :/ 1, 1 :/ 3};
    do_invalid_otp_key   dist {0 :/ 3, 1 :/ 1};
  }

  // SCB checks the err paths; don't double-check from the seq.
  virtual function bit get_check_en();
    return 0;
  endfunction

  // Override keymgr_dpe_advance to drive a fresh bad-input set roughly every other
  // call. The base random_vseq drives advance/generate/erase directly (it doesn't
  // route through keymgr_dpe_operations), so this is the central hook that catches
  // both the OTP latch advance and the iteration advances.
  virtual task keymgr_dpe_advance(bit wait_done = 1,
                                  int sw_binding = $urandom(),
                                  int max_key_ver = $urandom_range(0,4));
    if ($urandom_range(0, 1)) begin
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(num_invalid_hw_input)
      `uvm_info(`gfn, $sformatf("Drive random HW data with %0d invalid inputs",
                                num_invalid_hw_input), UVM_MEDIUM)
      cfg.keymgr_dpe_vif.drive_random_hw_input_data(num_invalid_hw_input);
    end
    super.keymgr_dpe_advance(wait_done, sw_binding, max_key_ver);
  endtask : keymgr_dpe_advance

  task body();
    // Invalid HW inputs cause the design to feed random data on the KMAC interface,
    // which can produce constantly-changing data on a stalled valid-not-ready beat.
    $assertoff(0, "tb.keymgr_dpe_kmac_intf.req_data_if.H_DataStableWhenValidAndNotReady_A");
    super.body();
  endtask : body

endclass : keymgr_dpe_hwsw_invalid_input_vseq
