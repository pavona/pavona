// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide (64-bit) TileLink sequence item for the DMA host64 SoC System port. Extends
// `tl_seq_item` (so it stays API-compatible with the tl_seq_item-typed env) and adds
// the full 64-bit address (parent `a_addr` is only 32-bit) and the wide command-integrity
// field. The low 32 bits of the address stay mirrored into the parent `a_addr`.
class dma_tl_seq_item extends tl_seq_item;

  // Full 64-bit A-channel address (the parent `a_addr` only holds the low `BUS_AW` bits).
  rand bit [dma_tlul_pkg::DmaTlAw-1:0]              a_addr_full;

  // Command-integrity bits carried in the wide `a_user.cmd_intg` field.
  rand bit [dma_tlul_pkg::DmaH2DCmdIntgWidth-1:0]   a_cmd_intg;

  `uvm_object_utils_begin(dma_tl_seq_item)
    `uvm_field_int(a_addr_full, UVM_DEFAULT)
    `uvm_field_int(a_cmd_intg,  UVM_DEFAULT)
  `uvm_object_utils_end

  `uvm_object_new

  // Extend parent's disable to also cover the wide address and command-integrity fields,
  // which would otherwise be re-randomized when `randomize_rsp` prepares the response.
  virtual function void disable_a_chan_randomization();
    super.disable_a_chan_randomization();
    a_addr_full.rand_mode(0);
    a_cmd_intg.rand_mode(0);
  endfunction

  // Set the full address, keeping the parent 32-bit `a_addr` mirrored to its low bits.
  function void set_a_addr_full(bit [dma_tlul_pkg::DmaTlAw-1:0] addr);
    a_addr_full = addr;
    a_addr      = addr[AddrWidth-1:0];
  endfunction

  // Return the full 64-bit address.
  function bit [dma_tlul_pkg::DmaTlAw-1:0] get_a_addr_full();
    return a_addr_full;
  endfunction

  virtual function string convert2string();
    string str = super.convert2string();
    str = {str, $sformatf("a_addr_full = 0x%0h ", a_addr_full),
                $sformatf("a_cmd_intg = 0x%0h ", a_cmd_intg)};
    return str;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    dma_tl_seq_item rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer)         &&
            (a_addr_full == rhs_.a_addr_full)       &&
            (a_cmd_intg  == rhs_.a_cmd_intg));
  endfunction

endclass : dma_tl_seq_item
