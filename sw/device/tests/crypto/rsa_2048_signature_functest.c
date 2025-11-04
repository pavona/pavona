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

// Valid signature of `kTestMessage` from the test private key, using PKCS#1
// v1.5 padding and SHA-256 as the hash function.
static const uint32_t kValidSignaturePkcs1v15[kRsa2048NumWords] = {
    0xab66c6c7, 0x97effc0a, 0x9869cdba, 0x7b6c09fe, 0x2124d28f, 0x793084b3,
    0x4da24b72, 0x4f6c8659, 0x63e3a27b, 0xbbe8d120, 0x8789190f, 0x1722fe46,
    0x25573178, 0x3accbdb3, 0x1eb7ca00, 0xe8eb40aa, 0x1d3b21a8, 0x9997925e,
    0x1793f81d, 0x12728f54, 0x66e40608, 0x4b1057a0, 0xba433eb3, 0x702c73b2,
    0xa9391740, 0xf838710f, 0xf33cf109, 0x595cee1d, 0x07341be9, 0xcfce52b1,
    0x5b48ba7a, 0xf70e5a0e, 0xdbb98c42, 0x85fd6979, 0xcdb760fc, 0xd2e09553,
    0x70bba417, 0x04e52609, 0xc215420e, 0x2407242e, 0x4f19674b, 0x5d996a9d,
    0xf2fb1d05, 0x88e0fc14, 0xe1a38f0c, 0xd111935d, 0xd23bf5b3, 0xdcd7a882,
    0x0f242315, 0xd7247d51, 0xc247d6ec, 0xe2492739, 0x3dfb115c, 0x031aea7a,
    0xcdcb09c0, 0x29318ddb, 0xd0a10dd8, 0x3307018e, 0xe13c5616, 0x98d4db80,
    0x50692a42, 0x41e94a74, 0x0a6f79eb, 0x1c405c66,
};

// Valid signature of `kTestMessage` from the test private key, using PSS
// padding and SHA-256 as the hash function.
static const uint32_t kValidSignaturePss[kRsa2048NumWords] = {
    0x6203140a, 0xa860e759, 0x65ddb724, 0x2b4eedfa, 0xf11d5e65, 0xa6ab5601,
    0x14097f2e, 0x56f9dda5, 0xcb43ebcc, 0x7914036d, 0x83e99afd, 0x323187a7,
    0x6f239172, 0x0fc9f25a, 0xe83555a7, 0xd12997e2, 0x65dcd504, 0x99ebef85,
    0x4a5f2679, 0xedf106d8, 0x68c21486, 0xeb7edb37, 0x33e22631, 0xf23699ae,
    0x679b750e, 0xb5c09869, 0x72f7ccd0, 0xef503c8f, 0xa0225545, 0x86554913,
    0xbce86ec4, 0x75f846d2, 0xf16318a8, 0xbce00097, 0x170a418f, 0x558e2f9f,
    0xed555d51, 0x061b6074, 0x859c0bb6, 0xb2800a5a, 0x0180afd3, 0x41f0a2d6,
    0xc75b12ff, 0xaa6179f7, 0x63e71a9a, 0xbdbd759e, 0xe39d7372, 0xa579683f,
    0x8db987a5, 0x8bd0e702, 0x8b32ed36, 0x988e28ee, 0x21c3402d, 0x48490be0,
    0xcbfb2e91, 0x1ba04f77, 0x0ca06d1d, 0xcf2a8645, 0xed3f78e4, 0x4483da1d,
    0x2df279d7, 0xada9475e, 0x6ec0863d, 0x94eb575c,
};

/**
 * Helper function to run the RSA-2048 signing routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_sign`
 * using the constant test private key.
 *
 * @param msg Message to sign.
 * @param msg_len Message length in bytes.
 * @param padding_mode RSA padding mode.
 * @param hash_mode Hash function to use.
 * @param[out] sig Buffer for the generated RSA signature (2048 bits).
 * @return OK or error.
 */
