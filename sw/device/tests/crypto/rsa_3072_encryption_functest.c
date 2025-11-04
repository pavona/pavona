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
  kRsa3072NumBytes = 3072 / 8,
  kRsa3072NumWords = kRsa3072NumBytes / sizeof(uint32_t),
};

// Note: The private key and valid signatures for this test were generated
// out-of-band using the PyCryptodome Python library.

// Test RSA-3072 key pair:
// e = 65537
// n =
// 0xa60f30a231261907afe74287a90cc23b24ec935f7520180f833bf3261c9f5a53c6057b0be827fc8c8adb26e8a4b442f1075a427b065433ac5b973b2ccc4ee3b8e82d5c810922ea4653cdc14e46dcfa85141f23d07fdec0a90b53c50ad1a7e9984bed7f9edcbafdb26398c69c6b8cfc8e2cd843c33fc8e54284807eb9abca302946b16dd82f8c428bd446f2cbf9d614e637c377b39d0a8e494b2dab398094aee11cf0109bb82214b11988b5df0943554126d660d3ac776aa1ea044e20f7e63fafddecb80bde3a683d64a074ff3e1dfa99ab5c16575dfe37bc5bb1b180434ccc4853b671a05c36a62b22df77e1482def92e576ea64ebf8d88d91fcadfeabc571ebedd8bc920d15ec18e300d4747b8bc3e8e04eb5afd95d6ff662ec62aa54ce8e23dd1beacfdde93cc03d9bdfffd2412d3255bed6946258c90c5fcfd55f1e9c1ce3bcd26c2b1299c298f941f8992318ca24154da24dee956a867b1f16bd0241a25db9c19f8630ca11035b29ea9cddf894ca239b6fe8c2242ceb61422b395248e8eb
// d =
// 0x2e1fdefed60f0279cfa2b9288c4ca6709e277621d81b2383bf8c79d3b6b48e76e17469429be7eb6eb02d022831837e6a8b83c71e7bda0c864de47a43cdb605ebb8d5ccb16cb3bd85ee4622f0d69f0f98c24789ffa25ce17fb2cd40586a76acdc280ede59666f2c038e4583b933e873c81bedb018be115398bfcc1f26fc700b2393e6b99f884979bc742886cd206695e4824db1647af4d123cb95724f6507277210c31fa1d929e23c74deb3c1b1457a1b4029e0b83ad9ea8cf1bee362a5e8d6fc546a4e705e73b4c9f8f5486c3c4dcc1e3e812025483a0ef65efe857ea81331256f43345142b3cba4cdb00270c27647b3b8d1185826066b83374bb038098a4e152a95830d621c40e752fc2a22a7bd0a88f7a1e86ae8f2bd3bde3d37027fc735a1f8a09cd55ce7738204a3767a15ce0940fe49e5b63c7a23fa15dae580446884981753730bc0944ac3421f557a1f44a1927863c8051c7f4bd88a71c55225b096ecc52df173bf748b23b332bc608702a398f1624a49919be3408341fecaf3cc45d9

// Modulus (n) in little-endian form.
static uint32_t kTestModulus[kRsa3072NumWords] = {
    0x5248e8eb, 0x61422b39, 0xc2242ceb, 0x239b6fe8, 0xddf894ca, 0x5b29ea9c,
    0x30ca1103, 0xb9c19f86, 0x0241a25d, 0x7b1f16bd, 0xee956a86, 0x154da24d,
    0x2318ca24, 0xf941f899, 0x1299c298, 0xbcd26c2b, 0x1e9c1ce3, 0x5fcfd55f,
    0x6258c90c, 0x55bed694, 0xd2412d32, 0x3d9bdfff, 0xdde93cc0, 0xdd1beacf,
    0x54ce8e23, 0x62ec62aa, 0xd95d6ff6, 0xe04eb5af, 0x7b8bc3e8, 0xe300d474,
    0x0d15ec18, 0xedd8bc92, 0xabc571eb, 0x91fcadfe, 0xebf8d88d, 0xe576ea64,
    0x482def92, 0x22df77e1, 0x5c36a62b, 0x53b671a0, 0x434ccc48, 0x5bb1b180,
    0x5dfe37bc, 0xab5c1657, 0x3e1dfa99, 0x64a074ff, 0xde3a683d, 0xddecb80b,
    0xf7e63faf, 0xea044e20, 0xac776aa1, 0x26d660d3, 0x09435541, 0x1988b5df,
    0xb82214b1, 0x1cf0109b, 0x8094aee1, 0x4b2dab39, 0x9d0a8e49, 0x37c377b3,
    0xf9d614e6, 0xd446f2cb, 0x2f8c428b, 0x46b16dd8, 0xabca3029, 0x84807eb9,
    0x3fc8e542, 0x2cd843c3, 0x6b8cfc8e, 0x6398c69c, 0xdcbafdb2, 0x4bed7f9e,
    0xd1a7e998, 0x0b53c50a, 0x7fdec0a9, 0x141f23d0, 0x46dcfa85, 0x53cdc14e,
    0x0922ea46, 0xe82d5c81, 0xcc4ee3b8, 0x5b973b2c, 0x065433ac, 0x075a427b,
    0xa4b442f1, 0x8adb26e8, 0xe827fc8c, 0xc6057b0b, 0x1c9f5a53, 0x833bf326,
    0x7520180f, 0x24ec935f, 0xa90cc23b, 0xafe74287, 0x31261907, 0xa60f30a2,
};

