// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/drivers/kmac.h"

#include "hw/top/dt/dt_kmac.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/drivers/rv_core_ibex.h"
#include "sw/device/lib/crypto/impl/status.h"

#include "hw/top/kmac_regs.h"  // Generated.

// Module ID for status codes.
#define MODULE_ID MAKE_MODULE_ID('d', 'k', 'c')

/**
 * Security strength values.
 *
 * These values corresponds to the half of the capacity of Keccak permutation.
 *
 * Hardened values generated with:
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 5 -n 11 \
 *   --avoid-zero -s 4008005493
 */
typedef enum kmac_security_str {
  kKmacSecurityStrength128 = 0x3e5,
  kKmacSecurityStrength224 = 0x639,
  kKmacSecurityStrength256 = 0x5cb,
  kKmacSecurityStrength384 = 0x536,
  kKmacSecurityStrength512 = 0x25e,
} kmac_security_str_t;

/**
 * List of supported KMAC modes.
 *
 * Hardened values generated with:
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 4 -n 11 \
 *     --avoid-zero -s 3610353144
 */
typedef enum kmac_operation {
  kKmacOperationSha3 = 0x5ca,
  kKmacOperationShake = 0x369,
  kKmacOperationCshake = 0x5b5,
  kKmacOperationKmac = 0x60f,
} kmac_operation_t;

enum {
  kKmacStateShareSize = KMAC_STATE_SIZE_BYTES / 2,
};

// Inline wrapper function for KMAC base address
static inline uintptr_t kmac_base(void) {
  return dt_kmac_primary_reg_block(kDtKmac);
}

// "KMAC" string in little endian
static const uint8_t kKmacFuncNameKMAC[] = {0x4b, 0x4d, 0x41, 0x43};

// We need 5 bytes at most for encoding the length of cust_str and func_name.
// That leaves 39 bytes for the string. We simply truncate it to 36 bytes.
OT_ASSERT_ENUM_VALUE(kKmacPrefixMaxSize, 4 * KMAC_PREFIX_MULTIREG_COUNT - 8);

// Check that KEY_SHARE registers form a continuous address space
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_1_REG_OFFSET,
                     KMAC_KEY_SHARE0_0_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_2_REG_OFFSET,
                     KMAC_KEY_SHARE0_1_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_3_REG_OFFSET,
                     KMAC_KEY_SHARE0_2_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_4_REG_OFFSET,
                     KMAC_KEY_SHARE0_3_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_5_REG_OFFSET,
                     KMAC_KEY_SHARE0_4_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_6_REG_OFFSET,
                     KMAC_KEY_SHARE0_5_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_7_REG_OFFSET,
                     KMAC_KEY_SHARE0_6_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_8_REG_OFFSET,
                     KMAC_KEY_SHARE0_7_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_9_REG_OFFSET,
                     KMAC_KEY_SHARE0_8_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_10_REG_OFFSET,
                     KMAC_KEY_SHARE0_9_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_11_REG_OFFSET,
                     KMAC_KEY_SHARE0_10_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_12_REG_OFFSET,
                     KMAC_KEY_SHARE0_11_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_13_REG_OFFSET,
                     KMAC_KEY_SHARE0_12_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_14_REG_OFFSET,
                     KMAC_KEY_SHARE0_13_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE0_15_REG_OFFSET,
                     KMAC_KEY_SHARE0_14_REG_OFFSET + 4);

OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_1_REG_OFFSET,
                     KMAC_KEY_SHARE1_0_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_2_REG_OFFSET,
                     KMAC_KEY_SHARE1_1_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_3_REG_OFFSET,
                     KMAC_KEY_SHARE1_2_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_4_REG_OFFSET,
                     KMAC_KEY_SHARE1_3_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_5_REG_OFFSET,
                     KMAC_KEY_SHARE1_4_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_6_REG_OFFSET,
                     KMAC_KEY_SHARE1_5_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_7_REG_OFFSET,
                     KMAC_KEY_SHARE1_6_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_8_REG_OFFSET,
                     KMAC_KEY_SHARE1_7_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_9_REG_OFFSET,
                     KMAC_KEY_SHARE1_8_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_10_REG_OFFSET,
                     KMAC_KEY_SHARE1_9_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_11_REG_OFFSET,
                     KMAC_KEY_SHARE1_10_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_12_REG_OFFSET,
                     KMAC_KEY_SHARE1_11_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_13_REG_OFFSET,
                     KMAC_KEY_SHARE1_12_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_14_REG_OFFSET,
                     KMAC_KEY_SHARE1_13_REG_OFFSET + 4);
OT_ASSERT_ENUM_VALUE(KMAC_KEY_SHARE1_15_REG_OFFSET,
                     KMAC_KEY_SHARE1_14_REG_OFFSET + 4);

// Ensure each PREFIX register is 4 bytes
OT_ASSERT_ENUM_VALUE(32, KMAC_PREFIX_PREFIX_FIELD_WIDTH);

