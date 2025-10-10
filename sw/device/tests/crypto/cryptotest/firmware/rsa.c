// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/rsa.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/kmac.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_datatypes.h"
#include "sw/device/lib/crypto/impl/sha2/sha256.h"
#include "sw/device/lib/crypto/impl/sha2/sha512.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/ujson_ottf.h"
#include "sw/device/lib/ujson/ujson.h"
#include "sw/device/tests/crypto/cryptotest/json/rsa_commands.h"

#define MODULE_ID MAKE_MODULE_ID('r', 's', 't')

// Randomly generated. Value should not affect test outcome.
uint32_t RANDOM_MASK[128] = {
    0xDB0D6BFB, 0x80308310, 0x361105B6, 0xB15692C8, 0x3D308230, 0xEC89226B,
    0xC6C5C81C, 0xF7FEA4C8, 0x2A732103, 0xC7347C0A, 0xDE441EC2, 0x26E637F6,
    0xAFDF8920, 0x00C7B84C, 0x40912032, 0xE98B6F79, 0x47F4F4AA, 0x0DE1334B,
    0xA3C1A83D, 0x62BA06FD, 0x5F047C79, 0xC9A53809, 0x92095318, 0xDF464ECA,
    0x221A7559, 0x35BD6893, 0x7E2DDA43, 0x3123F90B, 0xC596E7B5, 0x62997190,
    0xC7CE7312, 0xCBB6C5F9, 0xBA34F82E, 0x14BC1304, 0x1D4EDC54, 0x420046BF,
    0xE911F29F, 0xA562C6B4, 0x4610BFF5, 0xA0AAA613, 0x53814362, 0xAE8B0164,
    0x044DB282, 0x148BDF2A, 0x970641EB, 0x251237C5, 0x1DD1D8CB, 0x32A56BD7,
    0x4ACB6AFC, 0x6ACE9CCB, 0x55FF219A, 0x46BD4D3A, 0xA276D67B, 0x7DF78059,
    0x924C7FAD, 0x78FCA3E0, 0xFE86281A, 0xBFEB8C95, 0x7C9C1102, 0xA073209A,
    0xD234494A, 0xCBC7B24D, 0x8CBEEBB2, 0xEFC1E3DB, 0x34EC9A73, 0xE2F4257F,
    0x9C4D2800, 0xCF848037, 0x0340E240, 0xE3A0F59C, 0x8D43822C, 0x9E688CFF,
    0x66C7784B, 0x58223FEB, 0xF68EFE47, 0x688CDC18, 0x1D1D19EC, 0x66553221,
    0x6BCA5F00, 0x73DC3DE8, 0x92EA0FA4, 0xC12D4C80, 0x3BFF0125, 0x976032D2,
    0x36247086, 0x945143AC, 0xA814B11C, 0x17726B24, 0x3AAE5EE6, 0x7F728F9D,
    0xEDD2D692, 0x6B6360F5, 0x55A1A5E6, 0x7CF7D4C0, 0x31F8CAA7, 0xC39EA429,
    0x5ADF3D34, 0xB5435B61, 0xAE81102B, 0x39C867F0, 0x69CAC654, 0x07BD2F84,
    0x04BFE164, 0x1144891B, 0xBA67F017, 0xF27D0611, 0x91AB5FD5, 0xE8D270AC,
    0x2F495872, 0xDC1C731F, 0xA66D53E3, 0xEDB55706, 0xA41286C6, 0x84F5C6A0,
    0x5D5A8D90, 0x6228FA63, 0x8395B2C3, 0x0CCD227A, 0xFF5953C0, 0x6F09B051,
    0x7DCD3A69, 0x505FD1C2, 0x2E1CF9C5, 0xF705159F, 0x3D473B1B, 0x5F6902B8,
    0x6B5B171F, 0x2748C3A5,
};

