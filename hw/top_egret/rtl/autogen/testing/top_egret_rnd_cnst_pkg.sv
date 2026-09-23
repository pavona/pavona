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
    40'h57_878A468D
  };

  // Compile-time random permutation for LFSR output
  parameter otp_ctrl_top_specific_pkg::lfsr_perm_t RndCnstOtpCtrlLfsrPerm = {
    240'h9E04_5F2C2590_88949E61_A9818C60_178456C4_95C5073D_94CA31D9_0D3950C8
  };

  // Compile-time random permutation for scrambling key/nonce register reset value
  parameter otp_ctrl_top_specific_pkg::scrmbl_key_init_t RndCnstOtpCtrlScrmblKeyInit = {
    256'h67597646_45AAD1FB_21C18124_635E3D50_A88F6808_045627AC_18F377D9_071BECA6
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
  parameter logic [32767:0] RndCnstOtpCtrlPartInvDefault = {
    704'({
      320'h12107E5F937092382CB21F6ABCDC9A608A8E59E8CC6315D2495CA878EB2975046FD5443C2CB8B75A,
      384'h2B9403C190120BB318A937E66A6DF253E7DAA2EA63EA3209A1832965B9E9EB47171184A5B1C2CBB244E91725013B44B5
    }),
    384'({
      64'h0,
      64'h256DC69CA2BFCE,
      256'h67BAA00A00025E7FC9BD14102DC30C29978A4C70C8DA26CB202F5F59A412A339
    }),
    960'({
      64'hC9BB5C13BB8B59B0,
      256'h5EB6A7B2688A16B1C05693E7E037958183C9545358D14AAED1FCF0E1EDCB0316,
      256'h4A487A070E2D41C244CB7240CEE69DF76619E1BBA8167005EE5B59B17EF42013,
      256'hCC2B9D5A79CA02E338758DD6DE79680485CE6F2736649780ACF49BFADF4C4CEF,
      128'h628838F651B4B5E1188FD88EB8AEB542
    }),
    704'({
      64'hDF6859B6EC2E82EC,
      128'hFBC75FA47FD1EE356B0EE77C01530CB2,
      256'h10A9BD8A9D3ADE48339BAB0E6739719D66316FA6C7A2CFE54B57B94CCDB5B701,
      256'h34069D6201333F656283E5A7BD289D1E5E895532DB9EF56A3F39ACCE8428CD2F
    }),
    320'({
      64'hD6676D1479CCE4FD,
      128'hFC60FDA3EC7167EDF9CE31192D35CFE6,
      128'hAD9874386DBD4C92E0F24A7DB2A9D1F7
    }),
    384'({
      64'h0,
      64'h4EC4E535184E7F9,
      256'hA528E88DD62172CAFE980B4C39261457AF22D4755CDDD7CB28EF0FF7219351C5
    }),
    128'({
      64'hC1C01FB83B84F2C9,
      40'h0, // unallocated space
      8'h69,
      8'h69,
      8'h69
    }),
    320'({
      64'hA6CB33A8A83B48B3,
      256'hA6BC237A3081D9BCDD43BA90DE4CF7E1A302E95EC6D2AADEA8B6A9D4477ECD98
    }),
    640'({
      64'h0,
      576'h0
    }),
    64'({
      64'h688918E0426DC8EF
    }),
    64'({
      64'h5DA85540174714B1
    }),
    128'({
      64'h0,
      64'hE15CA1E92A56FEA1
    }),
    8256'({
      64'h0,
      8192'h0
    }),
    128'({
      64'hE8C36577FE1AB3E0,
      32'h0,
      32'h0
    }),
    128'({
      64'h502C03ACFF4AF30D,
      32'h0,
      32'h0
    }),
    192'({
      64'hF68D520B6DC525A3,
      32'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    192'({
      64'hFF807F2F9D87437A,
      32'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    960'({
      64'h0,
      64'h50FABDC8F2937D8F,
      32'h0,
      256'h0,
      512'h0,
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
    6400'({
      64'h0,
      64'h668AFD034DC05DF9,
      128'h0,
      6144'h0
    }),
    64'({
      64'h0
    }),
    5120'({
      64'hFD1F508AC4E1C5F6,
      672'h0, // unallocated space
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
    3136'({
      64'h187A352F7669266C,
      672'h0, // unallocated space
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
    128'hF194EF96_F3E535B5_8F2ADAD8_2B175FE9
  };

  // Diversification value used for the TEST_UNLOCKED* life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivTestUnlocked = {
    128'hEA1C326A_6610C111_7744DE61_CCBFABD3
  };

  // Diversification value used for the DEV life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivDev = {
    128'hE1FDA667_E0408247_8C14DB07_0A6129BB
  };

  // Diversification value used for the PROD/PROD_END life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivProduction = {
    128'h2945B88D_C6CFCF2A_E02F4701_0CB666A5
  };

  // Diversification value used for the RMA life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivRma = {
    128'hE22D3320_F89CAA47_E5CED5D2_9CC9CDB4
  };

  // Compile-time random bits used for invalid tokens in the token mux
  parameter lc_ctrl_pkg::lc_token_mux_t RndCnstLcCtrlInvalidTokens = {
    256'h68773EBA_CEC14DA3_4C505AED_C70EA184_C7A34193_D59C735B_5B4E2CBE_E5AB93CB,
    256'h024D6F8C_0C700110_CBF01425_DAF5141D_F19A882A_71D66B59_53DBC603_379DA9EF,
    256'hB2069BD7_9815B2F8_D99A40E7_FDC4FB13_143D7753_CE1CF9E2_02920739_6945C95C,
    256'h9B54BAE6_AEF30D85_77834CCC_6CAAA63A_8E660433_8151B9A2_3C08F9EE_D04CA1EB
  };

  ////////////////////////////////////////////
  // alert_handler
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter alert_handler_pkg::lfsr_seed_t RndCnstAlertHandlerLfsrSeed = {
    32'hB0BDD305
  };

  // Compile-time random permutation for LFSR output
  parameter alert_handler_pkg::lfsr_perm_t RndCnstAlertHandlerLfsrPerm = {
    160'h950BD4AD_A63B8371_E844D822_F9B119AF_95C862DF
  };

  ////////////////////////////////////////////
  // sram_ctrl_ret_aon
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlRetAonSramKey = {
    128'hB594ACDD_F170684F_6EAD2B7F_EBFE8955
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlRetAonSramNonce = {
    128'h23D7BC48_46A48595_6C7F904B_9EDED09B
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlRetAonLfsrSeed = {
    64'h89A75433_566F4963
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlRetAonLfsrPerm = {
    128'h625F508C_DA39A480_F25A750A_4ED15200,
    256'h16FE2E23_3A6A65D9_13571DC5_F3D1AD5C_F43B0806_0A486FFE_A7AEE07B_3BF09DF6
  };

  ////////////////////////////////////////////
  // flash_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for default address key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlAddrKey = {
    128'h06D60EDA_0F1BC67A_DF85BD9A_56EA088D
  };

  // Compile-time random bits for default data key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlDataKey = {
    128'h33FFAA6A_1155AFB0_169AB2DE_3973D027
  };

  // Compile-time random bits for default seeds
  parameter flash_ctrl_top_specific_pkg::all_seeds_t RndCnstFlashCtrlAllSeeds = {
    256'hEE30B8F9_01F644EC_7CD3E56C_8ED1EC38_739F1D0D_EB7C7741_99CF6DD0_57F44C13,
    256'hE25C7A58_77BC5242_E6EE63EC_DF458AE6_596E87F9_F973DB98_AAA29356_8FD1F31A
  };

  // Compile-time random bits for initial LFSR seed
  parameter flash_ctrl_top_specific_pkg::lfsr_seed_t RndCnstFlashCtrlLfsrSeed = {
    32'h0165939D
  };

  // Compile-time random permutation for LFSR output
  parameter flash_ctrl_top_specific_pkg::lfsr_perm_t RndCnstFlashCtrlLfsrPerm = {
    160'h79A3FBF3_C506F1A3_A564ED15_9AC91673_02D18A70
  };

  ////////////////////////////////////////////
  // acc
  ////////////////////////////////////////////
  // Default seed of the PRNG used for URND.
  parameter acc_pkg::urnd_prng_seed_t RndCnstAccUrndPrngSeed = {
    256'hD469171B_950E364B_0DAC5469_568E6614_98FD8919_7CCAE8EA_08FF43EF_C2BFB1C6
  };

  // Compile-time random reset value for IMem/DMem scrambling key.
  parameter otp_ctrl_pkg::acc_key_t RndCnstAccAccKey = {
    128'hAB5CC63E_6F4741E8_0F777CB7_FC05041A
  };

  // Compile-time random reset value for IMem/DMem scrambling nonce.
  parameter otp_ctrl_pkg::acc_nonce_t RndCnstAccAccNonce = {
    64'h1B896350_C9636D68
  };

  ////////////////////////////////////////////
  // aes
  ////////////////////////////////////////////
  // Default seed of the PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstAesClearingLfsrSeed = {
    64'h14D23E2F_5FF1275E
  };

  // Permutation applied to the LFSR of the PRNG used for clearing.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingLfsrPerm = {
    128'h7F2E3173_71580D7E_4F89B0BA_323AC494,
    256'h791D37D5_104FB9D1_2F6F801A_C809B8A6_88A4EC34_66F7B385_2575068B_7FA969BC
  };

  // Permutation applied to the clearing PRNG output for clearing the second share of registers.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingSharePerm = {
    128'h563918B7_56A10EE9_9FAD95C9_39E0A858,
    256'hDA9CCF19_4AC9BA41_23C412ED_11F7BCB3_FF77A006_F629F0F8_4D8CE39B_05513834
  };

  // Default seed of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstAesMaskingLfsrSeed = {
    32'h75ECC25D,
    256'h4E2267E3_BFF26E00_3AACBF7D_513AEA01_E9EE420D_5B523F6B_00C81BDE_D7282425
  };

  // Permutation applied to the output of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstAesMaskingLfsrPerm = {
    256'h1832345C_0A52743B_753D5019_44703F87_919F6915_06435D2D_8C821026_8B042A28,
    256'h0D472353_677F420F_86222E21_649B5885_4D14111B_4F4B3894_788E9749_245B1A1D,
    256'h548A655F_16099660_2073992B_00133046_4089774A_6E7D6836_2C2F3533_5A0C6B9C,
    256'h571F934E_664C4172_12450B17_9E6A8351_927A079D_318F026D_803E2795_6F903C76,
    256'h037E6263_8D815629_250E8839_7B611C7C_5E716C08_55059837_849A3A79_1E480159
  };

  ////////////////////////////////////////////
  // kmac
  ////////////////////////////////////////////
  // Compile-time random data for PRNG default seed
  parameter kmac_pkg::lfsr_seed_t RndCnstKmacLfsrSeed = {
    32'h30ED9B18,
    256'hB90E42E4_287F60AD_57D6A551_E78F940B_8AE9F2BB_40621F43_F3ABD8D7_37F8D12D
  };

  // Compile-time random permutation for PRNG output
  parameter kmac_pkg::lfsr_perm_t RndCnstKmacLfsrPerm = {
    64'h6DA99801_7028CC32,
    256'h59857614_F0F9F755_49F3227A_3BA8E64C_2F355C29_AAAA3D51_5AE6110B_1BE078FA,
    256'h55EE584E_7CA68DE2_804CB300_67ED0271_204751F1_6CD1F95C_77B2AFE7_69F42DA4,
    256'h2549F601_5FC64A70_576DEB49_C6ACD967_90FE38A7_129D6807_24E271DC_BE9EC5E5,
    256'hA898E311_11408086_B9F71A30_47B5B237_0DDEB8FA_2D78A1F3_5C9EB993_A7FE5545,
    256'h009AECF4_360C0C76_7935068B_5E3074E8_30A00777_8F13C2BE_18ABD9B0_D02B259B,
    256'hADB883B1_E7E16F36_D977B907_4F47E00D_674D27E8_A829005D_F5119A5C_67FAC402,
    256'h4FE931E0_E7B062E0_12494169_2268171C_AA5B5672_60A9B8E5_7886584B_027B17C8,
    256'hB4255B99_0CA4D498_51A50C65_DB402203_364772A1_A99A5B65_312C7C25_285E9375,
    256'hA93EDBDA_554C9956_64485CBF_123082E3_1B8EB441_457CAC81_2C144817_C4746F56,
    256'h8719D6BA_705733A0_AE6F1AA8_161C18E1_524E6068_F0060D7D_3A9AE8D9_65C39995,
    256'hEA2443C1_14328926_5227E69C_BBAB837D_878CE5A8_8B0638CF_8A2B1B46_8AAA82EF,
    256'h8D4ED732_742DEAD6_D6D410D1_E0EAAB80_54B37175_499F30B6_B08585A5_7C0C4631,
    256'h4C1EDF82_A73701A7_C55047E9_016306D0_C93794E1_7AFEEDA0_20805547_BD49BBA4,
    256'hCC6FDD23_11FD8865_F4A8352B_4B0919E8_AD07C78C_B9861B47_801D2915_05ACFF2C,
    256'h423AD4B2_A9161BB1_7B958FD3_969405AF_4C1658BF_7186191C_9B4F794B_0B8A1810,
    256'h9AAFA083_F4B86C24_64F11D0A_898F35DD_CF1D88A6_40DA4226_B6DD62B6_1A23B2A3,
    256'hB0EA8176_3FC20D14_B1A5A348_43188035_8B39148C_20ECDB4D_4DB76512_52B2922C,
    256'h23991134_B0419A61_A1052274_3C8E1E11_55312369_1A41561F_485104AB_039D6141,
    256'h8E90CC91_92CE841C_E7352752_686AB1C3_B9C315FC_2EADD3C6_36127249_0C0C3006,
    256'hE777FADB_B2716B2E_D93C9728_942745D5_E99D0D5D_2F788E68_8D30AA22_85419EFC,
    256'h3C70C464_B4E65D07_C606C2B6_11400566_DCA7EA98_0D295A6E_16C58FC0_82A62913,
    256'h2A65C798_0A2A11B1_24CFB16F_68B2A116_DB91A641_B905842E_FF4658BA_9D58091B,
    256'h2910191E_5BA3862F_3914175C_AF439545_28571781_208AC486_F0918538_824BF7A8,
    256'hFC82DD0B_C1481213_60E62B4B_C3D0AD21_2055C288_46745A0A_9AF20EC8_89517E79,
    256'h60D16434_BE116878_A5654730_DB0C2093_34A12B7D_6D125576_31EBC2F6_6E129AB5,
    256'hB80FB1C8_E6BD9C31_6E00CC51_1EA06492_3B6865E7_1C873813_0874924C_8BBA5EEA,
    256'h674BE196_F932C40B_424D544B_5B5A2933_8422F00D_C72AEA1E_9E852DA5_8E7666CE,
    256'hF54D60BC_4D381E8C_6266213F_104FB136_99AC9BD2_5085D567_81A5AA9D_9028B539,
    256'hE7135986_7E966441_3041881A_8D9602A2_021421D6_3C0E08FC_34972D23_A150897C,
    256'h0C2B3CE9_8C8533E5_2D89E78B_CDDD9A4F_65B6FB1D_28FBA164_50DCB40C_567B4A60,
    256'h2DD96B5B_B21A81B8_AC64EDA4_C047F92B_172E8181_39C5830B_8931C8A6_20F19E3D
  };

  // Compile-time random data for PRNG buffer default seed
  parameter kmac_pkg::buffer_lfsr_seed_t RndCnstKmacBufferLfsrSeed = {
    32'hBD2C1319,
    256'hE71A293A_C3249AFC_143E8770_E304FEE2_D365DA6C_4A29010A_99EAED07_3BCBD6E3,
    256'hEAFA23F4_8EEE34D3_1387B45B_91CE49E4_E6B58794_1D1EEC35_6888AE53_43DD784C,
    256'hBA5BEBBE_2A6EAD06_2D9516FD_D8B11086_1A797CB6_84A3032D_DAC2DA88_D91CB185
  };

  // Compile-time random permutation for LFSR Message output
  parameter kmac_pkg::msg_perm_t RndCnstKmacMsgPerm = {
    128'h025169E2_F243B307_1A371EA1_439DED46,
    256'h43A2C93F_CF781606_31BBA057_D1FE5089_D210BECA_D280999A_3D96AB57_7C5F3ADF
  };

  ////////////////////////////////////////////
  // keymgr
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter keymgr_pkg::lfsr_seed_t RndCnstKeymgrLfsrSeed = {
    64'hBCF7A824_20750E5D
  };

  // Compile-time random permutation for LFSR output
  parameter keymgr_pkg::lfsr_perm_t RndCnstKeymgrLfsrPerm = {
    128'h3826D361_45B622B2_4113BDCB_16A2B366,
    256'hD69589C1_B9C3A8F1_A26B0D0D_19509E10_2EFAFC87_F604A9D3_C7DEE0C7_64D4F5FF
  };

  // Compile-time random permutation for entropy used in share overriding
  parameter keymgr_pkg::rand_perm_t RndCnstKeymgrRandPerm = {
    160'h6A7171BF_59A089F3_44303AE4_8E31C5EA_AD59F81B
  };

  // Compile-time random bits for revision seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrRevisionSeed = {
    256'h31BBC9A8_C73FC4CC_3D14CA6B_C0B96812_DE7C775A_54FF1934_3CB32040_B3490768
  };

  // Compile-time random bits for creator identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrCreatorIdentitySeed = {
    256'h889D27E0_BA8588D3_4C05BCF1_27DAE58B_65D6A251_088099B3_7107B1CC_CF1A955F
  };

  // Compile-time random bits for owner intermediate identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrOwnerIntIdentitySeed = {
    256'h03DE1A84_47BF83B6_9C50E149_CF51784A_9D7AC691_306E5C56_CE38CD7D_7E3B1ABF
  };

  // Compile-time random bits for owner identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrOwnerIdentitySeed = {
    256'hB7978189_A21AE856_F1D908E3_F70DE343_D2226E9E_864465A8_EE55EC0E_6A296789
  };

  // Compile-time random bits for software generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrSoftOutputSeed = {
    256'hDED5C0AF_59EE62F1_FD1BBEBE_AC2205B1_FA5E94E7_2EB7EB1A_713AD15D_2565D9AB
  };

  // Compile-time random bits for hardware generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrHardOutputSeed = {
    256'h4FBCD2E1_7C406F48_D1401F8A_6A52286F_6954C27A_9AEFBE0B_C9EE440C_514CCACB
  };

  // Compile-time random bits for generation seed when aes destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrAesSeed = {
    256'h019995F3_1FA95885_9293C559_1AE604A9_2A303760_EB8D7785_A7BBDCE1_D6A02B6F
  };

  // Compile-time random bits for generation seed when kmac destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrKmacSeed = {
    256'h0F24F5DB_8EF02F9F_B0A4023D_8F96A41F_062BB66B_228701E8_317CD4BF_08BD6684
  };

  // Compile-time random bits for generation seed when acc destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrAccSeed = {
    256'hA1D596CC_57E137A0_321FB803_BFD2DE7A_90A1357E_743CE460_442C1068_6E82613D
  };

  // Compile-time random bits for generation seed when no CDI is selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrCdi = {
    256'hE0806DDE_1D35AD61_60EE7EF4_8222DAD7_2D4D6289_EDD5F001_DCD40958_90A290A9
  };

  // Compile-time random bits for generation seed when no destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrNoneSeed = {
    256'hB632F039_5D11CAC7_F7E9E764_ADD7EDE2_32A4E00D_ABF1D1D2_AD2E2A51_33F6A12F
  };

  ////////////////////////////////////////////
  // csrng
  ////////////////////////////////////////////
  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivNonProduction = {
    128'hF2EC1569_BEF1F0B9_24C470AC_5A998099,
    256'h85DC415B_A1EACED3_82D54C9E_378D030E_A5D37665_D43A035F_4EA1E463_032A3A8E
  };

  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivProduction = {
    128'h24B4547F_8B0DB0C7_7E902776_B104C3A9,
    256'hDA020306_21A4D3D7_3871FDAF_5AD0C1DD_1E95F99D_7129CA68_61A4425B_9CC42EDB
  };

  ////////////////////////////////////////////
  // sram_ctrl_main
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMainSramKey = {
    128'hA88A15B7_52539FB8_E598F891_C2BD3162
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMainSramNonce = {
    128'h77126EA6_934D3749_740A7CE7_C92A49F7
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMainLfsrSeed = {
    64'h1747D5A7_E3B7E444
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMainLfsrPerm = {
    128'h5D24753F_F8DA0D8B_30C721EB_59477DB7,
    256'h7D2893B2_C841F34C_D858957B_A1AF05B9_BE9594E0_B840B9CF_8F0986A0_27A4E29C
  };

  ////////////////////////////////////////////
  // rom_ctrl
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrlScrNonce = {
    64'hADE12AF0_DD48B922
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrlScrKey = {
    128'h7A978179_AA2E6ADC_5EA5FD83_777D3877
  };

  ////////////////////////////////////////////
  // rv_core_ibex
  ////////////////////////////////////////////
  // Default seed of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_seed_t RndCnstRvCoreIbexLfsrSeed = {
    32'h66BA9E8C
  };

  // Permutation applied to the LFSR of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_perm_t RndCnstRvCoreIbexLfsrPerm = {
    160'h65B0DBF4_A08A15A9_84F221B7_9F3E1FE2_4551AE8E
  };

  // Default icache scrambling key
  parameter logic [ibex_pkg::SCRAMBLE_KEY_W-1:0] RndCnstRvCoreIbexIbexKeyDefault = {
    128'h9DA8413D_DA43FECD_D6C1A586_93232D1C
  };

  // Default icache scrambling nonce
  parameter logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] RndCnstRvCoreIbexIbexNonceDefault = {
    64'h3E361D85_6AB2D1DC
  };

endpackage : top_egret_rnd_cnst_pkg
