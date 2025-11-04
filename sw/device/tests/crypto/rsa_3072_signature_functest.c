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
  kSha512DigestWords = 512 / 32,
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

// Valid signature of `kTestMessage` from the test private key, using PKCS#1
// v1.5 padding and SHA-512 as the hash function.
static const uint32_t kValidSignaturePkcs1v15[kRsa3072NumWords] = {
    0xb091ff65, 0xd1edc6a5, 0x574498d4, 0x2d6e34d9, 0xb96eb9fe, 0x48194af9,
    0x8973e3bd, 0x6f66bc1d, 0x55032373, 0x68d5ced7, 0x87998790, 0xe86f7eb1,
    0x0f07e31b, 0x2842ada5, 0x2af683ab, 0x55245677, 0x4ac777e8, 0x130aa2d6,
    0x0f7eebb5, 0x9dfa75db, 0x41bbe218, 0xf4f7a2d7, 0xff153220, 0x6e6cd5e8,
    0xa44fd6b5, 0xfe085392, 0x60e2b298, 0x1c5f74f4, 0x032e2d39, 0xd1c16723,
    0xa6ae5514, 0x357c60b7, 0x61a51bbc, 0x009391dd, 0x0142d92e, 0xd1593a14,
    0xbffd75c3, 0x55fdbde2, 0x40533d4b, 0xb423ded9, 0x83106eee, 0x0a6bd1cc,
    0x9c85a4cb, 0xfa1da7fe, 0x09b79f0c, 0x6ca08324, 0xa3182ce5, 0x9d9ee66d,
    0x94213c86, 0x9ac854b3, 0x8803ad55, 0xc3ad2e23, 0x7f11620c, 0x56032b2d,
    0xac4e36be, 0x553b2d2c, 0xc489cec1, 0x40846292, 0x9b4849fd, 0x0d63a0f4,
    0x27abfa17, 0xec055e10, 0x310e3ef2, 0x953a6701, 0xf844985e, 0x2944b2df,
    0x37c9097d, 0xcd40700e, 0x57759607, 0xdda27413, 0x77a65ad3, 0x8752df0c,
    0x50329618, 0x14b74fa7, 0xc9236c54, 0xb8f07265, 0x5b9efc20, 0x15f5f821,
    0xde9ca767, 0x34bf1a70, 0xca4d5d9c, 0x92725953, 0x998d1231, 0x73bd12aa,
    0xc222b65f, 0xde00db56, 0xc9e1aaff, 0xb2d32c27, 0x05b93bb4, 0x94b52732,
    0xbdc53790, 0x92e62a85, 0xc1cb4a8a, 0xff3fe179, 0x565f6d7f, 0x0f784c4a,
};

// Valid signature of `kTestMessage` from the test private key, using PSS
// padding and SHA-512 as the hash function.
static const uint32_t kValidSignaturePss[kRsa3072NumWords] = {
    0xff478de6, 0x9c32afcc, 0x606818a2, 0x10a3510f, 0x474819ee, 0x04be7c07,
    0xd8bd7511, 0xcf392927, 0x6883efcd, 0x15986843, 0x26e311b9, 0x27d718ac,
    0xc507b105, 0xfd519ef7, 0x1dd94e1e, 0x4bc8e633, 0x9c4acb4d, 0x21719940,
    0x7c7b6449, 0x998cd74f, 0xd33c1989, 0x5ef49d96, 0x63e111b0, 0xcca6d7f5,
    0x75c80acb, 0x07e8907d, 0x3e9d3fcd, 0x493a518e, 0x73aab881, 0xabdc13cc,
    0x81ed48f2, 0x12395425, 0x7957265f, 0xde23f84b, 0xa7a51962, 0xbceac204,
    0x1291a9bd, 0x72c83723, 0x9a110ca7, 0x46db7dcc, 0x8af37092, 0x27e9eacd,
    0xe37be422, 0xeded8b48, 0xdaa20d27, 0xb855507b, 0xe5d45f30, 0x15d6e2e4,
    0x795c88c2, 0xa7f130c7, 0x973ce990, 0x282625f7, 0x08f2ce39, 0xd8a2b491,
    0xea037444, 0x41efd30d, 0x44a69d6a, 0xf59709be, 0xc42b92df, 0x516ab280,
    0xe2f9c7b4, 0xcf3693a8, 0x9b28d5f3, 0x8cbda1ef, 0xa2a05f13, 0x344858e9,
    0xb8372f6a, 0x4bdc6efd, 0x90ecabab, 0xdb0589e8, 0x1d59f90f, 0x531cf1f2,
    0x486f3233, 0x6a946ee8, 0x302a6c49, 0x507dda2b, 0x21287d8f, 0x68ec5762,
    0x81df3cdb, 0x7f0a0851, 0x69f0e825, 0x3bba8632, 0x6a98b6fd, 0xf0bdd53d,
    0xc9d928a1, 0x6501fded, 0x0e4d8b0b, 0x11ffdc3a, 0xda6a6fa8, 0x567a7e65,
    0xe2f6c106, 0x4569d9c9, 0x3d69f35e, 0x6d1ebc67, 0x0f4ecb9a, 0x31628ec0,
};

/**
 * Helper function to run the RSA-3072 signing routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_sign`
 * using the constant test private key. Always uses SHA-512 as the hash
 * function.
 *
 * @param msg Message to sign.
 * @param msg_len Message length in bytes.
 * @param padding_mode RSA padding mode.
 * @param[out] sig Buffer for the generated RSA signature (3072 bits).
 * @return OK or error.
 */
