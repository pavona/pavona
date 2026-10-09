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
    40'hAB_13E0EC9C
  };

  // Compile-time random permutation for LFSR output
  parameter otp_ctrl_top_specific_pkg::lfsr_perm_t RndCnstOtpCtrlLfsrPerm = {
    240'h0D31_0D1A6547_1634A065_E7D18908_5890F39A_59B9DD94_930270A2_005CB501
  };

  // Compile-time random permutation for scrambling key/nonce register reset value
  parameter otp_ctrl_top_specific_pkg::scrmbl_key_init_t RndCnstOtpCtrlScrmblKeyInit = {
    256'hF833509A_CC7B3AA3_FA7DAC23_3E2B7823_06AF306A_1F36165E_E14A00EE_9FF9382A
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
      64'h4EC4E535184E7F9,
      256'h67BAA00A00025E7FC9BD14102DC30C29978A4C70C8DA26CB202F5F59A412A339
    }),
    960'({
      64'hC1C01FB83B84F2C9,
      256'h5EB6A7B2688A16B1C05693E7E037958183C9545358D14AAED1FCF0E1EDCB0316,
      256'h4A487A070E2D41C244CB7240CEE69DF76619E1BBA8167005EE5B59B17EF42013,
      256'hCC2B9D5A79CA02E338758DD6DE79680485CE6F2736649780ACF49BFADF4C4CEF,
      128'h628838F651B4B5E1188FD88EB8AEB542
    }),
    704'({
      64'hA6CB33A8A83B48B3,
      128'hFBC75FA47FD1EE356B0EE77C01530CB2,
      256'h10A9BD8A9D3ADE48339BAB0E6739719D66316FA6C7A2CFE54B57B94CCDB5B701,
      256'h34069D6201333F656283E5A7BD289D1E5E895532DB9EF56A3F39ACCE8428CD2F
    }),
    320'({
      64'h688918E0426DC8EF,
      128'hFC60FDA3EC7167EDF9CE31192D35CFE6,
      128'hAD9874386DBD4C92E0F24A7DB2A9D1F7
    }),
    384'({
      64'h0,
      64'h5DA85540174714B1,
      256'hA528E88DD62172CAFE980B4C39261457AF22D4755CDDD7CB28EF0FF7219351C5
    }),
    128'({
      64'hE15CA1E92A56FEA1,
      40'h0, // unallocated space
      8'h69,
      8'h69,
      8'h69
    }),
    320'({
      64'hE8C36577FE1AB3E0,
      256'hA6BC237A3081D9BCDD43BA90DE4CF7E1A302E95EC6D2AADEA8B6A9D4477ECD98
    }),
    192'({
      64'h0,
      128'h0
    }),
    128'({
      64'h502C03ACFF4AF30D,
      32'h0,
      32'h0
    }),
    128'({
      64'hF68D520B6DC525A3,
      32'h0,
      32'h0
    }),
    128'({
      64'hFF807F2F9D87437A,
      32'h0,
      32'h0
    }),
    128'({
      64'h50FABDC8F2937D8F,
      32'h0,
      32'h0
    }),
    960'({
      64'h0,
      64'hB7DBD27D94C9C8D9,
      32'h0,
      256'h0,
      512'h0,
      32'h0
    }),
    960'({
      64'h0,
      64'hF6DBA32A1E082D2A,
      32'h0,
      256'h0,
      512'h0,
      32'h0
    }),
    960'({
      64'h0,
      64'hEC203B9EB85C7EA3,
      32'h0,
      256'h0,
      512'h0,
      32'h0
    }),
    960'({
      64'h0,
      64'h668AFD034DC05DF9,
      32'h0,
      256'h0,
      512'h0,
      32'h0
    }),
    64'({
      64'h0
    }),
    4672'({
      64'hFD1F508AC4E1C5F6,
      224'h0, // unallocated space
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
    2688'({
      64'h187A352F7669266C,
      224'h0, // unallocated space
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
    128'hF33B4797_18558E67_59764645_AAD1FB21
  };

  // Diversification value used for the TEST_UNLOCKED* life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivTestUnlocked = {
    128'hC1812463_5E3D50A8_8F680804_5627AC18
  };

  // Diversification value used for the DEV life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivDev = {
    128'hF377D907_1BECA6F1_94EF96F3_E535B58F
  };

  // Diversification value used for the PROD/PROD_END life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivProduction = {
    128'h2ADAD82B_175FE9EA_1C326A66_10C11177
  };

  // Diversification value used for the RMA life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivRma = {
    128'h44DE61CC_BFABD3E1_FDA667E0_4082478C
  };

  // Compile-time random bits used for invalid tokens in the token mux
  parameter lc_ctrl_pkg::lc_token_mux_t RndCnstLcCtrlInvalidTokens = {
    256'h14DB070A_6129BB29_45B88DC6_CFCF2AE0_2F47010C_B666A5E2_2D3320F8_9CAA47E5,
    256'hCED5D29C_C9CDB468_773EBACE_C14DA34C_505AEDC7_0EA184C7_A34193D5_9C735B5B,
    256'h4E2CBEE5_AB93CB02_4D6F8C0C_700110CB_F01425DA_F5141DF1_9A882A71_D66B5953,
    256'hDBC60337_9DA9EFB2_069BD798_15B2F8D9_9A40E7FD_C4FB1314_3D7753CE_1CF9E202
  };

  ////////////////////////////////////////////
  // alert_handler
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter alert_handler_pkg::lfsr_seed_t RndCnstAlertHandlerLfsrSeed = {
    32'h92073969
  };

  // Compile-time random permutation for LFSR output
  parameter alert_handler_pkg::lfsr_perm_t RndCnstAlertHandlerLfsrPerm = {
    160'h263D4E08_D27DB7D2_FC60644E_D4E9D00D_6EA9AF28
  };

  ////////////////////////////////////////////
  // sram_ctrl_ret_aon
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlRetAonSramKey = {
    128'h818054E0_E0EDB0AC_D0B040FC_629EA7F8
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlRetAonSramNonce = {
    128'hB17FA88F_EE02E3F0_864223A2_E23A8CC3
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlRetAonLfsrSeed = {
    64'h1E2DE5E5_78D43D2D
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlRetAonLfsrPerm = {
    128'h38678252_6C4BD5D1_721F403A_F01A1066,
    256'h03D70D61_369EA24D_8CCBAFB2_4C3BE61A_51F88562_7CAF5B4D_A737AE5B_7F6384B3
  };

  ////////////////////////////////////////////
  // flash_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for default address key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlAddrKey = {
    128'h7118AF11_CDBE78D6_7060615A_20B9C074
  };

  // Compile-time random bits for default data key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlDataKey = {
    128'h0F07969C_CD2D10A1_A6E7988F_A528AC03
  };

  // Compile-time random bits for default seeds
  parameter flash_ctrl_top_specific_pkg::all_seeds_t RndCnstFlashCtrlAllSeeds = {
    256'h2E0A6138_CB8316FF_95C65CD7_A1A768B0_6E0106D6_0EDA0F1B_C67ADF85_BD9A56EA,
    256'h088D33FF_AA6A1155_AFB0169A_B2DE3973_D027EE30_B8F901F6_44EC7CD3_E56C8ED1
  };

  // Compile-time random bits for initial LFSR seed
  parameter flash_ctrl_top_specific_pkg::lfsr_seed_t RndCnstFlashCtrlLfsrSeed = {
    32'hEC38739F
  };

  // Compile-time random permutation for LFSR output
  parameter flash_ctrl_top_specific_pkg::lfsr_perm_t RndCnstFlashCtrlLfsrPerm = {
    160'h05ABE833_E7960BAC_9A24BEE9_C5892A6C_D0E7F423
  };

  ////////////////////////////////////////////
  // acc
  ////////////////////////////////////////////
  // Default seed of the PRNG used for URND.
  parameter acc_pkg::urnd_prng_seed_t RndCnstAccUrndPrngSeed = {
    256'hF31A0165_939D819D_1518690E_6473CDB2_47939163_5057CA10_45B9E191_7E1FF018
  };

  // Compile-time random reset value for IMem/DMem scrambling key.
  parameter otp_ctrl_pkg::acc_key_t RndCnstAccAccKey = {
    128'h9B04A4F7_FBA960FE_098A4FB9_D469171B
  };

  // Compile-time random reset value for IMem/DMem scrambling nonce.
  parameter otp_ctrl_pkg::acc_nonce_t RndCnstAccAccNonce = {
    64'h950E364B_0DAC5469
  };

  ////////////////////////////////////////////
  // aes
  ////////////////////////////////////////////
  // Default seed of the PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstAesClearingLfsrSeed = {
    64'h568E6614_98FD8919
  };

  // Permutation applied to the LFSR of the PRNG used for clearing.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingLfsrPerm = {
    128'hE771E48E_DD529CEE_F4BA8348_320E0928,
    256'h09566557_137842E1_F856B399_4622A46A_C1FDD0FC_45B3F65E_AC6CBF04_02F7AC9F
  };

  // Permutation applied to the clearing PRNG output for clearing the second share of registers.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingSharePerm = {
    128'h49F2A3B2_4CD710CF_F8BBACBD_1F4A000E,
    256'hB465AB90_A619E716_171EE077_C6EF3B66_09F99050_2143CDDD_AB69867D_5388BC15
  };

  // Default seed of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstAesMaskingLfsrSeed = {
    32'h0D58DC65,
    256'h508E869A_F565C1B8_7D687EE8_37FC119F_5BBE7395_CAC38919_C27006C2_3E142591
  };

  // Permutation applied to the output of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstAesMaskingLfsrPerm = {
    256'h32633B8D_506A4F98_92339135_1311550C_70390A43_61769A74_294B7887_219B8E68,
    256'h2E622C26_71730F96_10867C15_89371823_20465485_8C4C4909_80341664_1A192D06,
    256'h4A811F9F_99414D5F_450B1756_53608272_77036C27_053C837A_8B5A318A_9E2B1412,
    256'h0744471C_5C3D8430_0E5E586F_3E2F3897_69367E9D_9C656D02_7B88578F_7F93661D,
    256'h791E4890_59252428_1B956B3F_525B0D42_0194517D_3A006E67_224E5D75_2A044008
  };

  ////////////////////////////////////////////
  // kmac
  ////////////////////////////////////////////
  // Compile-time random data for PRNG default seed
  parameter kmac_pkg::lfsr_seed_t RndCnstKmacLfsrSeed = {
    32'h0CA53491,
    256'h1723E1EA_0687402A_816510C5_35A81649_39D97DF7_421AD4D2_C18B270D_422EC39C
  };

  // Compile-time random permutation for PRNG output
  parameter kmac_pkg::lfsr_perm_t RndCnstKmacLfsrPerm = {
    64'h9FD5D3AC_E7966BDC,
    256'h2922A394_6B9C1CAC_4E218A34_69CF5272_588602C1_F83E0181_E53267BC_5841A1B5,
    256'hA9CAC86A_64AC8FA9_F69F7B0F_E6F89A74_E0176C6B_3C56784E_B4C5DC4C_38447ACD,
    256'hB1C0EE7C_62D97D3A_9111F93E_D2AB4D88_84A74309_60DDDA59_60E9CD6B_704A3026,
    256'h46455831_ECD71DD8_501EDB9E_AB06CED8_6A999A25_754094F6_A58CC3E4_843D3537,
    256'h82F61D1D_41A386E2_83549FA4_27181312_30167452_EDE7FDF3_00E049C2_200A4016,
    256'hD1E1648C_8BBC028C_47832A24_012CB5CC_A03A072A_65003023_6A40D099_89E5E57D,
    256'hAB05F22E_0068DC25_9AC8261E_34D12033_61687F10_8B1A277A_5C71825C_65D83059,
    256'hA3754798_15BC745C_BB51A083_0B1B9CD9_46FF9944_B050F05C_5141BEC5_1C66AA6E,
    256'h355A0AE3_EEAB5F15_A18F0324_E56A45FE_605E4781_AE619EE7_290505E4_12D9F635,
    256'h2123D0EA_B656F750_28732338_FEBB6DD7_844AF9BB_19051155_C7C114F6_7E2662A5,
    256'h013FA495_7C457B51_715442F7_38CF896E_232AA11B_F65A3B5B_DACCB7A8_6B9B1DF2,
    256'h4783AA96_FBBA8DCC_31267882_DA367216_AA603118_C15BFB2A_6884197C_19047A71,
    256'h3B446D0C_93792663_BF2E09D7_020566D2_6E303316_C738C481_6179552A_0D4AD2C2,
    256'hD665A0A1_F1D22E5E_8695CF07_4A4542AE_3FCB108E_A82CAA45_85DF5C2D_F3F4E564,
    256'hC16BBAF6_93A84809_7A473097_E2F8AA9B_609AA39D_DFC7F46C_2464511D_0A870F35,
    256'hDDC01D88_A369087D_1A858994_3B2976F2_9C17625A_FCD14B28_2210C620_2712CE88,
    256'h7BDF7B01_D6536D09_1C949F23_EAD4E644_5F977066_95E79148_9D0F22E9_2C554C48,
    256'hDC028555_B1221441_2AC0EB10_5063A393_2464B068_649D499E_EA070EDA_0C57F0BA,
    256'h6B4F18D8_21C9242F_40C01BC7_2F5B3ABC_C1EBEB30_F25CA420_9D177EE5_D43574BA,
    256'h619A288C_8A29410E_15984D63_54833DCD_28995E0F_D2EADB1E_4E65307C_606C2A91,
    256'h1400566E_1A4EC280_D295A6D4_6C58FBCC_2A629132_A6527980_A2A11B12_4CFAE2E6,
    256'h88B1616D_B91A637B_5C58C6AF_04658B90_D58091B2_B70191E5_BA3862F3_914175CA,
    256'hF4395452_85717812_08AB786E_FA185388_24BF7A8F_C82DD0B8_D4812136_0E7144BC,
    256'h3D0AD212_055C2884_6745A0A6_AE50EC88_9517E796_0D164344_5A1E2959_51CC36B5,
    256'h4824CD28_4ADF5A00_955D8C7A_BCBD9B84_A6AD6E03_EBA239AF_670C5B4C_331447A8,
    256'h19248EDA_1979C721_CE04C21D_249322EE_DD674BE1_96EB32C4_0B0E4D54_4B5B2629,
    256'h338422F0_0DC3687A_7A14B356_39D99B3B_D535831B_34E07A31_899884FB_C93EC11A,
    256'h66B26F49_4217559E_0696AA76_40A2D4E7_9C4D6619_FA599104_C106206A_36580A88,
    256'h08508758_F03823EF_E25CB48E_854225F0_30ACF3A6_3214CF94_B6279E1D_D9A4F65B,
    256'h474A3EE8_5914372D_03159ED2_980B765A_D6EC86A0_6E2B193B_693011FE_4AC20BA0,
    256'h604E7160_C2E24C72_29883C67_8F4DF1F5_018AE50A_555F608A_142EE49B_0C327D07
  };

  // Compile-time random data for PRNG buffer default seed
  parameter kmac_pkg::buffer_lfsr_seed_t RndCnstKmacBufferLfsrSeed = {
    32'hF0C5DE01,
    256'h9FC073C4_C599518B_F1924441_728893C6_52D73724_32FCC4D3_092BD638_3FDBA352,
    256'h79FCBCD2_BD2C1319_E71A293A_C3249AFC_143E8770_E304FEE2_D365DA6C_4A29010A,
    256'h99EAED07_3BCBD6E3_EAFA23F4_8EEE34D3_1387B45B_91CE49E4_E6B58794_1D1EEC35
  };

  // Compile-time random permutation for LFSR Message output
  parameter kmac_pkg::msg_perm_t RndCnstKmacMsgPerm = {
    128'h0E63C8A4_D623AA07_34B5277B_242DB3E9,
    256'h9F313384_6457F3B5_5E89C7FB_00327F91_A112C165_2C1F5B2A_F5AE4DED_D052B89A
  };

  ////////////////////////////////////////////
  // keymgr
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter keymgr_pkg::lfsr_seed_t RndCnstKeymgrLfsrSeed = {
    64'h3335C20C_C778FC30
  };

  // Compile-time random permutation for LFSR output
  parameter keymgr_pkg::lfsr_perm_t RndCnstKeymgrLfsrPerm = {
    128'h59E4CEF8_27C1E4C3_444AB2BF_029C15D6,
    256'h81FD9D4B_1AD21BF3_97A8F70F_620992D3_D16FC43B_2D9C4681_87578B8A_9CCAE166
  };

  // Compile-time random permutation for entropy used in share overriding
  parameter keymgr_pkg::rand_perm_t RndCnstKeymgrRandPerm = {
    160'h70B73C52_DF449212_0FCB2815_1C9F55BF_0CC7F5B0
  };

  // Compile-time random bits for revision seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrRevisionSeed = {
    256'hD902019D_ABB6DD57_022C77ED_E8609C40_9D905B3C_7819B26A_67432881_9928C5D7
  };

  // Compile-time random bits for creator identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrCreatorIdentitySeed = {
    256'h9BF1DB63_D11E1C31_BBC9A8C7_3FC4CC3D_14CA6BC0_B96812DE_7C775A54_FF19343C
  };

  // Compile-time random bits for owner intermediate identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrOwnerIntIdentitySeed = {
    256'hB32040B3_49076888_9D27E0BA_8588D34C_05BCF127_DAE58B65_D6A25108_8099B371
  };

  // Compile-time random bits for owner identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrOwnerIdentitySeed = {
    256'h07B1CCCF_1A955F03_DE1A8447_BF83B69C_50E149CF_51784A9D_7AC69130_6E5C56CE
  };

  // Compile-time random bits for software generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrSoftOutputSeed = {
    256'h38CD7D7E_3B1ABFB7_978189A2_1AE856F1_D908E3F7_0DE343D2_226E9E86_4465A8EE
  };

  // Compile-time random bits for hardware generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrHardOutputSeed = {
    256'h55EC0E6A_296789DE_D5C0AF59_EE62F1FD_1BBEBEAC_2205B1FA_5E94E72E_B7EB1A71
  };

  // Compile-time random bits for generation seed when aes destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrAesSeed = {
    256'h3AD15D25_65D9AB4F_BCD2E17C_406F48D1_401F8A6A_52286F69_54C27A9A_EFBE0BC9
  };

  // Compile-time random bits for generation seed when kmac destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrKmacSeed = {
    256'hEE440C51_4CCACB01_9995F31F_A9588592_93C5591A_E604A92A_303760EB_8D7785A7
  };

  // Compile-time random bits for generation seed when acc destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrAccSeed = {
    256'hBBDCE1D6_A02B6F0F_24F5DB8E_F02F9FB0_A4023D8F_96A41F06_2BB66B22_8701E831
  };

  // Compile-time random bits for generation seed when no CDI is selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrCdi = {
    256'h7CD4BF08_BD6684A1_D596CC57_E137A032_1FB803BF_D2DE7A90_A1357E74_3CE46044
  };

  // Compile-time random bits for generation seed when no destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrNoneSeed = {
    256'h2C10686E_82613DE0_806DDE1D_35AD6160_EE7EF482_22DAD72D_4D6289ED_D5F001DC
  };

  ////////////////////////////////////////////
  // csrng
  ////////////////////////////////////////////
  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivNonProduction = {
    128'hD4095890_A290A9B6_32F0395D_11CAC7F7,
    256'hE9E764AD_D7EDE232_A4E00DAB_F1D1D2AD_2E2A5133_F6A12FF2_EC1569BE_F1F0B924
  };

  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivProduction = {
    128'hC470AC5A_99809985_DC415BA1_EACED382,
    256'hD54C9E37_8D030EA5_D37665D4_3A035F4E_A1E46303_2A3A8E24_B4547F8B_0DB0C77E
  };

  ////////////////////////////////////////////
  // sram_ctrl_main
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMainSramKey = {
    128'h902776B1_04C3A9DA_02030621_A4D3D738
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMainSramNonce = {
    128'h71FDAF5A_D0C1DD1E_95F99D71_29CA6861
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMainLfsrSeed = {
    64'hA4425B9C_C42EDBA8
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMainLfsrPerm = {
    128'h6B879784_62C36608_C73D622A_B25D09CF,
    256'h507FDA8C_50540F7B_3BA73947_EACA7C2C_92353DE9_6C475832_FC249AE9_FC52D162
  };

  ////////////////////////////////////////////
  // rom_ctrl
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrlScrNonce = {
    64'h44680CE9_3649A845
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrlScrKey = {
    128'h75B46547_9F31A975_234377E0_0D28EC32
  };

  ////////////////////////////////////////////
  // rv_core_ibex
  ////////////////////////////////////////////
  // Default seed of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_seed_t RndCnstRvCoreIbexLfsrSeed = {
    32'hFA5850E8
  };

  // Permutation applied to the LFSR of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_perm_t RndCnstRvCoreIbexLfsrPerm = {
    160'h67441359_D7E0D674_2A3B6E33_093C89D5_4B3F83D4
  };

  // Default icache scrambling key
  parameter logic [ibex_pkg::SCRAMBLE_KEY_W-1:0] RndCnstRvCoreIbexIbexKeyDefault = {
    128'h1AAD174D_D41ACA70_D3807BA5_4E793023
  };

  // Default icache scrambling nonce
  parameter logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] RndCnstRvCoreIbexIbexNonceDefault = {
    64'hFA711994_CCF5D2F4
  };

endpackage : top_egret_rnd_cnst_pkg
