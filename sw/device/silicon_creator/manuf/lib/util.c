// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/manuf/lib/util.h"

#include <stdint.h>

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/sha2.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/dif/dif_otp_ctrl.h"
#include "sw/device/lib/testing/otp_ctrl_testutils.h"

#include "hw/top/otp_ctrl_regs.h"  // Generated.
#include "hw/top_egret/sw/autogen/top_egret.h"

static_assert(
    OTP_CTRL_PARAM_VENDOR_TEST_SIZE % sizeof(uint32_t) == 0,
    "OTP Vendor Test partition should be an integer multiple of 32-bit words.");

static_assert(OTP_CTRL_PARAM_CREATOR_SW_CFG_AST_CFG_OFFSET ==
                  OTP_CTRL_PARAM_CREATOR_SW_CFG_OFFSET,
              "The CREATOR_SW_CFG_AST_CFG item must be at the beginning of the "
              "CREATOR_SW_CFG partition");

enum {
  kSha256DigestWords = 256 / 32,
};

status_t manuf_util_hash_lc_transition_token(const uint32_t *raw_token,
                                             size_t token_size_bytes,
                                             uint64_t *hashed_token) {
  otcrypto_const_byte_buf_t input = {
      .data = (unsigned char *)raw_token,
      .len = token_size_bytes,
  };
  otcrypto_const_byte_buf_t function_name_string = {
      .data = (unsigned char *)"",
      .len = 0,
  };
  otcrypto_const_byte_buf_t customization_string = {
      .data = (unsigned char *)"LC_CTRL",
      .len = 7,
  };

  // Create a temporary uint32_t buffer and copy the result from there to the
  // uint64_t buffer.
  // TODO(#16556): this is a workaround to avoid violating strict-aliasing; if
  // we pass -fno-strict-aliasing, then we can cast `hashed_token` to `uint32_t
  // *` instead.
  size_t token_num_words = token_size_bytes / sizeof(uint32_t);
  if (token_size_bytes % sizeof(uint32_t) != 0) {
    token_num_words++;
  }
  uint32_t token_data[token_num_words];
  memset(token_data, 0, sizeof(token_data));
  otcrypto_hash_digest_t output = {
      .data = token_data,
      .len = token_num_words,
  };

  TRY(otcrypto_cshake128(input, function_name_string, customization_string,
                         &output));
  memcpy(hashed_token, token_data, sizeof(token_data));

  return OK_STATUS();
}

status_t manuf_util_hash_otp_partition(const dif_otp_ctrl_t *otp_ctrl,
                                       otp_partition_t partition,
                                       otcrypto_word32_buf_t output) {
  if (otp_ctrl == NULL || output.len != kSha256DigestWords) {
    return INVALID_ARGUMENT();
  }
  otcrypto_hash_digest_t digest = {
      .data = output.data,
      .len = output.len,
  };

  switch (partition) {
    case kOtpPartitionVendorTest: {
      uint32_t
          vendor_test_32bit_array[(OTP_CTRL_PARAM_VENDOR_TEST_SIZE -
                                   OTP_CTRL_PARAM_VENDOR_TEST_DIGEST_SIZE) /
                                  sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionVendorTest, 0, vendor_test_32bit_array,
          (OTP_CTRL_PARAM_VENDOR_TEST_SIZE -
           OTP_CTRL_PARAM_VENDOR_TEST_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)vendor_test_32bit_array,
          .len = OTP_CTRL_PARAM_VENDOR_TEST_SIZE -
                 OTP_CTRL_PARAM_VENDOR_TEST_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionCreatorSwCfg: {
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)(TOP_EGRET_OTP_CTRL_CORE_BASE_ADDR +
                                    OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET +
                                    OTP_CTRL_PARAM_CREATOR_SW_CFG_OFFSET),
          .len = OTP_CTRL_PARAM_CREATOR_SW_CFG_SIZE -
                 OTP_CTRL_PARAM_CREATOR_SW_CFG_DIGEST_SIZE -
                 OTP_CTRL_PARAM_CREATOR_SW_CFG_AST_CFG_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionOwnerSwCfg: {
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)(TOP_EGRET_OTP_CTRL_CORE_BASE_ADDR +
                                    OTP_CTRL_SW_CFG_WINDOW_REG_OFFSET +
                                    OTP_CTRL_PARAM_OWNER_SW_CFG_OFFSET),
          .len = OTP_CTRL_PARAM_OWNER_SW_CFG_SIZE -
                 OTP_CTRL_PARAM_OWNER_SW_CFG_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot0: {
      uint32_t rot_owner_auth_slot0_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot0, 0,
          rot_owner_auth_slot0_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot0_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot0State: {
      uint32_t rot_owner_auth_slot0_state_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot0State, 0,
          rot_owner_auth_slot0_state_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot0_state_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT0_STATE_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot1: {
      uint32_t rot_owner_auth_slot1_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot1, 0,
          rot_owner_auth_slot1_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot1_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot1State: {
      uint32_t rot_owner_auth_slot1_state_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot1State, 0,
          rot_owner_auth_slot1_state_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot1_state_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT1_STATE_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot2: {
      uint32_t rot_owner_auth_slot2_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot2, 0,
          rot_owner_auth_slot2_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot2_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot2State: {
      uint32_t rot_owner_auth_slot2_state_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot2State, 0,
          rot_owner_auth_slot2_state_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot2_state_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT2_STATE_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot3: {
      uint32_t rot_owner_auth_slot3_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot3, 0,
          rot_owner_auth_slot3_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot3_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    case kOtpPartitionRotOwnerAuthSlot3State: {
      uint32_t rot_owner_auth_slot3_state_32bit_array
          [(OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_SIZE -
            OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_DIGEST_SIZE) /
           sizeof(uint32_t)];
      TRY(otp_ctrl_testutils_dai_read32_array(
          otp_ctrl, kOtpPartitionRotOwnerAuthSlot3State, 0,
          rot_owner_auth_slot3_state_32bit_array,
          (OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_SIZE -
           OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_DIGEST_SIZE) /
              sizeof(uint32_t)));
      otcrypto_const_byte_buf_t input = {
          .data = (unsigned char *)rot_owner_auth_slot3_state_32bit_array,
          .len = OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_SIZE -
                 OTP_CTRL_PARAM_ROT_OWNER_AUTH_SLOT3_STATE_DIGEST_SIZE,
      };
      TRY(otcrypto_sha2_256(input, &digest));
    } break;
    default:
      return INVALID_ARGUMENT();
  }

  return OK_STATUS();
}
