// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// smoke test vseq to walk through DAI states and request keys

// Digest markers can be zeroized, but the zeroization marker should be written to only when the
// partition is designated to be zeroized.
// The last 8 bytes or any partition is the zeroizable marker, hence ignore it when generating legal
// addresses to zeroize.
`define PART_CONTENT_RANGE_ZER(i) \
    {[PartInfo[``i``].offset: PartInfo[``i``+1].offset - 9]}
`define PART_CONTENT_RANGE(i) \
    {[PartInfo[``i``].offset: PartInfo[``i``+1].offset - 1]}

class otp_ctrl_zeroization_vseq extends otp_ctrl_smoke_vseq;
  `uvm_object_utils(otp_ctrl_zeroization_vseq)
  `uvm_object_new

  rand bit set_dai_regwen;
  rand bit enable_trigger_checks;

  bit dut_init_completed;
  bit trigger_routine_exit;

  constraint regwens_c {
    set_dai_regwen dist {0 :/ 8, 1 :/ 2};
  }

  constraint trigger_checks_c {
    enable_trigger_checks == 0;
  }

  constraint intr_enable_c {
    // intr_operation_done prediction in the model needs to be revisited
    // for now disabling operation_done checks with zeroization and enabling only otp_error
    en_intr == 2'b10;
  }

  constraint num_trans_c {
    num_trans  == 1;
    num_dai_op inside {[1:10]};
  }

  constraint partition_index_c {
    part_idx inside {
      VendorTestIdx,
      CreatorSwCfgIdx,
      OwnerSwCfgIdx,
      RotCreatorAuthCodesignIdx,
      RotCreatorAuthStateIdx,
      HwCfg0Idx,
      HwCfg1Idx,
      Secret0Idx,
      Secret1Idx,
      Secret2Idx
    };
  }

  constraint dai_wr_legal_addr_c {
    if (part_idx == VendorTestIdx)
        dai_addr inside `PART_CONTENT_RANGE(VendorTestIdx);
    if (part_idx == CreatorSwCfgIdx)
        dai_addr inside `PART_CONTENT_RANGE(CreatorSwCfgIdx);
    if (part_idx == OwnerSwCfgIdx)
        dai_addr inside `PART_CONTENT_RANGE(OwnerSwCfgIdx);
    if (part_idx == RotCreatorAuthCodesignIdx)
        dai_addr inside `PART_CONTENT_RANGE(RotCreatorAuthCodesignIdx);
    if (part_idx == RotCreatorAuthStateIdx)
        dai_addr inside `PART_CONTENT_RANGE(RotCreatorAuthStateIdx);
    if (part_idx == HwCfg0Idx)
        dai_addr inside `PART_CONTENT_RANGE(HwCfg0Idx);
    if (part_idx == HwCfg1Idx)
        dai_addr inside `PART_CONTENT_RANGE(HwCfg1Idx);
    if (part_idx == Secret0Idx)
        dai_addr inside `PART_CONTENT_RANGE(Secret0Idx);
    if (part_idx == Secret1Idx)
        dai_addr inside `PART_CONTENT_RANGE(Secret1Idx);
    if (part_idx == Secret2Idx)
        dai_addr inside `PART_CONTENT_RANGE(Secret2Idx);
    solve part_idx before dai_addr;
  }
