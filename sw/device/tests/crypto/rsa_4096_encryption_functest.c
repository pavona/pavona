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
  kRsa4096NumBytes = 4096 / 8,
  kRsa4096NumWords = kRsa4096NumBytes / sizeof(uint32_t),
};

// Note: The private key and valid signatures for this test were generated
// out-of-band using the PyCryptodome Python library.

// Test RSA-4096 key pair:
// e = 65537
// n =
// 0x923d26b1b8100867c52ceccbb7b12778bb56c41e74a00192f5cff3d6ca455764149f474abdff524f8711d18bca9ec1c8a911acb9f3b55b92c93741ae5096eb55ee537161caa24b43b7975de681890d9794274031f7d34763e616c66878c110562797e007df176908c5c7c09e28f41846a83522b7a080a8dee6f54599c11a46110733ddacda83238c5e2494c3a9db50ec2ac2bfcf456d1b349a20f3667d4b42e4301ba27152b6aeb4910a869848ba51ca6c4bc2bce4605201fb97013876b81c66f41e8e1a164bdfe9cf2c938d741a0a139a16aa5e371e6534f7b2fe46e9366e3fd94c6f9a84137166f9795da6a341b921ae584a1c5d772fa168ae9ea592da78749ead0010678acef1f405ca0387bf02a1d214c97078fc971eb9543c035b26d7fb59c05b949d589400456b541d1f538ee569f8e760ef593e46bf4a036b217125254a690b240d87195eb02f876604c40c5f43957974cc710705f63d8d4495e0d71a0b87bef169c526075428afc5d476a75343a405d3065717ba3cdee7b26398b8b1a272f6768ad109a2ebead54f19567c96caacc7d0f9ae495aff3fed73dea0d12f3a9c60c474fe316c964c7c044ab8c5fcc7b2b40c8dfeae93cf348dfbef92361d4f473ba5f9699bf22ab3eb21f22b2197a970c3dcd33d1707a86ad866b1d4b69cf071b30b17488f537c4ceeb0ea50031cde80fc8b02cdc82c85c4bdcf3114efe5
// d =
// 0x19aacb83965d940818a2c3b616d9ec6663a53d3b66375e475bc721d271829dadd673c558d043c3bfeb225cbfd732a9ab0d47a9a422ab12754f45584d1ede7a54450616c8b5fee9cc6b2911655f977d4ffd442d5f87d2a8bd5739689e1611b6cb145c730916a63e7c787050b5c1d4e3fce4d19cb413a2f960d4333901dd537df847a61a129870bb78cbde4a51145b46d708c35154b1280f061ac64d4a5013f95be138bc787ceeccf7aadc68d6ca2f0fa38282029e524c38a099f6bd535a7d02992c603f8b431e12a130486fe67c3a04ca3f799a71fa652698d71feec2e5f47481d6e334546fb994e620c3e544d5f33769fab68add732733f035d62e48bbdf861417fecf98658a898c297fec029ea004b708edc6ec008462ec7a62418a56bc03a553d53ac463a211a93a019ce8bc4e07269c7269f61b146fdb73fb2898e9371f6d087d75f53409f25ccda8258a7955470feda00eb93130ab1beeb31968ff0f46e59e8950467af1eeb7fb339c321aa75fe8f87aa3ccbd0107506a6ed6f1e3a10c0ef29cbee4e62df4f64eb8bd8aa40c8a129d1bf875ea48ce7801204058cf40085e248f7d36f3c16658252a9da39255f7addb82a4c11707763eccb95bca1fc075d6a6bca8d4db656795f0f0ec3a0a86efb9ed1cf5db010cc1af90a218e04a977ff1e077dea92fcbfb38bdbc9c786b11c61ded4cacbe4c0f18d02109108d2605e651