static status_t run_rsa_3072_sign(const uint8_t *msg, size_t msg_len,
                                  otcrypto_rsa_padding_t padding_mode,
                                  uint32_t *sig) {
  otcrypto_key_mode_t key_mode;
  switch (padding_mode) {
    case kOtcryptoRsaPaddingPkcs:
      key_mode = kOtcryptoKeyModeRsaSignPkcs;
      break;
    case kOtcryptoRsaPaddingPss:
      key_mode = kOtcryptoKeyModeRsaSignPss;
      break;
    default:
      return INVALID_ARGUMENT();
  };

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

  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
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

  // Hash the message.
  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  uint32_t msg_digest_data[kSha512DigestWords];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_512(msg_buf, &msg_digest));

  otcrypto_word32_buf_t sig_buf = {
      .data = sig,
      .len = kRsa3072NumWords,
  };

  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_sign(&private_key, msg_digest, padding_mode, sig_buf));
  profile_end_and_print(t_start, "RSA signature generation");

  return OK_STATUS();
}

/**
 * Helper function to run the RSA-3072 verification routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_verify`
 * using the constant test public key. Always uses SHA-512 as the hash
 * function.
 *
 * @param msg Message to verify.
 * @param msg_len Message length in bytes.
 * @param sig Signature to verify
 * @param padding_mode RSA padding mode.
 * @param[out] verification_result Whether the signature passed verification.
 * @return OK or error.
 */
static status_t run_rsa_3072_verify(const uint8_t *msg, size_t msg_len,
                                    const uint32_t *sig,
                                    const otcrypto_rsa_padding_t padding_mode,
                                    hardened_bool_t *verification_result) {
  otcrypto_key_mode_t key_mode;
  switch (padding_mode) {
    case kOtcryptoRsaPaddingPkcs:
      key_mode = kOtcryptoKeyModeRsaSignPkcs;
      break;
    case kOtcryptoRsaPaddingPss:
      key_mode = kOtcryptoKeyModeRsaSignPss;
      break;
    default:
      return INVALID_ARGUMENT();
  };

  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa3072PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = key_mode,
      .key_length = kOtcryptoRsa3072PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize3072, modulus,
                                        kTestPublicExponent, &public_key));

  // Hash the message.
  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  uint32_t msg_digest_data[kSha512DigestWords];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_512(msg_buf, &msg_digest));

  otcrypto_const_word32_buf_t sig_buf = {
      .data = sig,
      .len = kRsa3072NumWords,
  };

  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_verify(&public_key, msg_digest, padding_mode, sig_buf,
                          verification_result));
  profile_end_and_print(t_start, "RSA verify");

  return OK_STATUS();
}

status_t pkcs1v15_sign_test(void) {
  // Generate a signature using PKCS#1 v1.5 padding and SHA-512 as the hash
  // function.
  uint32_t sig[kRsa3072NumWords];
  TRY(run_rsa_3072_sign(kTestMessage, kTestMessageLen, kOtcryptoRsaPaddingPkcs,
                        sig));

  // Compare to the expected signature.
  TRY_CHECK_ARRAYS_EQ(sig, kValidSignaturePkcs1v15,
                      ARRAYSIZE(kValidSignaturePkcs1v15));
  return OK_STATUS();
}

status_t pkcs1v15_verify_valid_test(void) {
  // Try to verify a valid signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_3072_verify(kTestMessage, kTestMessageLen,
                          kValidSignaturePkcs1v15, kOtcryptoRsaPaddingPkcs,
                          &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pkcs1v15_verify_invalid_test(void) {
  // Try to verify an invalid signature (wrong padding mode).
  hardened_bool_t verification_result;
  TRY(run_rsa_3072_verify(kTestMessage, kTestMessageLen, kValidSignaturePss,
                          kOtcryptoRsaPaddingPkcs, &verification_result));

  // Expect the signature to fail verification.
  TRY_CHECK(verification_result == kHardenedBoolFalse);
  return OK_STATUS();
}

status_t pss_sign_test(void) {
  // PSS signatures are not deterministic, so we need to sign-then-verify.
  uint32_t sig[kRsa3072NumWords];
  TRY(run_rsa_3072_sign(kTestMessage, kTestMessageLen, kOtcryptoRsaPaddingPss,
                        sig));

  // Try to verify the signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_3072_verify(kTestMessage, kTestMessageLen, sig,
                          kOtcryptoRsaPaddingPss, &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pss_verify_valid_test(void) {
  // Try to verify a valid signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_3072_verify(kTestMessage, kTestMessageLen, kValidSignaturePss,
                          kOtcryptoRsaPaddingPss, &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pss_verify_invalid_test(void) {
  // Try to verify an invalid signature (wrong padding mode).
  hardened_bool_t verification_result;
  TRY(run_rsa_3072_verify(kTestMessage, kTestMessageLen,
                          kValidSignaturePkcs1v15, kOtcryptoRsaPaddingPss,
                          &verification_result));

  // Expect the signature to fail verification.
  TRY_CHECK(verification_result == kHardenedBoolFalse);
  return OK_STATUS();
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, pkcs1v15_sign_test);
  EXECUTE_TEST(test_result, pkcs1v15_verify_valid_test);
  EXECUTE_TEST(test_result, pkcs1v15_verify_invalid_test);
  EXECUTE_TEST(test_result, pss_sign_test);
  EXECUTE_TEST(test_result, pss_verify_valid_test);
  EXECUTE_TEST(test_result, pss_verify_invalid_test);
  return status_ok(test_result);
}
