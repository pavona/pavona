// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/include/rsa.h"
#include "sw/device/lib/crypto/include/sha2.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

// Module for status messages.
#define MODULE_ID MAKE_MODULE_ID('t', 's', 't')

enum {
  kRsa2048NumBytes = 2048 / 8,
  kRsa2048NumWords = kRsa2048NumBytes / sizeof(uint32_t),
};

// Note: The private key and valid signatures for this test were generated
// out-of-band using the PyCryptodome Python library.

// Test RSA-2048 key pair.
static uint32_t kTestModulus[kRsa2048NumWords] = {
    0x40d984b1, 0x3611356d, 0x9eb2f35c, 0x031a892c, 0x16354662, 0x6a260bad,
    0xb2b807d6, 0xb7de7ccb, 0x278492e0, 0x41adab06, 0x9e60110f, 0x1414eeff,
    0x8b80e14e, 0x5eb5ae79, 0x0d98fa5b, 0x58bece1f, 0xcf6bdca8, 0x82f5611f,
    0x351e3869, 0x075005d6, 0xe813fe23, 0xdd967a37, 0x682d1c41, 0x9fdd2d8c,
    0x21bdd5fc, 0x4fc459c7, 0x508c9293, 0x1f9ac759, 0x55aacb04, 0x58389f05,
    0x0d0b00fb, 0x59bb4141, 0x68f9e0bf, 0xc2f1a546, 0x0a71ad19, 0x9c400301,
    0xa4f8ecb9, 0xcdf39538, 0xaabe9cb0, 0xd9f7b2dc, 0x0e8b292d, 0x8ef6c717,
    0x720e9520, 0xb0c6a23e, 0xda1e92b1, 0x8b6b4800, 0x2f25082b, 0x7f2d6711,
    0x426fc94f, 0x9926ba5a, 0x89bd4d2b, 0x977718d5, 0x5a8406be, 0x87d090f3,
    0x639f9975, 0x5948488b, 0x1d3d9cd7, 0x28c7956b, 0xebb97a3e, 0x1edbf4e2,
    0x105cc797, 0x924ec514, 0x146810df, 0xb1ab4a49,
};

static uint32_t kTestCofactorP[kRsa2048NumWords / 2] = {
    0x69e8cdeb, 0x0aab5698, 0x2adbf5a2, 0xc6f3fed7, 0x9b0f148c, 0x68a4b636,
    0xc3c8948c, 0x5ee5c048, 0xb20f9f30, 0xaced9c36, 0xe2a0f71f, 0xf57f3401,
    0x8fb749f8, 0x24f4b1f2, 0x2811dd24, 0x0e45d624, 0x7e4fac27, 0x7049a420,
    0x4ea4172b, 0x1d4f1d2d, 0x15c1dd03, 0x733ce8c1, 0xe5415c61, 0xa3680f9a,
    0xa13ff562, 0xd12a0242, 0x3ef684a4, 0x5241db6e, 0x2e68b5f5, 0xaa3e5397,
    0x45e9606a, 0xb8505888,
};

static uint32_t kTestCofactorQ[kRsa2048NumWords / 2] = {
    0xc69864d3, 0x6eca1793, 0xd985ff65, 0xa888cce8, 0xcadcabc5, 0x47d31ff8,
    0x2eae994a, 0x0ba8594d, 0x956889ed, 0x117f0b01, 0x30ace812, 0x89aa41b9,
    0x716c8c93, 0xb3e54154, 0x70020ae3, 0x3f3926af, 0x91ae5a18, 0xa058daef,
    0xd5a8a0ee, 0xff73e9fb, 0xda00591c, 0x69220aec, 0xe9ee684b, 0x12f4ea77,
    0xea538fb5, 0x0505826e, 0xef416b24, 0x5c65d8d6, 0xce422bd4, 0x3f4f37ed,
    0xdd6aff12, 0xf6c55808,
};

static uint32_t kTestPrivateExponentComponentP[kRsa2048NumWords / 2] = {
    0x450b9217, 0x4edd47a6, 0x65eaa581, 0xa489536c, 0x46c6416e, 0xcdcd3461,
    0x07ba3fc0, 0x95d56f89, 0xcf3c23f1, 0x3a09db7b, 0x841780f5, 0x3ee50c5d,
    0x6858dd49, 0xf56e4c70, 0x872d1012, 0xe23c883f, 0x24170efd, 0xeb61ae33,
    0xd05cb6b7, 0x81db8c2f, 0x1cd58c9b, 0xa828fecf, 0x09db577e, 0xcdc21d77,
    0x9ebfb60c, 0xbacad629, 0x98bc44a7, 0x8498e6dc, 0x399dc28f, 0x95d22e4d,
    0x7b1d095d, 0xacc9ede5,
};