// Modulus (n) in little-endian form.
static uint32_t kTestModulus[kRsa4096NumWords] = {
    0x3114efe5, 0x85c4bdcf, 0x02cdc82c, 0xde80fc8b, 0xea50031c, 0x7c4ceeb0,
    0x17488f53, 0xf071b30b, 0xb1d4b69c, 0xa86ad866, 0xd33d1707, 0xa970c3dc,
    0xf22b2197, 0x2ab3eb21, 0xf9699bf2, 0x4f473ba5, 0xef92361d, 0xcf348dfb,
    0x8dfeae93, 0xc7b2b40c, 0x4ab8c5fc, 0x964c7c04, 0x74fe316c, 0x3a9c60c4,
    0xdea0d12f, 0xff3fed73, 0xf9ae495a, 0xcaacc7d0, 0x19567c96, 0xebead54f,
    0x8ad109a2, 0xa272f676, 0x6398b8b1, 0x3cdee7b2, 0x065717ba, 0x43a405d3,
    0xd476a753, 0x5428afc5, 0x69c52607, 0x0b87bef1, 0x95e0d71a, 0xf63d8d44,
    0xcc710705, 0x43957974, 0x04c40c5f, 0xb02f8766, 0x0d87195e, 0x4a690b24,
    0x21712525, 0xbf4a036b, 0xef593e46, 0x69f8e760, 0x1f538ee5, 0x456b541d,
    0x9d589400, 0x59c05b94, 0x5b26d7fb, 0xb9543c03, 0x78fc971e, 0xd214c970,
    0x87bf02a1, 0xf405ca03, 0x678acef1, 0x9ead0010, 0x92da7874, 0x68ae9ea5,
    0x5d772fa1, 0xae584a1c, 0xa341b921, 0xf9795da6, 0x84137166, 0xd94c6f9a,
    0xe9366e3f, 0xf7b2fe46, 0x371e6534, 0x9a16aa5e, 0x741a0a13, 0xcf2c938d,
    0x164bdfe9, 0xf41e8e1a, 0x76b81c66, 0xfb970138, 0xe4605201, 0x6c4bc2bc,
    0x48ba51ca, 0x910a8698, 0x52b6aeb4, 0x301ba271, 0x7d4b42e4, 0x9a20f366,
    0x456d1b34, 0x2ac2bfcf, 0xa9db50ec, 0x5e2494c3, 0xda83238c, 0x0733ddac,
    0xc11a4611, 0xe6f54599, 0xa080a8de, 0xa83522b7, 0x28f41846, 0xc5c7c09e,
    0xdf176908, 0x2797e007, 0x78c11056, 0xe616c668, 0xf7d34763, 0x94274031,
    0x81890d97, 0xb7975de6, 0xcaa24b43, 0xee537161, 0x5096eb55, 0xc93741ae,
    0xf3b55b92, 0xa911acb9, 0xca9ec1c8, 0x8711d18b, 0xbdff524f, 0x149f474a,
    0xca455764, 0xf5cff3d6, 0x74a00192, 0xbb56c41e, 0xb7b12778, 0xc52ceccb,
    0xb8100867, 0x923d26b1,

};

static uint32_t kTestCofactorP[kRsa4096NumWords / 2] = {
    0xa42b3975, 0x486e66a1, 0x429543c7, 0x640a9f4a, 0x15c68742, 0x6f01f7e4,
    0x2bc6994,  0xe3c6b400, 0x56da58b2, 0x4eef65dd, 0xf5985fae, 0x12a287d1,
    0x33539d02, 0xea714e4f, 0xbc2b044b, 0x59495543, 0x25aaba3,  0xd696b0b2,
    0x9aa7af94, 0x74c1bc0e, 0x3ac3053d, 0x34315540, 0x543108d0, 0xd0aed3b,
    0xb92acad,  0xccf328b1, 0x4b8656ef, 0x50e3b3bb, 0xde9d43b7, 0x36b40e1d,
    0xcdcf3890, 0x602561c0, 0x5f5f2f2a, 0xfab71bc8, 0xc0765982, 0x9f0660f9,
    0x323c984d, 0x66aa54f7, 0x5e520c5a, 0xacc26fa9, 0x9eee8b0c, 0xaaf4f879,
    0x364eb857, 0x893700d5, 0x3fd36893, 0x1e5712e8, 0x560e398b, 0xa0ef8592,
    0xebc145bf, 0x555b5a25, 0x569b23fc, 0x7ac028cc, 0xa3a4c627, 0x285d52e0,
    0xbceae56c, 0xa12e78cb, 0x157dfb6b, 0x7c64e3ca, 0x756b1935, 0xb52ac488,
    0x1534f8e2, 0x8dce8f10, 0x8f47fe7a, 0xbb02e9b1,
};

