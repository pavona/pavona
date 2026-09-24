// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/dif/dif_dma.h"

#include <stddef.h>
#include <stdint.h>

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/mmio.h"

static_assert(kDifDmaOpentitanInternalBus ==
                  DMA_ADDR_SPACE_ID_DST_ASID_VALUE_OT_ADDR,
              "Address Space ID mismatches with value defined in HW");
static_assert(kDifDmaSoCControlRegisterBus ==
                  DMA_ADDR_SPACE_ID_DST_ASID_VALUE_SOC_ADDR,
              "Address Space ID mismatches with value defined in HW");
static_assert(kDifDmaSoCSystemBus == DMA_ADDR_SPACE_ID_DST_ASID_VALUE_SYS_ADDR,
              "Address Space ID mismatches with value defined in HW");

dif_result_t dif_dma_configure(const dif_dma_t *dma,
                               dif_dma_transaction_t transaction) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  // Source address.
  mmio_region_write32(dma->base_addr, DMA_SRC_ADDR_LO_REG_OFFSET,
                      transaction.source.address & UINT32_MAX);
  mmio_region_write32(dma->base_addr, DMA_SRC_ADDR_HI_REG_OFFSET,
                      transaction.source.address >> (sizeof(uint32_t) * 8));

  // Destination address.
  mmio_region_write32(dma->base_addr, DMA_DST_ADDR_LO_REG_OFFSET,
                      transaction.destination.address & UINT32_MAX);
  mmio_region_write32(
      dma->base_addr, DMA_DST_ADDR_HI_REG_OFFSET,
      transaction.destination.address >> (sizeof(uint32_t) * 8));

  // Source configuration.
  uint32_t reg = 0;
  reg = bitfield_bit32_write(reg, DMA_SRC_CONFIG_WRAP_BIT,
                             transaction.src_config.wrap);
  reg = bitfield_bit32_write(reg, DMA_SRC_CONFIG_INCREMENT_BIT,
                             transaction.src_config.increment);
  mmio_region_write32(dma->base_addr, DMA_SRC_CONFIG_REG_OFFSET, reg);

  // Destination configuration.
  reg = 0;
  reg = bitfield_bit32_write(reg, DMA_DST_CONFIG_WRAP_BIT,
                             transaction.dst_config.wrap);
  reg = bitfield_bit32_write(reg, DMA_DST_CONFIG_INCREMENT_BIT,
                             transaction.dst_config.increment);
  mmio_region_write32(dma->base_addr, DMA_DST_CONFIG_REG_OFFSET, reg);

  // Address Space IDs.
  reg = 0;
  reg = bitfield_field32_write(reg, DMA_ADDR_SPACE_ID_SRC_ASID_FIELD,
                               transaction.source.asid);
  reg = bitfield_field32_write(reg, DMA_ADDR_SPACE_ID_DST_ASID_FIELD,
                               transaction.destination.asid);
  mmio_region_write32(dma->base_addr, DMA_ADDR_SPACE_ID_REG_OFFSET, reg);

  // Transfer quantities.
  mmio_region_write32(dma->base_addr, DMA_CHUNK_DATA_SIZE_REG_OFFSET,
                      transaction.chunk_size);
  mmio_region_write32(dma->base_addr, DMA_TOTAL_DATA_SIZE_REG_OFFSET,
                      transaction.total_size);
  mmio_region_write32(dma->base_addr, DMA_TRANSFER_WIDTH_REG_OFFSET,
                      transaction.width);

  return kDifOk;
}

dif_result_t dif_dma_handshake_enable(const dif_dma_t *dma) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = mmio_region_read32(dma->base_addr, DMA_CONTROL_REG_OFFSET);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT,
                             true);
  mmio_region_write32(dma->base_addr, DMA_CONTROL_REG_OFFSET, reg);
  return kDifOk;
}

dif_result_t dif_dma_handshake_disable(const dif_dma_t *dma) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = mmio_region_read32(dma->base_addr, DMA_CONTROL_REG_OFFSET);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT,
                             false);
  mmio_region_write32(dma->base_addr, DMA_CONTROL_REG_OFFSET, reg);
  return kDifOk;
}

