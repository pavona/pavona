// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Inline-AES reference prediction via the AES IP's aes_model_dpi (OpenSSL/BoringSSL-backed CTR/GCM,
// incl. the GHASH tag). Pure helpers (no DV_CHECK / `gfn`); the comparisons live in the scoreboard
// and the KAT self-check lives in the AES vseq.
//
// Conventions (mirror hw/ip/aes/dv/env/aes_scoreboard.sv):
//   - data_in/data_out are memory-order bytes (the DMA moves bytes in increasing address order, so
//     they map 1:1 to the DPI byte arrays - no transpose).
//   - key/iv/tag_in are register-native words, passed as-is (no input transpose).
//   - the DPI output tag is byte-transposed (aes_transpose) to register-native, matching TAG_OUT.
//   - op: 0 = encrypt, 1 = decrypt (1-bit, NOT ciph_op_e). For decrypt the DPI verifies the tag
//     internally and returns crypto_res < 0 on mismatch.

// Predict the AES output for one message. `key` is the already-combined key (KEY_SHARE0 ^ KEY_SHARE1).
function automatic void dma_aes_predict(
    input  bit              ref_model,
    input  bit              op,          // 0 = encrypt, 1 = decrypt
    input  aes_pkg::aes_mode_e mode,     // AES_CTR / AES_GCM
    input  bit [7:0][31:0]  key,
    input  bit [2:0]        key_len,     // one-hot 128/192/256
    input  bit [3:0][31:0]  iv,
    input  bit [7:0]        data_in[],
    input  bit [7:0]        aad_in[],
    input  bit [3:0][31:0]  tag_in,      // expected tag for decrypt; ignored for encrypt
    output bit [7:0]        data_out[],
    output bit [3:0][31:0]  tag_out,     // register-native (transposed)
    output int              crypto_res);
  bit [3:0][31:0] tag_raw;
  bit [7:0]       aad_arg[];
  data_out = new[data_in.size()];
  // The C DPI dislikes a zero-length AAD array; pass a single zero byte when empty (aad_len stays 0),
  // exactly as aes_scoreboard.sv does.
  if (aad_in.size() == 0) begin
    aad_arg = new[1];
    aad_arg[0] = 8'h0;
  end else begin
    aad_arg = aad_in;
  end
  c_dpi_aes_crypt_message(ref_model, op, mode, iv, key_len, key,
                          data_in.size(), aad_in.size(), data_in, aad_arg,
                          tag_in, data_out, tag_raw, crypto_res);
  // The DPI returns the tag in NIST byte order; transpose to the register-native layout (matches
  // the DUT TAG_OUT and the register-native KAT tag).
  tag_out = aes_pkg::aes_transpose(tag_raw);
endfunction