static uint32_t kTestCofactorQ[kRsa4096NumWords / 2] = {
    0xc74c9eb1, 0xddcba2ef, 0xaa08cb01, 0x12cf797a, 0x6a5b6bfb, 0x6a8a9245,
    0x273fdf28, 0x390d1889, 0xd67ed07a, 0xd6d03b4,  0xde1d046,  0xf24027e4,
    0xb78ae458, 0xc6d64366, 0xc35854d1, 0x58678ba5, 0x570a4b1b, 0xc672fa48,
    0xd47e1386, 0x30ac5c2f, 0xbb099956, 0xda62cbde, 0xead45575, 0xaa73c5e1,
    0x27394296, 0xfc2b2f82, 0x9c229f4a, 0x955d2059, 0x4a39df8a, 0x2cb560e4,
    0xa20ac9c0, 0xc5162ee,  0xd1956baf, 0x10bf68f,  0x13af452,  0xccf7dc9a,
    0x1471570c, 0x4250206d, 0x5db5432c, 0x89f86282, 0xa9e2d8dd, 0x7f347b65,
    0xaa95e9e,  0x415c412b, 0xb0714e9a, 0xfdfce5c,  0x6ef02097, 0xfbb85f61,
    0x9ef30dad, 0x13e6a5c0, 0x17fa02ae, 0xb41c40fb, 0x57f93251, 0xcba454f1,
    0x366f99ba, 0xddc08695, 0x8d9d7550, 0x78189a3f, 0x649807dd, 0x25aa2d48,
    0x6ddccb17, 0xafc6264d, 0xfd2816c8, 0xc82fbdb5,
};

static uint32_t kTestPrivateExponentComponentP[kRsa4096NumWords / 2] = {
    0x5b5a4fc9, 0xc59b19b5, 0x2b7b2ff6, 0xafc22452, 0x3aa7b9f2, 0xf58eae14,
    0x953b7e4c, 0x404fb3f8, 0x67335ef4, 0x82a1b5f2, 0x18c34ec2, 0xda3476fd,
    0xf3cb8131, 0xcc1dce4d, 0x3a3001e,  0xe1fbe96f, 0x404ad557, 0x1821ebd2,
    0xc067a549, 0x3ac6c40a, 0xdc55cf46, 0x74f68602, 0x2a3bef1e, 0x2012804a,
    0xac0b75bc, 0x688e4385, 0x677bcd5d, 0x9f61a83a, 0x67f25048, 0x8713276a,
    0xdfca979c, 0xe905483b, 0x35c0088,  0x91675ce7, 0xf9479513, 0xd319a129,
    0xf9eac12a, 0xfedf48c3, 0xa655fc6c, 0x5f009ed0, 0x2620d234, 0x7b818891,
    0x57fac406, 0x2b69700a, 0x998e495f, 0xf6926214, 0x79578463, 0xb42fe656,
    0x4948177f, 0xc7b888ac, 0xb5a7436a, 0xae493b28, 0xbca5cb2a, 0xb6516614,
    0xcb459e67, 0x48dd01f0, 0xff620c66, 0x86c37195, 0x739f09d5, 0x37df79d6,
    0x3efcafc4, 0xd2e1d9f7, 0xcfc2e0e1, 0x524173bc,
};

static uint32_t kTestPrivateExponentComponentQ[kRsa4096NumWords / 2] = {
    0x5810f281, 0xdd044ece, 0x921b9c1c, 0xb0b4f9f3, 0x1cd91924, 0x1af81c8e,
    0xd68d49df, 0x3dedb354, 0xd58402f2, 0x53714747, 0x5e2f11a6, 0xb1b9a30c,
    0x14cd48a8, 0x6d94c42d, 0xd6809126, 0x5dfb7702, 0x18c16eaf, 0xf6295fc6,
    0xf407d458, 0x79324b14, 0x67dfe161, 0x649b91f2, 0x47917651, 0xebbb6cc6,
    0x67809985, 0xbb20ba18, 0x789b8860, 0xe976be9f, 0x5d172695, 0x5e86663,
    0xf142d3af, 0xedf383d0, 0x63f4f32b, 0x285c57a9, 0x566b2441, 0xc642effa,
    0x70952e2a, 0x760614fb, 0xe96375dc, 0x3b842975, 0x1a41a281, 0xa064d0ef,
    0x19045944, 0x743dadf3, 0x70454d0b, 0x2bc1dcd0, 0xdb507ab8, 0xbe7437fd,
    0x70d8e461, 0x75d09c24, 0x32840920, 0xbbf27036, 0x84a8939a, 0x390cd63f,
    0xc6b36b7,  0x2f2f19ab, 0x708b63f8, 0xe3688a08, 0xb101ff93, 0x8b8db1d2,
    0xafc8a9f,  0xc28deac3, 0xc593a10a, 0x21fdb940,
};