status_t handle_rsa_sign(ujson_t *uj, otcrypto_rsa_padding_t padding_mode) {
  cryptotest_rsa_security_level_t uj_security_level;
  cryptotest_rsa_hash_alg_t uj_hash_alg;
  cryptotest_rsa_message_digest_t uj_message;
  cryptotest_rsa_private_key_t uj_private_key;
  TRY(ujson_deserialize_cryptotest_rsa_security_level_t(uj,
                                                        &uj_security_level));
  TRY(ujson_deserialize_cryptotest_rsa_hash_alg_t(uj, &uj_hash_alg));
  TRY(ujson_deserialize_cryptotest_rsa_message_digest_t(uj, &uj_message));
  TRY(ujson_deserialize_cryptotest_rsa_private_key_t(uj, &uj_private_key));

  otcrypto_key_mode_t key_mode;
  switch (padding_mode) {
    case kOtcryptoRsaPaddingPkcs:
      key_mode = kOtcryptoKeyModeRsaSignPkcs;
      break;
    case kOtcryptoRsaPaddingPss:
      key_mode = kOtcryptoKeyModeRsaSignPss;
      break;
    default:
      // Unreachable
      return INTERNAL();
  }

  otcrypto_hash_mode_t mode;
  switch (uj_hash_alg) {
    case kCryptotestRsaHashAlgSha256:
      mode = kOtcryptoHashModeSha256;
      break;
    case kCryptotestRsaHashAlgSha384:
      mode = kOtcryptoHashModeSha384;
      break;
    case kCryptotestRsaHashAlgSha512:
      mode = kOtcryptoHashModeSha512;
      break;
    case kCryptotestRsaHashAlgSha3_224:
      mode = kOtcryptoHashModeSha3_224;
      break;
    case kCryptotestRsaHashAlgSha3_256:
      mode = kOtcryptoHashModeSha3_256;
      break;
    case kCryptotestRsaHashAlgSha3_384:
      mode = kOtcryptoHashModeSha3_384;
      break;
    case kCryptotestRsaHashAlgSha3_512:
      mode = kOtcryptoHashModeSha3_512;
      break;
    case kCryptotestRsaHashAlgShake128:
      mode = kOtcryptoHashXofModeShake128;
      break;
    case kCryptotestRsaHashAlgShake256:
      mode = kOtcryptoHashXofModeShake256;
      break;
    default:
      LOG_ERROR("Unrecognized RSA hash mode: %d", uj_hash_alg);
      return INVALID_ARGUMENT();
  }
  size_t key_length;
  size_t keyblob_length;
  uint32_t d_share1_buf[sizeof(rsa_4096_int_t) / sizeof(uint32_t)];
  otcrypto_rsa_size_t rsa_size;
  size_t signature_len;
  switch (uj_security_level) {
    case kCryptotestRsaSecurityLevelRsa2048:
      key_length = kOtcryptoRsa2048PrivateKeyBytes;
      keyblob_length = kOtcryptoRsa2048PrivateKeyblobBytes;
      rsa_size = kOtcryptoRsaSize2048;
      // Blind private exponent d using random mask
      for (size_t i = 0; i < sizeof(rsa_2048_int_t) / sizeof(uint32_t); i++) {
        d_share1_buf[i] = RANDOM_MASK[i] ^ ((uint32_t *)uj_private_key.d)[i];
      }
      signature_len = kRsa2048NumWords;
      break;
    case kCryptotestRsaSecurityLevelRsa3072:
      key_length = kOtcryptoRsa3072PrivateKeyBytes;
      keyblob_length = kOtcryptoRsa3072PrivateKeyblobBytes;
      rsa_size = kOtcryptoRsaSize3072;
      // Blind private exponent d using random mask
      for (size_t i = 0; i < sizeof(rsa_3072_int_t) / sizeof(uint32_t); i++) {
        d_share1_buf[i] = RANDOM_MASK[i] ^ ((uint32_t *)uj_private_key.d)[i];
      }
      signature_len = kRsa3072NumWords;
      break;
    case kCryptotestRsaSecurityLevelRsa4096:
      key_length = kOtcryptoRsa4096PrivateKeyBytes;
      keyblob_length = kOtcryptoRsa4096PrivateKeyblobBytes;
      rsa_size = kOtcryptoRsaSize4096;
      // Blind private exponent d using random mask
      for (size_t i = 0; i < sizeof(rsa_4096_int_t) / sizeof(uint32_t); i++) {
        d_share1_buf[i] = RANDOM_MASK[i] ^ ((uint32_t *)uj_private_key.d)[i];
      }
      signature_len = kRsa4096NumWords;
      break;
    default:
      LOG_ERROR("Unsupported RSA security level: %d", uj_security_level);
      return INVALID_ARGUMENT();
  }
  otcrypto_key_config_t kPrivateKeyConfig = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
      .key_length = key_length,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelLow,
  };
  uint32_t n[uj_private_key.n_len];
  memcpy(n, uj_private_key.n, uj_private_key.n_len);
  otcrypto_const_word32_buf_t modulus = {
      .len = key_length / sizeof(uint32_t),
      .data = n,
  };
  otcrypto_const_word32_buf_t d_share0 = {
      .len = key_length / sizeof(uint32_t),
      .data = RANDOM_MASK,
  };
  otcrypto_const_word32_buf_t d_share1 = {
      .len = key_length / sizeof(uint32_t),
      .data = d_share1_buf,
  };
  uint32_t keyblob[keyblob_length / sizeof(uint32_t)];
  otcrypto_blinded_key_t private_key = {
      .config = kPrivateKeyConfig,
      .keyblob_length = keyblob_length,
      .keyblob = keyblob,
  };
  // Create blinded private key object from components
  otcrypto_status_t status = otcrypto_rsa_private_key_from_exponents(
      rsa_size, modulus, uj_private_key.e, d_share0, d_share1, &private_key);
  if (status.value != kOtcryptoStatusValueOk) {
    LOG_ERROR("Bad status value from key creation = 0x%x", status.value);
    return INTERNAL(status.value);
  }

  uint8_t message_buf[RSA_CMD_MAX_MESSAGE_DIGEST_BYTES];
  memcpy(message_buf, uj_message.message_digest, uj_message.message_digest_len);
  const otcrypto_hash_digest_t message_digest = {
      .mode = mode,
      .len = uj_message.message_digest_len / sizeof(uint32_t),
      .data = (uint32_t *)message_buf,
  };

  uint32_t signature_buf[RSA_CMD_MAX_SIGNATURE_BYTES / sizeof(uint32_t)];
  otcrypto_word32_buf_t signature = {
      .data = signature_buf,
      .len = signature_len,
  };
  status =
      otcrypto_rsa_sign(&private_key, message_digest, padding_mode, signature);
  if (status.value != kOtcryptoStatusValueOk) {
    LOG_ERROR("Bad status value = 0x%x", status.value);
    return INTERNAL(status.value);
  }
  cryptotest_rsa_signature_t uj_signature;
  memcpy(uj_signature.signature, signature.data,
         signature.len * sizeof(uint32_t));
  uj_signature.signature_len = signature_len * sizeof(uint32_t);
  RESP_OK(ujson_serialize_cryptotest_rsa_signature_t, uj, &uj_signature);
  return OK_STATUS(0);
}

