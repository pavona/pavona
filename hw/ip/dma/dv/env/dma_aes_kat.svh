// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Inline-AES known-answer-test (KAT) vectors for the directed DMA AES sequence.
//
// Register-native little-endian word ordering (word0 at the lowest address), mined from the
// prototype pre-DV bench (dma_inline_tb): NIST SP800-38A F.5.1 CTR-AES128 and NIST GCM-AES128
// Test Case 3, plus one fixed AAD block for the GCM+AAD path. AES-128 (key words 4..7 = 0).

// Up to 16 text words (4 blocks) and 8 AAD words (2 blocks) are supported by these vectors.
typedef struct {
  string     name;
  bit        gcm;          // 1 = AES-GCM, 0 = AES-CTR
  int        n_blocks;     // number of 16-byte text blocks
  int        aad_blocks;   // number of 16-byte AAD blocks
  bit [31:0] key[8];
  bit [31:0] iv[4];
  bit [31:0] aad[8];
  bit [31:0] pt[16];
  bit [31:0] ct[16];
  bit [31:0] tag[4];       // GCM authentication tag (register-native words)
} aes_kat_t;

// Build the list of KAT vectors used by dma_aes_smoke_vseq.
function automatic void get_aes_kats(ref aes_kat_t kats[$]);
  aes_kat_t k;

  // --- CTR-AES128 (NIST SP800-38A F.5.1), 2 text blocks, no AAD/tag ---
  k = '{default: 0};
  k.name = "ctr_aes128_f5_1"; k.gcm = 0; k.n_blocks = 2; k.aad_blocks = 0;
  k.key[0] = 32'h16157e2b; k.key[1] = 32'ha6d2ae28;
  k.key[2] = 32'h8815f7ab; k.key[3] = 32'h3c4fcf09;
  k.iv[0]  = 32'hf3f2f1f0; k.iv[1]  = 32'hf7f6f5f4;
  k.iv[2]  = 32'hfbfaf9f8; k.iv[3]  = 32'hfffefdfc;
  k.pt[0]  = 32'he2bec16b; k.pt[1]  = 32'h969f402e;
  k.pt[2]  = 32'h117e3de9; k.pt[3]  = 32'h2a179373;
  k.pt[4]  = 32'h578a2dae; k.pt[5]  = 32'h9cac031e;
  k.pt[6]  = 32'hac6fb79e; k.pt[7]  = 32'h518eaf45;
  k.ct[0]  = 32'h91614d87; k.ct[1]  = 32'h26e320b6;
  k.ct[2]  = 32'h6468ef1b; k.ct[3]  = 32'hceb60d99;
  k.ct[4]  = 32'h6bf60698; k.ct[5]  = 32'hfffd7079;
  k.ct[6]  = 32'h7b181786; k.ct[7]  = 32'hfffdffb9;
  kats.push_back(k);

  // --- GCM-AES128 Test Case 3, 4 text blocks, no AAD ---
  k = '{default: 0};
  k.name = "gcm_aes128_tc3"; k.gcm = 1; k.n_blocks = 4; k.aad_blocks = 0;
  k.key[0] = 32'h92e9fffe; k.key[1] = 32'h1c736586;
  k.key[2] = 32'h948f6a6d; k.key[3] = 32'h08833067;
  k.iv[0]  = 32'hbebafeca; k.iv[1]  = 32'haddbcefa;
  k.iv[2]  = 32'h88f8cade; k.iv[3]  = 32'h00000000;
  k.pt[0]  = 32'h253231d9; k.pt[1]  = 32'he50684f8;
  k.pt[2]  = 32'hc50959a5; k.pt[3]  = 32'h9a26f5af;
  k.pt[4]  = 32'h53a9a786; k.pt[5]  = 32'hdaf73415;
  k.pt[6]  = 32'h3d304c2e; k.pt[7]  = 32'h728a318a;
  k.pt[8]  = 32'h950c3c1c; k.pt[9]  = 32'h53096895;
  k.pt[10] = 32'h240ecf2f; k.pt[11] = 32'h25b5a649;
  k.pt[12] = 32'hf5ed6ab1; k.pt[13] = 32'h57e60daa;
  k.pt[14] = 32'h397b63ba; k.pt[15] = 32'h55d2af1a;
  k.ct[0]  = 32'hc21e8342; k.ct[1]  = 32'h24747721;
  k.ct[2]  = 32'hb721724b; k.ct[3]  = 32'h9cd4d084;
  k.ct[4]  = 32'h2f21aae3; k.ct[5]  = 32'he0a4022c;
  k.ct[6]  = 32'h237ec135; k.ct[7]  = 32'h2ea1ac29;
  k.ct[8]  = 32'hb214d521; k.ct[9]  = 32'h1c936654;
  k.ct[10] = 32'h5a6a8f7d; k.ct[11] = 32'h05aa84ac;
  k.ct[12] = 32'h390ba31b; k.ct[13] = 32'h97ac0a6a;
  k.ct[14] = 32'h91e0583d; k.ct[15] = 32'h85593f47;
  k.tag[0] = 32'hf32a5c4d; k.tag[1] = 32'ha664cd27;
  k.tag[2] = 32'hbd5af32c; k.tag[3] = 32'hb4faa62b;
  kats.push_back(k);
endfunction
