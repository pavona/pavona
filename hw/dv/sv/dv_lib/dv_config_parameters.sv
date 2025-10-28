// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class dv_config_parameters extends uvm_sequence_item;
  typedef enum {DISABLE=0, ENABLE} ENABLE_TYPE;


  `uvm_object_utils_begin (dv_config_parameters)
  `uvm_object_utils_end

  function new(string name = "");
  endfunction : new


  constraint additional {
      // Constraints for Test that are to be spcified in the
      // derived class
  }
endclass : dv_config_parameters
