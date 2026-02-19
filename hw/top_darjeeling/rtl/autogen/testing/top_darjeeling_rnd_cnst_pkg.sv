// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/topgen.py -t hw/top_darjeeling/data/top_darjeeling.hjson
//                -o hw/top_darjeeling/
//
// File is generated based on the following seed configuration:
//   hw/top_darjeeling/data/top_darjeeling_seed.testing.hjson


package top_darjeeling_rnd_cnst_pkg;

  ////////////////////////////////////////////
  // otp_ctrl
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter otp_ctrl_top_specific_pkg::lfsr_seed_t RndCnstOtpCtrlLfsrSeed = {
    40'h30_65F53E38
  };

  // Compile-time random permutation for LFSR output
  parameter otp_ctrl_top_specific_pkg::lfsr_perm_t RndCnstOtpCtrlLfsrPerm = {
    240'h0257_5209C785_2A49CF4C_72166467_CD415389_98486352_05C36016_CB44C89A
  };

  // Compile-time random permutation for scrambling key/nonce register reset value
  parameter otp_ctrl_top_specific_pkg::scrmbl_key_init_t RndCnstOtpCtrlScrmblKeyInit = {
    256'h2CC1ED9B_EC346650_D956B1FD_CFCDAA85_10F4ABD3_BBE952C4_C216B684_0C8C08A6
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
  parameter logic [131071:0] RndCnstOtpCtrlPartInvDefault = {
    704'({
      320'hD08F694A5F790581D728BD369D03F8087A60A7F8ED956442C9CFF0F99E594C7307F376E7B2B2FF8C,
      384'h6149B9FF4F5979607AEAD63A44F896431DF745A52C5AF5FDF86D2CE9FA1041C43F145A8BF5BE7640D7AAF2481067180F
    }),
    384'({
      64'h0,
      64'hBA37DEB973D827E0,
      256'h9C47222C695C123916E90F1BDDE834C31D3EEF689E998822EDDEB20732F666FA
    }),
    1024'({
      64'h0,
      64'h5A7F3E2373A78AA2,
      256'h276D9C42B4B5C6539C73A2705A4682BAA1885457797963C3980BFF063FC8BC64,
      256'h2E2904AA8A7090712CF9A372BE9C2B9C1FBFF3B68368C5AFEDCDEE44F5D8D84,
      256'h4C8FD64171EDB20835AEF32CF20B0C620E9AF6C53593DAEC8E3CAA2E495A8976,
      128'hEFF32B59C0A86294D9767FDCB4745699
    }),
    256'({
      64'h0,
      64'h8688686A7D26F94A,
      128'h2552A6AA7830346413591B15ED255318
    }),
    384'({
      64'h0,
      64'hDDF650F1A00008EE,
      128'hB5742826D2CE8D8BB874DDD1DBCA5322,
      128'h1FB5110B0618183CBF722F142EF9FACF
    }),
    128'({
      64'h1F2A6BD606D55F72,
      16'h0, // unallocated space
      8'h69,
      8'h69,
      32'h0
    }),
    576'({
      64'h6FB88C3B4FD535BD,
      256'hE78E601C1704C34A6DFD043E96E1EF76D15C0798EF406091D605165216FD3F85,
      256'h58B183F3D37975B4A9524DE21084A9D64BBA835C10B5E29043022273F7AFBF68
    }),
    78912'({
      64'hCA832DA13EB53FEA,
      5312'h0, // unallocated space
      73536'h0
    }),
    8192'({
      8192'h0
    }),
    2624'({
      64'h28B1AE331BF3824C,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'hEBAA1ACD79D438BB,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'h8A4FE08CE276C9C9,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'hB5A6FD9823EB9F1C,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'hB51350C5C23EBE77,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'hFDEEF22E74536D01,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'h4BEDD6920E68A84C,
      1280'h0,
      1280'h0
    }),
    2624'({
      64'hF9D303313B0977A8,
      1280'h0,
      1280'h0
    }),
    11392'({
      64'hC167C84BFDB86457,
      32'h0, // unallocated space
      6144'h0,
      1280'h0,
      1280'h0,
      1280'h0,
      32'h0,
      1280'h0
    }),
    384'({
      128'h0,
      128'h0,
      128'h0
    }),
    4800'({
      64'h2A24E15352C559FD,
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
      224'h0,
      3360'h0,
      32'h0,
      32'h0,
      32'h0,
      32'h0
    }),
    2432'({
      64'h9521702FCBCF4F54,
      32'h0, // unallocated space
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
      64'h0,
      32'h0,
      64'h0,
      32'h0,
      32'h0,
      256'h0,
      32'h0,
      992'h0
    }),
    512'({
      64'h45515694E825B33,
      448'h0
    })
  };

  ////////////////////////////////////////////
  // lc_ctrl
  ////////////////////////////////////////////
  // Diversification value used for all invalid life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivInvalid = {
    128'h0F7AE497_EDB550D6_780626A1_2B5904A9
  };

  // Diversification value used for the TEST_UNLOCKED* life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivTestUnlocked = {
    128'hB37439F8_177D19D0_4D3FAD04_0ED02909
  };

  // Diversification value used for the DEV life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivDev = {
    128'hA9EA4B54_29B9E60D_20B07721_F7FF507A
  };

  // Diversification value used for the PROD/PROD_END life cycle states.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivProduction = {
    128'hD2B9FB9C_C7FF06E4_C72C47D9_E15FA8FF
  };

  // Diversification value used for the RMA life cycle state.
  parameter lc_ctrl_pkg::lc_keymgr_div_t RndCnstLcCtrlLcKeymgrDivRma = {
    128'h9F82833E_32C151D2_FD2987E3_062F6119
  };

  // Compile-time random bits used for invalid tokens in the token mux
  parameter lc_ctrl_pkg::lc_token_mux_t RndCnstLcCtrlInvalidTokens = {
    256'hC7560ACB_BE9F6FFF_C2171A49_199BB53D_8E0DAA8F_0578DBAA_5F022791_480B4E70,
    256'h9E0F8097_6E096601_357E1375_8A3E2211_E20FAA36_D00779EB_2CFF38B9_0ADF94A0,
    256'h675DA263_541C78AA_9DC0C623_C09EE7FD_16A6687D_3A1B4E21_456518EA_00DB8F75,
    256'h489D9325_35FCB768_4ED330AD_9AA219EA_28BFB6FD_A16A61BB_EACDDC92_2169858A
  };

  ////////////////////////////////////////////
  // alert_handler
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter alert_handler_pkg::lfsr_seed_t RndCnstAlertHandlerLfsrSeed = {
    32'h90A977C0
  };

  // Compile-time random permutation for LFSR output
  parameter alert_handler_pkg::lfsr_perm_t RndCnstAlertHandlerLfsrPerm = {
    160'h28174B98_F0C5999E_6C95D446_16C8534A_BCE7FFA8
  };

  ////////////////////////////////////////////
  // sram_ctrl_ret_aon
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlRetAonSramKey = {
    128'hA8A09119_70AC4838_B2C251C9_B9A2DBE2
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlRetAonSramNonce = {
    128'h29A87DB1_1E1E1611_1C07365C_B738535A
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlRetAonLfsrSeed = {
    64'h96AAD6C3_3DCD8C46
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlRetAonLfsrPerm = {
    128'h2BBC20E2_36EFA367_94225AD2_07F70089,
    256'h39C9EB9C_6E1D992D_D1830509_73FC6BE3_4B87DDE6_57341DD6_CA8444E5_9FA431B2
  };

  ////////////////////////////////////////////
  // acc
  ////////////////////////////////////////////
  // Default seed of the PRNG used for URND.
  parameter acc_pkg::urnd_prng_seed_t RndCnstAccUrndPrngSeed = {
    256'hCD45C60D_144177E8_9F75139F_749DE9B3_74A3636A_66F969AE_A3E98FC6_F4892BEB
  };

  // Compile-time random reset value for IMem/DMem scrambling key.
  parameter otp_ctrl_pkg::acc_key_t RndCnstAccAccKey = {
    128'h458D5B4B_D644E79A_35D690BB_B852739D
  };

  // Compile-time random reset value for IMem/DMem scrambling nonce.
  parameter otp_ctrl_pkg::acc_nonce_t RndCnstAccAccNonce = {
    64'hC155FEC8_B9A9CA90
  };

  ////////////////////////////////////////////
  // aes
  ////////////////////////////////////////////
  // Default seed of the PRNG used for register clearing.
  parameter aes_pkg::clearing_lfsr_seed_t RndCnstAesClearingLfsrSeed = {
    64'hAFAA4655_965A49D1
  };

  // Permutation applied to the LFSR of the PRNG used for clearing.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingLfsrPerm = {
    128'hBD8D049A_41BE7F3F_680FB06D_A47563E1,
    256'h370A8601_65E9D59E_43130934_BDACFEB6_6E3AA442_4948B5DF_C9F96C0C_883D7C1A
  };

  // Permutation applied to the clearing PRNG output for clearing the second share of registers.
  parameter aes_pkg::clearing_lfsr_perm_t RndCnstAesClearingSharePerm = {
    128'hD2333689_5FDB16AC_70DEF229_E54B005D,
    256'h1C9309CE_180D6B4F_CC774A79_9384D508_493466A8_F6E967F0_B920981E_AB7FE4BB
  };

  // Default seed of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_seed_t RndCnstAesMaskingLfsrSeed = {
    32'hCBC6D57F,
    256'hE7489F41_54987039_5C90D9AB_F4E0F5ED_5BA097B3_BA3CCF06_D21E5139_60C35528
  };

  // Permutation applied to the output of the PRNG used for masking.
  parameter aes_pkg::masking_lfsr_perm_t RndCnstAesMaskingLfsrPerm = {
    256'h8061271D_536B0B52_815B2007_44953B7E_9994658D_2B453A9F_03258E0A_70139A3E,
    256'h6277876A_1B14545E_0F2E0891_36907124_72027A31_3F8F3D41_6C63062F_4637681E,
    256'h1C3C3564_8A327860_7693424F_342A4A4C_66491923_8C5F5718_84857339_1621929D,
    256'h7417404B_304E797B_4D557F0C_48296E69_9C510415_968B1098_0E881259_3856055D,
    256'h1F330928_677D1A97_83226D9B_016F269E_7500110D_89824350_5C587C47_5A2C2D86
  };

  ////////////////////////////////////////////
  // kmac
  ////////////////////////////////////////////
  // Compile-time random data for PRNG default seed
  parameter kmac_pkg::lfsr_seed_t RndCnstKmacLfsrSeed = {
    32'h0315A177,
    256'hC7516ECD_4B002AF6_B49253AD_7151C8E8_F1A51FD1_84ABFA40_D2CD2D16_F3D54D9D
  };

  // Compile-time random permutation for PRNG output
  parameter kmac_pkg::lfsr_perm_t RndCnstKmacLfsrPerm = {
    64'h3F2076C6_CD702CF9,
    256'h84C7BE62_58F0F53F_9B42F9D7_070945CE_6D8A1B66_02D3056B_34A8ECB1_176C41A7,
    256'hBFD40292_396A08F2_287E67D0_A7A1358E_97CB0A88_0F1160D8_80480397_E9B8A2D8,
    256'h26283004_14384A3E_BFA95A65_ECC48328_369311C3_B1B89A3D_9E2A425D_C0D6206E,
    256'h432B63B9_F193AAE3_11023679_AA82DA63_1C58F829_314B0447_60CB47F0_26A4B104,
    256'hD6B77DDD_2A2EB8AD_573724EC_6CD64A57_469AC109_298280D9_AB687731_0F78C038,
    256'h7237C719_4AD4B027_1CD20ED1_B4B162AA_C53449D4_96460A92_201EF10D_2184F9C2,
    256'hA245D2B0_C23344F3_FE24B6CB_A4606D7A_E1E99059_9F93F470_8D9C5B30_7C3A89A9,
    256'h4745120B_D9EAFDC4_24CD80A1_E45C9992_F51960CC_81ECAB68_AD0908B2_31153AB1,
    256'hF8296203_3C845FEC_3261AC53_C4534860_66EB62D6_DF805C31_ACB86C92_B962C094,
    256'hB098F45A_A9E04B8A_4138A2DC_3EA2574E_F1267FC7_DAA15171_4B9071EA_E9A6CD47,
    256'h52744561_B6B4D50B_4A661DAE_9A8A1A7A_02716A02_ECCCA460_F8D04BBB_E8FC4D03,
    256'h97E03739_596F60B1_995EBB45_005AB03B_8A3AC808_49EE7981_6485585C_745CC006,
    256'h594D0215_46A5F5BA_C185E421_349E9968_89CB5A2E_E38D5BA5_DEF3A46F_05273A11,
    256'h476925CC_507D16D1_07F22143_46C374F2_3DE4C0D4_1D098725_19146955_A68E6C32,
    256'h4863A2DE_341FB868_9737D008_15F60654_E91C5226_6800495C_7A9B5596_AE35C872,
    256'hE651530D_B31532AE_98D54A83_7061905C_22BB21D2_3AC92043_F2FD6A2A_41AB2317,
    256'h72077424_5F3C5AF1_060EAF97_73EEA96C_21373CE4_8B16085C_059AD41C_365A6830,
    256'hEA0AA67B_59295C62_4E6F81E4_3D66A786_048B8300_B925D628_864A3979_92DF33D1,
    256'h519A4F34_5D95A969_A381429A_10418EF4_ADD4ABF5_1D4E9E00_AEB15606_8226596F,
    256'hDD3748B7_7D1AB8BE_7738670B_C9FE8CD8_49D8EA03_A119D475_B8D21725_332316C1,
    256'hD2CE2597_515A3832_B08C6578_46891132_2E7BAE87_DDA1A85E_9660C074_29F4E169,
    256'h62C0F394_029291E9_C890B808_8406080C_DF557E4D_5B51B598_4DB68F09_9E10644A,
    256'hF77AD982_6CA7C437_BAAF51C2_230E1490_46D71F1D_929E5034_C782D031_52EC6B51,
    256'h303B4005_52923E51_1AE6FA25_4DA01AE6_A14EB8A8_5858E562_082CAA82_061AB44F,
    256'h2C74BC01_AE004625_2DB92271_FE45319B_E3E18C8A_68A4A28C_08E79C2A_5B4EC675,
    256'hC02599AD_CC3232C1_44330526_95704858_FA771E10_F9901081_EC6AE5B3_07643113,
    256'h1282E55B_071A6A44_19B94395_57C80DBC_C2737A14_4D809032_FCB75B71_4D5093D4,
    256'h502A812C_ED83F505_796651CE_9626EBC9_78570A6A_FAF70B72_9F0214C3_671C6A19,
    256'h6F121C74_91377E6D_5B589E91_04E2F13D_87F15520_E65F9235_BA4079E9_C676F758,
    256'h5BC9217B_B2D8E119_FDC057A4_2F1E9EC9_FA366E53_6E1C4654_BDA6F768_E7819443,
    256'h38619F5D_576D888F_E628D630_A8D9759C_21C61BB2_4851062B_BBC0AE80_1FFBEE9D
  };

  // Compile-time random data for PRNG buffer default seed
  parameter kmac_pkg::buffer_lfsr_seed_t RndCnstKmacBufferLfsrSeed = {
    32'hA842CCDF,
    256'h4B2EC9D2_8B150F71_0414CE5D_EA1A1A07_2DC4AB7B_A0EF929D_5FFE85FF_7E8747F1,
    256'hA7D617AC_1C0E61C4_2612F0F1_FA533FE0_5F758B96_21FE31C4_C8719432_8BAC3EFD,
    256'h7F8F4DE7_2295AF15_BB8788A9_1BE7E977_56C83F7C_886F4D03_CB27B76F_F5B776E1
  };

  // Compile-time random permutation for LFSR Message output
  parameter kmac_pkg::msg_perm_t RndCnstKmacMsgPerm = {
    128'h9827E164_4CCFDE85_50779FE0_5236BDCB,
    256'h52B8EFC2_6E1DBE98_1AD2E2A9_2BEC3819_CC364D88_A57F854E_B5B47919_710F0700
  };

  ////////////////////////////////////////////
  // keymgr_dpe
  ////////////////////////////////////////////
  // Compile-time random bits for initial LFSR seed
  parameter keymgr_pkg::lfsr_seed_t RndCnstKeymgrDpeLfsrSeed = {
    64'hF463EF2F_DFF5F6DD
  };

  // Compile-time random permutation for LFSR output
  parameter keymgr_pkg::lfsr_perm_t RndCnstKeymgrDpeLfsrPerm = {
    128'h87EB6290_A74B0F14_C2CDB5CC_7154858C,
    256'h123F6680_0E7D1A47_9B8BFD83_2E49AF4D_5E37A9EC_6AAF10BA_5606D943_D6C3B137
  };

  // Compile-time random permutation for entropy used in share overriding
  parameter keymgr_pkg::rand_perm_t RndCnstKeymgrDpeRandPerm = {
    160'hE5E9E327_784327AB_15EBE924_DFBB3038_A2155460
  };

  // Compile-time random bits for revision seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeRevisionSeed = {
    256'hBC99A2C9_FF8D13E6_E3C95B9F_3B64C459_30F2E8FF_6A1D7485_E74BB880_5C552E9E
  };

  // Compile-time random bits for software generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeSoftOutputSeed = {
    256'h002301F1_82196997_5992AD61_B3498070_84EBB1B4_7B416B49_B114F994_A969864A
  };

  // Compile-time random bits for hardware generation seed
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeHardOutputSeed = {
    256'h57C3482A_B3BDCBD9_FE825728_F7BA40A2_2C9719C5_D7C160F4_92D0E875_7631EBF7
  };

  // Compile-time random bits for generation seed when aes destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeAesSeed = {
    256'h52A1E560_4E2D6171_F5DBA9EC_4249052D_CC7A4D58_4D57AC27_843EA2A0_163EFEDA
  };

  // Compile-time random bits for generation seed when kmac destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeKmacSeed = {
    256'h5B24D93F_97D62D99_C960542F_4A1F2595_192E9A96_9A885419_A9D57E36_519FA42D
  };

  // Compile-time random bits for generation seed when acc destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeAccSeed = {
    256'h20EFA348_CB77F508_9A8381B6_2D9717B3_647E5CE0_796CA68A_A29523D3_F94F27C7
  };

  // Compile-time random bits for generation seed when no destination selected
  parameter keymgr_pkg::seed_t RndCnstKeymgrDpeNoneSeed = {
    256'h4ACAE76B_3E145326_741F804E_3C3A3451_469C6118_FA23BC32_E428AD2B_E2584FE8
  };

  ////////////////////////////////////////////
  // csrng
  ////////////////////////////////////////////
  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivNonProduction = {
    128'hD5491FA8_E7F19AAA_4133AD0D_2704702A,
    256'hE2FF9D98_49FCB598_74CDDC9C_BC645D9E_02A96B99_80911844_D3C74DE8_5E05164B
  };

  // Compile-time random bits for csrng state group diversification value
  parameter csrng_pkg::cs_keymgr_div_t RndCnstCsrngCsKeymgrDivProduction = {
    128'h829D484B_D447C9D7_611999CA_523B1157,
    256'h5A82D625_EA331F0D_D07B9876_A95D4846_9D8BE58D_526100D8_26EBF413_7728E993
  };

  ////////////////////////////////////////////
  // sram_ctrl_main
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMainSramKey = {
    128'hB979B05B_DDC26CCB_34AAB934_13F8B7DC
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMainSramNonce = {
    128'h7CC8C4BF_DB394D03_E99A0DAE_61EAF3B6
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMainLfsrSeed = {
    64'h4EFFA6DE_29A9812F
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMainLfsrPerm = {
    128'hF343EC70_C7545598_84C6D4E1_23DA4142,
    256'h3CD20C22_EF7CD9A4_E9B1F0D9_8B8546B5_B52AA809_017E7EEC_63A7CB8A_257B76BF
  };

  ////////////////////////////////////////////
  // sram_ctrl_mbox
  ////////////////////////////////////////////
  // Compile-time random reset value for SRAM scrambling key.
  parameter otp_ctrl_pkg::sram_key_t RndCnstSramCtrlMboxSramKey = {
    128'h61CDB1A7_CA1990BF_F0B4C0F1_A0CC87EF
  };

  // Compile-time random reset value for SRAM scrambling nonce.
  parameter otp_ctrl_pkg::sram_nonce_t RndCnstSramCtrlMboxSramNonce = {
    128'hC382B123_A4E4BD11_53024473_BBD5FA0E
  };

  // Compile-time random bits for initial LFSR seed
  parameter sram_ctrl_pkg::lfsr_seed_t RndCnstSramCtrlMboxLfsrSeed = {
    64'h188EBEF9_45F9D57D
  };

  // Compile-time random permutation for LFSR output
  parameter sram_ctrl_pkg::lfsr_perm_t RndCnstSramCtrlMboxLfsrPerm = {
    128'h342D7E87_93192674_AF0CEC5F_A631EC79,
    256'hC215F449_97170D37_520CA2E1_B3CA97FF_36433B80_ED6AFA45_891A4C6A_01B4B76A
  };

  ////////////////////////////////////////////
  // rom_ctrl0
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrl0ScrNonce = {
    64'hAC8FEB4F_2302C232
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrl0ScrKey = {
    128'hC482D07B_560A3D67_8FB9A9DC_420A1339
  };

  ////////////////////////////////////////////
  // rom_ctrl1
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrl1ScrNonce = {
    64'hB243BB28_853B19B5
  };

  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrl1ScrKey = {
    128'hC399D4DA_9B067ED9_BE1D5753_FFD02F20
  };

  ////////////////////////////////////////////
  // rv_core_ibex
  ////////////////////////////////////////////
  // Default seed of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_seed_t RndCnstRvCoreIbexLfsrSeed = {
    32'hF4E52516
  };

  // Permutation applied to the LFSR of the PRNG used for random instructions.
  parameter ibex_pkg::lfsr_perm_t RndCnstRvCoreIbexLfsrPerm = {
    160'h74A8BEDC_9C896DAD_CD8368A0_6C20EA0D_5E0FFB29
  };

  // Default icache scrambling key
  parameter logic [ibex_pkg::SCRAMBLE_KEY_W-1:0] RndCnstRvCoreIbexIbexKeyDefault = {
    128'h49127EC5_6C7B0E96_45BF231B_5B37B8C5
  };

  // Default icache scrambling nonce
  parameter logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] RndCnstRvCoreIbexIbexNonceDefault = {
    64'h559AEE0D_0E2F2DAB
  };

endpackage : top_darjeeling_rnd_cnst_pkg