/**
 * Get the rate of the current mode in 32-bit words.
 *
 * Returns 0 if the strength configured in the hardware is invalid, which
 * should not happen; the caller must check this value.
 *
 * @return The keccak rate in 32-bit words.
 */
static size_t get_keccak_rate_words(void) {
  const uint32_t kBase = kmac_base();
  uint32_t cfg_reg = abs_mmio_read32(kBase + KMAC_CFG_SHADOWED_REG_OFFSET);
  uint32_t kstrength =
      bitfield_field32_read(cfg_reg, KMAC_CFG_SHADOWED_KSTRENGTH_FIELD);
  switch (kstrength) {
    case KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L128:
      return (1600 - 2 * 128) / 32;
    case KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L224:
      return (1600 - 2 * 224) / 32;
    case KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L256:
      return (1600 - 2 * 256) / 32;
    case KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L384:
      return (1600 - 2 * 384) / 32;
    case KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L512:
      return (1600 - 2 * 512) / 32;
    default:
      return 0;
  }
}

/**
 * Get the KEY_LEN register value for the given length.
 *
 * Returns an error if the key length is not supported.
 *
 * @param key_len The size of the key in bytes.
 * @param[out] reg KEY_LEN register value (pointer cannot be NULL).
 * @return Error code.
 */
static_assert(KMAC_KEY_LEN_LEN_OFFSET == 0,
              "Code assumes that length field is at offset 0.");
OT_WARN_UNUSED_RESULT
static status_t key_len_reg_get(size_t key_len, uint32_t *key_len_reg) {
  *key_len_reg = 0;
  switch (launder32(key_len)) {
    case 128 / 8:
      HARDENED_CHECK_EQ(key_len * 8, 128);
      *key_len_reg = KMAC_KEY_LEN_LEN_VALUE_KEY128;
      break;
    case 192 / 8:
      HARDENED_CHECK_EQ(key_len * 8, 192);
      *key_len_reg = KMAC_KEY_LEN_LEN_VALUE_KEY192;
      break;
    case 256 / 8:
      HARDENED_CHECK_EQ(key_len * 8, 256);
      *key_len_reg = KMAC_KEY_LEN_LEN_VALUE_KEY256;
      break;
    case 384 / 8:
      HARDENED_CHECK_EQ(key_len * 8, 384);
      *key_len_reg = KMAC_KEY_LEN_LEN_VALUE_KEY384;
      break;
    case 512 / 8:
      HARDENED_CHECK_EQ(key_len * 8, 512);
      *key_len_reg = KMAC_KEY_LEN_LEN_VALUE_KEY512;
      break;
    default:
      return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_NE(key_len_reg, 0);
  return OTCRYPTO_OK;
}

status_t kmac_hwip_default_configure(void) {
  // Ensure that the entropy complex is initialized.
  HARDENED_TRY(entropy_complex_check());

  uint32_t status_reg = abs_mmio_read32(kmac_base() + KMAC_STATUS_REG_OFFSET);

  // Check that core is not in fault state
  if (bitfield_bit32_read(status_reg, KMAC_STATUS_ALERT_FATAL_FAULT_BIT)) {
    return OTCRYPTO_FATAL_ERR;
  }
  if (bitfield_bit32_read(status_reg,
                          KMAC_STATUS_ALERT_RECOV_CTRL_UPDATE_ERR_BIT)) {
    return OTCRYPTO_RECOV_ERR;
  }
  // Check that core is not busy
  if (!bitfield_bit32_read(status_reg, KMAC_STATUS_SHA3_IDLE_BIT)) {
    return OTCRYPTO_RECOV_ERR;
  }

  // Check that there is no err pending in intr state
  uint32_t intr_state =
      abs_mmio_read32(kmac_base() + KMAC_INTR_STATE_REG_OFFSET);
  if (bitfield_bit32_read(intr_state, KMAC_INTR_STATE_KMAC_ERR_BIT)) {
    return OTCRYPTO_RECOV_ERR;
  }

  // Check CFG.regwen
  uint32_t cfg_regwen =
      abs_mmio_read32(kmac_base() + KMAC_CFG_REGWEN_REG_OFFSET);
  if (!bitfield_bit32_read(cfg_regwen, KMAC_CFG_REGWEN_EN_BIT)) {
    return OTCRYPTO_RECOV_ERR;
  }

  // Keep err interrupt disabled
  uint32_t intr_reg = KMAC_INTR_ENABLE_REG_RESVAL;
  intr_reg = bitfield_bit32_write(intr_reg, KMAC_INTR_ENABLE_KMAC_ERR_BIT, 0);
  abs_mmio_write32(kmac_base() + KMAC_INTR_ENABLE_REG_OFFSET, intr_reg);

  // Configure max for entropy period (use UINT32_MAX and let bitfield clamp
  // them to their bitfield)
  uint32_t entropy_period = KMAC_ENTROPY_PERIOD_REG_RESVAL;
  entropy_period = bitfield_field32_write(
      entropy_period, KMAC_ENTROPY_PERIOD_PRESCALER_FIELD, UINT32_MAX);
  entropy_period = bitfield_field32_write(
      entropy_period, KMAC_ENTROPY_PERIOD_WAIT_TIMER_FIELD, UINT32_MAX);
  abs_mmio_write32(kmac_base() + KMAC_ENTROPY_PERIOD_REG_OFFSET,
                   entropy_period);

  // Configure max for hash threshold (use UINT32_MAX and let bitfield clamp
  // them to their bitfield)
  uint32_t entropy_hash_threshold =
      KMAC_ENTROPY_REFRESH_THRESHOLD_SHADOWED_REG_RESVAL;
  entropy_hash_threshold = bitfield_field32_write(
      entropy_hash_threshold,
      KMAC_ENTROPY_REFRESH_THRESHOLD_SHADOWED_THRESHOLD_FIELD, UINT32_MAX);
  abs_mmio_write32(
      kmac_base() + KMAC_ENTROPY_REFRESH_THRESHOLD_SHADOWED_REG_OFFSET,
      entropy_hash_threshold);

  // Configure CFG
  uint32_t cfg_reg = KMAC_CFG_SHADOWED_REG_RESVAL;
  // Little_endian
  cfg_reg =
      bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_MSG_ENDIANNESS_BIT, 0);
  cfg_reg =
      bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_STATE_ENDIANNESS_BIT, 0);

  // Sideload: off, default key comes from SW
  cfg_reg = bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_SIDELOAD_BIT, 0);

  // Entropy mode: EDN
  cfg_reg =
      bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_ENTROPY_MODE_FIELD,
                             KMAC_CFG_SHADOWED_ENTROPY_MODE_VALUE_EDN_MODE);

  // Use quality randomness for message blocks too
  cfg_reg = bitfield_bit32_write(cfg_reg,
                                 KMAC_CFG_SHADOWED_ENTROPY_FAST_PROCESS_BIT, 1);
  // Do not remask message blocks
  cfg_reg = bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_MSG_MASK_BIT, 0);

  // Mark entropy source as ready
  cfg_reg =
      bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_ENTROPY_READY_BIT, 1);
  // Unsupported modes: disabled
  cfg_reg = bitfield_bit32_write(
      cfg_reg, KMAC_CFG_SHADOWED_EN_UNSUPPORTED_MODESTRENGTH_BIT, 0);

  abs_mmio_write32_shadowed(kmac_base() + KMAC_CFG_SHADOWED_REG_OFFSET,
                            cfg_reg);

  return OTCRYPTO_OK;
}