static uint32_t kTestPrivateExponentComponentQ[kRsa2048NumWords / 2] = {
    0x1294bbf7, 0x8b2919b9, 0x19e6e6bb, 0x5bac57cf, 0x94878d05, 0xdd0297c9,
    0xc2fa4a31, 0x250dbc5d, 0xa6e04ae3, 0xc4f6deb7, 0x5d21fd5f, 0x6e02cdea,
    0xb967b151, 0x1324bb70, 0xe7c7e19a, 0x93faa85b, 0xcea179ee, 0xda7b268f,
    0xb4953e88, 0x5da887cf, 0xf3475b09, 0xf0f59bd2, 0xd783b40b, 0x871df1f6,
    0x7781156f, 0x2d8a9b67, 0xf1555281, 0xdf14b659, 0x85d12616, 0x28f80092,
    0x50663f6f, 0xb2191d7f,
};

static uint32_t kTestCrtCoefficient[kRsa2048NumWords / 2] = {
    0x8678e23f, 0x208181a5, 0x4c846651, 0xd7015b89, 0x75c82ec3, 0x9ab976a8,
    0xdc502277, 0xe354d4f1, 0x57b4eecb, 0x347c059,  0xf98ab29f, 0x38b694ec,
    0x8ef8acf0, 0xd530b8a6, 0x36cf279f, 0xacdb1beb, 0xc89e371d, 0xe9080f0f,
    0x05f32291, 0x4c4cc843, 0x4f7bd2e4, 0xa158cc81, 0x2b3fdadf, 0x20b88f37,
    0x5e424f2a, 0x41794ace, 0x86297642, 0x1472ceaa, 0xeedce93a, 0xad62154d,
    0xae949fc6, 0x267d8cbc,
};

static uint32_t kTestPublicExponent = 65537;

// Message data for testing.
static const unsigned char kTestMessage[] = "Test message.";
static const size_t kTestMessageLen = sizeof(kTestMessage) - 1;

// OAEP label for testing.
static const unsigned char kTestLabel[] = "Test label.";
static const size_t kTestLabelLen = sizeof(kTestLabel) - 1;

// Hash mode for testing (and digest length in bytes).
static const otcrypto_hash_mode_t kTestHashMode = kOtcryptoHashModeSha256;
static const size_t kTestHashModeDigestBytes = 256 / 8;

// Maximum plaintext length for OAEP (see IETF RFC 8017).
static const size_t kMaxPlaintextBytes =
    kRsa2048NumBytes - 2 * kTestHashModeDigestBytes - 2;

// Valid ciphertext for `kTestMessage` with the test private key, using OAEP
// encoding with `kTestLabel` and `kTestHashMode`.
static const uint32_t kValidCiphertext[kRsa2048NumWords] = {
    0xfd4efa2a, 0x98502230, 0x8f40a23d, 0xf1bc68ec, 0x32c09a86, 0x31a34a7f,
    0x4cc36d4d, 0xebde83bb, 0xd8641f7e, 0xedc26ed4, 0x8cd83ce6, 0xca3e0696,
    0x5a425138, 0xd5d55a43, 0x4666b6eb, 0x7d031dee, 0xbc92a18d, 0xce7f14be,
    0x768d170,  0xa3b26259, 0x668cf732, 0x72b44d0e, 0xd9f35df1, 0x67e194af,
    0xf4a47c8a, 0x8c0be5ee, 0x3b132be9, 0x797cdeb,  0x5ac41ab2, 0x960bd1bb,
    0x4d5f9c16, 0x1b40df52, 0x1cc85cae, 0x897f104f, 0xa6d56f86, 0x13d59592,
    0x741b5a79, 0x15732dbb, 0xa792b600, 0x8a1a6ad8, 0x6192b34b, 0xd5516b1a,
    0xab6c8133, 0x4b820cb3, 0xdec5f9b5, 0x9d479d3a, 0xd8e8109c, 0xe9e79346,
    0x91e4c925, 0x730c258,  0x3ae71747, 0x50ab1e5e, 0x931bd40a, 0x351d2440,
    0xb5e9273d, 0xd07a5e7b, 0x84487ef2, 0xfa2c3eae, 0x60a289db, 0x533d9a42,
    0x3473ae8,  0x6b43b4a4, 0x4944f45f, 0x9588b044,
};

/**
 * Helper function to run the RSA-2048 encryption routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_encrypt`
 * using the constant test private key.
 *
 * @param msg Message to encrypt.
 * @param msg_len Message length in bytes.
 * @param label Label for OAEP padding.
 * @param label_len Label length in bytes.
 * @param[out] ciphertext Buffer for the generated ciphertext (2048 bits).
 * @return OK or error.
 */