// Decode an operation selector into the orthogonal CONTROL fields.
//
// Maps each `dif_dma_transaction_opcode_t` value to (read_en, write_en,
// digest) where `digest` is one of the DMA_CONTROL_DIGEST_VALUE_* encodings.
typedef struct dif_dma_control_fields {
  bool read_en;
  bool write_en;
  uint32_t digest;
  // Inline-AES operation written to CONTROL.aes_op (Off/Enc/Dec). OFF for the
  // non-AES operations (zero-initialised by the positional initialisers below).
  uint32_t aes_op;
  // CONTROL.aes_mode: 0 = CTR, 1 = GCM (only meaningful when aes_op != Off).
  bool aes_gcm;
} dif_dma_control_fields_t;

static dif_result_t dif_dma_decode_opcode(dif_dma_transaction_opcode_t opcode,
                                          dif_dma_control_fields_t *fields) {
  switch (opcode) {
    case kDifDmaCopyOpcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaSha256Opcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_SHA256,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaSha384Opcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_SHA384,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaSha512Opcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_SHA512,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaMemsetOpcode:
      *fields = (dif_dma_control_fields_t){
          false, true, DMA_CONTROL_DIGEST_VALUE_NONE,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaVerifySha256Opcode:
      *fields = (dif_dma_control_fields_t){
          true, false, DMA_CONTROL_DIGEST_VALUE_SHA256,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaVerifySha384Opcode:
      *fields = (dif_dma_control_fields_t){
          true, false, DMA_CONTROL_DIGEST_VALUE_SHA384,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    case kDifDmaVerifySha512Opcode:
      *fields = (dif_dma_control_fields_t){
          true, false, DMA_CONTROL_DIGEST_VALUE_SHA512,
          DMA_CONTROL_AES_OP_VALUE_OFF, false};
      break;
    // Inline AES: a copy (read_en=1, write_en=1, no SHA digest) with
    // CONTROL.aes_op/aes_mode selecting the cipher operation and mode.
    case kDifDmaAesCtrEncOpcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
          DMA_CONTROL_AES_OP_VALUE_ENC, false};
      break;
    case kDifDmaAesCtrDecOpcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
          DMA_CONTROL_AES_OP_VALUE_DEC, false};
      break;
    case kDifDmaAesGcmEncOpcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
          DMA_CONTROL_AES_OP_VALUE_ENC, true};
      break;
    case kDifDmaAesGcmDecOpcode:
      *fields = (dif_dma_control_fields_t){
          true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
          DMA_CONTROL_AES_OP_VALUE_DEC, true};
      break;
    default:
      return kDifBadArg;
  }
  return kDifOk;
}

// Map an operation selector to its digest length in 32-bit words (0 if the
// operation does not compute a digest).
static dif_result_t dif_dma_decode_digest_words(
    dif_dma_transaction_opcode_t opcode, uint32_t *digest_len) {
  dif_dma_control_fields_t fields;
  DIF_RETURN_IF_ERROR(dif_dma_decode_opcode(opcode, &fields));
  switch (fields.digest) {
    case DMA_CONTROL_DIGEST_VALUE_NONE:
      *digest_len = 0;
      break;
    case DMA_CONTROL_DIGEST_VALUE_SHA256:
      *digest_len = 8;
      break;
    case DMA_CONTROL_DIGEST_VALUE_SHA384:
      *digest_len = 12;
      break;
    case DMA_CONTROL_DIGEST_VALUE_SHA512:
      *digest_len = 16;
      break;
    default:
      return kDifBadArg;
  }
  return kDifOk;
}

dif_result_t dif_dma_start(const dif_dma_t *dma,
                           dif_dma_transaction_opcode_t opcode) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  dif_dma_control_fields_t fields;
  DIF_RETURN_IF_ERROR(dif_dma_decode_opcode(opcode, &fields));

  uint32_t reg = mmio_region_read32(dma->base_addr, DMA_CONTROL_REG_OFFSET);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_READ_EN_BIT, fields.read_en);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_WRITE_EN_BIT, fields.write_en);
  reg = bitfield_field32_write(reg, DMA_CONTROL_DIGEST_FIELD, fields.digest);
  // Inline-AES operation/mode (Off for the non-AES operations).
  reg = bitfield_field32_write(reg, DMA_CONTROL_AES_OP_FIELD, fields.aes_op);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_AES_MODE_BIT, fields.aes_gcm);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_GO_BIT, 1);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_INITIAL_TRANSFER_BIT, 1);
  mmio_region_write32(dma->base_addr, DMA_CONTROL_REG_OFFSET, reg);
  return kDifOk;
}