/**
 * Wait until given status bit is set.
 *
 * Loops until the `bit_position` of status register reaches the value
 * `bit_value`.
 * @param bit_position The bit position in the status register.
 * @param bit_value Whether it should wait for 0 or 1.
 * @return Error status.
 */
OT_WARN_UNUSED_RESULT
static status_t wait_status_bit(uint32_t bit_position, bool bit_value) {
  if (bit_position > 31) {
    return OTCRYPTO_BAD_ARGS;
  }

  while (true) {
    uint32_t reg = abs_mmio_read32(kmac_base() + KMAC_STATUS_REG_OFFSET);
    if (bitfield_bit32_read(reg, KMAC_STATUS_ALERT_FATAL_FAULT_BIT)) {
      return OTCRYPTO_FATAL_ERR;
    }
    if (bitfield_bit32_read(reg, KMAC_STATUS_ALERT_RECOV_CTRL_UPDATE_ERR_BIT)) {
      return OTCRYPTO_RECOV_ERR;
    }
    if (bitfield_bit32_read(reg, bit_position) == bit_value) {
      return OTCRYPTO_OK;
    }
  }
}

/*
 * Returns the minimum positive number of bytes needed to encode the value.
 *
 * Note that if `value` is zero, the result will be 1; this matches
 * `right_encode` and `left_encode from NIST SP900-185, which require the
 * number of bytes to be strictly positive.
 *
 * This routine is not constant-time and should not be used for secret values.
 *
 * @param value
 */
static uint8_t byte_len(uint32_t value) {
  uint8_t len = 0;
  do {
    value >>= 8;
    len++;
  } while (value > 0);
  return len;
}