static uint32_t kTestCrtCoefficient[kRsa4096NumWords / 2] = {
    0xd2d24361, 0x91dd5ca9, 0x83c0e47b, 0x94ec892b, 0x652a48c3, 0xfaca1c9b,
    0xf4edb448, 0xa67fae42, 0x36f2871c, 0xd10a8426, 0x4155eccf, 0x7238be69,
    0x544410aa, 0x93f34c6e, 0x42c22222, 0xf392befa, 0x63466b4b, 0xea3ad8c0,
    0xa541b3f0, 0xeef32c4d, 0x54662925, 0x56b407e9, 0x320bda91, 0x6f106dc2,
    0xcd8f5e30, 0x96693547, 0xc4133d08, 0xd9adb683, 0x857bc942, 0x42c54d7e,
    0x36f927a4, 0xb3243a6c, 0x614de345, 0x158b2a23, 0xb56229ae, 0x7a3c5311,
    0x16a39fe1, 0x104e3cd3, 0xa264825d, 0xeab97e2b, 0x56ba7f27, 0x76e5e942,
    0xd13146b1, 0x1cc6da68, 0xd2e9a365, 0x1e120c65, 0x3524be6,  0x34394c2,
    0x67a3a94e, 0x2849824e, 0x540c18dd, 0xee4c8498, 0x8bbf5867, 0x68760f54,
    0x107bf54e, 0xc4801efe, 0x500f1e6,  0x2735f8a6, 0xae9e2f6b, 0x367e6f4d,
    0xfdfece3f, 0xd89234df, 0x22642014, 0x72406ade,
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
    kRsa4096NumBytes - 2 * kTestHashModeDigestBytes - 2;

// Valid ciphertext for `kTestMessage` with the test private key, using OAEP
// encoding with `kTestLabel` and `kTestHashMode`.
static const uint32_t kValidCiphertext[kRsa4096NumWords] = {
    0x42a40b29, 0xa9e7c20e, 0x7229218d, 0x6adfd94d, 0xa2709c0f, 0xb1869aa6,
    0xe66df4ec, 0x3fe2e2be, 0x2310879a, 0x998a866f, 0x53b5f100, 0x7a4bebc3,
    0xd9db4396, 0xbd7af1aa, 0xd051fe30, 0x4f52e2f2, 0x0ebb7da5, 0xd2f96ff6,
    0xc1304a31, 0xb3f710ea, 0xf980e2f0, 0x7ef01c93, 0xa7b73a37, 0x4587a521,
    0x1a7f0a71, 0x835158b0, 0x3262a0d7, 0xd359786e, 0xece9e7e9, 0xe400e7c0,
    0x6ed96856, 0x57a2f617, 0xd2d4bf82, 0xe374efae, 0xaf030584, 0xc5ec8a95,
    0x7804969e, 0xf6b44a9a, 0xec4d4a98, 0x12d61757, 0xf19f1ed9, 0xd7be001b,
    0x92a8bd19, 0x79cc858b, 0x73012956, 0xaf66e1c3, 0xe47cb8c1, 0x102d248e,
    0x2969803e, 0x90ca2b21, 0xf041da6e, 0xf51ec9ee, 0x572e44c1, 0x3e1db731,
    0xb12833ef, 0x6af42cca, 0x828a2df6, 0xa89103b8, 0x86f855d0, 0x875bea08,
    0x8066bf5f, 0xaf2d014a, 0x0ba9c32e, 0x2b02b146, 0x8eb0df08, 0x1c81761f,
    0x11a1c9d9, 0x188b2d8f, 0x84653142, 0xbe987ec5, 0xf6d2f67a, 0x693dce03,
    0xea71d9e3, 0x0122ce4a, 0xa72f399f, 0xbb29813e, 0x27d59adf, 0x36a1c589,
    0x4e8cc2bd, 0x1679bfcd, 0x419dce2b, 0x077acaf9, 0x6254f95b, 0x65810c70,
    0x8cde365a, 0xbccb64ad, 0xdc3e0a13, 0x963fd8ae, 0x1627c5e7, 0xe837c36f,
    0xb855be34, 0x99e7c8cc, 0x09dac107, 0x31f68815, 0x41b5d8fc, 0x5d949ded,
    0xe39f3441, 0xe292435e, 0x053ef928, 0xd4c82d6e, 0x79f38b21, 0x07a88c1c,
    0xed85bf5c, 0x740512ef, 0xcc9fad4e, 0x23a57321, 0x037e42aa, 0xab0dc2db,
    0x17e8c01b, 0x6d8fcd64, 0xdc79ec50, 0xc22c7dba, 0x5fe34630, 0x75506752,
    0x0008cccd, 0x5c4dfa38, 0xca58a514, 0xfeb14e99, 0xd56bebeb, 0x78a151f8,
    0x974ca820, 0x209be80c, 0x75da5a56, 0xade9c225, 0x7a10c26b, 0x62edd3b0,
    0xcad4a315, 0x91f5f137,
};

/**
 * Helper function to run the RSA-4096 encryption routine.
 *
 * Packages input into cryptolib-style structs and calls `otcrypto_rsa_encrypt`
 * using the constant test private key.
 *
 * @param msg Message to encrypt.
 * @param msg_len Message length in bytes.
 * @param label Label for OAEP padding.
 * @param label_len Label length in bytes.
 * @param[out] ciphertext Buffer for the generated ciphertext (4096 bits).
 * @return OK or error.
 */
static status_t run_rsa_4096_encrypt(const uint8_t *msg, size_t msg_len,
                                     const uint8_t *label, size_t label_len,
                                     uint32_t *ciphertext) {
  // Construct the public key.
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  uint32_t public_key_data[ceil_div(kOtcryptoRsa4096PublicKeyBytes,
                                    sizeof(uint32_t))];
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeRsaEncryptOaep,
      .key_length = kOtcryptoRsa4096PublicKeyBytes,
      .key = public_key_data,
  };
  TRY(otcrypto_rsa_public_key_construct(kOtcryptoRsaSize4096, modulus,
                                        kTestPublicExponent, &public_key));

  otcrypto_const_byte_buf_t msg_buf = {.data = msg, .len = msg_len};
  otcrypto_const_byte_buf_t label_buf = {.data = label, .len = label_len};
  otcrypto_word32_buf_t ciphertext_buf = {
      .data = ciphertext,
      .len = kRsa4096NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_encrypt(&public_key, kTestHashMode, msg_buf, label_buf,
                           ciphertext_buf));
  profile_end_and_print(t_start, "RSA-4096 encryption");

  return OK_STATUS();
}