static uint32_t kTestCofactorP[kRsa3072NumWords / 2] = {
    0x2dcdaa29, 0xa5479f83, 0xf0865f20, 0xa00e6b5c, 0xda2f3b0b, 0xe25ee188,
    0xda871b22, 0x7f3c5312, 0x70d3dbb9, 0x18b5d5c4, 0x6aab200b, 0x4e0f3f82,
    0xf8a21a59, 0x50ef0295, 0x46e46aab, 0x7d2400cd, 0x7eba5cd,  0x663c5c3e,
    0x9864429f, 0x43b5f720, 0x44c7bce9, 0xd1b4e7a6, 0x182fad9f, 0xa44f60d1,
    0x9fbaa2fc, 0xaec05186, 0x5a153b8d, 0x260d7233, 0xf1ca731,  0x3a732dc0,
    0xb8569f49, 0xff65af8b, 0xe7e52e22, 0x89488e07, 0x48d1fb75, 0xa25d2fc9,
    0xd7cc292f, 0xb03ed86e, 0xade0e9e8, 0xc2c7d9a6, 0x3669559e, 0x5e42d96e,
    0xe88cc13f, 0x6e0f4140, 0xbb1d7819, 0xa51aeef0, 0xde49201f, 0xcd8321b3,
};

static uint32_t kTestCofactorQ[kRsa3072NumWords / 2] = {
    0x2ea1c4f3, 0xfc66f8f8, 0x14f3a7a1, 0x7bc379a7, 0x4ead8bc9, 0xa6deed,
    0x3ce15fd7, 0x728a5f2,  0x137b7369, 0x5148e796, 0x4b35584,  0xfd3198c0,
    0x27b7bd07, 0xd1f161c2, 0x3fe253b1, 0x776469d8, 0x2ff32c90, 0x60e7e92b,
    0xc4634b76, 0x92ef2f4,  0x6f47669c, 0x646656d3, 0x84ba2a40, 0x644b9d6c,
    0x46aa19de, 0xac1775f8, 0x4544e5b5, 0xc2016a75, 0xe9e0123b, 0x2a68042b,
    0x1e4ae26a, 0xe5694a01, 0xd4f37598, 0x90dbad6f, 0x73c1fcd1, 0xd038763c,
    0xc4a259da, 0xf346012e, 0xcc1ceddb, 0xa58dc466, 0xd98f53bf, 0xc23171b1,
    0x99d751f5, 0xb0cbd5d5, 0x1c51a0a8, 0x3b583faf, 0x94e9ca26, 0xcedad392,
};

static uint32_t kTestPrivateExponentComponentP[kRsa3072NumWords / 2] = {
    0x8d4c3841, 0xb47d2df,  0x78d7e5cd, 0xa813c5d1, 0x88a5ea0e, 0x7e645d47,
    0xa0234973, 0x9e9f6c13, 0x63aaa6bc, 0xe9499bd,  0xc460330c, 0x8c6f1c30,
    0x574669c4, 0x40f08ad8, 0xf7ecd674, 0xe6f44b6,  0x973659ae, 0x8f8a5927,
    0xd3487ce8, 0x60c3d55e, 0xb435892b, 0x5666de34, 0x794e7453, 0x45fd426a,
    0xe44fbfd5, 0x66bc0c93, 0x3aa737d2, 0x90fca9f9, 0x69e76acd, 0x6ba875fa,
    0x55e10f38, 0xf6b12022, 0x1a119c21, 0x58b5c16b, 0x14bf7b98, 0x1c80a387,
    0x280ab1c4, 0x84f513c3, 0xf6a4c8b,  0x687217ba, 0xe087f11d, 0x8d4259bc,
    0x454af9,   0xcff6d9cd, 0xac279129, 0x351b6fb4, 0x85357c74, 0x866381de,
};