status_t handle_rsa_verify(ujson_t *uj, otcrypto_rsa_padding_t padding_mode) {
  cryptotest_rsa_security_level_t uj_security_level;
  cryptotest_rsa_hash_alg_t uj_hash_alg;
  cryptotest_rsa_message_digest_t uj_message;
  cryptotest_rsa_public_key_t uj_public_key;
  cryptotest_rsa_signature_t uj_signature;
  TRY(ujson_deserialize_cryptotest_rsa_security_level_t(uj,
                                                        &uj_security_level));
  TRY(ujson_deserialize_cryptotest_rsa_hash_alg_t(uj, &uj_hash_alg));
  TRY(ujson_deserialize_cryptotest_rsa_message_digest_t(uj, &uj_message));
  TRY(ujson_deserialize_cryptotest_rsa_public_key_t(uj, &uj_public_key));
  TRY(ujson_deserialize_cryptotest_rsa_signature_t(uj, &uj_signature));

  otcrypto_key_mode_t key_mode;
  switch (padding_mode) {
    case kOtcryptoRsaPaddingPkcs:
      key_mode = kOtcryptoKeyModeRsaSignPkcs;
      break;
    case kOtcryptoRsaPaddingPss:
      key_mode = kOtcryptoKeyModeRsaSignPss;
      break;
    default:
      // Unreachable
      return INTERNAL();
  }

  otcrypto_hash_mode_t mode;
  switch (uj_hash_alg) {
    case kCryptotestRsaHashAlgSha256:
      mode = kOtcryptoHashModeSha256;
      break;
    case kCryptotestRsaHashAlgSha384:
      mode = kOtcryptoHashModeSha384;
      break;
    case kCryptotestRsaHashAlgSha512:
      mode = kOtcryptoHashModeSha512;
      break;
    case kCryptotestRsaHashAlgSha3_224:
      mode = kOtcryptoHashModeSha3_224;
      break;
    case kCryptotestRsaHashAlgSha3_256:
      mode = kOtcryptoHashModeSha3_256;
      break;
    case kCryptotestRsaHashAlgSha3_384:
      mode = kOtcryptoHashModeSha3_384;
      break;
    case kCryptotestRsaHashAlgSha3_512:
      mode = kOtcryptoHashModeSha3_512;
      break;
    case kCryptotestRsaHashAlgShake128:
      mode = kOtcryptoHashXofModeShake128;
      break;
    case kCryptotestRsaHashAlgShake256:
      mode = kOtcryptoHashXofModeShake256;
      break;
    default:
      LOG_ERROR("Unrecognized RSA hash mode: %d", uj_hash_alg);
      return INVALID_ARGUMENT();
  }

  uint32_t message_buf[uj_message.message_digest_len / sizeof(uint32_t)];
  memcpy(message_buf, uj_message.message_digest, uj_message.message_digest_len);
  const otcrypto_hash_digest_t message_digest = {
      .mode = mode,
      .len = uj_message.message_digest_len / sizeof(uint32_t),
      .data = message_buf,
  };

  rsa_2048_public_key_t public_key_2048;
  rsa_3072_public_key_t public_key_3072;
  rsa_4096_public_key_t public_key_4096;
  uint32_t *key;
  size_t key_length;
  switch (uj_security_level) {
    case kCryptotestRsaSecurityLevelRsa2048:
      memset(public_key_2048.n.data, 0, sizeof(rsa_2048_int_t));
      memcpy(public_key_2048.n.data, uj_public_key.n, uj_public_key.n_len);
      public_key_2048.e = uj_public_key.e;
      key_length = sizeof(rsa_2048_public_key_t);
      key = (uint32_t *)&public_key_2048;
      break;
    case kCryptotestRsaSecurityLevelRsa3072:
      memset(public_key_3072.n.data, 0, sizeof(rsa_3072_int_t));
      memcpy(public_key_3072.n.data, uj_public_key.n, uj_public_key.n_len);
      public_key_3072.e = uj_public_key.e;
      key_length = sizeof(rsa_3072_public_key_t);
      key = (uint32_t *)&public_key_3072;
      break;
    case kCryptotestRsaSecurityLevelRsa4096:
      memset(public_key_4096.n.data, 0, sizeof(rsa_4096_int_t));
      memcpy(public_key_4096.n.data, uj_public_key.n, uj_public_key.n_len);
      public_key_4096.e = uj_public_key.e;
      key_length = sizeof(rsa_4096_public_key_t);
      key = (uint32_t *)&public_key_4096;
      break;
    default:
      LOG_ERROR("Unsupported RSA security level: %d", uj_security_level);
      return INVALID_ARGUMENT();
  }
  otcrypto_unblinded_key_t public_key = {
      .key_mode = key_mode,
      .key_length = key_length,
      .key = key,
  };
  public_key.checksum = integrity_unblinded_checksum(&public_key);

  uint32_t signature_buf[uj_signature.signature_len / sizeof(uint32_t)];
  memcpy(signature_buf, uj_signature.signature, uj_signature.signature_len);
  otcrypto_const_word32_buf_t signature = {
      .data = signature_buf,
      .len = uj_signature.signature_len / sizeof(uint32_t),
  };

  hardened_bool_t verification_result = kHardenedBoolFalse;

  otcrypto_status_t status =
      otcrypto_rsa_verify(&public_key, message_digest, padding_mode, signature,
                          &verification_result);
  cryptotest_rsa_verify_output_t uj_output;
  switch (status.value) {
    case kOtcryptoStatusValueOk: {
      switch (verification_result) {
        case kHardenedBoolFalse:
          uj_output = kCryptotestRsaVerifyOutputFailure;
          break;
        case kHardenedBoolTrue:
          uj_output = kCryptotestRsaVerifyOutputSuccess;
          break;
        default:
          LOG_ERROR("Unexpected result value from otcrypto_ecdsa_verify: %d",
                    verification_result);
          return INTERNAL();
      }
      RESP_OK(ujson_serialize_cryptotest_rsa_verify_output_t, uj, &uj_output);
      break;
    }
    case kOtcryptoStatusValueBadArgs: {
      // Some RSA test vectors test invalid inputs. If cryptolib returns
      // an invalid input code, we simply respond with "validation
      // failed". Otherwise, we error out.
      LOG_ERROR("BAD ARGUMENT");
      uj_output = kCryptotestRsaVerifyOutputFailure;
      RESP_OK(ujson_serialize_cryptotest_rsa_verify_output_t, uj, &uj_output);
      break;
    }
    default: {
      LOG_ERROR(
          "Unexpected status value returned from otcrypto_rsa_verify: "
          "0x%x",
          status.value);
      return INTERNAL();
    }
  }
  return OK_STATUS(0);
}