/**
 * Set the prefix registers in the KMAC hardware block.
 *
 * The caller must ensure that the hardware is idle. Returns an error if the
 * combined size of customization string and the function name must not exceed
 * `kKmacPrefixMaxSize`.
 *
 * @param func_name Function name input in cSHAKE.
 * @param func_name_bytelen Function name input length in bytes.
 * @param cust_str Customization string input in cSHAKE.
 * @param cust_str_bytelen Customization string input length in bytes.
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
static status_t set_prefix_regs(const unsigned char *func_name,
                                size_t func_name_bytelen,
                                const unsigned char *cust_str,
                                size_t cust_str_bytelen) {
  // Check if the lengths will fit in the prefix registers, including checking
  // for overflow.
  if (func_name_bytelen + cust_str_bytelen > kKmacPrefixMaxSize ||
      func_name_bytelen > UINT32_MAX - cust_str_bytelen) {
    return OTCRYPTO_BAD_ARGS;
  }

  // Initialize so that trailing bytes are set to zero.
  uint32_t prefix[KMAC_PREFIX_MULTIREG_COUNT];
  memset(prefix, 0, sizeof(prefix));
  unsigned char *prefix_bytes = (unsigned char *)prefix;

  // Encode the length of the function name parameter using `left_encode`.
  uint32_t func_name_bitlen = 8 * func_name_bytelen;
  uint8_t func_name_bitlen_nbytes = byte_len(func_name_bitlen);
  func_name_bitlen = __builtin_bswap32(func_name_bitlen);
  unsigned char *func_name_bitlen_ptr = (unsigned char *)&func_name_bitlen;
  func_name_bitlen_ptr += sizeof(uint32_t) - func_name_bitlen_nbytes;
  memcpy(prefix_bytes, &func_name_bitlen_nbytes, 1);
  prefix_bytes++;
  memcpy(prefix_bytes, func_name_bitlen_ptr, func_name_bitlen_nbytes);
  prefix_bytes += func_name_bitlen_nbytes;

  // Write the function name.
  memcpy(prefix_bytes, func_name, func_name_bytelen);
  prefix_bytes += func_name_bytelen;

  // Encode the length of the customization string parameter using
  // `left_encode`.
  uint32_t cust_str_bitlen = 8 * cust_str_bytelen;
  uint8_t cust_str_bitlen_nbytes = byte_len(cust_str_bitlen);
  cust_str_bitlen = __builtin_bswap32(cust_str_bitlen);
  unsigned char *cust_str_bitlen_ptr = (unsigned char *)&cust_str_bitlen;
  cust_str_bitlen_ptr += sizeof(uint32_t) - cust_str_bitlen_nbytes;
  memcpy(prefix_bytes, &cust_str_bitlen_nbytes, 1);
  prefix_bytes++;
  memcpy(prefix_bytes, cust_str_bitlen_ptr, cust_str_bitlen_nbytes);
  prefix_bytes += cust_str_bitlen_nbytes;

  // Write the customization string.
  memcpy(prefix_bytes, cust_str, cust_str_bytelen);
  prefix_bytes += cust_str_bytelen;

  // Copy from `prefix` to PREFIX_REGS
  hardened_mmio_write(kmac_base() + KMAC_PREFIX_0_REG_OFFSET, prefix,
                      KMAC_PREFIX_MULTIREG_COUNT);

  return OTCRYPTO_OK;
}

/**
 * Initializes the KMAC configuration and starts the operation.
 *
 * In particular, this function sets the CFG register of KMAC for given
 * operation, including security strength and operation type.
 *
 * `hw_backed` must be either `kHardenedBoolFalse` or `kHardenedBoolTrue`. For
 * other values, this function returns an error.
 * For KMAC operations, if `hw_backed = kHardenedBoolTrue` the sideloaded key
 * coming from Keymgr is used. If `hw_backed = kHardenedBoolFalse`, the key
 * configured by SW is used.
 *
 * For non-KMAC operations, the value of `hw_backed` can be either of
 * `kHardenedBoolFalse` or `kHardenedBoolTrue`. It is recommended to set it to
 * `kHardenedBoolFalse` for consistency.
 *
 * This function issues the `start` command to KMAC, so any additional
 * necessary configuration registers (e.g. key block) must be written before
 * calling this.
 *
 * @param operation The chosen operation, see kmac_operation_t struct.
 * @param security_str Security strength for KMAC (128 or 256).
 * @param hw_backed Whether the key comes from the sideload port.
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
static status_t start(kmac_operation_t operation,
                      kmac_security_str_t security_str,
                      hardened_bool_t hw_backed) {
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_IDLE_BIT, 1));

  // If the operation is KMAC, ensure that the entropy complex has been
  // initialized for masking.
  if (operation == kKmacOperationKmac) {
    HARDENED_TRY(entropy_complex_check());
  }

  // We need to preserve some bits of CFG register, such as:
  // entropy_mode, entropy_ready etc. On the other hand, some bits
  // need to be reset for each invocation.
  uint32_t cfg_reg =
      abs_mmio_read32(kmac_base() + KMAC_CFG_SHADOWED_REG_OFFSET);

  if (launder32(hw_backed) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(hw_backed, kHardenedBoolTrue);
    cfg_reg = bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_SIDELOAD_BIT, 1);
  } else if (launder32(hw_backed) == kHardenedBoolFalse) {
    HARDENED_CHECK_EQ(hw_backed, kHardenedBoolFalse);
    cfg_reg = bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_SIDELOAD_BIT, 0);
  } else {
    return OTCRYPTO_BAD_ARGS;
  };

  // Set the KMAC enable bit to zero by default.
  cfg_reg = bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_KMAC_EN_BIT, 0);

  // Set the operation type.
  switch (launder32(operation)) {
    case kKmacOperationSha3: {
      HARDENED_CHECK_EQ(operation, kKmacOperationSha3);
      cfg_reg = bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_MODE_FIELD,
                                       KMAC_CFG_SHADOWED_MODE_VALUE_SHA3);
      break;
    }
    case kKmacOperationShake: {
      HARDENED_CHECK_EQ(operation, kKmacOperationShake);
      cfg_reg = bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_MODE_FIELD,
                                       KMAC_CFG_SHADOWED_MODE_VALUE_SHAKE);
      break;
    }
    case kKmacOperationCshake: {
      HARDENED_CHECK_EQ(operation, kKmacOperationCshake);
      cfg_reg = bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_MODE_FIELD,
                                       KMAC_CFG_SHADOWED_MODE_VALUE_CSHAKE);
      break;
    }
    case kKmacOperationKmac: {
      HARDENED_CHECK_EQ(operation, kKmacOperationKmac);
      cfg_reg = bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_MODE_FIELD,
                                       KMAC_CFG_SHADOWED_MODE_VALUE_CSHAKE);
      cfg_reg = bitfield_bit32_write(cfg_reg, KMAC_CFG_SHADOWED_KMAC_EN_BIT, 1);
      break;
    }
    default:
      return OTCRYPTO_BAD_ARGS;
  }

  switch (launder32(security_str)) {
    case kKmacSecurityStrength128:
      HARDENED_CHECK_EQ(security_str, kKmacSecurityStrength128);
      cfg_reg =
          bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_KSTRENGTH_FIELD,
                                 KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L128);
      break;
    case kKmacSecurityStrength224:
      HARDENED_CHECK_EQ(security_str, kKmacSecurityStrength224);
      cfg_reg =
          bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_KSTRENGTH_FIELD,
                                 KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L224);
      break;
    case kKmacSecurityStrength256:
      HARDENED_CHECK_EQ(security_str, kKmacSecurityStrength256);
      cfg_reg =
          bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_KSTRENGTH_FIELD,
                                 KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L256);
      break;
    case kKmacSecurityStrength384:
      HARDENED_CHECK_EQ(security_str, kKmacSecurityStrength384);
      cfg_reg =
          bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_KSTRENGTH_FIELD,
                                 KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L384);
      break;
    case kKmacSecurityStrength512:
      HARDENED_CHECK_EQ(security_str, kKmacSecurityStrength512);
      cfg_reg =
          bitfield_field32_write(cfg_reg, KMAC_CFG_SHADOWED_KSTRENGTH_FIELD,
                                 KMAC_CFG_SHADOWED_KSTRENGTH_VALUE_L512);
      break;
    default:
      return OTCRYPTO_BAD_ARGS;
  }

  abs_mmio_write32_shadowed(kmac_base() + KMAC_CFG_SHADOWED_REG_OFFSET,
                            cfg_reg);

  // Issue the `start` command.
  uint32_t cmd_reg = KMAC_CMD_REG_RESVAL;
  cmd_reg = bitfield_field32_write(cmd_reg, KMAC_CMD_CMD_FIELD,
                                   KMAC_CMD_CMD_VALUE_START);
  abs_mmio_write32(kmac_base() + KMAC_CMD_REG_OFFSET, cmd_reg);

  return OTCRYPTO_OK;
}

/**
 * Update the key registers with given key shares.
 *
 * Returns an error if the key byte length is not one of the acceptable values:
 * 16, 24, 32, 40, or 48.
 *
 * If the key is hardware-backed, this is a no-op.
 *
 * Uses hardening primitives internally that consume entropy; the caller must
 * ensure the entropy complex is up before calling.
 *
 * @param key The input key passed as a struct.
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
static status_t write_key_block(kmac_blinded_key_t *key) {
  if (launder32(key->hw_backed) == kHardenedBoolTrue) {
    // Nothing to do.
    return OTCRYPTO_OK;
  } else if (launder32(key->hw_backed) != kHardenedBoolFalse) {
    // Invalid value.
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(key->hw_backed, kHardenedBoolFalse);

  const uint32_t kBase = kmac_base();
  uint32_t key_len_reg;
  HARDENED_TRY(key_len_reg_get(key->len, &key_len_reg));
  abs_mmio_write32(kBase + KMAC_KEY_LEN_REG_OFFSET, key_len_reg);

  // Write random words to the key registers first for SCA defense.
  for (size_t i = 0; i * sizeof(uint32_t) < key->len; i++) {
    abs_mmio_write32(
        kBase + KMAC_KEY_SHARE0_0_REG_OFFSET + i * sizeof(uint32_t),
        ibex_rnd32_read());
  }
  hardened_mmio_write(kBase + KMAC_KEY_SHARE0_0_REG_OFFSET, key->share0,
                      key->len / sizeof(uint32_t));
  for (size_t i = 0; i * sizeof(uint32_t) < key->len; i++) {
    abs_mmio_write32(
        kBase + KMAC_KEY_SHARE1_0_REG_OFFSET + i * sizeof(uint32_t),
        ibex_rnd32_read());
  }
  hardened_mmio_write(kBase + KMAC_KEY_SHARE1_0_REG_OFFSET, key->share1,
                      key->len / sizeof(uint32_t));
  return OTCRYPTO_OK;
}

void kmac_process(void) {
  uint32_t cmd_reg = KMAC_CMD_REG_RESVAL;
  cmd_reg = bitfield_field32_write(cmd_reg, KMAC_CMD_CMD_FIELD,
                                   KMAC_CMD_CMD_VALUE_PROCESS);
  abs_mmio_write32(kmac_base() + KMAC_CMD_REG_OFFSET, cmd_reg);
}

status_t kmac_absorb(const uint8_t *message, size_t message_len) {
  const uint32_t kBase = kmac_base();

  // Block until KMAC is ready to absorb input.
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_ABSORB_BIT, 1));

  // Begin by writing a one byte at a time until the data is aligned.
  size_t i = 0;
  for (; misalignment32_of((uintptr_t)(&message[i])) > 0 && i < message_len;
       i++) {
    HARDENED_TRY(wait_status_bit(KMAC_STATUS_FIFO_FULL_BIT, 0));
    abs_mmio_write8(kBase + KMAC_MSG_FIFO_REG_OFFSET, message[i]);
  }

  // Write one word at a time as long as there is a full word available.
  for (; i + sizeof(uint32_t) <= message_len; i += sizeof(uint32_t)) {
    HARDENED_TRY(wait_status_bit(KMAC_STATUS_FIFO_FULL_BIT, 0));
    uint32_t next_word = read_32(&message[i]);
    abs_mmio_write32(kBase + KMAC_MSG_FIFO_REG_OFFSET, next_word);
  }

  // For the last few bytes, we need to write one byte at a time again.
  for (; i < message_len; i++) {
    HARDENED_TRY(wait_status_bit(KMAC_STATUS_FIFO_FULL_BIT, 0));
    abs_mmio_write8(kBase + KMAC_MSG_FIFO_REG_OFFSET, message[i]);
  }

  return OTCRYPTO_OK;
}

/**
 * Write the digest length for KMAC operations.
 *
 * Expects input to have already been absorbed by the KMAC block. Writes result
 * directly into the message FIFO.
 *
 * Corresponds to `right_encode` in NIST SP800-185. Although that document
 * allows encoding values up to 2^2040, this driver only supports digests with
 * a bit-length up to 2^32 and returns an error if the word length is too big.
 *
 * @param digest_wordlen Length of the digest in 32-bit words.
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
static status_t encode_digest_length(size_t digest_wordlen) {
  if (digest_wordlen > (UINT32_MAX / (8 * sizeof(uint32_t)))) {
    return OTCRYPTO_BAD_ARGS;
  }
  uint32_t digest_bitlen = 8 * sizeof(uint32_t) * digest_wordlen;
  const uint32_t kBase = kmac_base();

  // Write the number of bits in big-endian order, using only as many bytes as
  // strictly required.
  unsigned char *bitlen_ptr = (unsigned char *)&digest_bitlen;
  uint8_t nbytes = byte_len(digest_bitlen);
  for (uint8_t i = 0; i < nbytes; i++) {
    abs_mmio_write8(kBase + KMAC_MSG_FIFO_REG_OFFSET,
                    bitlen_ptr[nbytes - 1 - i]);
  }
  abs_mmio_write8(kBase + KMAC_MSG_FIFO_REG_OFFSET, nbytes);
  return OTCRYPTO_OK;
}

/**
 * Read raw output from a SHA-3, SHAKE, cSHAKE, or KMAC operation.
 *
 * This is an internal operation that trusts its input; it does not check that
 * the number of words is within the Keccak rate. It simply reads the requested
 * number of words from the state registers. The caller is responsible for
 * ensuring enough data is available.
 *
 * Blocks until the squeeze bit goes high before reading.
 *
 * The caller must ensure that there is an amount of space matching the Keccak
 * rate times the number of blocks available at `share0`. If `nwords` is 0,
 * both shares are ignored and may be NULL. If `read_masked` is set, there must
 * also be the same amount of space available at `share1`; otherwise, `share1`
 * is ignored and may be NULL.
 *
 * @param nwords Number of words to read.
 * @param read_masked Whether to return the digest in two shares.
 * @param[out] share0 Destination for output (share if `read_masked`).
 * @param[out] share1 Destination for share of output (if `read_masked`).
 * @return Error code.
 */