static uint32_t kTestPrivateExponentComponentQ[kRsa3072NumWords / 2] = {
    0x4f94d00b, 0xcaacdde0, 0x81aa7fd7, 0xc265ae41, 0x326c9940, 0x8b427abf,
    0x3a8f513a, 0x35580c14, 0xebfa05c1, 0x52b27b33, 0x7619c80c, 0xa5e076dc,
    0xdef8c89c, 0xd42498c4, 0x753d842c, 0x44858361, 0x7e0b2e5f, 0x9da6b987,
    0x9868b4ce, 0xb7ecb1ac, 0x381254c5, 0xa273df4e, 0x29aa3f66, 0xe8fd5603,
    0xd6fe3210, 0x24041fe2, 0xf4c60024, 0x42cb4edf, 0x94713c64, 0xd3f5212c,
    0x10f126,   0xad37458f, 0x820f1d42, 0x5a0b1136, 0xe000246d, 0x77fdaca4,
    0xf244711b, 0xdceeefad, 0xc968d70a, 0xb73ee87d, 0xc0e913b3, 0x70629c,
    0xdbf9ea12, 0xeeb64955, 0x3d24759f, 0x2ec3bd38, 0xd0def2f7, 0x8d57af0b,
};

static uint32_t kTestCrtCoefficient[kRsa3072NumWords / 2] = {
    0x95932eaa, 0x59702111, 0x2ac49f32, 0x294792d7, 0x8ad3e891, 0x5b5a0c15,
    0x2b6e7c2d, 0x56e13332, 0xe2a6188e, 0x4062dc8d, 0xdaa62268, 0xf28f7c86,
    0x959632bd, 0xb85a7f81, 0xa5885ac,  0x44a95688, 0x871011f5, 0xd5fae09d,
    0xd18a788a, 0x17dc874f, 0x1c9367f2, 0x94ba8be8, 0xdcd7ea3c, 0xd872e83e,
    0x58690c6c, 0xf7f17944, 0x5b7a09ef, 0x2c9440e6, 0x98a67461, 0xc0ffe122,
    0x17a3638,  0x733a43ea, 0x78476d0d, 0xaf954cab, 0x687da12f, 0x7480080e,
    0xd573ce7c, 0xdc8e3c64, 0xa740368d, 0x17af4d83, 0xc45af0e2, 0xdd51be35,
    0xfe85d4f0, 0xa0871757, 0xda54186d, 0x9b3ed119, 0xfe9b64d6, 0x66f89262,
};

static uint32_t kTestPublicExponent = 65537;

// Message data for testing.
static const unsigned char kTestMessage[] = "Test message.";
static const size_t kTestMessageLen = sizeof(kTestMessage) - 1;

// OAEP label for testing.
static const unsigned char kTestLabel[] = "Test label.";
static const size_t kTestLabelLen = sizeof(kTestLabel) - 1;

// Hash mode for testing (and digest length in bytes).
static const otcrypto_hash_mode_t kTestHashMode = kOtcryptoHashModeSha512;
static const size_t kTestHashModeDigestBytes = 512 / 8;

// Maximum plaintext length for OAEP (see IETF RFC 8017).
static const size_t kMaxPlaintextBytes =
    kRsa3072NumBytes - 2 * kTestHashModeDigestBytes - 2;

// Valid ciphertext for `kTestMessage` with the test private key, using OAEP
// encoding with `kTestLabel` and `kTestHashMode`.
static const uint32_t kValidCiphertext[kRsa3072NumWords] = {
    0x2b57a10f, 0x26bbfdb9, 0x22f881b6, 0x3ea3735c, 0xb97896d8, 0x5ca9f2b9,
    0xd70a4c1a, 0xaf1ead0d, 0xc4b0ae6d, 0x76ae6d9b, 0xcacf7b07, 0xb63f651f,
    0x9fc70de5, 0x5f85a0c0, 0xda3b7882, 0x6c539d54, 0xe5566273, 0xeb461031,
    0xb20242d6, 0x0cfcb276, 0x01b4e765, 0xe6ac1931, 0x82bf7c08, 0xb3aebe9c,
    0x37d2f9cd, 0x0fe684a5, 0x9db2afd2, 0xa99b45e5, 0x17a8aff7, 0x22c56bae,
    0x911f3c58, 0x645e7a67, 0x8833eaa5, 0x11e5d4f0, 0xafff8172, 0x40fc3c4c,
    0x0a261c85, 0x6d623878, 0x30115176, 0x2853df91, 0x2bd02f85, 0xb1958b8e,
    0x9288b3f9, 0x430f8ab2, 0x2556cf3a, 0xe485dbfb, 0xa644d055, 0xe0707828,
    0xbd2aef6b, 0xfeb784a2, 0xe5ebbf8b, 0xa5f8b0fa, 0xb24c0f7b, 0xbfad7a83,
    0x54903942, 0x56a20d38, 0xef1ad9a2, 0xbae1bc9b, 0x235c90c3, 0x3a9bd4ef,
    0x2606ef34, 0x643add05, 0x57bc256c, 0xa45749dd, 0x1784134c, 0x3f553100,
    0x46e3ae90, 0x44552576, 0x4feb281d, 0x4f83b747, 0xa890f513, 0x979afc28,
    0x2addc3f2, 0x45a1064e, 0x9e1ade54, 0x551bf540, 0x4337b81c, 0x24259077,
    0x6ba0c23c, 0xd6d81aab, 0xdf94cc28, 0x679ca168, 0xfc2b4700, 0x5018295b,
    0xb8bf3cce, 0x3afdd992, 0x478989db, 0xfd095c8b, 0xd75b556b, 0x4672dd8c,
    0x7b9dfe21, 0xb615edad, 0xf001b4d9, 0x9e6f9920, 0x58a92869, 0x15125194,
};