status_t handle_rsa_oaep_encrypt(ujson_t *uj) {
  cryptotest_rsa_security_level_t uj_security_level;
  cryptotest_rsa_hash_alg_t uj_hash_alg;
  cryptotest_rsa_raw_message_t uj_message;
  cryptotest_rsa_label_t uj_label;
  cryptotest_rsa_expected_length_t uj_ciphertext_length;
  cryptotest_rsa_public_key_t uj_public_key;
  TRY(ujson_deserialize_cryptotest_rsa_security_level_t(uj,
                                                        &uj_security_level));
  TRY(ujson_deserialize_cryptotest_rsa_hash_alg_t(uj, &uj_hash_alg));
  TRY(ujson_deserialize_cryptotest_rsa_raw_message_t(uj, &uj_message));
  TRY(ujson_deserialize_cryptotest_rsa_label_t(uj, &uj_label));
  TRY(ujson_deserialize_cryptotest_rsa_expected_length_t(
      uj, &uj_ciphertext_length));
  TRY(ujson_deserialize_cryptotest_rsa_public_key_t(uj, &uj_public_key));

  otcrypto_hash_mode_t mode;
  switch (uj_hash_alg) {
    case kCryptotestRsaHashAlgSha256:
      mode = kOtcryptoHashModeSha256;
      break;
    case kCryptotestRsaHashAlgSha384:
      mode = kOtcryptoHashModeSha384;
      break;
    case kCryptotestRsaHashAlgSha512:
      mode = kOtcryptoHashModeSha512;
      break;
    case kCryptotestRsaHashAlgSha3_256:
      mode = kOtcryptoHashModeSha3_256;
      break;
    case kCryptotestRsaHashAlgSha3_384:
      mode = kOtcryptoHashModeSha3_384;
      break;
    case kCryptotestRsaHashAlgSha3_512:
      mode = kOtcryptoHashModeSha3_512;
      break;
    case kCryptotestRsaHashAlgShake128:
      mode = kOtcryptoHashXofModeShake128;
      break;
    case kCryptotestRsaHashAlgShake256:
      mode = kOtcryptoHashXofModeShake256;
      break;
    default:
      LOG_ERROR("Unrecognized RSA hash mode: %d", uj_hash_alg);
      return INVALID_ARGUMENT();
  }

  // Message is un-hashed (otherwise we couldn't decrypt)
  uint8_t message_buf[RSA_CMD_MAX_RAW_MESSAGE_BYTES];
  memcpy(message_buf, uj_message.message, uj_message.message_len);
  otcrypto_const_byte_buf_t message = {
      .data = message_buf,
      .len = uj_message.message_len,
  };

  rsa_2048_public_key_t public_key_2048;
  rsa_3072_public_key_t public_key_3072;
  rsa_4096_public_key_t public_key_4096;
  uint32_t *key;
  size_t key_length;
  switch (uj_security_level) {
    case kCryptotestRsaSecurityLevelRsa2048:
      memset(public_key_2048.n.data, 0, sizeof(rsa_2048_int_t));
      memcpy(public_key_2048.n.data, uj_public_key.n, uj_public_key.n_len);
      public_key_2048.e = uj_public_key.e;
      key_length = sizeof(rsa_2048_public_key_t);
      key = (uint32_t *)&public_key_2048;
      break;
    case kCryptotestRsaSecurityLevelRsa3072:
      memset(public_key_3072.n.data, 0, sizeof(rsa_3072_int_t));
      memcpy(public_key_3072.n.data, uj_public_key.n, uj_public_key.n_len);
      public_key_3072.e = uj_public_key.e;
      key_length = sizeof(rsa_3072_public_key_t);
      key = (uint32_t *)&public_key_3072;
      break;
    case kCryptotestRsaSecurityLevelRsa4096:
      memset(public_key_4096.n.data, 0, sizeof(rsa_4096_int_t));
      memcpy(&public_key_4096.n.data, uj_public_key.n, uj_public_key.n_len);
      public_key_4096.e = uj_public_key.e;
      key_length = sizeof(rsa_4096_public_key_t);
      key = (uint32_t *)&public_key_4096;
      break;
    default:
      LOG_ERROR("Unsupported RSA security level: %d", uj_security_level);
      return INVALID_ARGUMENT();
  }
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeRsaEncryptOaep,
      .key_length = key_length,
      .key = key,
  };

  uint8_t label_buf[RSA_CMD_MAX_LABEL_BYTES];
  memcpy(label_buf, uj_label.label, uj_label.label_len);
  otcrypto_const_byte_buf_t label = {
      .data = label_buf,
      .len = uj_label.label_len,
  };

  uint32_t ciphertext_buf[uj_ciphertext_length.expected_len / sizeof(uint32_t)];
  otcrypto_word32_buf_t ciphertext = {
      .data = ciphertext_buf,
      .len = uj_ciphertext_length.expected_len / sizeof(uint32_t),
  };

  otcrypto_status_t status =
      otcrypto_rsa_encrypt(&public_key, mode, message, label, ciphertext);
  if (status.value != kOtcryptoStatusValueOk) {
    return INTERNAL(status.value);
  }
  cryptotest_rsa_ciphertext_t uj_ciphertext;
  memcpy(uj_ciphertext.ciphertext, ciphertext.data,
         ciphertext.len * sizeof(uint32_t));
  uj_ciphertext.ciphertext_len = ciphertext.len * sizeof(uint32_t);
  RESP_OK(ujson_serialize_cryptotest_rsa_ciphertext_t, uj, &uj_ciphertext);

  return OK_STATUS(0);
}

