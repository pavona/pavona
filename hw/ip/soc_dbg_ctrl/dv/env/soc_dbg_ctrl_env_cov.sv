// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Covergroups that are dependent on run-time parameters that may be available
 * only in build_phase can be defined here
 * Covergroups may also be wrapped inside helper classes if needed.
 */

class soc_dbg_ctrl_env_cov extends cip_base_env_cov #(.CFG_T(soc_dbg_ctrl_env_cfg));
  `uvm_component_utils(soc_dbg_ctrl_env_cov)

  // Coverpoints
  soc_dbg_state_t dbg_state_cp;
  mubi4_t         bcast_valid_cp;
  dbg_category_e  bcast_category_cp;
  mubi4_t         bcast_relocked_cp;

  covergroup soc_dbg_policy_cg;
    cp_dbg_state: coverpoint dbg_state_cp {
      bins blank   = {SocDbgStBlank};
      bins preprod = {SocDbgStPreProd};
      bins prod    = {SocDbgStProd};
      bins other   = default;
    }

    cp_bcast_valid: coverpoint bcast_valid_cp {
      bins t = {MuBi4True};
      bins f = {MuBi4False};
    }
    cp_bcast_category: coverpoint bcast_category_cp {
      bins locked = {DbgCategoryLocked};
      bins cat2   = {DbgCategory2};
      bins cat3   = {DbgCategory3};
      bins cat4   = {DbgCategory4};
      bins unused = {DbgCategoryUnused0, DbgCategoryUnused1,
                     DbgCategoryUnused2, DbgCategoryUnused3};
    }
    cp_bcast_relocked: coverpoint bcast_relocked_cp {
      bins t = {MuBi4True};
      bins f = {MuBi4False};
    }

    cr_state_x_bcast_category: cross cp_dbg_state, cp_bcast_category;
    cr_state_x_bcast_valid:    cross cp_dbg_state, cp_bcast_valid;
    cr_state_x_bcast_relocked: cross cp_dbg_state, cp_bcast_relocked;
  endgroup

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void sample_soc_dbg_policy_cg(soc_dbg_state_t dbg_state,
                                                mubi4_t         bcast_valid,
                                                dbg_category_e  bcast_category,
                                                mubi4_t         bcast_relocked);
endclass : soc_dbg_ctrl_env_cov


function soc_dbg_ctrl_env_cov::new(string name, uvm_component parent);
  super.new(name, parent);
  soc_dbg_policy_cg = new();
endfunction : new

function void soc_dbg_ctrl_env_cov::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

function void soc_dbg_ctrl_env_cov::sample_soc_dbg_policy_cg(soc_dbg_state_t dbg_state,
                                                             mubi4_t         bcast_valid,
                                                             dbg_category_e  bcast_category,
                                                             mubi4_t         bcast_relocked);
  this.dbg_state_cp      = dbg_state;
  this.bcast_valid_cp    = bcast_valid;
  this.bcast_category_cp = bcast_category;
  this.bcast_relocked_cp = bcast_relocked;

  soc_dbg_policy_cg.sample();
endfunction : sample_soc_dbg_policy_cg
