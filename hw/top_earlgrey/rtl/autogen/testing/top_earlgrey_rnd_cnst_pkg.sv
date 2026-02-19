// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/topgen.py -t hw/top_earlgrey/data/top_earlgrey.hjson
//                -o hw/top_earlgrey/
//
// File is generated based on the following seed configuration:
//   hw/top_earlgrey/data/top_earlgrey_seed.testing.hjson


package top_earlgrey_rnd_cnst_pkg;

  ////////////////////////////////////////////
  // otp_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter otp_ctrl_top_specific_pkg::lfsr_seed_t RndCnstOtpCtrlLfsrSeed = {
    40'hAB_60DA8B65
  };

  // Compile-time random permutation for LFSR output
  parameter otp_ctrl_top_specific_pkg::lfsr_perm_t RndCnstOtpCtrlLfsrPerm = {
    240'h3D30_E520D90C_60400150_98DE85C1_5268A98B_1D788255_141D3995_A07C69DB
  };

  // Compile-time random permutation for scrambling key/nonce register reset value
  parameter otp_ctrl_top_specific_pkg::scrmbl_key_init_t RndCnstOtpCtrlScrmblKeyInit = {
    256'hE933D88E_2E1CF654_60F23FB7_80499E6F_CCE64CEA_FD282C0E_33FD2C07_986C2A51
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

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst0 = {
    128'hEA1EA059_DC5C584C_99E3E946_397824F3
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst1 = {
    128'hC0A5A56F_968FD7E9_8071EF1B_FF0C99F0
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst2 = {
    128'hC02ABD64_5FC814BC_BC1CFCFF_9F3E4CD4
  };

  // Compile-time digest const
  parameter otp_ctrl_top_specific_pkg::digest_const_t RndCnstOtpCtrlDigestConst3 = {
    128'h2214D762_08E9943A_43242540_D2120889
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV0 = {
    64'h9ACF416A_D5455D1D
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV1 = {
    64'h74E7B5C1_5957663A
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV2 = {
    64'h7A827E95_A7385B32
  };

  // Compile-time digest initial vector
  parameter otp_ctrl_top_specific_pkg::digest_iv_t RndCnstOtpCtrlDigestIV3 = {
    64'hFE6728D0_D0879EC6
  };

  // OTP invalid partition default for buffered partitions
  parameter logic [16383:0] RndCnstOtpCtrlPartInvDefault = {
    704'({
      320'h67BAA00A00025E7FC9BD14102DC30C29978A4C70C8DA26CB202F5F59A412A3392B9403C190120BB3,
      384'h6619E1BBA8167005EE5B59B17EF420135EB6A7B2688A16B1C05693E7E037958183C9545358D14AAED1FCF0E1EDCB0316
    }),
    704'({
      64'h6FD5443C2CB8B75A,
      256'h85CE6F2736649780ACF49BFADF4C4CEF4A487A070E2D41C244CB7240CEE69DF7,
      256'h628838F651B4B5E1188FD88EB8AEB542CC2B9D5A79CA02E338758DD6DE796804,
      128'hFBC75FA47FD1EE356B0EE77C01530CB2
    }),
    704'({
      64'h495CA878EB297504,
      128'h66316FA6C7A2CFE54B57B94CCDB5B701,
      256'h5E895532DB9EF56A3F39ACCE8428CD2F10A9BD8A9D3ADE48339BAB0E6739719D,
      256'hFC60FDA3EC7167EDF9CE31192D35CFE634069D6201333F656283E5A7BD289D1E
    }),
    320'({
      64'h8A8E59E8CC6315D2,
      128'hAD9874386DBD4C92E0F24A7DB2A9D1F7,
      128'hAF22D4755CDDD7CB28EF0FF7219351C5
    }),
    128'({
      64'h2CB21F6ABCDC9A60,
      40'h0, // unallocated space
      8'h69,
      8'h69,
      8'h69
    }),
    576'({
      64'h12107E5F93709238,
      256'hA302E95EC6D2AADEA8B6A9D4477ECD98A528E88DD62172CAFE980B4C39261457,
      256'hE17E956C21B003D0BCB1CBCD1EB02317A6BC237A3081D9BCDD43BA90DE4CF7E1
    }),
    320'({
      64'h44E91725013B44B5,
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
      64'h171184A5B1C2CBB2,
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
    5696'({
      64'hA1832965B9E9EB47,
      96'h0, // unallocated space
      1024'h0,
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
    2944'({
      64'hE7DAA2EA63EA3209,
      96'h0, // unallocated space
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
      64'h18A937E66A6DF253,
      448'h0
    })
  };

  ////////////////////////////////////////////
  // lc_ctrl
  ////////////////////////////////////////////
  // Diversification value used for all invalid life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivInvalid = {
    128'h1755F072_EE7A8E2F_C45E111D_F07FA067
  };

  // Diversification value used for the TEST_UNLOCKED* life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivTestUnlocked = {
    128'hF64056D9_BF30D485_43BEC2E9_A075D7D5
  };

  // Diversification value used for the DEV life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivDev = {
    128'h36D6F825_05255EA0_645554DD_5F9355F5
  };

  // Diversification value used for the PROD/PROD_END life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivProduction = {
    128'hA89085A9_5A12AB13_E0EC9CCD_04512F5C
  };

  // Diversification value used for the RMA life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivRma = {
    128'h01D8958E_F421D22B_B7701362_4B5A4BFF
  };

  // Compile-time random bits used for invalid tokens in the token mux
  parameter lc_ctrl_pkg::lc_token_mux_t RndCnstLcCtrlInvalidTokens = {
    256'h0BDD4DD6_B30B717A_A80FF777_A157878A_468D23EE_CBD09DE6_B8F9FAEA_F1A70E57,
    256'hE8EDA03A_353B76A2_F833509A_CC7B3AA3_FA7DAC23_3E2B7823_06AF306A_1F36165E,
    256'hE14A00EE_9FF9382A_F33B4797_18558E67_59764645_AAD1FB21_C1812463_5E3D50A8,
    256'h8F680804_5627AC18_F377D907_1BECA6F1_94EF96F3_E535B58F_2ADAD82B_175FE9EA
  };

  ////////////////////////////////////////////
  // alert_handler
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter alert_handler_pkg::lfsr_seed_t RndCnstAlertHandlerLfsrSeed = {
    32'h1C326A66
  };

  // Compile-time random permutation for LFSR output
  parameter alert_handler_pkg::lfsr_perm_t RndCnstAlertHandlerLfsrPerm = {
    160'h1A9E9284_FE911733_700DEC6D_0DEA95BE_58877F02
  };

  ////////////////////////////////////////////
  // sram_ctrl_ret_aon
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlRetAonSramKey = {
    128'hB666A5E2_2D3320F8_9CAA47E5_CED5D29C
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlRetAonSramNonce = {
    128'hC9CDB468_773EBACE_C14DA34C_505AEDC7
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlRetAonLfsrSeed = {
    64'h0EA184C7_A34193D5
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlRetAonLfsrPerm = {
    128'h65E836CD_53E143AB_2B32E192_468C7F3B,
    256'h85E96087_7709F974_04DE54F1_AC0A8A61_ED245135_F838DBEC_0CA4AAF2_D3F56727
  };

  ////////////////////////////////////////////
  // flash_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for default address key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlAddrKey = {
    128'hA63A8E66_04338151_B9A23C08_F9EED04C
  };

  // Compile-time random bits for default data key
  parameter flash_ctrl_pkg::flash_key_t RndCnstFlashCtrlDataKey = {
    128'hA1EBB0BD_D305FFB6_C4818054_E0E0EDB0
  };

  // Compile-time random bits for default seeds
  parameter flash_ctrl_top_specific_pkg::all_seeds_t RndCnstFlashCtrlAllSeeds = {
    256'hACD0B040_FC629EA7_F8B17FA8_8FEE02E3_F0864223_A2E23A8C_C31E2DE5_E578D43D,
    256'h2DCE49E3_60CFB594_ACDDF170_684F6EAD_2B7FEBFE_895523D7_BC4846A4_85956C7F
  };

  // Compile-time random bits for initial LFSR seed
  parameter flash_ctrl_top_specific_pkg::lfsr_seed_t RndCnstFlashCtrlLfsrSeed = {
    32'h904B9EDE
  };

  // Compile-time random permutation for LFSR output
  parameter flash_ctrl_top_specific_pkg::lfsr_perm_t RndCnstFlashCtrlLfsrPerm = {
    160'hFE2AEB5F_2259647E_011D0C3C_F191896E_CCAA467A
  };

  ////////////////////////////////////////////
  // acc
  ////////////////////////////////////////////
  // Default seed of the PRNG used for URND.
  parameter acc_pkg::urnd_prng_seed_t RndCnstAccUrndPrngSeed = {
    256'hB87118AF_11CDBE78_D6706061_5A20B9C0_740F0796_9CCD2D10_A1A6E798_8FA528AC
  };

  // Compile-time random reset value for IMem/DMem scrambling key.
  parameter otp_ctrl_pkg::acc_key_t RndCnstAccAccKey = {
    128'h032E0A61_38CB8316_FF95C65C_D7A1A768
  };

  // Compile-time random reset value for IMem/DMem scrambling nonce.
  parameter otp_ctrl_pkg::acc_nonce_t RndCnstAccAccNonce = {
    64'hB06E0106_D60EDA0F
  };

  ////////////////////////////////////////////
  // aes
  ////////////////////////////////////////////
  // Default seed of the PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstAesClearingLfsrSeed = {
    64'h1BC67ADF_85BD9A56
  };

  // Permutation applied to the LFSR of the PRNG used for clearing.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingLfsrPerm = {
    128'h625A41FE_D1B9D544_96922D13_359CE0BC,
    256'h8297A213_CB9FEC1E_E3B41DDC_31F1CBD6_DF440BBC_25C3B698_5B2B5446_AA3230BA
  };

  // Permutation applied to the clearing PRNG output for clearing the second share of registers.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingSharePerm = {
    128'h4AF43178_0AD6DB89_798CB5CE_21D3FFFA,
    256'hDA4CB9B3_4AC28261_EAAF7B4E_20B2066F_077F7D44_55463491_1B337190_DA1859E0
  };

  // Default seed of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstAesMaskingLfsrSeed = {
    32'h05041A1B,
    256'h896350C9_636D6814_D23E2F5F_F1275EF1_9959AAA8_B6A004D5_574984DE_D1CC79BD
  };

  // Permutation applied to the output of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstAesMaskingLfsrPerm = {
    256'h0412893D_8B73114B_3646052E_795F7845_815B8C15_23951C07_26566C4C_637B7D51,
    256'h7F4A7A7E_331A6250_168D8A31_5D14642B_0E85492F_5E481382_301D7701_55029609,
    256'h0A1F0338_9A6A392D_6F943F34_3E524D43_91753290_86102947_8497749B_0F4F190D,
    256'h179D5C1E_6E925893_0C767C8E_61704108_6D187159_0B282740_69729C5A_4437548F,
    256'h3B986024_209F0642_21533C35_6B9E4E88_2C578000_1B998325_652A6822_3A668767
  };

  ////////////////////////////////////////////
  // kmac
  ////////////////////////////////////////////
  // Compile-time random data for PRNG default seed
  parameter kmac_pkg::lfsr_seed_t RndCnstKmacLfsrSeed = {
    32'hCD252956,
    256'hBA816163_62B27EAF_B903EC79_BDDF0A4F_7DFF07DB_05DE6391_0E4EE4D8_A2C7D402
  };

  // Compile-time random permutation for PRNG output
  parameter kmac_pkg::lfsr_perm_t RndCnstKmacLfsrPerm = {
    64'h039B0B1D_7EC6423A,
    256'h3DE08898_652A0B19_58C22D4D_0A9CB596_0D4CDACB_751898E7_5C1975B2_2B087C34,
    256'h7207AC4B_1A396ED2_30307BF1_771EF4B6_9544EABF_81D13989_EC5DE607_60D7918B,
    256'h78C6F321_D232650D_066B1409_2065D712_58F554E3_A70EE187_2991B497_4E23272A,
    256'h6D1CCEE8_B43C501A_69301A09_5CD2A600_58EA4B99_2A7E8708_85DD272A_8856C912,
    256'h6AA6F456_4589E8BA_8AB0CE61_EE4984A3_D45510AE_AB819EF9_1B0320A2_B65CCC1B,
    256'h120AA78E_C6754BB6_E5F54A51_4F0CD66C_68B5E9DC_512B18EE_3779F7A7_18757C16,
    256'h6FED8176_9FA56290_5D4E692B_486AC210_4D250519_3EECE1C5_F85BA275_B4F66DE0,
    256'h878D0095_D262AF07_A12DFA94_743A1A55_FE6A6824_B4284526_1F2C456A_B525B377,
    256'h002928B8_ADD350AA_D8A80CBD_70375079_31512285_A8850EF0_76E50DCF_2936BB5E,
    256'h9452E508_B426B186_9A9E71D7_6E421F84_C685C280_E786E132_2345F658_2D129FC7,
    256'h3A7CC32F_D3CE8016_4647CC55_2CD5C62D_29B58EB0_A44B34CB_2A36F722_2EC24B02,
    256'h5681509E_4E444832_B2ABAFA5_9B2A963F_C6E96105_BDA0C5F4_D04111BC_26AE4716,
    256'hC784333E_6EBADCE4_47D564B0_B1B2DCFA_4C7F9BEC_6C6DEE34_42F1F5DA_3AA28320,
    256'h1141ACFA_0AFF5986_6146DE4B_D83424BE_8F290C7E_35A0C4F2_76134F70_F3698211,
    256'h2B37C5EA_4D43D678_C6AC8141_D8AF2F68_57AE74BF_8A58150E_80544281_F0BA24F3,
    256'h3EEA238C_774AA60B_2D24C446_494F19B9_502E1D77_069701B1_5011B524_59F07955,
    256'h59F1E6F2_87AB2914_6A1B1AAC_0C3AFC56_EF8150D8_288D9049_57710F81_398F7A27,
    256'hB3DF0A63_4814889A_4FAD1C72_4815C056_412E1CA7_7A89B916_A16564DC_200E2902,
    256'h114A1933_F82089AC_D102F229_DE532536_6BE98BB9_74212567_FD645ED7_6611E62D,
    256'h4A36293B_4C23316C_137D43F7_F82B624A_E5892165_6E035281_91C2468D_BBBC1399,
    256'h863475A3_72281B2F_C076BA88_22422949_E9770314_DE3F0F8C_E914AD41_CE16CF10,
    256'h47580C35_D9005E22_98860341_8085E79A_65C51972_1E21745C_7C50C85B_C4FD688C,
    256'hC1719280_991AF686_022106EA_5E40D986_6AC55F16_B8C2386A_DBE355D5_BA44737E,
    256'hBC581346_D250928F_4546D57B_61E1A4ED_42EA736C_77742CC9_F8C26DA4_12D2FA72,
    256'h6670D9DF_79254070_02300005_7AD953D2_D7160418_178880C3_BBE0E9CA_DC32E7D9,
    256'hA04D6B6E_48DAE789_6196069B_37A3B025_8EC599C9_967F6A4B_A8262F8E_6FB7EC10,
    256'h0E96F744_90312895_6304178E_9329691B_CD69B048_14A64109_68382A16_CA245310,
    256'hC38DF652_68E0E127_7E5C603C_9B14C829_75F4C21C_C586A352_11E9E89F_10F01861,
    256'hAAB4F0B2_A1142540_A140E709_81FC4EE2_2DAAF43D_880BA3E5_1EB57F43_9C62712E,
    256'hC358B06B_492A0650_AA8748F9_1294AA47_502E2394_E5AB0643_4FDB1AE5_707020F6,
    256'h9D859568_CA48B03F_2734055D_00F05818_589D8945_E599188F_03EA7099_83B24CBC
  };

  // Compile-time random data for PRNG buffer default seed
  parameter kmac_pkg::buffer_lfsr_seed_t RndCnstKmacBufferLfsrSeed = {
    32'h0B67838A,
    256'hDFB99A5E_CA671672_CF19BCA6_ADC1EBFA_B611F19E_7262E0A4_91970E51_B28E7026,
    256'hD0E5DCE9_E265A416_A812231C_FA76E3D9_82F8FDCE_C9AE1AF0_B8CD9E17_606EC981,
    256'h060E9479_5A1D5730_89578C10_4A36A647_E90FFAFF_9760F5E8_38BD8E24_13AB956B
  };

  // Compile-time random permutation for LFSR Message output
  parameter kmac_pkg::msg_perm_t RndCnstKmacMsgPerm = {
    128'h728AD408_62DDE228_12C09C8C_7804D81F,
    256'h1F50917B_EAD2E6AD_EE3F2722_5D4DB215_91CDF0CE_1763D9EB_E2B75790_66FE96C4
  };

  ////////////////////////////////////////////
  // keymgr
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter keymgr_pkg::lfsr_seed_t RndCnstKeymgrLfsrSeed = {
    64'h32FCC4D3_092BD638
  };

  // Compile-time random permutation for LFSR output
  parameter keymgr_pkg::lfsr_perm_t RndCnstKeymgrLfsrPerm = {
    128'h89362C32_395757BB_BDB4747E_E20E7C0D,
    256'hF76BC699_F759091A_348CAA08_0CD26D90_5C87F166_27038AD4_610BEB4B_DE528D8F
  };

  // Compile-time random permutation for entropy used in share overriding
  parameter keymgr_pkg::rand_perm_t RndCnstKeymgrRandPerm = {
    160'hA9333D85_87160C94_5D4D7497_CD7A2505_3F6EBC70
  };

  // Compile-time random bits for revision seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrRevisionSeed = {
    256'h504AA7AC_1C67F59C_BA5482C1_E35E6E33_35C20CC7_78FC3099_17B9C870_ABE0895D
  };

  // Compile-time random bits for creator identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrCreatorIdentitySeed = {
    256'h76F862EF_81F419E3_C6CDC866_2C71EAC1_41666E44_3C6492D9_BCF7A824_20750E5D
  };

  // Compile-time random bits for owner intermediate identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrOwnerIntIdentitySeed = {
    256'hFC5E3ED4_F2907532_E179EBEC_7ED7D3A5_EF4982F7_3ED91C4B_1CD0C85E_C5E548B4
  };

  // Compile-time random bits for owner identity seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrOwnerIdentitySeed = {
    256'h0184A69E_B1E54396_460E36C5_5C459EFE_9E43836F_E878E464_337EBCAE_3238DCDF
  };

  // Compile-time random bits for software generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrSoftOutputSeed = {
    256'h7DE88B56_B405E02B_BFD73849_C511F7F0_B79F91DC_D1D589B4_CAC4372C_385F89D9
  };

  // Compile-time random bits for hardware generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrHardOutputSeed = {
    256'h02019DAB_B6DD5702_2C77EDE8_609C409D_905B3C78_19B26A67_43288199_28C5D79B
  };

  // Compile-time random bits for generation seed when aes destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrAesSeed = {
    256'hF1DB63D1_1E1C31BB_C9A8C73F_C4CC3D14_CA6BC0B9_6812DE7C_775A54FF_19343CB3
  };

  // Compile-time random bits for generation seed when kmac destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrKmacSeed = {
    256'h2040B349_0768889D_27E0BA85_88D34C05_BCF127DA_E58B65D6_A2510880_99B37107
  };

  // Compile-time random bits for generation seed when acc destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrAccSeed = {
    256'hB1CCCF1A_955F03DE_1A8447BF_83B69C50_E149CF51_784A9D7A_C691306E_5C56CE38
  };

  // Compile-time random bits for generation seed when no CDI is selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrCdi = {
    256'hCD7D7E3B_1ABFB797_8189A21A_E856F1D9_08E3F70D_E343D222_6E9E8644_65A8EE55
  };

  // Compile-time random bits for generation seed when no destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrNoneSeed = {
    256'hEC0E6A29_6789DED5_C0AF59EE_62F1FD1B_BEBEAC22_05B1FA5E_94E72EB7_EB1A713A
  };

  ////////////////////////////////////////////
  // csrng
  ////////////////////////////////////////////
  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivNonProduction = {
    128'hD15D2565_D9AB4FBC_D2E17C40_6F48D140,
    256'h1F8A6A52_286F6954_C27A9AEF_BE0BC9EE_440C514C_CACB0199_95F31FA9_58859293
  };

  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivProduction = {
    128'hC5591AE6_04A92A30_3760EB8D_7785A7BB,
    256'hDCE1D6A0_2B6F0F24_F5DB8EF0_2F9FB0A4_023D8F96_A41F062B_B66B2287_01E8317C
  };

  ////////////////////////////////////////////
  // sram_ctrl_main
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMainSramKey = {
    128'hD4BF08BD_6684A1D5_96CC57E1_37A0321F
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMainSramNonce = {
    128'hB803BFD2_DE7A90A1_357E743C_E460442C
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMainLfsrSeed = {
    64'h10686E82_613DE080
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMainLfsrPerm = {
    128'h77FE01B8_FF706A32_7247B85C_D92433C5,
    256'h5B26967F_2F17E786_50AD03A5_911738CA_ADA24582_022E532F_52207FA6_2B347DDB
  };

  ////////////////////////////////////////////
  // rom_ctrl
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrlScrNonce = {
    64'h5F4EA1E4_63032A3A
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrlScrKey = {
    128'h8E24B454_7F8B0DB0_C77E9027_76B104C3
  };

  ////////////////////////////////////////////
  // rv_core_ibex
  ////////////////////////////////////////////
  // Default seed of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_seed_t RndCnstRvCoreIbexLfsrSeed = {
    32'hA9DA0203
  };

  // Permutation applied to the LFSR of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_perm_t RndCnstRvCoreIbexLfsrPerm = {
    160'hFC2DBE9A_F10A1E24_E3CA634B_99C86BAB_8FCD5080
  };

  // Default icache scrambling key
  parameter logic [ibex_pkg::SCRAMBLE_KEY_W-1:0] RndCnstRvCoreIbexIbexKeyDefault = {
    128'h91C2BD31_6277126E_A6934D37_49740A7C
  };

  // Default icache scrambling nonce
  parameter logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] RndCnstRvCoreIbexIbexNonceDefault = {
    64'hE7C92A49_F71747D5
  };

endpackage : top_earlgrey_rnd_cnst_pkg