`undef PART_CONTENT_RANGE
`undef PART_CONTENT_RANGE_ZER


  task body();
    bit [TL_DW-1:0] reg_rd_val, rdata0, rdata1, rdata0_pre, rdata1_pre;
    bit [TL_DW-1:0] addr;

    bit zeroized_partition [0:LifeCycleIdx-1];
    bit used_zeroized_addrs[bit [TL_DW-1:0]];

    bit dai_regwen_state = 1;

    for (int i = 0; i < NumPart; i++) begin
      part_idx = i;
      `uvm_info(`gfn, $sformatf("part_idx :%s, addr offset :%x",
                                 part_idx.name, PartInfo[i].offset), UVM_LOW);
    end

    // Adding a mechanism to ignore dai_idle checks in main smoke part of the test.
    ignore_dai_idle_check = 1;

    super.body();
    isr_present           = 1;

    this.rand_mode(0);
    this.dai_addr.rand_mode(1);
    this.part_idx.rand_mode(1);

    dut_init_completed = 0;
    trigger_routine_exit = 0;

    fork
      intr_service_routine();
      check_trigger_routine();
    join_none
    #0 // Force the fork processes to have started

    for (int i = 0; i < num_dai_op; i++) begin
      // Now randomize the partitions and address to zeroize
      `DV_CHECK_RANDOMIZE_FATAL(this)

      // First check if the partition zeroizable marker is set for the partition that contains the
      // DAI address that was generated in the randomize method above.
      // If the marker is not set, first set the marker before zeroizing the address location.
      if (!part_is_zeroizable(part_idx)) begin
        `uvm_info(`gfn, $sformatf("ZRing Non Zeroizable Partition: part_idx :%s, dai_addr :%x",
                part_idx.name, dai_addr), UVM_LOW);
        dai_zeroize(.addr(dai_addr));
      end else begin
        if (!zeroized_partition[part_idx]) begin
          `uvm_info(`gfn, $sformatf("ZRing Partition: part_idx :%s, dai_addr :%x",
                  part_idx.name, zeroized_offset(part_idx)), UVM_LOW);
          dai_zeroize(.addr(zeroized_offset(part_idx)));
          zeroized_partition[part_idx] = 1;
          dai_rd(.addr(zeroized_offset(part_idx)), .rdata0(rdata0), .rdata1(rdata1),
                 .skip_idle_check(1));
        end

        if (used_zeroized_addrs.exists(dai_addr)) begin
          `uvm_info(`gfn, $sformatf("addr %0h is already written!", addr), UVM_MEDIUM)
          continue;
        end

        if (set_dai_regwen && dai_regwen_state) begin
          csr_rd(ral.direct_access_regwen, reg_rd_val);
          `uvm_info(`gfn, $sformatf("Setting DAI Regwen to zero - Locking DAI"), UVM_LOW);
          dai_regwen_state = 0;
          csr_wr(ral.direct_access_regwen, dai_regwen_state);
        end

        `uvm_info(`gfn, $sformatf("ZRing(Pre): part_idx :%s, dai_addr :%x",
                   part_idx.name, dai_addr), UVM_LOW);
        dai_zeroize(.addr(dai_addr));
        used_zeroized_addrs[dai_addr] = 1;

        // Once Zeroization command completes, if zerorization is successful rdata0 should return the
        // count of ones in the bits updated depending on the granule size, and rdata1 should
        // return 0
        csr_rd(ral.direct_access_rdata[0], rdata0);
        if (is_granule_64(dai_addr))
          csr_rd(ral.direct_access_rdata[1], rdata1);

        `uvm_info(`gfn, $sformatf("ZRing(Post): part_idx :%s, dai_addr :%x, rdata0:%x, rdata1:%x",
                  part_idx.name, dai_addr, rdata0, rdata1), UVM_LOW);
      end
    end

    `uvm_info(`gfn, "Reseting OTP - Zeroization State should be saved", UVM_LOW);
    do_otp_ctrl_init = 0;
    dut_init();
    dut_init_completed = 1;

    // dut_init() also sets interrupt enables. For this sequence otp_operation_done is disabled as
    // we are expliciting testing otp_error.

    // TODO: #80 (zerorisc/expo)
    // However the prediction model for otp_operation_done
    // does need a revisit to make sure the interrupt state registers are set at the time the RTL
    // also sets the same register and not the current way the model is coded

    foreach (used_zeroized_addrs[addr]) begin
      `uvm_info(`gfn, $sformatf("Reading back ZRed Addr: %x", addr), UVM_LOW);
      dai_rd(.addr(addr), .rdata0(rdata0), .rdata1(rdata1), .skip_idle_check(1));
    end

    trigger_routine_exit = 1;
  endtask : body

  // This is an interrupt service routine that waits for interrupt and clears the following
  // Registers
  // - INTR
  // - STATUS
  // - ERROR CODE
  task intr_service_routine();
    bit [DataWidth-1:0] intr_enable;
    bit [DataWidth-1:0] csr_rd_value;

    `uvm_info(`gfn, $sformatf("intr_service_routine - Starting"), UVM_LOW);
    wait (cfg.under_reset == 0);

    `uvm_info(`gfn, $sformatf("(ISR) Starting foreverloop for Reset / Interrupt"), UVM_LOW);

    forever begin
      @ (posedge cfg.under_reset or posedge cfg.intr_vif.pins[1]) begin
        if (cfg.under_reset) begin
          `uvm_info(`gfn, $sformatf("(ISR)- Reset Seen"), UVM_LOW);
          // Reset has been triggered, wait until OTP is initialized
          wait (cfg.under_reset == 0);
          wait (cfg.otp_ctrl_vif.pwr_otp_done_o == 1'b1);
          wait (dut_init_completed == 1);

          `uvm_info(`gfn, $sformatf("(ISR) DUT Init Complete-Starting wait for Interrrupt"), UVM_LOW);
          dut_init_completed = 0;
        end else if (cfg.intr_vif.pins[1] == 1'b1) begin
          `uvm_info(`gfn, $sformatf("(ISR)- OTP Error Interrupt Seen"), UVM_LOW);
          csr_rd(ral.intr_state, csr_rd_value);

          csr_rd(ral.status, csr_rd_value);
          csr_rd(ral.err_code[OtpDaiErrIdx], csr_rd_value);
        end
      end
    end
  endtask : intr_service_routine

  task check_trigger_routine();

    if (!enable_trigger_checks) begin
      `uvm_info(`gfn, $sformatf("check_trigger_routine - disabled"), UVM_LOW);
      return;
    end

    `uvm_info(`gfn, $sformatf("check_trigger_routine - Starting"), UVM_LOW);

    forever begin
      if (trigger_routine_exit) break;

      cfg.clk_rst_vif.wait_clks($urandom_range(10, 50));
      if (cfg.under_reset) begin
        `uvm_info(`gfn, $sformatf("(CTR) - In Reset, Wait until Otp Init is done"), UVM_LOW);
        wait (cfg.under_reset == 0);
        wait (cfg.otp_ctrl_vif.pwr_otp_done_o == 1);
      end

      `uvm_info(`gfn, $sformatf("(CTR) - Starting Threads"), UVM_MEDIUM);
      fork
        begin : Thread1
          `uvm_info(`gfn, $sformatf("(CTR)- Triggering Checks"), UVM_HIGH);
          trigger_checks(.val(check_trigger_val), .wait_done(1), .wait_backdoor(1));
          `uvm_info(`gfn, $sformatf("(CTR)- Checks Completed"), UVM_HIGH);
        end : Thread1
        begin : Thread2
            wait (cfg.under_reset);
            `uvm_info(`gfn, $sformatf("(CTR)- Reset Seen"), UVM_LOW);
        end : Thread2
      join_any
      disable fork;

      `uvm_info(`gfn, $sformatf("(CTR) - Threads Disabled"), UVM_MEDIUM);
    end
  endtask : check_trigger_routine

endclass : otp_ctrl_zeroization_vseq
