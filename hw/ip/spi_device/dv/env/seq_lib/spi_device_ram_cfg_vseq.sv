// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Randomly set the dut ram_cfg inputs and check the values are propagated to the memories inside
// u_spid_dpram. In 1r1w mode each memory has its own cfg input, so both are driven with independent
// values to also catch a swap or a tie-off of either input.
class spi_device_ram_cfg_vseq extends spi_device_base_vseq;
  `uvm_object_utils(spi_device_ram_cfg_vseq)
  `uvm_object_new

  virtual task body();
    prim_ram_2p_pkg::ram_2p_cfg_t sys2spi_ram_cfg, spi2sys_ram_cfg;
    prim_ram_2p_pkg::ram_2p_cfg_t dst_ram_cfg, egress_ram_cfg, ingress_ram_cfg;
    string sys2spi_src_path = "tb.dut.ram_cfg_sys2spi_i";
    string spi2sys_src_path = "tb.dut.ram_cfg_spi2sys_i";
    string dst_path         = "tb.dut.u_spid_dpram.gen_ram2p.u_memory_2p.u_mem.cfg_i";
    string egress_path      = "tb.dut.u_spid_dpram.gen_ram1r1w.u_sys2spi_mem.u_mem.cfg_i";
    string ingress_path     = "tb.dut.u_spid_dpram.gen_ram1r1w.u_spi2sys_mem.u_mem.cfg_i";

    repeat (100) begin
      // The 2p memory only uses the sys2spi input, so spi2sys is left alone in that mode.
      `DV_CHECK_STD_RANDOMIZE_FATAL(sys2spi_ram_cfg)
      `DV_CHECK(uvm_hdl_deposit(sys2spi_src_path, sys2spi_ram_cfg))
      if (`SRAM_TYPE == spi_device_pkg::SramType1r1w) begin
        `DV_CHECK_STD_RANDOMIZE_FATAL(spi2sys_ram_cfg)
        `DV_CHECK(uvm_hdl_deposit(spi2sys_src_path, spi2sys_ram_cfg))
      end
      #($urandom_range(1, 100) * 1ns);
      if (`SRAM_TYPE == spi_device_pkg::SramType2p) begin
        `DV_CHECK(uvm_hdl_read(dst_path, dst_ram_cfg))
        `DV_CHECK_CASE_EQ(sys2spi_ram_cfg, dst_ram_cfg)
      end else begin // 1r1w
        `DV_CHECK(uvm_hdl_read(egress_path, egress_ram_cfg))
        `DV_CHECK_CASE_EQ(sys2spi_ram_cfg, egress_ram_cfg)
        `DV_CHECK(uvm_hdl_read(ingress_path, ingress_ram_cfg))
        `DV_CHECK_CASE_EQ(spi2sys_ram_cfg, ingress_ram_cfg)
      end
    end
  endtask
endclass : spi_device_ram_cfg_vseq
