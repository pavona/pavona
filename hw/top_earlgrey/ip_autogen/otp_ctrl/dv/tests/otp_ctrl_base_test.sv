// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otp_ctrl_base_test #(
    type CFG_T = otp_ctrl_env_cfg,
    type ENV_T = otp_ctrl_env
  ) extends cip_base_test #(
    .CFG_T(CFG_T),
    .ENV_T(ENV_T)
  );

  // A prototype for the registry to associate the parameterized base test
  // with the name 'otp_ctrl_base_test'
  //
  // Register the name 'otp_ctrl_base_test' with the UVM factory to be associated
  // with the template base test class parameterized with the default types (see
  // declaration. We cannot invoke the standard UVM factory automation macro t
  // (uvm_component_param_utils) to register a parameterized test class with the
  // factory because the creation of the test by name (via the UVM_TESTNAME
  // plusarg) does not work. We expand the contents of the automation macro
  // here instead. See the following paper for details:
  // https://verificationacademy-news.s3.amazonaws.com/DVCon2016/Papers/
  // dvcon-2016_paramaters-uvm-coverage-and-emulation-take-two-and-call-me-in-the-morning_paper.pdf
  typedef uvm_component_registry#(otp_ctrl_base_test#(CFG_T, ENV_T), "otp_ctrl_base_test") type_id;

  // functions to support the component registry above
  static function type_id get_type();
    return type_id::get();
  endfunction : get_type

  virtual function uvm_object_wrapper get_object_type();
    return type_id::get();
  endfunction : get_object_type

  const static string type_name = "otp_ctrl_base_test";

  virtual function string get_type_name();
    return type_name;
  endfunction : get_type_name

  `uvm_component_new

  // the base class dv_base_test creates the following instances:
  // otp_ctrl_env_cfg: cfg
  // otp_ctrl_env:     env

  // the base class also looks up UVM_TEST_SEQ plusarg to create and run that seq in
  // the run_phase; as such, nothing more needs to be done

  virtual function void add_message_demotes(dv_report_catcher catcher);
    string msg;

    super.add_message_demotes(catcher);

    // Demote field access warnings to infos
    msg = {
      "\s*Trying to predict value of field 'otp_operation_done' while register",
      "\s*'otp_ctrl_core_reg_block.intr_state' is being accessed"
    };
    catcher.add_change_sev("RegModel", msg, UVM_INFO);

    msg = {
      "\s*Trying to predict value of register 'otp_ctrl_core_reg_block.direct_access_regwen'",
      "\s*while it is being accessed"
    };
    catcher.add_change_sev("RegModel", msg, UVM_INFO);


  endfunction : add_message_demotes

endclass : otp_ctrl_base_test