status_t handle_rsa_oaep_decrypt(ujson_t *uj) {
  cryptotest_rsa_security_level_t uj_security_level;
  cryptotest_rsa_hash_alg_t uj_hash_alg;
  cryptotest_rsa_ciphertext_t uj_ciphertext;
  cryptotest_rsa_label_t uj_label;
  cryptotest_rsa_expected_length_t uj_plaintext_length;
  cryptotest_rsa_private_key_t uj_private_key;
  TRY(ujson_deserialize_cryptotest_rsa_security_level_t(uj,
                                                        &uj_security_level));
  TRY(ujson_deserialize_cryptotest_rsa_hash_alg_t(uj, &uj_hash_alg));
  TRY(ujson_deserialize_cryptotest_rsa_ciphertext_t(uj, &uj_ciphertext));
  TRY(ujson_deserialize_cryptotest_rsa_label_t(uj, &uj_label));
  TRY(ujson_deserialize_cryptotest_rsa_expected_length_t(uj,
                                                         &uj_plaintext_length));
  TRY(ujson_deserialize_cryptotest_rsa_private_key_t(uj, &uj_private_key));

  otcrypto_hash_mode_t mode;
  size_t hash_len;
  switch (uj_hash_alg) {
    case kCryptotestRsaHashAlgSha256:
      mode = kOtcryptoHashModeSha256;
      hash_len = kSha256DigestBytes;
      break;
    case kCryptotestRsaHashAlgSha384:
      mode = kOtcryptoHashModeSha384;
      hash_len = kSha384DigestBytes;
      break;
    case kCryptotestRsaHashAlgSha512:
      mode = kOtcryptoHashModeSha512;
      hash_len = kSha512DigestBytes;
      break;
    case kCryptotestRsaHashAlgSha3_256:
      mode = kOtcryptoHashModeSha3_256;
      hash_len = kSha256DigestBytes;
      break;
    case kCryptotestRsaHashAlgSha3_384:
      mode = kOtcryptoHashModeSha3_384;
      hash_len = kSha384DigestBytes;
      break;
    case kCryptotestRsaHashAlgSha3_512:
      mode = kOtcryptoHashModeSha3_512;
      hash_len = kSha512DigestBytes;
      break;
    default:
      LOG_ERROR("Unrecognized RSA hash mode: %d", uj_hash_alg);
      return INVALID_ARGUMENT();
  }
  size_t key_length;
  size_t keyblob_length;
  uint32_t d_share1_buf[sizeof(rsa_4096_int_t) / sizeof(uint32_t)];
  otcrypto_rsa_size_t rsa_size;
  switch (uj_security_level) {
    case kCryptotestRsaSecurityLevelRsa2048:
      key_length = kOtcryptoRsa2048PrivateKeyBytes;
      keyblob_length = kOtcryptoRsa2048PrivateKeyblobBytes;
      rsa_size = kOtcryptoRsaSize2048;
      // Blind private exponent d using random mask
      for (size_t i = 0; i < sizeof(rsa_2048_int_t) / sizeof(uint32_t); i++) {
        d_share1_buf[i] = RANDOM_MASK[i] ^ ((uint32_t *)uj_private_key.d)[i];
      }
      break;
    case kCryptotestRsaSecurityLevelRsa3072:
      key_length = kOtcryptoRsa3072PrivateKeyBytes;
      keyblob_length = kOtcryptoRsa3072PrivateKeyblobBytes;
      rsa_size = kOtcryptoRsaSize3072;
      // Blind private exponent d using random mask
      for (size_t i = 0; i < sizeof(rsa_3072_int_t) / sizeof(uint32_t); i++) {
        d_share1_buf[i] = RANDOM_MASK[i] ^ ((uint32_t *)uj_private_key.d)[i];
      }
      break;
    case kCryptotestRsaSecurityLevelRsa4096:
      key_length = kOtcryptoRsa4096PrivateKeyBytes;
      keyblob_length = kOtcryptoRsa4096PrivateKeyblobBytes;
      rsa_size = kOtcryptoRsaSize4096;
      // Blind private exponent d using random mask
      for (size_t i = 0; i < sizeof(rsa_4096_int_t) / sizeof(uint32_t); i++) {
        d_share1_buf[i] = RANDOM_MASK[i] ^ ((uint32_t *)uj_private_key.d)[i];
      }
      break;
    default:
      LOG_ERROR("Unsupported RSA security level: %d", uj_security_level);
      return INVALID_ARGUMENT();
  }
  otcrypto_key_config_t kPrivateKeyConfig = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeRsaEncryptOaep,
      .key_length = key_length,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelLow,
  };
  uint32_t n[uj_private_key.n_len];
  memcpy(n, uj_private_key.n, uj_private_key.n_len);
  otcrypto_const_word32_buf_t modulus = {
      .len = key_length / sizeof(uint32_t),
      .data = n,
  };
  otcrypto_const_word32_buf_t d_share0 = {
      .len = key_length / sizeof(uint32_t),
      .data = RANDOM_MASK,
  };
  otcrypto_const_word32_buf_t d_share1 = {
      .len = key_length / sizeof(uint32_t),
      .data = d_share1_buf,
  };
  uint32_t keyblob[keyblob_length / sizeof(uint32_t)];
  otcrypto_blinded_key_t private_key = {
      .config = kPrivateKeyConfig,
      .keyblob_length = keyblob_length,
      .keyblob = keyblob,
  };
  // Create blinded private key object from components
  otcrypto_status_t status = otcrypto_rsa_private_key_from_exponents(
      rsa_size, modulus, uj_private_key.e, d_share0, d_share1, &private_key);
  if (status.value != kOtcryptoStatusValueOk) {
    LOG_ERROR("Bad status value from key generation: 0x%x", status.value);
    return INTERNAL(status.value);
  }

  uint32_t ciphertext_buf[RSA_CMD_MAX_CIPHERTEXT_BYTES / sizeof(uint32_t)];
  memcpy(ciphertext_buf, uj_ciphertext.ciphertext,
         uj_ciphertext.ciphertext_len);
  otcrypto_const_word32_buf_t ciphertext = {
      .data = ciphertext_buf,
      .len = uj_ciphertext.ciphertext_len / sizeof(uint32_t),
  };

  uint8_t label_buf[RSA_CMD_MAX_LABEL_BYTES];
  memcpy(label_buf, uj_label.label, uj_label.label_len);
  otcrypto_const_byte_buf_t label = {
      .data = label_buf,
      .len = uj_label.label_len,
  };

  // len(n) - 2 * (hash digest size) - 2
  size_t max_plaintext_len = uj_private_key.n_len - 2 * hash_len - 2;
  uint8_t plaintext_buf[max_plaintext_len];
  otcrypto_byte_buf_t plaintext = {
      .data = plaintext_buf,
      .len = max_plaintext_len,
  };

  size_t actual_plaintext_length;
  status = otcrypto_rsa_decrypt(&private_key, mode, ciphertext, label,
                                plaintext, &actual_plaintext_length);
  cryptotest_rsa_decrypt_output_t uj_output;
  switch (status.value) {
    case kOtcryptoStatusValueOk: {
      uj_output.success = true;
      memcpy(uj_output.plaintext, plaintext.data, actual_plaintext_length);
      uj_output.plaintext_len = actual_plaintext_length;
      RESP_OK(ujson_serialize_cryptotest_rsa_decrypt_output_t, uj, &uj_output);
      break;
    }
    case kOtcryptoStatusValueBadArgs: {
      // Some RSA test vectors test invalid inputs. If cryptolib returns
      // an invalid input code, we simply respond with "validation
      // failed". Otherwise, we error out.
      LOG_ERROR("BAD ARGUMENT");
      uj_output.success = false;
      RESP_OK(ujson_serialize_cryptotest_rsa_decrypt_output_t, uj, &uj_output);
      break;
    }
    default: {
      LOG_ERROR(
          "Unexpected status value returned from otcrypto_rsa_decrypt: "
          "0x%x",
          status.value);
      return INTERNAL();
    }
  }
  return OK_STATUS(0);
}

