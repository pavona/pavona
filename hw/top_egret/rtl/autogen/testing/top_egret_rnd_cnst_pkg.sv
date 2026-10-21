// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/gen_top_sv.py --completecfg hw/top_egret/data/autogen/top_egret.gen.hjson
//                    --seedcfg hw/top_egret/data/autogen/top_egret.secrets.testing.gen.hjson
//
// File is generated based on the following seed configuration:
//   hw/top_egret/data/autogen/top_egret.secrets.testing.gen.hjson


package top_egret_rnd_cnst_pkg;

  ////////////////////////////////////////////
  // otp_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter otp_ctrl_top_specific_pkg::lfsr_seed_t RndCnstOtpCtrlLfsrSeed = {
    40'hBA_D605BB69
  };

  // Compile-time random permutation for LFSR output
  parameter otp_ctrl_top_specific_pkg::lfsr_perm_t RndCnstOtpCtrlLfsrPerm = {
    240'h79F3_0E48484B_4640C622_51406673_C94E0094_8958CD61_D5C75816_D072629A
  };

  // Compile-time random permutation for scrambling key/nonce register reset value
  parameter otp_ctrl_top_specific_pkg::scrmbl_key_init_t RndCnstOtpCtrlScrmblKeyInit = {
    256'h5CE4EE55_B032C07A_29B920B7_953E485F_23AD102C_6A0EFCE9_F0EC4C71_2146A4AB
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey0 = {
    128'h008E023B_1E052DAC_1E0FCEBE_AC537EDC
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey1 = {
    128'h7848DA13_345040C2_95FCBD76_684E7170
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey2 = {
    128'h57AF0328_8E6C3C38_3A73E698_950BFAB6
  };

  // Compile-time scrambling key
  parameter otp_ctrl_top_specific_pkg::key_t RndCnstOtpCtrlScrmblKey3 = {
    128'h9ACF416A_D5455D1D_EA1EA059_DC5C584C
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst0 = {
    128'h74E7B5C1_5957663A_C0A5A56F_968FD7E9
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst1 = {
    128'h7A827E95_A7385B32_C02ABD64_5FC814BC
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst2 = {
    128'hFE6728D0_D0879EC6_2214D762_08E9943A
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst3 = {
    128'hE17E956C_21B003D0_BCB1CBCD_1EB02317
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV0 = {
    64'h99E3E946_397824F3
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV1 = {
    64'h8071EF1B_FF0C99F0
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV2 = {
    64'hBC1CFCFF_9F3E4CD4
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV3 = {
    64'h43242540_D2120889
  };

  // OTP invalid partition default for buffered partitions
  parameter logic [16383:0] RndCnstOtpCtrlPartInvDefault = {
    704'({
      320'h12107E5F937092382CB21F6ABCDC9A608A8E59E8CC6315D2495CA878EB2975046FD5443C2CB8B75A,
      384'h2B9403C190120BB318A937E66A6DF253E7DAA2EA63EA3209A1832965B9E9EB47171184A5B1C2CBB244E91725013B44B5
    }),
    384'({
      64'h0,
      64'h502C03ACFF4AF30D,
      256'h67BAA00A00025E7FC9BD14102DC30C29978A4C70C8DA26CB202F5F59A412A339
    }),
    960'({
      64'hF68D520B6DC525A3,
      256'h5EB6A7B2688A16B1C05693E7E037958183C9545358D14AAED1FCF0E1EDCB0316,
      256'h4A487A070E2D41C244CB7240CEE69DF76619E1BBA8167005EE5B59B17EF42013,
      256'hCC2B9D5A79CA02E338758DD6DE79680485CE6F2736649780ACF49BFADF4C4CEF,
      128'h628838F651B4B5E1188FD88EB8AEB542
    }),
    704'({
      64'hFF807F2F9D87437A,
      128'hFBC75FA47FD1EE356B0EE77C01530CB2,
      256'h10A9BD8A9D3ADE48339BAB0E6739719D66316FA6C7A2CFE54B57B94CCDB5B701,
      256'h34069D6201333F656283E5A7BD289D1E5E895532DB9EF56A3F39ACCE8428CD2F
    }),
    320'({
      64'h50FABDC8F2937D8F,
      128'hFC60FDA3EC7167EDF9CE31192D35CFE6,
      128'hAD9874386DBD4C92E0F24A7DB2A9D1F7
    }),
    128'({
      64'hB7DBD27D94C9C8D9,
      40'h0, // unallocated space
      8'h69,
      8'h69,
      8'h69
    }),
    576'({
      64'hF6DBA32A1E082D2A,
      256'hA528E88DD62172CAFE980B4C39261457AF22D4755CDDD7CB28EF0FF7219351C5,
      256'hA6BC237A3081D9BCDD43BA90DE4CF7E1A302E95EC6D2AADEA8B6A9D4477ECD98
    }),
    320'({
      64'hEC203B9EB85C7EA3,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    3776'({
      64'h668AFD034DC05DF9,
      256'h0,
      32'h0,
      256'h0,
      32'h0,
      32'h0,
      256'h0,
      32'h0,
      32'h0,
      256'h0,
      32'h0,
      32'h0,
      256'h0,
      32'h0,
      512'h0,
      32'h0,
      512'h0,
      32'h0,
      512'h0,
      32'h0,
      512'h0,
      32'h0
    }),
    4864'({
      64'hFD1F508AC4E1C5F6,
      288'h0, // unallocated space
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0,
      96'h0,
      32'h0,
      32'h0,
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
      512'h0,
      2560'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    3136'({
      64'h187A352F7669266C,
      288'h0, // unallocated space
      256'h0,
      256'h0,
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
      1248'h0
    }),
    512'({
      64'h8FFF2C83BEF2B0C1,
      448'h0
    })
  };

  ////////////////////////////////////////////
  // lc_ctrl
  ////////////////////////////////////////////
  // Diversification value used for all invalid life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivInvalid = {
    128'h60DA8B65_6EABB0B3_EF6E9B19_7CE582FC
  };

  // Diversification value used for the TEST_UNLOCKED* life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivTestUnlocked = {
    128'h9B5965D6_97C23BEA_FE8389E9_F8AC17B7
  };

  // Diversification value used for the DEV life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivDev = {
    128'hFEBD3C5A_12FD51BF_1196B12E_5259BDED
  };

  // Diversification value used for the PROD/PROD_END life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivProduction = {
    128'h90261100_C8CCC2B1_BE459977_5614975D
  };

  // Diversification value used for the RMA life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivRma = {
    128'h3D2B32E9_33D88E2E_1CF65460_F23FB780
  };

  // Compile-time random bits used for invalid tokens in the token mux
  parameter lc_ctrl_pkg::lc_token_mux_t RndCnstLcCtrlInvalidTokens = {
    256'h499E6FCC_E64CEAFD_282C0E33_FD2C0798_6C2A5117_55F072EE_7A8E2FC4_5E111DF0,
    256'h7FA067F6_4056D9BF_30D48543_BEC2E9A0_75D7D536_D6F82505_255EA064_5554DD5F,
    256'h9355F5A8_9085A95A_12AB13E0_EC9CCD04_512F5C01_D8958EF4_21D22BB7_7013624B,
    256'h5A4BFF0B_DD4DD6B3_0B717AA8_0FF777A1_57878A46_8D23EECB_D09DE6B8_F9FAEAF1
  };

  ////////////////////////////////////////////
  // alert_handler
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter alert_handler_pkg::lfsr_seed_t RndCnstAlertHandlerLfsrSeed = {
    32'hA70E57E8
  };

  // Compile-time random permutation for LFSR output
  parameter alert_handler_pkg::lfsr_perm_t RndCnstAlertHandlerLfsrPerm = {
    160'h92608B33_4D58703B_80512E49_5DBE6AE7_9DF31E9D
  };

  ////////////////////////////////////////////
  // sram_ctrl_ret_aon
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlRetAonSramKey = {
    128'h382AF33B_47971855_8E675976_4645AAD1
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlRetAonSramNonce = {
    128'hFB21C181_24635E3D_50A88F68_08045627
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlRetAonLfsrSeed = {
    64'hAC18F377_D9071BEC
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlRetAonLfsrPerm = {
    128'h5535942E_1E920F2C_0E9F524F_E066F188,
    256'h0728B26F_9E21FCE4_A82074DE_B810BFF6_1176E119_68C1D717_62A3B4DE_7DEE5F29
  };

  ////////////////////////////////////////////
  // flash_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for default address key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlAddrKey = {
    128'hC70EA184_C7A34193_D59C735B_5B4E2CBE
  };

  // Compile-time random bits for default data key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlDataKey = {
    128'hE5AB93CB_024D6F8C_0C700110_CBF01425
  };

  // Compile-time random bits for default seeds
  parameter flash_ctrl_top_specific_pkg::all_seeds_t RndCnstFlashCtrlAllSeeds = {
    256'hDAF5141D_F19A882A_71D66B59_53DBC603_379DA9EF_B2069BD7_9815B2F8_D99A40E7,
    256'hFDC4FB13_143D7753_CE1CF9E2_02920739_6945C95C_9B54BAE6_AEF30D85_77834CCC
  };

  // Compile-time random bits for initial LFSR seed
  parameter flash_ctrl_top_specific_pkg::lfsr_seed_t RndCnstFlashCtrlLfsrSeed = {
    32'h6CAAA63A
  };

  // Compile-time random permutation for LFSR output
  parameter flash_ctrl_top_specific_pkg::lfsr_perm_t RndCnstFlashCtrlLfsrPerm = {
    160'h10D16ACF_C5CF08DF_ADEED4B7_DC2427A5_D5030191
  };

  ////////////////////////////////////////////
  // acc
  ////////////////////////////////////////////
  // Default seed of the PRNG used for URND.
  parameter acc_pkg::urnd_prng_seed_t RndCnstAccUrndPrngSeed = {
    256'hE23A8CC3_1E2DE5E5_78D43D2D_CE49E360_CFB594AC_DDF17068_4F6EAD2B_7FEBFE89
  };

  // Compile-time random reset value for IMem/DMem scrambling key.
  parameter otp_ctrl_pkg::acc_key_t RndCnstAccAccKey = {
    128'h5523D7BC_4846A485_956C7F90_4B9EDED0
  };

  // Compile-time random reset value for IMem/DMem scrambling nonce.
  parameter otp_ctrl_pkg::acc_nonce_t RndCnstAccAccNonce = {
    64'h9B89A754_33566F49
  };

  ////////////////////////////////////////////
  // aes
  ////////////////////////////////////////////
  // Default seed of the PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstAesClearingLfsrSeed = {
    64'h63D9DC27_F3ECB11C
  };

  // Permutation applied to the LFSR of the PRNG used for clearing.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingLfsrPerm = {
    128'hAE32AD30_72CD6496_C80E6435_6BCFACC1,
    256'h4D054D20_01CF95E5_5A2627E8_4C5C768F_DFA4F472_576ECEDE_0182921B_FDA9EBB8
  };

  // Permutation applied to the clearing PRNG output for clearing the second share of registers.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingSharePerm = {
    128'h916527B0_77529506_57EADFB9_B98F0BCA,
    256'h928DE088_8FFFB4E0_A1B7D103_025C3B41_6BCC46AA_3230959A_F8777B11_BDD83D41
  };

  // Default seed of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstAesMaskingLfsrSeed = {
    32'hF31A0165,
    256'h939D819D_1518690E_6473CDB2_47939163_5057CA10_45B9E191_7E1FF018_9B04A4F7
  };

  // Permutation applied to the output of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstAesMaskingLfsrPerm = {
    256'h97681C82_18856353_9D6B8F6E_2E9E8798_2657917A_8C794A73_3F258601_65757223,
    256'h45514D5D_07463A0B_83783B6C_06373D74_9C38040C_6D809070_20883958_2D22992A,
    256'h485F5A30_59499F03_2110291E_1A35614E_27811667_40007D6A_84123215_7611521D,
    256'h628D335E_3C42242B_7F505B93_552C4C71_132F9A1F_920A3496_7B642831_447E9402,
    256'h058B770F_41476F3E_5C43087C_19891466_8E569B54_0D4B360E_951B1769_4F8A0960
  };

  ////////////////////////////////////////////
  // kmac
  ////////////////////////////////////////////
  // Compile-time random data for PRNG default seed
  parameter kmac_pkg::lfsr_seed_t RndCnstKmacLfsrSeed = {
    32'h25910840,
    256'h042A75EC_C25D4E22_67E3BFF2_6E003AAC_BF7D513A_EA01E9EE_420D5B52_3F6B00C8
  };

  // Compile-time random permutation for PRNG output
  parameter kmac_pkg::lfsr_perm_t RndCnstKmacLfsrPerm = {
    64'h48C6797A_4D96D406,
    256'h1E345D65_00F1DE5D_EB818D18_BE0D3290_97B1464A_B21106B0_2A692BA9_50044D32,
    256'hB595F938_2856A4B9_DDFF9731_CBE520AD_C8D6953C_68DA1229_A03C9C1C_40C5A72F,
    256'hB91D2942_9A812EB3_8349E92B_051C51BB_20E598E8_AA62E5C5_2EF305CD_0D111125,
    256'hB8675A68_EABDBC4B_90C6D354_95CC2196_AE84A441_2C3CC998_071A4E88_BA141B98,
    256'hA1B01DBD_97C56039_655B14E8_A1E68307_3BB0EF2D_C6DA5C65_7529B2CC_8754E7FA,
    256'h89FE1566_D1D1E33D_5F893233_2A61572D_8C261EB5_16908525_6B550D9A_5C4A1C1D,
    256'h920374CD_083B1EEA_C6521864_244AFC5F_84C5FF0E_45A1C52D_6D60E221_B19B3DA5,
    256'h19E0163A_070A0A79_8E02D0C2_60BA5F27_C5E5ADA0_74987970_DB0B348C_5A85D926,
    256'hCB65C2A1_66BF4097_352832B4_5F3559F0_2AE806E6_46C2D8B9_D6FA8846_81E80CA3,
    256'h631B814D_349E9AEE_919F30F4_66D93355_406496A9_0253EDDB_2CA03B38_88B31E07,
    256'hBC1509E3_720CAC45_69F7F142_608FF1BA_1A4162E2_FEC33410_46F1A447_299B9C33,
    256'h3E54199C_E447EE62_C6866EC7_F4E26E7B_2D80BC7D_6DCEA7A0_C8C1106A_C2588B71,
    256'hD19851AF_92FAAD09_2FA0B9D2_FE87E6A1_3C9D6D53_D36A3D7D_5CA74D35_0F59E31A,
    256'hD7050762_BCBD71ED_D5BB0C4E_50E09144_282DC759_7133ECA2_38C76B28_80B2264C,
    256'h446494F1_95D502E2_B2986DE0_1AF40122_72457D07_95559EFD_9AEA146A_051A9D2B,
    256'hBA3C56EF_F150D828_8D977157_67CF8139_8F70AD03_DEF36348_14889A4F_A0A8C857,
    256'hC6D904B8_72A9E351_6A00564D_C200E28A_8224A193_3F82085A_81102D22_9DBF3253,
    256'h66BE7B22_5742123F_761645ED_76610B52_8F094EDE_AB505B04_DCE0FDD7_0AD892B9,
    256'h6248595B_00D46B84_1BD92A04_8D1375DD_2489CA58_A1C607E7_6845C5EB_44C05FA5,
    256'h67D35DC8_73E8F821_E1112A85_8C11AAA9_E9BEAE90_0EE5EA13_4DE290F8_CEBB4AD4,
    256'h1CE1C4F1_14758096_5D9005E2_29886034_18085E78_AEDF5197_21E21745_C7C50C85,
    256'hA0CFD688_CC171928_09919CA4_F022106E_A4540D98_66AA65F1_6B8C1AB6_F8D5756C,
    256'h911CDFA7_5604D1B4_3D151B1D_ED878693_B50BA24D_B1DDD0AB_693309B6_904B4B69,
    256'hC90D9DFC_66540700_23000057_AE253D2D_71604181_78C34C3B_3E0EAF0C_B9A04D6B,
    256'h6C48DA84_89619606_7EC5A3B0_2701BD59_C995A92E_A098BE39_B6DFB040_3A5BDD1C,
    256'h78C45630_7178E932_969C7CD6_9B04814A_64109683_81B28914_C430E37D_949A3838,
    256'h49DF9718_0F26C532_0A5D7D2E_873161A8_D4847A7A_27C43B86_186AAEB2_A1142540,
    256'hA140E709_B03BCAC2_2DAAF43D_880BA3E5_1EB57F70_0C1A712E_C358B06B_492A0650,
    256'hAA8748F9_1294AA47_502E2394_E5AB0643_4FDB1AE5_707020F6_9F0A9568_CA48B03F,
    256'h2734055D_00E06162_76253126_64623C0F_A9C2660E_C932F28B_0E58EC54_1F7DC29B,
    256'hDEE47E98_A616EA29_62039AE3_61AF05E5_B308C173_7A123ADE_41EC0559_AC62406F
  };

  // Compile-time random data for PRNG buffer default seed
  parameter kmac_pkg::buffer_lfsr_seed_t RndCnstKmacBufferLfsrSeed = {
    32'hA9AACA4D,
    256'hB84A32E5_C6985A1A_6435118B_5F5F3FD3_B9313116_B67192D8_56DD742D_40E072E4,
    256'h17AD9A5F_261204CB_CC69A214_7819B290_A4BB0264_347C0F91_B0CEC93C_0129D85B,
    256'h95801DBE_03F17E69_DC260A79_998EFF5C_710B6783_8ADFB99A_5ECA6716_72CF19BC
  };

  // Compile-time random permutation for LFSR Message output
  parameter kmac_pkg::msg_perm_t RndCnstKmacMsgPerm = {
    128'hE4D3967C_CC7D4325_616A64EF_7A88AE09,
    256'h7ED1D4AC_CB3D2040_D1BDFE1A_074723CA_85D99278_8EC50396_4FD87271_2DEB0AE9
  };

  ////////////////////////////////////////////
  // keymgr_dpe
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter keymgr_pkg::lfsr_seed_t RndCnstKeymgrDpeLfsrSeed = {
    64'h9A07EFFE_E457DEE8
  };

  // Compile-time random permutation for LFSR output
  parameter keymgr_pkg::lfsr_perm_t RndCnstKeymgrDpeLfsrPerm = {
    128'hABB890A3_69BD68B0_ADE4C254_5DDA528F,
    256'hAC38C930_187B3B07_56783473_71AEAE41_2F225F8D_D61C5647_C7C3385F_CF6416CA
  };

  // Compile-time random permutation for entropy used in share overriding
  parameter keymgr_pkg::rand_perm_t RndCnstKeymgrDpeRandPerm = {
    160'h4AF980C9_48FD2AC3_3411742D_D990FBC8_C45F6AEF
  };

  // Compile-time random bits for revision seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeRevisionSeed = {
    256'h8EEE34D3_1387B45B_91CE49E4_E6B58794_1D1EEC35_6888AE53_43DD784C_BA5BEBBE
  };

  // Compile-time random bits for software generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeSoftOutputSeed = {
    256'h2A6EAD06_2D9516FD_D8B11086_1A797CB6_84A3032D_DAC2DA88_D91CB185_7DADCDFC
  };

  // Compile-time random bits for hardware generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeHardOutputSeed = {
    256'h5C5F76D4_A8E259D8_8DFE9B67_0AA0DD99_2BFE5D2E_12489D22_504AA7AC_1C67F59C
  };

  // Compile-time random bits for generation seed when aes destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeAesSeed = {
    256'hBA5482C1_E35E6E33_35C20CC7_78FC3099_17B9C870_ABE0895D_76F862EF_81F419E3
  };

  // Compile-time random bits for generation seed when kmac destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeKmacSeed = {
    256'hC6CDC866_2C71EAC1_41666E44_3C6492D9_BCF7A824_20750E5D_FC5E3ED4_F2907532
  };

  // Compile-time random bits for generation seed when acc destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeAccSeed = {
    256'hE179EBEC_7ED7D3A5_EF4982F7_3ED91C4B_1CD0C85E_C5E548B4_0184A69E_B1E54396
  };

  // Compile-time random bits for generation seed when no destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeNoneSeed = {
    256'h460E36C5_5C459EFE_9E43836F_E878E464_337EBCAE_3238DCDF_7DE88B56_B405E02B
  };

  ////////////////////////////////////////////
  // csrng
  ////////////////////////////////////////////
  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivNonProduction = {
    128'hBFD73849_C511F7F0_B79F91DC_D1D589B4,
    256'hCAC4372C_385F89D9_02019DAB_B6DD5702_2C77EDE8_609C409D_905B3C78_19B26A67
  };

  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivProduction = {
    128'h43288199_28C5D79B_F1DB63D1_1E1C31BB,
    256'hC9A8C73F_C4CC3D14_CA6BC0B9_6812DE7C_775A54FF_19343CB3_2040B349_0768889D
  };

  ////////////////////////////////////////////
  // sram_ctrl_main
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMainSramKey = {
    128'h27E0BA85_88D34C05_BCF127DA_E58B65D6
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMainSramNonce = {
    128'hA2510880_99B37107_B1CCCF1A_955F03DE
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMainLfsrSeed = {
    64'h1A8447BF_83B69C50
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMainLfsrPerm = {
    128'hA7D73A6A_33FC6531_EADA6B89_58012C60,
    256'hBFEBBC53_4129DE75_461D0840_30B2B688_A0946DF0_7CE5576C_C931EE7F_9E5334B8
  };

  ////////////////////////////////////////////
  // rom_ctrl
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrlScrNonce = {
    64'h6F48D140_1F8A6A52
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrlScrKey = {
    128'h286F6954_C27A9AEF_BE0BC9EE_440C514C
  };

  ////////////////////////////////////////////
  // rv_core_ibex
  ////////////////////////////////////////////
  // Default seed of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_seed_t RndCnstRvCoreIbexLfsrSeed = {
    32'hCACB0199
  };

  // Permutation applied to the LFSR of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_perm_t RndCnstRvCoreIbexLfsrPerm = {
    160'h4D2CF092_276F302D_5D487326_6283BBCF_E0BA8FD2
  };

  // Default icache scrambling key
  parameter logic [ibex_pkg::SCRAMBLE_KEY_W-1:0] RndCnstRvCoreIbexIbexKeyDefault = {
    128'h023D8F96_A41F062B_B66B2287_01E8317C
  };

  // Default icache scrambling nonce
  parameter logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] RndCnstRvCoreIbexIbexNonceDefault = {
    64'hD4BF08BD_6684A1D5
  };

endpackage : top_egret_rnd_cnst_pkg
