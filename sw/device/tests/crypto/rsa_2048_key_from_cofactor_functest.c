// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/rsa/rsa_datatypes.h"
#include "sw/device/lib/crypto/include/rsa.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

// Module for status messages.
#define MODULE_ID MAKE_MODULE_ID('t', 's', 't')

enum {
  kRsa2048CofactorNumWords = kRsa2048NumWords / 2,
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
// The prime cofactor p for the test private key.
static uint32_t kTestPrimeP[kRsa2048CofactorNumWords] = {
    0x69e8cdeb, 0xaab5698,  0x2adbf5a2, 0xc6f3fed7, 0x9b0f148c, 0x68a4b636,
    0xc3c8948c, 0x5ee5c048, 0xb20f9f30, 0xaced9c36, 0xe2a0f71f, 0xf57f3401,
    0x8fb749f8, 0x24f4b1f2, 0x2811dd24, 0xe45d624,  0x7e4fac27, 0x7049a420,
    0x4ea4172b, 0x1d4f1d2d, 0x15c1dd03, 0x733ce8c1, 0xe5415c61, 0xa3680f9a,
    0xa13ff562, 0xd12a0242, 0x3ef684a4, 0x5241db6e, 0x2e68b5f5, 0xaa3e5397,
    0x45e9606a, 0xb8505888,
};
// The prime cofactor q for the test private key.
static uint32_t kTestPrimeQ[kRsa2048CofactorNumWords] = {
    0xc69864d3, 0x6eca1793, 0xd985ff65, 0xa888cce8, 0xcadcabc5, 0x47d31ff8,
    0x2eae994a, 0x0ba8594d, 0x956889ed, 0x117f0b01, 0x30ace812, 0x89aa41b9,
    0x716c8c93, 0xb3e54154, 0x70020ae3, 0x3f3926af, 0x91ae5a18, 0xa058daef,
    0xd5a8a0ee, 0xff73e9fb, 0xda00591c, 0x69220aec, 0xe9ee684b, 0x12f4ea77,
    0xea538fb5, 0x0505826e, 0xef416b24, 0x5c65d8d6, 0xce422bd4, 0x3f4f37ed,
    0xdd6aff12, 0xf6c55808,
};

// The first CRT component d_p of the private exponent for the test private key.
static uint32_t kTestPrivateExponentComponentP[kRsa2048CofactorNumWords] = {
    0x450b9217, 0x4edd47a6, 0x65eaa581, 0xa489536c, 0x46c6416e, 0xcdcd3461,
    0x07ba3fc0, 0x95d56f89, 0xcf3c23f1, 0x3a09db7b, 0x841780f5, 0x3ee50c5d,
    0x6858dd49, 0xf56e4c70, 0x872d1012, 0xe23c883f, 0x24170efd, 0xeb61ae33,
    0xd05cb6b7, 0x81db8c2f, 0x1cd58c9b, 0xa828fecf, 0x09db577e, 0xcdc21d77,
    0x9ebfb60c, 0xbacad629, 0x98bc44a7, 0x8498e6dc, 0x399dc28f, 0x95d22e4d,
    0x7b1d095d, 0xacc9ede5,
};

// The first CRT component d_q of the private exponent for the test private key.
static uint32_t kTestPrivateExponentComponentQ[kRsa2048CofactorNumWords] = {
    0x1294bbf7, 0x8b2919b9, 0x19e6e6bb, 0x5bac57cf, 0x94878d05, 0xdd0297c9,
    0xc2fa4a31, 0x250dbc5d, 0xa6e04ae3, 0xc4f6deb7, 0x5d21fd5f, 0x6e02cdea,
    0xb967b151, 0x1324bb70, 0xe7c7e19a, 0x93faa85b, 0xcea179ee, 0xda7b268f,
    0xb4953e88, 0x5da887cf, 0xf3475b09, 0xf0f59bd2, 0xd783b40b, 0x871df1f6,
    0x7781156f, 0x2d8a9b67, 0xf1555281, 0xdf14b659, 0x85d12616, 0x28f80092,
    0x50663f6f, 0xb2191d7f,
};

// The CRT reconstruction coefficient i_q, inverse of q mod p.
static uint32_t kTestCrtCoefficientQinvP[kRsa2048CofactorNumWords] = {
    0x8678e23f, 0x208181a5, 0x4c846651, 0xd7015b89, 0x75c82ec3, 0x9ab976a8,
    0xdc502277, 0xe354d4f1, 0x57b4eecb, 0x347c059,  0xf98ab29f, 0x38b694ec,
    0x8ef8acf0, 0xd530b8a6, 0x36cf279f, 0xacdb1beb, 0xc89e371d, 0xe9080f0f,
    0x05f32291, 0x4c4cc843, 0x4f7bd2e4, 0xa158cc81, 0x2b3fdadf, 0x20b88f37,
    0x5e424f2a, 0x41794ace, 0x86297642, 0x1472ceaa, 0xeedce93a, 0xad62154d,
    0xae949fc6, 0x267d8cbc,
};

// The CRT reconstruction coefficient i_p, inverse of p mod q. This is used when
// we swap the roles of p and q as a second functionality test.
static uint32_t kTestCrtCoefficientPinvQ[kRsa2048CofactorNumWords] = {
    0xff019a0f, 0x58ec641a, 0xa8b6a4dc, 0x338e8a6a, 0xb98e701c, 0xe710b453,
    0xc7b5ee24, 0x4268bb56, 0xf7474ef4, 0x6f88b191, 0x2079740b, 0x24cf5722,
    0xce523e5d, 0xb5aeb747, 0x963673,   0x564f2e69, 0x7124e565, 0x73e023aa,
    0xca525e98, 0x483a1ec4, 0x46f0f3fd, 0x5fc69d0d, 0x55b96618, 0x8612dc35,
    0x43b77913, 0xc00a23fc, 0xdf0ce49d, 0x28b92fa7, 0xca347165, 0xb3634a2,
    0x9c351d76, 0xc33ccc12,
};

static uint32_t kTestPublicExponent = 65537;

// Key mode for testing.
static otcrypto_key_mode_t kTestKeyMode = kOtcryptoKeyModeRsaSignPss;

/**
 * Helper function to run the key-from-cofactor routine.
 *
 * Packages input into cryptolib-style structs and calls
 * `otcrypto_rsa_private_key_from_public_and_cofactor` using the constant test
 * public key and the given cofactor. Ensures that the resulting private
 * exponent matches the test private exponent.
 *
 * @param cofactor Pointer to the cofactor data.
 * @return OK or error.
 */
static status_t run_key_from_cofactor(const uint32_t *cofactor,
                                      const bool cofactor_is_p) {
  // Create two shares for the cofactor (second share is all-zero).
  otcrypto_const_word32_buf_t cofactor_share0 = {
      .data = cofactor,
      .len = kRsa2048CofactorNumWords,
  };
  uint32_t cofactor_share1_data[kRsa2048CofactorNumWords] = {0};
  otcrypto_const_word32_buf_t cofactor_share1 = {
      .data = cofactor_share1_data,
      .len = ARRAYSIZE(cofactor_share1_data),
  };

  // Buffer for the modulus.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };

  // Construct the private key buffer and configuration.
  otcrypto_key_config_t private_key_config = {
      .version = kOtcryptoLibVersion1,
      .key_mode = kTestKeyMode,
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

  // Construct the public key buffer.
  size_t public_key_words =
      ceil_div(kOtcryptoRsa2048PublicKeyBytes, sizeof(uint32_t));
  uint32_t public_key_data[public_key_words];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kTestKeyMode,
      .key = public_key_data,
      .key_length = kOtcryptoRsa2048PublicKeyBytes,
  };

  // Construct the RSA key pair using the cofactor.
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_keypair_from_cofactor(
      kOtcryptoRsaSize2048, modulus, kTestPublicExponent, cofactor_share0,
      cofactor_share1, &public_key, &private_key));
  profile_end_and_print(t_start, "RSA keypair from cofactor");

