// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/gen_top_sv.py --completecfg hw/top_dragonfly/data/autogen/top_dragonfly.gen.hjson
//                    --seedcfg hw/top_dragonfly/data/autogen/top_dragonfly.secrets.testing.gen.hjson
//
// File is generated based on the following seed configuration:
//   hw/top_dragonfly/data/autogen/top_dragonfly.secrets.testing.gen.hjson


package top_dragonfly_rnd_cnst_pkg;

  ////////////////////////////////////////////
  // otp_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter otp_ctrl_top_specific_pkg::lfsr_seed_t RndCnstOtpCtrlLfsrSeed = {
    40'hCD_45C60D14
  };

  // Compile-time random permutation for LFSR output
  parameter otp_ctrl_top_specific_pkg::lfsr_perm_t RndCnstOtpCtrlLfsrPerm = {
    240'h0120_437874C2_90F5A29E_07DC38A1_9724B648_15B85151_534C6988_E5126750
  };

  // Compile-time random permutation for scrambling key/nonce register reset value
  parameter otp_ctrl_top_specific_pkg::scrmbl_key_init_t RndCnstOtpCtrlScrmblKeyInit = {
    256'h5F3D22F5_CA036E02_9DFE3E01_3F88514B_08E645BB_A939B145_66456BA4_39FB382D
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey0 = {
    128'h688A9A20_B68E0D35_660E593F_560F6866
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey1 = {
    128'hA1AD90A5_09423977_40AB78C5_737A2379
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey2 = {
    128'hC2EDE5B2_5EC5514B_680CCAAB_361C3F85
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey3 = {
    128'h8E1C5CCC_C121A2C9_5D21294D_190AB75C
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst0 = {
    128'h09C87E42_745452D8_A010A9F0_EF3221D5
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst1 = {
    128'h4DCBA329_FF2F7D4B_8A3ACDB3_25087FAB
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV0 = {
    64'hA0806E02_A1FBA55B
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV1 = {
    64'h9BD623E4_0AEC9B61
  };

  // OTP invalid partition default for buffered partitions
  parameter logic [163839:0] RndCnstOtpCtrlPartInvDefault = {
    704'({
      320'hD08F694A5F790581D728BD369D03F8087A60A7F8ED956442C9CFF0F99E594C7307F376E7B2B2FF8C,
      384'h6149B9FF4F5979607AEAD63A44F896431DF745A52C5AF5FDF86D2CE9FA1041C43F145A8BF5BE7640D7AAF2481067180F
    }),
    384'({
      64'h0,
      64'hF29E32E9E581EE74,
      256'h9C47222C695C123916E90F1BDDE834C31D3EEF689E998822EDDEB20732F666FA
    }),
    1024'({
      64'h0,
      64'h18E89A42A1CBF7CC,
      256'h276D9C42B4B5C6539C73A2705A4682BAA1885457797963C3980BFF063FC8BC64,
      256'h2E2904AA8A7090712CF9A372BE9C2B9C1FBFF3B68368C5AFEDCDEE44F5D8D84,
      256'h4C8FD64171EDB20835AEF32CF20B0C620E9AF6C53593DAEC8E3CAA2E495A8976,
      128'hEFF32B59C0A86294D9767FDCB4745699
    }),
    256'({
      64'h0,
      64'h506068E7D20C8309,
      128'h2552A6AA7830346413591B15ED255318
    }),
    384'({
      64'h0,
      64'hBA37DEB973D827E0,
      128'hB5742826D2CE8D8BB874DDD1DBCA5322,
      128'h1FB5110B0618183CBF722F142EF9FACF
    }),
    448'({
      64'h0,
      64'h5A7F3E2373A78AA2,
      32'h0, // unallocated space
      256'hE78E601C1704C34A6DFD043E96E1EF76D15C0798EF406091D605165216FD3F85,
      32'h0
    }),
    192'({
      64'h0,
      64'h8688686A7D26F94A,
      48'h0, // unallocated space
      8'h69,
      8'h69
    }),
    384'({
      64'h0,
      64'hDDF650F1A00008EE,
      256'h58B183F3D37975B4A9524DE21084A9D64BBA835C10B5E29043022273F7AFBF68
    }),
    19200'({
      64'h0,
      19136'h0
    }),
    33856'({
      64'h1F2A6BD606D55F72,
      30720'h0,
      3072'h0
    }),
    3136'({
      64'h6FB88C3B4FD535BD,
      1024'h0,
      2048'h0
    }),
    65664'({
      64'h0,
      64'hCA832DA13EB53FEA,
      65536'h0
    }),
    8256'({
      64'h0,
      8192'h0
    }),
    1280'({
      64'h0,
      64'h28B1AE331BF3824C,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    1280'({
      64'h0,
      64'hEBAA1ACD79D438BB,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    1280'({
      64'h0,
      64'h8A4FE08CE276C9C9,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    1280'({
      64'h0,
      64'hB5A6FD9823EB9F1C,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    1280'({
      64'h0,
      64'hB51350C5C23EBE77,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    1280'({
      64'h0,
      64'hFDEEF22E74536D01,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    2432'({
      64'h0,
      64'h4BEDD6920E68A84C,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    2880'({
      64'h0,
      64'hF9D303313B0977A8,
      512'h0,
      512'h0,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0,
      512'h0,
      32'h0,
      32'h0
    }),
    6400'({
      64'h0,
      64'hC167C84BFDB86457,
      128'h0,
      6144'h0
    }),
    448'({
      64'h0,
      128'h0,
      128'h0,
      128'h0
    }),
    7744'({
      64'h0,
      64'h2A24E15352C559FD,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      512'h0,
      128'h0,
      128'h0,
      224'h0,
      6304'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    1792'({
      64'h0,
      64'h9521702FCBCF4F54,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h69696969,
      32'h69696969,
      32'h69696969,
      32'h0,
      992'h0
    }),
    576'({
      64'h0,
      64'h45515694E825B33,
      448'h0
    })
  };

  ////////////////////////////////////////////
  // lc_ctrl
  ////////////////////////////////////////////
  // Diversification value used for all invalid life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivInvalid = {
    128'h362730AC_A45340F2_B0EE60F2_5E2CEE80
  };

  // Diversification value used for the TEST_UNLOCKED* life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivTestUnlocked = {
    128'hA251609D_5DDA4A4A_D8C83D39_7D1F83D0
  };

  // Diversification value used for the DEV life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivDev = {
    128'h345AEDBB_B4D7AA71_9297D83A_E6DF7CA6
  };

  // Diversification value used for the PROD/PROD_END life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivProduction = {
    128'h2C4B0BD6_EE484A7E_AFE9079B_80932F7D
  };

  // Diversification value used for the RMA life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivRma = {
    128'h9EF197BA_49CEEBED_E8F7A26B_19372684
  };

  // Compile-time random bits used for invalid tokens in the token mux
  parameter lc_ctrl_pkg::lc_token_mux_t RndCnstLcCtrlInvalidTokens = {
    256'hCDC4422C_133B9D9A_6699B6C7_7A29761F_9598107C_33B11AC5_761C1498_1AEAC9E2,
    256'h8F9D016C_02B80B15_81BA47B0_81EDAD79_56485909_768EF3DB_A808CBC6_D57FE748,
    256'h9F415498_70395C90_D9ABF4E0_F5ED5BA0_97B3BA3C_CF06D21E_513960C3_5528862D,
    256'hB5CAC22C_B2A45AB2_E047CE9E_7C9AEC58_AC5C5043_82899FC9_0D110075_FF2D2698
  };

  ////////////////////////////////////////////
  // alert_handler
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter alert_handler_pkg::lfsr_seed_t RndCnstAlertHandlerLfsrSeed = {
    32'h6FC60147
  };

  // Compile-time random permutation for LFSR output
  parameter alert_handler_pkg::lfsr_perm_t RndCnstAlertHandlerLfsrPerm = {
    160'hF4B8EC7D_09BD8593_EC0BD1A2_12B293AB_C6A811BD
  };

  ////////////////////////////////////////////
  // sram_ctrl_ret_aon
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlRetAonSramKey = {
    128'hB4D3DD52_91DC19BA_AB9BB350_9C609680
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlRetAonSramNonce = {
    128'h2E87C858_22432D73_C32BACAC_31C93158
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlRetAonLfsrSeed = {
    64'h0247F133_92519995
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlRetAonLfsrPerm = {
    128'h0DBC23C6_43FE3015_C5589C9C_98B45DA3,
    256'h52A54F67_E982F033_88D1024A_CEAB437B_74B8E7BB_614647E7_820687F9_FC695F6A
  };

  ////////////////////////////////////////////
  // acc
  ////////////////////////////////////////////
  // Default seed of the PRNG used for URND.
  parameter acc_pkg::urnd_prng_seed_t RndCnstAccUrndPrngSeed = {
    256'h7FBA1C57_A496D093_77DF413B_2B191272_161213B8_0315A177_C7516ECD_4B002AF6
  };

  // Compile-time random reset value for IMem/DMem scrambling key.
  parameter otp_ctrl_pkg::acc_key_t RndCnstAccAccKey = {
    128'hB49253AD_7151C8E8_F1A51FD1_84ABFA40
  };

  // Compile-time random reset value for IMem/DMem scrambling nonce.
  parameter otp_ctrl_pkg::acc_nonce_t RndCnstAccAccNonce = {
    64'hD2CD2D16_F3D54D9D
  };

  ////////////////////////////////////////////
  // aes
  ////////////////////////////////////////////
  // Default seed of the PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstAesClearingLfsrSeed = {
    64'hA75EBED2_7FDCF8D1
  };

  // Permutation applied to the LFSR of the PRNG used for clearing.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingLfsrPerm = {
    128'h6BF7A2AA_1B9700C2_38C0B468_C69F2750,
    256'h6903CB54_D535F74E_118B1C98_78F9590E_BDEF36ED_25217406_B6763F70_AF97E2A0
  };

  // Permutation applied to the clearing PRNG output for clearing the second share of registers.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingSharePerm = {
    128'h56E70202_3A418B52_201BD383_29A45DEF,
    256'h2F132EFF_E194750D_B525B0E8_FADBCFE6_241197CC_178D17DF_142A9B69_F925EA2C
  };

  // Default seed of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstAesMaskingLfsrSeed = {
    32'hBCADEAB4,
    256'h279AB5AA_B57E7E67_4DFB4937_71D9122B_5BE0CC21_F042CEB1_A1AE71A7_671B30F5
  };

  // Permutation applied to the output of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstAesMaskingLfsrPerm = {
    256'h834D718E_47131628_25331018_4B5C4807_60644414_7D4F9346_863B7843_618D825F,
    256'h126C3463_450F9C8B_1D321E73_9954845D_2B818C96_8985309A_8F505A1A_2D6D6B6E,
    256'h3197390E_1F4C2270_059B8A0C_557B5E69_205B3A37_409F277A_563E389D_2F870423,
    256'h911B669E_5990003D_6A17012E_29199453_090B0358_67369506_6F082A92_6865493C,
    256'h5102772C_747E763F_7F415779_35751C80_26520D15_980A4E24_6272884A_117C4221
  };

  ////////////////////////////////////////////
  // kmac
  ////////////////////////////////////////////
  // Compile-time random data for PRNG default seed
  parameter kmac_pkg::lfsr_seed_t RndCnstKmacLfsrSeed = {
    32'hC0511E4A,
    256'h008FF9B0_AFBD938A_4FC64B63_243E286F_90F55031_A6F3F5C5_DF91521F_F989F25F
  };

  // Compile-time random permutation for PRNG output
  parameter kmac_pkg::lfsr_perm_t RndCnstKmacLfsrPerm = {
    64'hA71975D9_8430122B,
    256'h9D0D1F27_C4BA4D76_65BA3513_BA66624A_E38B6636_CC012881_97C92F01_2B919A46,
    256'hBF612701_6E39CA82_D43172DD_5665879E_C12BE5D8_7B6DB02C_609D5ACA_F70E2AA2,
    256'h71402895_14F02622_AC8B01D4_26C28C89_AA61582D_61365579_8530A652_B798A210,
    256'h72A93194_01E976A5_317F1374_09D19D63_5011F906_FA12A78A_69B43167_4381045B,
    256'h4423EA16_A5EB021C_5673A827_295D3D84_15B23E04_53C7D08D_70C5C95E_A66481D7,
    256'hE1EE6AEF_579CC738_C174FE18_4C95C0B4_A39B02AA_7DA8C2E0_A62005C1_6177766B,
    256'h05888A42_2F068037_786CB2C5_463A7383_DE532C79_392A034D_8DA7A4A8_3A2C75D8,
    256'h3348C1A4_5183D645_4CC48B2A_625F2E16_86EE7BE3_514824A6_CD44DEBF_A39F10D9,
    256'h646E55E5_3687AEDF_B5BC9797_DB236D96_93AD05DF_035421C3_7EC8B8AD_50EEFCA1,
    256'h0EC23293_8F1BA584_A5374772_B21076F1_756E9986_D49032F4_569AA53A_88A186BA,
    256'hB9191A65_DC506E86_4E5A4A47_961D1544_9A4416B2_B4378084_581EF6B1_D2018EE5,
    256'h45E71A3D_A630E9D0_BC8F3F6A_84ED2516_C340213A_458960B9_C44717A0_7CD53ADD,
    256'h255311C7_626262F8_095B0561_730D6838_CEF71FAC_D215C79A_6EB1EEC5_A2586475,
    256'hAE96AF32_069435D9_19FA20B0_62B8A418_08559444_2B46D2B7_A1420810_97D94834,
    256'h6FB138BB_42A594E5_A75E1418_8ED1A316_9725033A_243609EB_038686F6_C33CDB65,
    256'h4EDA3E6E_6BFDA536_A376EED8_2900A1D2_956F1C51_45021FE8_A8799B60_4E162523,
    256'h52E034C0_DEB3E6E1_331B3BCB_4AC50C84_E303B65C_155D406C_BC1C23B2_EA112189,
    256'hE050B2BF_AB78B862_4D8D9735_F3ADA496_71E00CCB_D3350131_846B0240_1C4008E5,
    256'h8C41B151_5DFD3F02_3A597129_88374C3D_81590362_767DC599_BCE95592_4AD0224A,
    256'h115B6482_B824F451_AD13CF0B_754A1A9F_AC431290_AEA5AA70_66306589_9E8907A0,
    256'hE09BA047_3B928019_677C10FE_4A85DA8D_E2185126_3EB51110_F549F93D_06F7FC7D,
    256'h594BF875_74342442_7D1AC00B_12E12D2E_4B7AAA31_24E655F6_1F5D5057_08CFC1E1,
    256'h49E9478E_AD3A2C78_BA1A342D_95202A5C_20B36DF1_EA609459_E0C77E3F_86A2A57C,
    256'hF1AAD799_CA383DE0_B07A282A_6A127215_8CA56C3C_1062F018_D87673E6_D0083A41,
    256'hC159A13E_67DA464D_315A2C24_A5439471_67300778_45A280CC_A9D26239_945CAD2A,
    256'hB1AF510D_CBC6ECAC_E5025600_602BE979_BEBB71A8_34AE810B_629F1C07_2065C24C,
    256'h78E09820_0D9FD551_2EBA7F22_5485F59F_6BCB1ACE_286CCB11_B1AA54C9_82485F83,
    256'h9018E27C_099669A2_7B089328_47325DC2_4546A8B1_F0F97F24_04903EF0_1613822E,
    256'hF2AE2015_5DD66D43_071A856A_41322B0C_6757BC61_4592C43C_0AD77F8C_43CADF4D,
    256'h0CE4B2AF_2F9C87AA_790F0643_FDC13EC3_22AEAD30_9667913D_6FE34B72_640B30D3,
    256'hAA3D3BAE_F6E02742_267614E6_B52C9100_AFC24F80_FC6D4790_E178D668_13549E21
  };

  // Compile-time random data for PRNG buffer default seed
  parameter kmac_pkg::buffer_lfsr_seed_t RndCnstKmacBufferLfsrSeed = {
    32'h14532674,
    256'h1F804E3C_3A345146_9C6118FA_23BC32E4_28AD2BE2_584FE8D5_491FA8E7_F19AAA41,
    256'h33AD0D27_04702AE2_FF9D9849_FCB59874_CDDC9CBC_645D9E02_A96B9980_911844D3,
    256'hC74DE85E_05164B82_9D484BD4_47C9D761_1999CA52_3B11575A_82D625EA_331F0DD0
  };

  // Compile-time random permutation for LFSR Message output
  parameter kmac_pkg::msg_perm_t RndCnstKmacMsgPerm = {
    128'hAF01B9E3_2EDA3190_65BC80B6_2E1DC782,
    256'hDE8FA1C4_1517CD7E_BB40F34C_E7F1A4D6_D6B3F90A_F4424061_48E29D14_97A9D99E
  };

  ////////////////////////////////////////////
  // keymgr_dpe
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter keymgr_pkg::lfsr_seed_t RndCnstKeymgrDpeLfsrSeed = {
    64'h1D6EC345_718E6E72
  };

  // Compile-time random permutation for LFSR output
  parameter keymgr_pkg::lfsr_perm_t RndCnstKeymgrDpeLfsrPerm = {
    128'hB0699333_D6F03EA5_77BF48FA_227A4212,
    256'h541D7B8A_F57D4599_60E80B27_1BA80337_3F6BBE51_B62C8A34_3841F241_C55FED92
  };

  // Compile-time random permutation for entropy used in share overriding
  parameter keymgr_pkg::rand_perm_t RndCnstKeymgrDpeRandPerm = {
    160'h08DD1C40_4954C8FE_7CD7397D_ACD80BAD_11B64BAD
  };

  // Compile-time random bits for revision seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeRevisionSeed = {
    256'hFFD7E826_5FAF402C_8DBEE783_3F8128F5_87EE8A3B_05767C77_806068F2_725A3C40
  };

  // Compile-time random bits for software generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeSoftOutputSeed = {
    256'hAC8FEB4F_2302C232_C482D07B_560A3D67_8FB9A9DC_420A1339_B243BB28_853B19B5
  };

  // Compile-time random bits for hardware generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeHardOutputSeed = {
    256'hC399D4DA_9B067ED9_BE1D5753_FFD02F20_F4E52516_4DCFF3CB_4E007DAC_CF0A553E
  };

  // Compile-time random bits for generation seed when aes destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeAesSeed = {
    256'h45BAB60F_D530AE84_156D37CC_68063276_F9E85FAE_E129AE80_F5B440DC_77964912
  };

  // Compile-time random bits for generation seed when kmac destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeKmacSeed = {
    256'h7EC56C7B_0E9645BF_231B5B37_B8C5559A_EE0D0E2F_2DAB7D37_1048B9F8_DB4F3775
  };

  // Compile-time random bits for generation seed when acc destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeAccSeed = {
    256'h8860FF09_D90EECE3_C2F34229_DD0318DE_05CFB093_C70D4B54_DC8AFD1F_07532671
  };

  // Compile-time random bits for generation seed when dma destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeDmaSeed = {
    256'hEB83C820_E1F1EAA3_A18AD34D_471B199C_FD72B03F_A6BEDB61_B505C2E5_45C708D5
  };

  // Compile-time random bits for generation seed when no destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeNoneSeed = {
    256'h5FC11ABC_F2E75091_BF86783E_6A04BF53_B6DF5D93_E4C8A20B_7DA9320C_6D31E224
  };

  ////////////////////////////////////////////
  // csrng
  ////////////////////////////////////////////
  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivNonProduction = {
    128'h35A360E9_F49E943C_6DF7A058_352E5EE5,
    256'h4F3D6CB2_8EDB47B1_5F73CFAE_197DC3F9_534A8714_5D40138D_0DAA41D0_EFE0910F
  };

  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivProduction = {
    128'h221C4F25_A8801439_ADC672FB_B9D5B077,
    256'hF2CD4011_EC5D8376_28672043_36105D80_C00220F1_DA1D3249_B8B27F54_0D01C612
  };

  ////////////////////////////////////////////
  // sram_ctrl_main
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMainSramKey = {
    128'h6736232F_99134307_9175C6A3_F36D389B
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMainSramNonce = {
    128'hD5D0A06E_314F7E0E_FDC7B797_0A3EA735
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMainLfsrSeed = {
    64'h116A0C6B_28F2300D
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMainLfsrPerm = {
    128'h722174AE_FA7935B2_4EC36828_3D294747,
    256'h513752CE_8CAA67C3_09A60607_186343C5_732DDB56_EE44FF65_7E2E0272_3E2B27BD
  };

  ////////////////////////////////////////////
  // sram_ctrl_mbox
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMboxSramKey = {
    128'hC6653CDA_8E066B98_9FB2BD83_BEADCF1A
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMboxSramNonce = {
    128'hB871270C_C1E53754_5255EEF8_BBC56B20
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMboxLfsrSeed = {
    64'h6E008162_473AE6CB
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMboxLfsrPerm = {
    128'h2A3013E0_72729C1D_3D8AA22C_BD099219,
    256'h57DAF9DC_607B0505_5A9FE8E6_1F0F2EE1_1C60D0C2_457325EC_EDF3DADE_AB65B935
  };

  ////////////////////////////////////////////
  // rom_ctrl0
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrl0ScrNonce = {
    64'h9D3CD85F_EB1EE319
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrl0ScrKey = {
    128'h926BE21C_682953B4_98F09788_18DB9932
  };

  ////////////////////////////////////////////
  // rom_ctrl1
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrl1ScrNonce = {
    64'hD6137CB3_FBD79C14
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrl1ScrKey = {
    128'h73B06B9F_20A29EAB_FCBBC16B_35164D75
  };

  ////////////////////////////////////////////
  // dma
  ////////////////////////////////////////////
  // Default seed of the inline-AES PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstDmaClearingLfsrSeed = {
    64'hEBC2E3B5_0AEFA1CD
  };

  // Permutation applied to the LFSR of the inline-AES clearing PRNG.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstDmaClearingLfsrPerm = {
    128'h88BDEC0B_A7D7FDC8_6EACDBDA_450A38EC,
    256'hACE6C8F0_D6789187_A5B8F64B_CD14335F_93920179_66AC0094_13889C47_7D558B71
  };

  // Permutation applied to the clearing PRNG output for clearing the second share.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstDmaClearingSharePerm = {
    128'h03DCB036_61A784F0_5729C41F_12CFAEBC,
    256'h52366AA7_BF1DB4F7_ECCCC9F0_B0E08928_F8E6856B_7599640A_9C584745_8EB54D7A
  };

  // Default seed of the inline-AES PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstDmaMaskingLfsrSeed = {
    32'hF75D37F2,
    256'h8396B53D_310D4457_746BFF34_06C193B6_DB9883CD_A8C2D0DD_65578D17_3D15E674
  };

  // Permutation applied to the output of the inline-AES masking PRNG.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstDmaMaskingLfsrPerm = {
    256'h512B820F_343B5D11_029E742C_8C365F86_4D439828_1F372F60_77507899_101D737A,
    256'h0B8D6D17_814F0140_8E722026_568A447D_32492389_1896853D_7C667B5A_29056F91,
    256'h46353F71_16949768_6B848862_522D4C48_6A5C4B5E_191E591A_3E769D12_6E63800E,
    256'h4A6C4E24_90302192_709F139C_54337F69_0A642279_38558758_04036509_42003C47,
    256'h75416708_145B2A9A_3A2E159B_25391C83_27538B1B_610D4506_957E9331_570C8F07
  };

  ////////////////////////////////////////////
  // rv_core_ibex
  ////////////////////////////////////////////
  // Default seed of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_seed_t RndCnstRvCoreIbexLfsrSeed = {
    32'h9537750D
  };

  // Permutation applied to the LFSR of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_perm_t RndCnstRvCoreIbexLfsrPerm = {
    160'hC37F1648_83F1742B_85C7AD10_FE6EDD82_9260666B
  };

  // Default icache scrambling key
  parameter logic [ibex_pkg::SCRAMBLE_KEY_W-1:0] RndCnstRvCoreIbexIbexKeyDefault = {
    128'h849FA1D7_A18F21A6_6540109B_BA8C96E7
  };

  // Default icache scrambling nonce
  parameter logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] RndCnstRvCoreIbexIbexNonceDefault = {
    64'hF370BE9D_9C3DE579
  };

endpackage : top_dragonfly_rnd_cnst_pkg