dif_result_t dif_dma_aes_configure(const dif_dma_t *dma,
                                   dif_dma_aes_config_t config) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = 0;
  reg = bitfield_field32_write(reg, DMA_AES_CTRL_KEY_LEN_FIELD, config.key_len);
  reg = bitfield_bit32_write(reg, DMA_AES_CTRL_SIDELOAD_BIT, config.sideload);
  reg = bitfield_field32_write(reg, DMA_AES_CTRL_PRNG_RESEED_RATE_FIELD,
                               config.reseed_rate);
  reg = bitfield_field32_write(reg, DMA_AES_CTRL_AAD_BLOCKS_FIELD,
                               config.aad_blocks);
  mmio_region_write32(dma->base_addr, DMA_AES_CTRL_REG_OFFSET, reg);
  return kDifOk;
}

dif_result_t dif_dma_aes_key_set(const dif_dma_t *dma, const uint32_t share0[8],
                                 const uint32_t share1[8]) {
  if (dma == NULL || share0 == NULL || share1 == NULL) {
    return kDifBadArg;
  }

  for (size_t i = 0; i < DMA_KEY_SHARE0_MULTIREG_COUNT; ++i) {
    mmio_region_write32(
        dma->base_addr,
        (ptrdiff_t)(DMA_KEY_SHARE0_0_REG_OFFSET + i * sizeof(uint32_t)),
        share0[i]);
    mmio_region_write32(
        dma->base_addr,
        (ptrdiff_t)(DMA_KEY_SHARE1_0_REG_OFFSET + i * sizeof(uint32_t)),
        share1[i]);
  }
  return kDifOk;
}

dif_result_t dif_dma_aes_iv_set(const dif_dma_t *dma, const uint32_t iv[4]) {
  if (dma == NULL || iv == NULL) {
    return kDifBadArg;
  }

  for (size_t i = 0; i < DMA_IV_MULTIREG_COUNT; ++i) {
    mmio_region_write32(dma->base_addr,
                        (ptrdiff_t)(DMA_IV_0_REG_OFFSET + i * sizeof(uint32_t)),
                        iv[i]);
  }
  return kDifOk;
}

dif_result_t dif_dma_aes_aad_set(const dif_dma_t *dma, const uint32_t *aad,
                                 size_t num_words) {
  if (dma == NULL || num_words > DMA_AAD_MULTIREG_COUNT ||
      (aad == NULL && num_words > 0)) {
    return kDifBadArg;
  }

  for (size_t i = 0; i < num_words; ++i) {
    ptrdiff_t offset = (ptrdiff_t)(DMA_AAD_0_REG_OFFSET + i * sizeof(uint32_t));
    mmio_region_write32(dma->base_addr, offset, aad[i]);
  }
  return kDifOk;
}

dif_result_t dif_dma_aes_tag_in_set(const dif_dma_t *dma,
                                    const uint32_t tag[4]) {
  if (dma == NULL || tag == NULL) {
    return kDifBadArg;
  }

  for (size_t i = 0; i < DMA_TAG_IN_MULTIREG_COUNT; ++i) {
    mmio_region_write32(
        dma->base_addr,
        (ptrdiff_t)(DMA_TAG_IN_0_REG_OFFSET + i * sizeof(uint32_t)), tag[i]);
  }
  return kDifOk;
}

dif_result_t dif_dma_aes_tag_out_get(const dif_dma_t *dma, uint32_t tag[4]) {
  if (dma == NULL || tag == NULL) {
    return kDifBadArg;
  }

  for (size_t i = 0; i < DMA_TAG_OUT_MULTIREG_COUNT; ++i) {
    tag[i] = mmio_region_read32(
        dma->base_addr,
        (ptrdiff_t)(DMA_TAG_OUT_0_REG_OFFSET + i * sizeof(uint32_t)));
  }
  return kDifOk;
}

dif_result_t dif_dma_aes_tag_status_get(const dif_dma_t *dma, bool *tag_valid,
                                        bool *tag_failed) {
  if (dma == NULL || tag_valid == NULL || tag_failed == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = mmio_region_read32(dma->base_addr, DMA_STATUS_REG_OFFSET);
  *tag_valid = bitfield_bit32_read(reg, DMA_STATUS_TAG_VALID_BIT);
  *tag_failed = bitfield_bit32_read(reg, DMA_STATUS_TAG_FAILED_BIT);
  return kDifOk;
}

dif_result_t dif_dma_abort(const dif_dma_t *dma) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  uint32_t reg = mmio_region_read32(dma->base_addr, DMA_CONTROL_REG_OFFSET);
  reg = bitfield_bit32_write(reg, DMA_CONTROL_ABORT_BIT, 1);
  mmio_region_write32(dma->base_addr, DMA_CONTROL_REG_OFFSET, reg);
  return kDifOk;
}