  // Interpret the private key and ensure that the cofactors, private exponent
  // CRT components, and CRT reconstruction coefficient match their expected
  // values. Note: This depends on the internal representation of RSA keyblobs,
  // and will need to be updated if the representation changes.
  TRY_CHECK(private_key.keyblob_length == sizeof(rsa_2048_private_key_t));
  rsa_2048_private_key_t *sk = (rsa_2048_private_key_t *)private_key.keyblob;
  if (cofactor_is_p) {
    // Internally, the key from cofactor logic sets the provided cofactor as
    // sk->q, and sets sk->p to be the quotient of the RSA modulus by that
    // cofactor. As such, if the provided cofactor is kTestPrimeP, then we need
    // to switch the roles of cofactors p and q in our checks below.
    TRY_CHECK_ARRAYS_EQ(sk->p.data, kTestPrimeQ, ARRAYSIZE(kTestPrimeQ));
    TRY_CHECK_ARRAYS_EQ(sk->q.data, kTestPrimeP, ARRAYSIZE(kTestPrimeP));
    TRY_CHECK_ARRAYS_EQ(sk->d_p.data, kTestPrivateExponentComponentQ,
                        ARRAYSIZE(kTestPrivateExponentComponentQ));
    TRY_CHECK_ARRAYS_EQ(sk->d_q.data, kTestPrivateExponentComponentP,
                        ARRAYSIZE(kTestPrivateExponentComponentP));
    TRY_CHECK_ARRAYS_EQ(sk->i_q.data, kTestCrtCoefficientPinvQ,
                        ARRAYSIZE(kTestCrtCoefficientPinvQ));
  } else {
    // Otherwise, if the provided cofactor is kTestPrimeQ, then there's no need
    // to switch the roles of the cofactors.
    TRY_CHECK_ARRAYS_EQ(sk->p.data, kTestPrimeP, ARRAYSIZE(kTestPrimeP));
    TRY_CHECK_ARRAYS_EQ(sk->q.data, kTestPrimeQ, ARRAYSIZE(kTestPrimeQ));
    TRY_CHECK_ARRAYS_EQ(sk->d_p.data, kTestPrivateExponentComponentP,
                        ARRAYSIZE(kTestPrivateExponentComponentP));
    TRY_CHECK_ARRAYS_EQ(sk->d_q.data, kTestPrivateExponentComponentQ,
                        ARRAYSIZE(kTestPrivateExponentComponentQ));
    TRY_CHECK_ARRAYS_EQ(sk->i_q.data, kTestCrtCoefficientQinvP,
                        ARRAYSIZE(kTestCrtCoefficientQinvP));
  }

  // Check the other values too, just to be safe.
  TRY_CHECK(public_key.key_length == sizeof(rsa_2048_public_key_t));
  rsa_2048_public_key_t *pk = (rsa_2048_public_key_t *)public_key.key;
  TRY_CHECK_ARRAYS_EQ(pk->n.data, kTestModulus, ARRAYSIZE(kTestModulus));
  TRY_CHECK(pk->e == kTestPublicExponent);
  return OK_STATUS();
}

status_t keypair_from_p_test(void) {
  return run_key_from_cofactor(kTestPrimeP, true);
}

status_t keypair_from_q_test(void) {
  return run_key_from_cofactor(kTestPrimeQ, false);
}

OTTF_DEFINE_TEST_CONFIG();

bool test_main(void) {
  status_t test_result = OK_STATUS();
  CHECK_STATUS_OK(entropy_complex_init());
  EXECUTE_TEST(test_result, keypair_from_p_test);
  EXECUTE_TEST(test_result, keypair_from_q_test);
  return status_ok(test_result);
}
