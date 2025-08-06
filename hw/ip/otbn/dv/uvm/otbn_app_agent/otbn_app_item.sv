// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otbn_app_item extends kmac_app_item;

  // request msg
  rand bit                          req_valid;
  rand bit                          req_hold;
  rand bit                          req_next;
  rand bit [kmac_pkg::MsgWidth-1:0] req_data;
  rand bit [kmac_pkg::MsgStrbW-1:0] req_strb;
  rand bit                          req_last;
  rand bit                          rsp_done;
  rand bit                          rsp_ready;
  rand bit                          drive_rsp_ready;
  rand int unsigned                 rsp_ready_delay;

  `uvm_object_utils_begin(otbn_app_item)
    `uvm_field_int(req_valid,         UVM_DEFAULT)
    `uvm_field_int(req_hold,          UVM_DEFAULT)
    `uvm_field_int(req_next,          UVM_DEFAULT)
    `uvm_field_int(req_data,          UVM_DEFAULT)
    `uvm_field_int(req_strb,          UVM_DEFAULT)
    `uvm_field_int(req_last,          UVM_DEFAULT)
    `uvm_field_int(rsp_done,          UVM_DEFAULT)
    `uvm_field_int(rsp_ready,         UVM_DEFAULT)
    `uvm_field_int(drive_rsp_ready,   UVM_DEFAULT)
    `uvm_field_int(rsp_ready_delay,   UVM_DEFAULT)
  `uvm_object_utils_end

  `uvm_object_new
endclass