dif_result_t dif_dma_memory_range_set(const dif_dma_t *dma, uint32_t address,
                                      size_t size) {
  if (dma == NULL || size == 0) {
    return kDifBadArg;
  }

  mmio_region_write32(dma->base_addr, DMA_ENABLED_MEMORY_RANGE_BASE_REG_OFFSET,
                      address);
  // The limit address is inclusive so we subtract one.
  uint32_t end_addr = address + size - 1;
  mmio_region_write32(dma->base_addr, DMA_ENABLED_MEMORY_RANGE_LIMIT_REG_OFFSET,
                      end_addr);
  // Indicate the range to be valid
  mmio_region_write32(dma->base_addr, DMA_RANGE_VALID_REG_OFFSET, 1);

  return kDifOk;
}

dif_result_t dif_dma_memory_range_get(const dif_dma_t *dma, uint32_t *address,
                                      size_t *size) {
  if (dma == NULL || size == NULL || address == NULL) {
    return kDifBadArg;
  }

  *address = mmio_region_read32(dma->base_addr,
                                DMA_ENABLED_MEMORY_RANGE_BASE_REG_OFFSET);

  // The limit address is inclusive so we add one.
  *size = mmio_region_read32(dma->base_addr,
                             DMA_ENABLED_MEMORY_RANGE_LIMIT_REG_OFFSET) -
          *address + 1;

  return kDifOk;
}

dif_result_t dif_dma_memory_range_lock(const dif_dma_t *dma) {
  if (dma == NULL) {
    return kDifBadArg;
  }

  mmio_region_write32(dma->base_addr, DMA_RANGE_REGWEN_REG_OFFSET,
                      kMultiBitBool4False);
  return kDifOk;
}

dif_result_t dif_dma_is_memory_range_locked(const dif_dma_t *dma,
                                            bool *is_locked) {
  if (dma == NULL || is_locked == NULL) {
    return kDifBadArg;
  }

  *is_locked = kMultiBitBool4False ==
               mmio_region_read32(dma->base_addr, DMA_RANGE_REGWEN_REG_OFFSET);
  return kDifOk;
}

dif_result_t dif_dma_is_memory_range_valid(const dif_dma_t *dma,
                                           bool *is_valid) {
  if (dma == NULL || is_valid == NULL) {
    return kDifBadArg;
  }

  *is_valid = mmio_region_read32(dma->base_addr, DMA_RANGE_VALID_REG_OFFSET);
  return kDifOk;
}

dif_result_t dif_dma_status_get(const dif_dma_t *dma,
                                dif_dma_status_t *status) {
  if (dma == NULL || status == NULL) {
    return kDifBadArg;
  }
  *status = mmio_region_read32(dma->base_addr, DMA_STATUS_REG_OFFSET);

  return kDifOk;
}

dif_result_t dif_dma_status_write(const dif_dma_t *dma,
                                  dif_dma_status_t status) {
  if (dma == NULL) {
    return kDifBadArg;
  }
  mmio_region_write32(dma->base_addr, DMA_STATUS_REG_OFFSET, status);

  return kDifOk;
}

dif_result_t dif_dma_status_clear(const dif_dma_t *dma) {
  // Clear every write-1-to-clear STATUS bit (busy and sha2_digest_valid are
  // read-only; the AES tag_valid/tag_failed bits are read-only too).
  return dif_dma_status_write(dma, kDifDmaStatusDone | kDifDmaStatusAborted |
                                       kDifDmaStatusError |
                                       kDifDmaStatusChunkDone);
}

dif_result_t dif_dma_status_poll(const dif_dma_t *dma,
                                 dif_dma_status_code_t flag) {
  while (true) {
    dif_dma_status_t status;
    DIF_RETURN_IF_ERROR(dif_dma_status_get(dma, &status));

    if (status & flag) {
      break;
    }
    if (status & kDifDmaStatusError) {
      return kDifError;
    }
  }
  return kDifOk;
}