static status_t run_rsa_2048_sign(const uint8_t *msg, size_t msg_len,
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

  // Construct the private key.
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = key_mode,
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

  // Hash the message.
  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  uint32_t msg_digest_data[256 / 32];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_256(msg_buf, &msg_digest));

  otcrypto_word32_buf_t sig_buf = {
      .data = sig,
      .len = kRsa2048NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_sign(&private_key, msg_digest, padding_mode, sig_buf));
  profile_end_and_print(t_start, "RSA signature generation");

  return OK_STATUS();
}

/**
 * Helper function to run the RSA-2048 verification routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_verify`
 * using the constant test public key. Always uses SHA-256 as the hash
 * function.
 *
 * @param msg Message to verify.
 * @param msg_len Message length in bytes.
 * @param sig Signature to verify
 * @param padding_mode RSA padding mode.
 * @param[out] verification_result Whether the signature passed verification.
 * @return OK or error.
 */
static status_t run_rsa_2048_verify(const uint8_t *msg, size_t msg_len,
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
  uint32_t public_key_data[ceil_div(kOtcryptoRsa2048PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = key_mode,
      .key_length = kOtcryptoRsa2048PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize2048, modulus,
                                        kTestPublicExponent, &public_key));

  // Hash the message.
  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  uint32_t msg_digest_data[256 / 32];
  otcrypto_hash_digest_t msg_digest = {
      .data = msg_digest_data,
      .len = ARRAYSIZE(msg_digest_data),
  };
  TRY(otcrypto_sha2_256(msg_buf, &msg_digest));

  otcrypto_const_word32_buf_t sig_buf = {
      .data = sig,
      .len = kRsa2048NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_verify(&public_key, msg_digest, padding_mode, sig_buf,
                          verification_result));
  profile_end_and_print(t_start, "RSA verify");

  return OK_STATUS();
}

status_t pkcs1v15_sign_test(void) {
  // Generate a signature using PKCS#1 v1.5 padding and SHA-256 as the hash
  // function.
  uint32_t sig[kRsa2048NumWords];
  TRY(run_rsa_2048_sign(kTestMessage, kTestMessageLen, kOtcryptoRsaPaddingPkcs,
                        sig));

  // Compare to the expected signature.
  TRY_CHECK_ARRAYS_EQ(sig, kValidSignaturePkcs1v15,
                      ARRAYSIZE(kValidSignaturePkcs1v15));
  return OK_STATUS();
}

status_t pkcs1v15_verify_valid_test(void) {
  // Try to verify a valid signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_2048_verify(kTestMessage, kTestMessageLen,
                          kValidSignaturePkcs1v15, kOtcryptoRsaPaddingPkcs,
                          &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pkcs1v15_verify_invalid_test(void) {
  // Try to verify an invalid signature (wrong padding mode).
  hardened_bool_t verification_result;
  TRY(run_rsa_2048_verify(kTestMessage, kTestMessageLen, kValidSignaturePss,
                          kOtcryptoRsaPaddingPkcs, &verification_result));

  // Expect the signature to fail verification.
  TRY_CHECK(verification_result == kHardenedBoolFalse);
  return OK_STATUS();
}

status_t pss_sign_test(void) {
  // PSS signatures are not deterministic, so we need to sign-then-verify.
  uint32_t sig[kRsa2048NumWords];
  TRY(run_rsa_2048_sign(kTestMessage, kTestMessageLen, kOtcryptoRsaPaddingPss,
                        sig));

  // Try to verify the signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_2048_verify(kTestMessage, kTestMessageLen, sig,
                          kOtcryptoRsaPaddingPss, &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pss_verify_valid_test(void) {
  // Try to verify a valid signature.
  hardened_bool_t verification_result;
  TRY(run_rsa_2048_verify(kTestMessage, kTestMessageLen, kValidSignaturePss,
                          kOtcryptoRsaPaddingPss, &verification_result));

  // Expect the signature to pass verification.
  TRY_CHECK(verification_result == kHardenedBoolTrue);
  return OK_STATUS();
}

status_t pss_verify_invalid_test(void) {
  // Try to verify an invalid signature (wrong padding mode).
  hardened_bool_t verification_result;
  TRY(run_rsa_2048_verify(kTestMessage, kTestMessageLen,
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