/**
 * Helper function to run the RSA-4096 decryption routine.
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
 * @param ciphertext Ciphertext to decrypt (4096 bits).
 * @param[out] msg Decrypted message.
 * @param[out] msg_len Message length in bytes.
 * @return OK or error.
 */
static status_t run_rsa_4096_decrypt(const uint8_t *label, size_t label_len,
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
      .key_length = kOtcryptoRsa4096PrivateKeyBytes,
      .hw_backed = kHardenedBoolFalse,
      .security_level = kOtcryptoKeySecurityLevelLow,
  };
  size_t keyblob_words =
      ceil_div(kOtcryptoRsa4096PrivateKeyblobBytes, sizeof(uint32_t));
  uint32_t keyblob[keyblob_words];
  otcrypto_blinded_key_t private_key = {
      .config = private_key_config,
      .keyblob = keyblob,
      .keyblob_length = kOtcryptoRsa4096PrivateKeyblobBytes,
  };
  otcrypto_const_word32_buf_t modulus = {
      .data = kTestModulus,
      .len = ARRAYSIZE(kTestModulus),
  };
  TRY(otcrypto_rsa_private_key_from_exponents(kOtcryptoRsaSize4096, modulus, p,
                                              q, kTestPublicExponent, d_p, d_q,
                                              i_q, &private_key));

  otcrypto_byte_buf_t plaintext_buf = {.data = msg, .len = kMaxPlaintextBytes};
  otcrypto_const_byte_buf_t label_buf = {.data = label, .len = label_len};
  otcrypto_const_word32_buf_t ciphertext_buf = {
      .data = ciphertext,
      .len = kRsa4096NumWords,
  };
  uint64_t t_start = profile_start();
  TRY(otcrypto_rsa_decrypt(&private_key, kTestHashMode, ciphertext_buf,
                           label_buf, plaintext_buf, msg_len));
  profile_end_and_print(t_start, "RSA-4096 decryption");

  return OK_STATUS();
}

status_t oaep_decrypt_valid_test(void) {
  // Decrypt the valid ciphertext.
  uint8_t actual_msg[kMaxPlaintextBytes];
  size_t actual_msg_len;
  TRY(run_rsa_4096_decrypt(kTestLabel, kTestLabelLen, kValidCiphertext,
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
  uint32_t ciphertext[kRsa4096NumWords];
  TRY(run_rsa_4096_encrypt(kTestMessage, kTestMessageLen, kTestLabel,
                           kTestLabelLen, ciphertext));

  // Decrypt the message.
  uint8_t actual_msg[kMaxPlaintextBytes];
  size_t actual_msg_len;
  TRY(run_rsa_4096_decrypt(kTestLabel, kTestLabelLen, ciphertext, actual_msg,
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