OT_WARN_UNUSED_RESULT
static status_t read_state(size_t nwords, hardened_bool_t read_masked,
                           uint32_t *share0, uint32_t *share1) {
  const uint32_t kBase = kmac_base();
  const uint32_t kAddrShare0 = kBase + KMAC_STATE_REG_OFFSET;
  const uint32_t kAddrShare1 = kAddrShare0 + kKmacStateShareSize;

  // Poll the status register until in the 'squeeze' state.
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_SQUEEZE_BIT, 1));

  if (launder32(read_masked) == kHardenedBoolTrue) {
    HARDENED_CHECK_EQ(read_masked, kHardenedBoolTrue);

    // Read the digest into each share in turn.
    hardened_mmio_read(share0, kAddrShare0, nwords);
    hardened_mmio_read(share1, kAddrShare1, nwords);
  } else {
    // Skip right to the hardened check here instead of returning
    // `OTCRYPTO_BAD_ARGS` if the value is not `kHardenedBoolFalse`; this
    // value always comes from within the cryptolib, so we expect it to be
    // valid and should be suspicious if it's not.
    HARDENED_CHECK_EQ(read_masked, kHardenedBoolFalse);

    // Unmask the digest as we read it.
    for (size_t offset = 0; offset < nwords; offset++) {
      share0[offset] = abs_mmio_read32(kAddrShare0 + offset * sizeof(uint32_t));
      share0[offset] ^=
          abs_mmio_read32(kAddrShare1 + offset * sizeof(uint32_t));
    }
  }

  return OTCRYPTO_OK;
}