static status_t run_rsa_2048_encrypt(const uint8_t *msg, size_t msg_len,
                                     const uint8_t *label, size_t label_len,
                                     uint32_t *ciphertext) {
  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa2048PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeRsaEncryptOaep,
      .key_length = kOtcryptoRsa2048PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize2048, modulus,
                                        kTestPublicExponent, &public_key));

  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  otcrypto_const_byte_buf_t label_buf = {.data = label, .len = label_len};
  otcrypto_word32_buf_t ciphertext_buf = {
      .data = ciphertext,
      .len = kRsa2048NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_encrypt(&public_key, kTestHashMode, msg_buf, label_buf,
                           ciphertext_buf));
  profile_end_and_print(t_start, "RSA-2048 encryption");

  return OK_STATUS();
}

/**
 * Helper function to run the RSA-2048 decryption routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_decrypt`
 * using the constant test private key.
 *
 * The caller must allocate enough space at `msg` for the maximum message
 * length, `kMaxPlaintextBytes`. The actual message length is returned in
 * `msg_len`.
 *
 * @param label Label for OAEP padding.
 * @param label_len Label length in bytes.
 * @param ciphertext Ciphertext to decrypt (2048 bits).
 * @param[out] msg Decrypted message.
 * @param[out] msg_len Message length in bytes.
 * @return OK or error.
 */
static status_t run_rsa_2048_decrypt(const uint8_t *label, size_t label_len,
                                     const uint32_t *ciphertext, uint8_t *msg,
                                     size_t *msg_len) {
  // Create two shares for the private exponent (second share is all-zero).
  otcrypto_const_word32_buf_t p = {
      .data = kTestCofactorP,
      .len = ARRAYSIZE(kTestCofactorP),
  };
  otcrypto_const_word32_buf_t q = {
      .data = kTestCofactorQ,
      .len = ARRAYSIZE(kTestCofactorQ),
  };
  otcrypto_const_word32_buf_t d_p = {
      .data = kTestPrivateExponentComponentP,
      .len = ARRAYSIZE(kTestPrivateExponentComponentP),
  };
  otcrypto_const_word32_buf_t d_q = {
      .data = kTestPrivateExponentComponentQ,
      .len = ARRAYSIZE(kTestPrivateExponentComponentQ),
  };
  otcrypto_const_word32_buf_t i_q = {
      .data = kTestCrtCoefficient,
      .len = ARRAYSIZE(kTestCrtCoefficient),
  };

  // Construct the private key.
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kOtcryptoKeyModeRsaEncryptOaep,
      .key_length = kOtcryptoRsa2048PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelLow,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa2048PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa2048PrivateKeyblobBytes,
  };
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  TRY(otcrypto_rsa_private_key_from_exponents(kOtcryptoRsaSize2048, modulus, p,
                                              q, kTestPublicExponent, d_p, d_q,
                                              i_q, &private_key));

  otcrypto_byte_buf_t plaintext_buf = {.data = msg, .len = kMaxPlaintextBytes};
  otcrypto_const_byte_buf_t label_buf = {.data = label, .len = label_len};
  otcrypto_const_word32_buf_t ciphertext_buf = {
      .data = ciphertext,
      .len = kRsa2048NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_decrypt(&private_key, kTestHashMode, ciphertext_buf,
                           label_buf, plaintext_buf, msg_len));
  profile_end_and_print(t_start, "RSA-2048 decryption");

  return OK_STATUS();
}

status_t oaep_decrypt_valid_test(void) {
  // Decrypt the valid ciphertext.
  uint8_t actual_msg[kMaxPlaintextBytes];
  size_t actual_msg_len;
  TRY(run_rsa_2048_decrypt(kTestLabel, kTestLabelLen, kValidCiphertext,
                           actual_msg, &actual_msg_len));

  // Compare to the expected plaintext.
  TRY_CHECK(actual_msg_len == kTestMessageLen);
  TRY_CHECK_ARRAYS_EQ(actual_msg, kTestMessage, actual_msg_len);
  return OK_STATUS();
}

status_t oaep_encrypt_decrypt_test(void) {
  // Encrypt the message. Because OAEP is not deterministic, we cannot compare
  // to an exact expected value, but we can check that it successfully
  // decrypts.
  uint32_t ciphertext[kRsa2048NumWords];
  TRY(run_rsa_2048_encrypt(kTestMessage, kTestMessageLen, kTestLabel,
                           kTestLabelLen, ciphertext));

  // Decrypt the message.
  uint8_t actual_msg[kMaxPlaintextBytes];
  size_t actual_msg_len;
  TRY(run_rsa_2048_decrypt(kTestLabel, kTestLabelLen, ciphertext, actual_msg,
                           &actual_msg_len));

  // Compare to the original message.
  TRY_CHECK(actual_msg_len == kTestMessageLen);
  TRY_CHECK_ARRAYS_EQ(actual_msg, kTestMessage, actual_msg_len);
  return OK_STATUS();
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, oaep_decrypt_valid_test);
  EXECUTE_TEST(test_result, oaep_encrypt_decrypt_test);
  return status_ok(test_result);
}