/**
 * Helper function to run the RSA-3072 encryption routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_encrypt`
 * using the constant test private key.
 *
 * @param msg Message to encrypt.
 * @param msg_len Message length in bytes.
 * @param label Label for OAEP padding.
 * @param label_len Label length in bytes.
 * @param[out] ciphertext Buffer for the generated ciphertext (3072 bits).
 * @return OK or error.
 */
static status_t run_rsa_3072_encrypt(const uint8_t *msg, size_t msg_len,
                                     const uint8_t *label, size_t label_len,
                                     uint32_t *ciphertext) {
  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa3072PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeRsaEncryptOaep,
      .key_length = kOtcryptoRsa3072PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize3072, modulus,
                                        kTestPublicExponent, &public_key));

  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  otcrypto_const_byte_buf_t label_buf = {.data = label, .len = label_len};
  otcrypto_word32_buf_t ciphertext_buf = {
      .data = ciphertext,
      .len = kRsa3072NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_encrypt(&public_key, kTestHashMode, msg_buf, label_buf,
                           ciphertext_buf));
  profile_end_and_print(t_start, "RSA-3072 encryption");

  return OK_STATUS();
}

/**
 * Helper function to run the RSA-3072 decryption routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_encrypt`
 * using the constant test private key.
 *
 * The caller must allocate enough space at `msg` for the maximum message
 * length, `kMaxPlaintextBytes`. The actual message length is returned in
 * `msg_len`.
 *
 * @param label Label for OAEP padding.
 * @param label_len Label length in bytes.
 * @param ciphertext Ciphertext to decrypt (3072 bits).
 * @param[out] msg Decrypted message.
 * @param[out] msg_len Message length in bytes.
 * @return OK or error.
 */
static status_t run_rsa_3072_decrypt(const uint8_t *label, size_t label_len,
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
      .key_length = kOtcryptoRsa3072PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelLow,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa3072PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa3072PrivateKeyblobBytes,
  };
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  TRY(otcrypto_rsa_private_key_from_exponents(kOtcryptoRsaSize3072, modulus, p,
                                              q, kTestPublicExponent, d_p, d_q,
                                              i_q, &private_key));

  otcrypto_byte_buf_t plaintext_buf = {.data = msg, .len = kMaxPlaintextBytes};
  otcrypto_const_byte_buf_t label_buf = {.data = label, .len = label_len};
  otcrypto_const_word32_buf_t ciphertext_buf = {
      .data = ciphertext,
      .len = kRsa3072NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_decrypt(&private_key, kTestHashMode, ciphertext_buf,
                           label_buf, plaintext_buf, msg_len));
  profile_end_and_print(t_start, "RSA-3072 decryption");

  return OK_STATUS();
}

status_t oaep_decrypt_valid_test(void) {
  // Decrypt the valid ciphertext.
  uint8_t actual_msg[kMaxPlaintextBytes];
  size_t actual_msg_len;
  TRY(run_rsa_3072_decrypt(kTestLabel, kTestLabelLen, kValidCiphertext,
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
  uint32_t ciphertext[kRsa3072NumWords];
  TRY(run_rsa_3072_encrypt(kTestMessage, kTestMessageLen, kTestLabel,
                           kTestLabelLen, ciphertext));

  // Decrypt the message.
  uint8_t actual_msg[kMaxPlaintextBytes];
  size_t actual_msg_len;
  TRY(run_rsa_3072_decrypt(kTestLabel, kTestLabelLen, ciphertext, actual_msg,
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