status_t kmac_squeeze_blocks(size_t nblocks, hardened_bool_t read_masked,
                             uint32_t *blocks_share0, uint32_t *blocks_share1) {
  const uint32_t kBase = kmac_base();
  size_t keccak_rate_words = get_keccak_rate_words();
  if (keccak_rate_words == 0) {
    return OTCRYPTO_FATAL_ERR;
  }

  size_t i = 0;
  for (; launder32(i) < nblocks; i++) {
    HARDENED_TRY(read_state(keccak_rate_words, read_masked, blocks_share0,
                            blocks_share1));
    blocks_share0 += keccak_rate_words;
    if (read_masked == kHardenedBoolTrue) {
      blocks_share1 += keccak_rate_words;
    }

    // Issue `CMD.RUN` to generate more state.
    uint32_t cmd_reg = KMAC_CMD_REG_RESVAL;
    cmd_reg = bitfield_field32_write(cmd_reg, KMAC_CMD_CMD_FIELD,
                                     KMAC_CMD_CMD_VALUE_RUN);
    abs_mmio_write32(kBase + KMAC_CMD_REG_OFFSET, cmd_reg);
  }
  HARDENED_CHECK_EQ(i, nblocks);
  return OTCRYPTO_OK;
}

status_t kmac_squeeze_end(size_t digest_wordlen, hardened_bool_t read_masked,
                          uint32_t *digest_share0, uint32_t *digest_share1) {
  // First, squeeze any full blocks.
  size_t keccak_rate_words = get_keccak_rate_words();
  if (keccak_rate_words == 0) {
    return OTCRYPTO_FATAL_ERR;
  }
  size_t nblocks = digest_wordlen / keccak_rate_words;
  HARDENED_TRY(
      kmac_squeeze_blocks(nblocks, read_masked, digest_share0, digest_share1));
  digest_share0 += nblocks * keccak_rate_words;
  digest_share1 += nblocks * keccak_rate_words;

  size_t remaining_words = digest_wordlen % keccak_rate_words;
  HARDENED_TRY(
      read_state(remaining_words, read_masked, digest_share0, digest_share1));

  // Send the `done` command so that KMAC goes back to idle mode.
  uint32_t cmd_reg = KMAC_CMD_REG_RESVAL;
  cmd_reg = bitfield_field32_write(cmd_reg, KMAC_CMD_CMD_FIELD,
                                   KMAC_CMD_CMD_VALUE_DONE);
  abs_mmio_write32(kmac_base() + KMAC_CMD_REG_OFFSET, cmd_reg);

  return OTCRYPTO_OK;
}

