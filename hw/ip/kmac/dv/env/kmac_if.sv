// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

interface kmac_if(input clk_i, input rst_ni);

  import kmac_env_pkg::*;

  logic                                          en_masking_o;
  lc_ctrl_pkg::lc_tx_t                           lc_escalate_en_i;
  prim_mubi_pkg::mubi4_t                         idle_o;
  kmac_pkg::app_req_t [kmac_app_agent_pkg::NUM_APP_INTF-1:0] app_req;
  kmac_pkg::app_rsp_t [kmac_app_agent_pkg::NUM_APP_INTF-1:0] app_rsp;

  function automatic void drive_lc_escalate(lc_ctrl_pkg::lc_tx_t val);
    lc_escalate_en_i = val;
  endfunction

  `ASSERT(KmacMaskingO_A, `EN_MASKING == en_masking_o)

  `ASSERT(AppKeymgrErrOutputZeros_A, app_rsp[kmac_app_agent_pkg::AppKeymgr].error |->
          app_rsp[kmac_app_agent_pkg::AppKeymgr].digest_share0 == 0 &&
          app_rsp[kmac_app_agent_pkg::AppKeymgr].digest_share1 == 0)

  `ASSERT(AppLcErrOutputZeros_A, app_rsp[kmac_app_agent_pkg::AppLc].error |->
          app_rsp[kmac_app_agent_pkg::AppLc].digest_share0 == 0 &&
          app_rsp[kmac_app_agent_pkg::AppLc].digest_share1 == 0)

  `ASSERT(AppRomErrOutputZeros_A, app_rsp[kmac_app_agent_pkg::AppRom].error |->
          app_rsp[kmac_app_agent_pkg::AppRom].digest_share0 == 0 &&
          app_rsp[kmac_app_agent_pkg::AppRom].digest_share1 == 0)

  `ASSERT(AppAccErrOutputZeros_A, app_rsp[kmac_app_agent_pkg::AppAcc].error |->
          app_rsp[kmac_app_agent_pkg::AppAcc].digest_share0 == 0 &&
          app_rsp[kmac_app_agent_pkg::AppAcc].digest_share1 == 0)

  // Assertions to check if hold is high outside of ACC mode
  `ASSERT(AppKeymgrHoldNever_A, !app_req[kmac_app_agent_pkg::AppKeymgr].hold)
  `ASSERT(AppLcHoldNever_A,     !app_req[kmac_app_agent_pkg::AppLc].hold)
  `ASSERT(AppRomHoldNever_A,    !app_req[kmac_app_agent_pkg::AppRom].hold)

  // Assertions to check if next is high outside of ACC mode
  `ASSERT(AppKeymgrNextNever_A, !app_req[kmac_app_agent_pkg::AppKeymgr].next)
  `ASSERT(AppLcNextNever_A,     !app_req[kmac_app_agent_pkg::AppLc].next)
  `ASSERT(AppRomNextNever_A,    !app_req[kmac_app_agent_pkg::AppRom].next)

endinterface