status_t handle_rsa(ujson_t *uj) {
  cryptotest_rsa_operation_t uj_op;
  cryptotest_rsa_padding_t uj_padding;
  TRY(ujson_deserialize_cryptotest_rsa_operation_t(uj, &uj_op));
  TRY(ujson_deserialize_cryptotest_rsa_padding_t(uj, &uj_padding));

  switch (uj_op) {
    case kCryptotestRsaOperationSign: {
      switch (uj_padding) {
        case kCryptotestRsaPaddingPkcs15:
          return handle_rsa_sign(uj, kOtcryptoRsaPaddingPkcs);
        case kCryptotestRsaPaddingPss:
          return handle_rsa_sign(uj, kOtcryptoRsaPaddingPss);
        default:
          LOG_ERROR("Unexpected RSA padding mode for sign operation: %d",
                    uj_padding);
          return INVALID_ARGUMENT();
      }
    }
    case kCryptotestRsaOperationVerify: {
      switch (uj_padding) {
        case kCryptotestRsaPaddingPkcs15:
          return handle_rsa_verify(uj, kOtcryptoRsaPaddingPkcs);
        case kCryptotestRsaPaddingPss:
          return handle_rsa_verify(uj, kOtcryptoRsaPaddingPss);
        default:
          LOG_ERROR("Unexpected RSA padding mode for cerify operation: %d",
                    uj_padding);
          return INVALID_ARGUMENT();
      }
    }
    case kCryptotestRsaOperationEncrypt: {
      switch (uj_padding) {
        case kCryptotestRsaPaddingOaep:
          return handle_rsa_oaep_encrypt(uj);
        default:
          LOG_ERROR("Unexpected RSA padding mode for encrypt operation: %d",
                    uj_padding);
          return INVALID_ARGUMENT();
      }
    }
    case kCryptotestRsaOperationDecrypt: {
      switch (uj_padding) {
        case kCryptotestRsaPaddingOaep:
          return handle_rsa_oaep_decrypt(uj);
        default:
          LOG_ERROR("Unexpected RSA padding mode for decrypt operation: %d",
                    uj_padding);
          return INVALID_ARGUMENT();
      }
    }
  }
}