status_t kmac_sha3_224_begin(void) {
  return start(kKmacOperationSha3, kKmacSecurityStrength224,
               /*hw_backed=*/kHardenedBoolFalse);
}

status_t kmac_sha3_256_begin(void) {
  return start(kKmacOperationSha3, kKmacSecurityStrength256,
               /*hw_backed=*/kHardenedBoolFalse);
}

status_t kmac_sha3_384_begin(void) {
  return start(kKmacOperationSha3, kKmacSecurityStrength384,
               /*hw_backed=*/kHardenedBoolFalse);
}

status_t kmac_sha3_512_begin(void) {
  return start(kKmacOperationSha3, kKmacSecurityStrength512,
               /*hw_backed=*/kHardenedBoolFalse);
}

status_t kmac_shake128_begin(void) {
  return start(kKmacOperationShake, kKmacSecurityStrength128,
               /*hw_backed=*/kHardenedBoolFalse);
}

status_t kmac_shake256_begin(void) {
  return start(kKmacOperationShake, kKmacSecurityStrength256,
               /*hw_backed=*/kHardenedBoolFalse);
}

/**
 * Perform a one-shot SHA3, SHAKE, or cSHAKE operation.
 *
 * Do not use this routine for KMAC operations.
 *
 * @param operation Hash function to perform.
 * @param strength Security strength parameter.
 * @param message Message data to hash.
 * @param message_len Length of message data in bytes.
 * @param digest_wordlen Length of digest in words.
 * @param[out] digest Computed digest.
 * @return OK or error.
 */