dif_result_t dif_dma_error_code_get(const dif_dma_t *dma,
                                    dif_dma_error_code_t *error) {
  if (dma == NULL || error == NULL) {
    return kDifBadArg;
  }
  *error = mmio_region_read32(dma->base_addr, DMA_ERROR_CODE_REG_OFFSET);

  return kDifOk;
}

dif_result_t dif_dma_get_digest_length(dif_dma_transaction_opcode_t opcode,
                                       uint32_t *digest_len) {
  if (digest_len == NULL) {
    return kDifBadArg;
  }
  uint32_t words = 0;
  DIF_RETURN_IF_ERROR(dif_dma_decode_digest_words(opcode, &words));
  // Operations without a digest (e.g. copy, memset) have no length to report.
  if (words == 0) {
    return kDifBadArg;
  }
  *digest_len = words;
  return kDifOk;
}

dif_result_t dif_dma_sha2_digest_get(const dif_dma_t *dma,
                                     dif_dma_transaction_opcode_t opcode,
                                     uint32_t digest[]) {
  if (dma == NULL || digest == NULL) {
    return kDifBadArg;
  }

  uint32_t digest_len;
  DIF_RETURN_IF_ERROR(dif_dma_get_digest_length(opcode, &digest_len));

  for (int i = 0; i < digest_len; ++i) {
    ptrdiff_t offset = DMA_SHA2_DIGEST_0_REG_OFFSET +
                       (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t);

    digest[i] = mmio_region_read32(dma->base_addr, offset);
  }
  return kDifOk;
}

dif_result_t dif_dma_handshake_irq_enable(const dif_dma_t *dma,
                                          uint32_t enable_state) {
  if (dma == NULL) {
    return kDifBadArg;
  }
  mmio_region_write32(dma->base_addr, DMA_HANDSHAKE_INTR_ENABLE_REG_OFFSET,
                      enable_state);
  return kDifOk;
}

dif_result_t dif_dma_handshake_clear_irq(const dif_dma_t *dma,
                                         uint32_t clear_state) {
  if (dma == NULL) {
    return kDifBadArg;
  }
  mmio_region_write32(dma->base_addr, DMA_CLEAR_INTR_SRC_REG_OFFSET,
                      clear_state);

  return kDifOk;
}

dif_result_t dif_dma_handshake_clear_irq_asid(const dif_dma_t *dma,
                                            uint32_t source,
                                            dif_dma_address_space_id_t asid) {
  if (dma == NULL || source >= DMA_PARAM_NUM_INT_CLEAR_SOURCES) {
    return kDifBadArg;
  }
  switch (asid) {
    case kDifDmaAsid0:
    case kDifDmaAsid1:
    case kDifDmaAsid2:
    case kDifDmaAsid3:
    case kDifDmaAsid4:
    case kDifDmaAsid5:
    case kDifDmaAsid6:
    case kDifDmaAsid7:
    case kDifDmaAsid8:
    case kDifDmaAsid9:
    case kDifDmaAsid10:
    case kDifDmaAsid11:
    case kDifDmaAsid12:
    case kDifDmaAsid13:
    case kDifDmaAsid14:
    case kDifDmaAsid15:
      break;
    default:
      return kDifBadArg;
  }
  mmio_region_write32(dma->base_addr,
                      DMA_CLEAR_INTR_ASID_0_REG_OFFSET + (ptrdiff_t)(4 * source),
                      (uint32_t)asid);

  return kDifOk;
}

dif_result_t dif_dma_intr_src_addr(const dif_dma_t *dma, dif_dma_intr_idx_t idx,
                                   uint32_t intr_src_addr) {
  if (dma == NULL) {
    return kDifBadArg;
  }
  mmio_region_write32(dma->base_addr,
                      DMA_INTR_SRC_ADDR_0_REG_OFFSET + (ptrdiff_t)idx,
                      intr_src_addr);
  return kDifOk;
}

dif_result_t dif_dma_intr_write_value(const dif_dma_t *dma,
                                      dif_dma_intr_idx_t idx,
                                      uint32_t intr_src_value) {
  if (dma == NULL) {
    return kDifBadArg;
  }
  mmio_region_write32(dma->base_addr,
                      DMA_INTR_SRC_WR_VAL_0_REG_OFFSET + (ptrdiff_t)idx,
                      intr_src_value);
  return kDifOk;
}
