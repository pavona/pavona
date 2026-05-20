// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


class otp_ctrl_zeroization_with_checks_vseq extends otp_ctrl_zeroization_vseq;
  `uvm_object_utils(otp_ctrl_zeroization_with_checks_vseq)
  `uvm_object_new


  constraint trigger_checks_c {
    enable_trigger_checks == 1;
  }

  constraint num_trans_c {
    num_trans  == 1;
    num_dai_op inside {[1:10]};
  }

endclass : otp_ctrl_zeroization_with_checks_vseq