OT_WARN_UNUSED_RESULT
static status_t hash(kmac_operation_t operation, kmac_security_str_t strength,
                     const uint8_t *message, size_t message_len,
                     size_t digest_wordlen, uint32_t *digest) {
  // Note: to save code size, we check for null pointers here instead of
  // separately for every different Keccak hash operation.
  if (digest == NULL || (message == NULL && message_len != 0)) {
    return OTCRYPTO_BAD_ARGS;
  }

  HARDENED_TRY(start(operation, strength, /*hw_backed=*/kHardenedBoolFalse));
  HARDENED_TRY(kmac_absorb(message, message_len));
  kmac_process();
  return kmac_squeeze_end(digest_wordlen, /*read_masked=*/kHardenedBoolFalse,
                          digest, NULL);
}

inline status_t kmac_sha3_224(const uint8_t *message, size_t message_len,
                              uint32_t *digest) {
  return hash(kKmacOperationSha3, kKmacSecurityStrength224, message,
              message_len, kKmacSha3224DigestWords, digest);
}

inline status_t kmac_sha3_256(const uint8_t *message, size_t message_len,
                              uint32_t *digest) {
  return hash(kKmacOperationSha3, kKmacSecurityStrength256, message,
              message_len, kKmacSha3256DigestWords, digest);
}

inline status_t kmac_sha3_384(const uint8_t *message, size_t message_len,
                              uint32_t *digest) {
  return hash(kKmacOperationSha3, kKmacSecurityStrength384, message,
              message_len, kKmacSha3384DigestWords, digest);
}

inline status_t kmac_sha3_512(const uint8_t *message, size_t message_len,
                              uint32_t *digest) {
  return hash(kKmacOperationSha3, kKmacSecurityStrength512, message,
              message_len, kKmacSha3512DigestWords, digest);
}

inline status_t kmac_shake_128(const uint8_t *message, size_t message_len,
                               uint32_t *digest, size_t digest_len) {
  return hash(kKmacOperationShake, kKmacSecurityStrength128, message,
              message_len, digest_len, digest);
}

inline status_t kmac_shake_256(const uint8_t *message, size_t message_len,
                               uint32_t *digest, size_t digest_len) {
  return hash(kKmacOperationShake, kKmacSecurityStrength256, message,
              message_len, digest_len, digest);
}

status_t kmac_cshake_128(const uint8_t *message, size_t message_len,
                         const unsigned char *func_name, size_t func_name_len,
                         const unsigned char *cust_str, size_t cust_str_len,
                         uint32_t *digest, size_t digest_len) {
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_IDLE_BIT, 1));
  HARDENED_TRY(
      set_prefix_regs(func_name, func_name_len, cust_str, cust_str_len));
  return hash(kKmacOperationCshake, kKmacSecurityStrength128, message,
              message_len, digest_len, digest);
}

status_t kmac_cshake_256(const uint8_t *message, size_t message_len,
                         const unsigned char *func_name, size_t func_name_len,
                         const unsigned char *cust_str, size_t cust_str_len,
                         uint32_t *digest, size_t digest_len) {
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_IDLE_BIT, 1));
  HARDENED_TRY(
      set_prefix_regs(func_name, func_name_len, cust_str, cust_str_len));
  return hash(kKmacOperationCshake, kKmacSecurityStrength256, message,
              message_len, digest_len, digest);
}

status_t kmac_kmac_128(kmac_blinded_key_t *key, hardened_bool_t masked_digest,
                       const uint8_t *message, size_t message_len,
                       const unsigned char *cust_str, size_t cust_str_len,
                       uint32_t *digest, size_t digest_len) {
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_IDLE_BIT, 1));
  HARDENED_TRY(write_key_block(key));
  HARDENED_TRY(set_prefix_regs(kKmacFuncNameKMAC, sizeof(kKmacFuncNameKMAC),
                               cust_str, cust_str_len));

  HARDENED_TRY(
      start(kKmacOperationKmac, kKmacSecurityStrength128, key->hw_backed));

  HARDENED_TRY(kmac_absorb(message, message_len));
  HARDENED_TRY(encode_digest_length(digest_len));
  kmac_process();

  return kmac_squeeze_end(digest_len, masked_digest, digest,
                          digest + digest_len);
}

status_t kmac_kmac_256(kmac_blinded_key_t *key, hardened_bool_t masked_digest,
                       const uint8_t *message, size_t message_len,
                       const unsigned char *cust_str, size_t cust_str_len,
                       uint32_t *digest, size_t digest_len) {
  HARDENED_TRY(wait_status_bit(KMAC_STATUS_SHA3_IDLE_BIT, 1));
  HARDENED_TRY(write_key_block(key));
  HARDENED_TRY(set_prefix_regs(kKmacFuncNameKMAC, sizeof(kKmacFuncNameKMAC),
                               cust_str, cust_str_len));
  HARDENED_TRY(
      start(kKmacOperationKmac, kKmacSecurityStrength256, key->hw_backed));

  HARDENED_TRY(kmac_absorb(message, message_len));
  HARDENED_TRY(encode_digest_length(digest_len));
  kmac_process();

  return kmac_squeeze_end(digest_len, masked_digest, digest,
                          digest + digest_len);
}
