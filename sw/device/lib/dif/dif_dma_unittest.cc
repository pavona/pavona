// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/dif/dif_dma.h"

#include "gtest/gtest.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/base/mock_mmio.h"
#include "sw/device/lib/dif/dif_test_base.h"

extern "C" {
#include "hw/top/dma_regs.h"  // Generated.
}  // extern "C"

namespace dif_dma_test {
using mock_mmio::MmioTest;
using mock_mmio::MockDevice;
using testing::Test;

// Base class for the rest fixtures in this file.
class DmaTest : public testing::Test, public mock_mmio::MmioTest {};

// Base class for the rest of the tests in this file, provides a
// `dif_dma_t` instance.
class DmaTestInitialized : public DmaTest {
 protected:
  dif_dma_t dma_;

  DmaTestInitialized() { EXPECT_DIF_OK(dif_dma_init(dev().region(), &dma_)); }
};

class ConfigureTest
    : public DmaTestInitialized,
      public testing::WithParamInterface<dif_dma_transaction_t> {};

TEST_P(ConfigureTest, Success) {
  dif_dma_transaction_t transaction = GetParam();
  EXPECT_WRITE32(
      DMA_SRC_ADDR_LO_REG_OFFSET,
      transaction.source.address & std::numeric_limits<uint32_t>::max());
  EXPECT_WRITE32(DMA_SRC_ADDR_HI_REG_OFFSET, transaction.source.address >> 32);
  EXPECT_WRITE32(
      DMA_DST_ADDR_LO_REG_OFFSET,
      transaction.destination.address & std::numeric_limits<uint32_t>::max());
  EXPECT_WRITE32(DMA_DST_ADDR_HI_REG_OFFSET,
                 transaction.destination.address >> 32);

  EXPECT_WRITE32(
      DMA_SRC_CONFIG_REG_OFFSET,
      {
          {DMA_SRC_CONFIG_INCREMENT_BIT, transaction.src_config.increment},
          {DMA_SRC_CONFIG_WRAP_BIT, transaction.src_config.wrap},
      });
  EXPECT_WRITE32(
      DMA_DST_CONFIG_REG_OFFSET,
      {
          {DMA_DST_CONFIG_INCREMENT_BIT, transaction.dst_config.increment},
          {DMA_DST_CONFIG_WRAP_BIT, transaction.dst_config.wrap},
      });

  EXPECT_WRITE32(
      DMA_ADDR_SPACE_ID_REG_OFFSET,
      {
          {DMA_ADDR_SPACE_ID_SRC_ASID_OFFSET, transaction.source.asid},
          {DMA_ADDR_SPACE_ID_DST_ASID_OFFSET, transaction.destination.asid},
      });

  EXPECT_WRITE32(DMA_CHUNK_DATA_SIZE_REG_OFFSET, transaction.chunk_size);
  EXPECT_WRITE32(DMA_TOTAL_DATA_SIZE_REG_OFFSET, transaction.total_size);
  EXPECT_WRITE32(DMA_TRANSFER_WIDTH_REG_OFFSET, transaction.width);

  EXPECT_DIF_OK(dif_dma_configure(&dma_, transaction));
}

INSTANTIATE_TEST_SUITE_P(
    ConfigureTest, ConfigureTest,
    testing::ValuesIn(std::vector<dif_dma_transaction_t>{{
        // Test 0
        {
            .source =
                {
                    .address = 0xB05BA84B,
                    .asid = kDifDmaOpentitanInternalBus,
                },
            .destination =
                {
                    .address = 0x721F400F,
                    .asid = kDifDmaOpentitanInternalBus,
                },
            // Regular memory behavior.
            .src_config =
                {
                    .wrap = 0,
                    .increment = 1,
                },
            // Typical FIFO behavior.
            .dst_config =
                {
                    .wrap = 1,
                    .increment = 0,
                },
            .chunk_size = 0x1,
            .total_size = 0x1,
            .width = kDifDmaTransWidth1Byte,
        },
        // Test 1
        {
            .source =
                {
                    .address = 0x34FCA80BC5C5CA67,
                    .asid = kDifDmaSoCSystemBus,
                },
            .destination =
                {
                    .address = 0xD0CF2C50,
                    .asid = kDifDmaSoCControlRegisterBus,
                },
            // Typical FIFO behavior.
            .src_config =
                {
                    .wrap = 1,
                    .increment = 0,
                },
            // Regular memory behavior.
            .dst_config =
                {
                    .wrap = 0,
                    .increment = 1,
                },
            .chunk_size = 0x2,
            .total_size = 0x2,
            .width = kDifDmaTransWidth2Bytes,
        },
        // Test 2
        {
            .source =
                {
                    .address = 0x05BA857F8D9C0838,
                    .asid = kDifDmaSoCControlRegisterBus,
                },
            .destination =
                {
                    .address = 0x32CD872A12225CCE,
                    .asid = kDifDmaSoCSystemBus,
                },
            // Regular memory behavior.
            .src_config =
                {
                    .wrap = 0,
                    .increment = 1,
                },
            // FIFO occupying a block of addresses.
            .dst_config =
                {
                    .wrap = 1,
                    .increment = 1,
                },
            .chunk_size = 0x4,
            .total_size = 0x4,
            .width = kDifDmaTransWidth4Bytes,
        },
        // Test 3
        {
            .source =
                {
                    .address = 0xBFED148856E0555E,
                    .asid = kDifDmaSoCSystemBus,
                },
            .destination =
                {
                    .address = 0x9ECFA11919F684D7,
                    .asid = kDifDmaOpentitanInternalBus,
                },
            // Regular memory behavior.
            .src_config =
                {
                    .wrap = 0,
                    .increment = 1,
                },
            // Regular memory behavior.
            .dst_config =
                {
                    .wrap = 0,
                    .increment = 1,
                },
            .chunk_size = std::numeric_limits<uint32_t>::max(),
            .total_size = std::numeric_limits<uint32_t>::max(),
            .width = kDifDmaTransWidth4Bytes,
        },
        // Test 4
        {
            .source =
                {
                    .address = 0x05BA857F8D9C0838,
                    .asid = kDifDmaSoCControlRegisterBus,
                },
            .destination =
                {
                    .address = 0x32CD872A12225CCE,
                    .asid = kDifDmaSoCSystemBus,
                },
            // Unusual addressing; FIFO-like but not wrapping.
            .src_config =
                {
                    .wrap = 0,
                    .increment = 0,
                },
            // Typical FIFO behavior.
            .dst_config =
                {
                    .wrap = 1,
                    .increment = 0,
                },
            .chunk_size = 0x4,
            .total_size = 0x4,
            .width = kDifDmaTransWidth4Bytes,
        },
        // Test 5
        {
            .source =
                {
                    .address = 0x05BA857F8D9C0838,
                    .asid = kDifDmaSoCControlRegisterBus,
                },
            .destination =
                {
                    .address = 0x32CD872A12225CCE,
                    .asid = kDifDmaSoCSystemBus,
                },
            // Chunk-based firmware-controlled transfer.
            .src_config =
                {
                    .wrap = 1,
                    .increment = 1,
                },
            // Unusual addressing; FIFO-like but not wrapping.
            .dst_config =
                {
                    .wrap = 0,
                    .increment = 0,
                },
            .chunk_size = 0x4,
            .total_size = 0x4,
            .width = kDifDmaTransWidth4Bytes,
        },
    }}));

TEST_F(ConfigureTest, BadArg) {
  dif_dma_transaction_t transaction;
  EXPECT_DIF_BADARG(dif_dma_configure(nullptr, transaction));
}

// Handshake tests
class HandshakeTest : public DmaTestInitialized {};

TEST_F(HandshakeTest, EnableSuccess) {
  EXPECT_READ32(DMA_CONTROL_REG_OFFSET,
                {
                    {DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true},
                });
  EXPECT_WRITE32(DMA_CONTROL_REG_OFFSET,
                 {
                     {DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true},
                 });

  EXPECT_DIF_OK(dif_dma_handshake_enable(&dma_));
}

TEST_F(HandshakeTest, DisableSuccess) {
  EXPECT_READ32(DMA_CONTROL_REG_OFFSET,
                {
                    {DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true},
                });
  EXPECT_WRITE32(DMA_CONTROL_REG_OFFSET,
                 {
                     {DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, false},
                 });

  EXPECT_DIF_OK(dif_dma_handshake_disable(&dma_));
}

TEST_F(HandshakeTest, EnableBadArg) {
  EXPECT_DIF_BADARG(dif_dma_handshake_enable(nullptr));
}

TEST_F(HandshakeTest, DisableBadArg) {
  EXPECT_DIF_BADARG(dif_dma_handshake_disable(nullptr));
}

// DMA start tests
//
// Each operation selector decodes into the orthogonal CONTROL fields
// (read_en, write_en, digest); the test asserts the exact CONTROL write.
typedef struct start_op {
  dif_dma_transaction_opcode_t opcode;
  bool read_en;
  bool write_en;
  uint32_t digest;
  // Inline-AES CONTROL fields; default to Off/CTR for the non-AES selectors.
  uint32_t aes_op;
  bool aes_gcm;
} start_op_t;

class StartTest : public DmaTestInitialized,
                  public testing::WithParamInterface<start_op_t> {};

TEST_P(StartTest, Success) {
  start_op_t op = GetParam();
  EXPECT_READ32(DMA_CONTROL_REG_OFFSET,
                {{DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true}});
  EXPECT_WRITE32(DMA_CONTROL_REG_OFFSET,
                 {
                     {DMA_CONTROL_READ_EN_BIT, op.read_en},
                     {DMA_CONTROL_WRITE_EN_BIT, op.write_en},
                     {DMA_CONTROL_DIGEST_OFFSET, op.digest},
                     {DMA_CONTROL_AES_OP_OFFSET, op.aes_op},
                     {DMA_CONTROL_AES_MODE_BIT, op.aes_gcm},
                     {DMA_CONTROL_INITIAL_TRANSFER_BIT, true},
                     {DMA_CONTROL_GO_BIT, true},
                     {DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true},
                 });

  EXPECT_DIF_OK(dif_dma_start(&dma_, op.opcode));
}

INSTANTIATE_TEST_SUITE_P(
    StartTest, StartTest,
    testing::ValuesIn(std::vector<start_op_t>{{
        // Legacy copy/hash selectors map to (read_en=1, write_en=1, digest).
        {kDifDmaCopyOpcode, true, true, DMA_CONTROL_DIGEST_VALUE_NONE},
        {kDifDmaSha256Opcode, true, true, DMA_CONTROL_DIGEST_VALUE_SHA256},
        {kDifDmaSha384Opcode, true, true, DMA_CONTROL_DIGEST_VALUE_SHA384},
        {kDifDmaSha512Opcode, true, true, DMA_CONTROL_DIGEST_VALUE_SHA512},
        // Memset: write only, fill pattern from SRC_ADDR_LO.
        {kDifDmaMemsetOpcode, false, true, DMA_CONTROL_DIGEST_VALUE_NONE},
        // Verify: read only, digest over source data.
        {kDifDmaVerifySha256Opcode, true, false, DMA_CONTROL_DIGEST_VALUE_SHA256},
        {kDifDmaVerifySha384Opcode, true, false, DMA_CONTROL_DIGEST_VALUE_SHA384},
        {kDifDmaVerifySha512Opcode, true, false, DMA_CONTROL_DIGEST_VALUE_SHA512},
        // Inline AES: copy with CONTROL.aes_op/aes_mode set.
        {kDifDmaAesCtrEncOpcode, true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
         DMA_CONTROL_AES_OP_VALUE_ENC, false},
        {kDifDmaAesCtrDecOpcode, true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
         DMA_CONTROL_AES_OP_VALUE_DEC, false},
        {kDifDmaAesGcmEncOpcode, true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
         DMA_CONTROL_AES_OP_VALUE_ENC, true},
        {kDifDmaAesGcmDecOpcode, true, true, DMA_CONTROL_DIGEST_VALUE_NONE,
         DMA_CONTROL_AES_OP_VALUE_DEC, true},
    }}));

TEST_F(StartTest, BadArg) {
  EXPECT_DIF_BADARG(dif_dma_start(nullptr, kDifDmaCopyOpcode));
}

// DMA memory range tests
class MemoryRangeTests : public DmaTestInitialized {};

TEST_F(MemoryRangeTests, SetSuccess) {
  enum { kStartAddr = 0xD0CF2C50, kEndAddr = 0xD1CF2C0F };
  EXPECT_WRITE32(DMA_ENABLED_MEMORY_RANGE_BASE_REG_OFFSET, kStartAddr);
  EXPECT_WRITE32(DMA_ENABLED_MEMORY_RANGE_LIMIT_REG_OFFSET, kEndAddr);
  EXPECT_WRITE32(DMA_RANGE_VALID_REG_OFFSET, 1);

  EXPECT_DIF_OK(
      dif_dma_memory_range_set(&dma_, kStartAddr, kEndAddr - kStartAddr + 1));
}

TEST_F(MemoryRangeTests, GetSuccess) {
  enum { kAddress = 0x721F400F, kSize = 0xF0000 };
  EXPECT_READ32(DMA_ENABLED_MEMORY_RANGE_BASE_REG_OFFSET, kAddress);
  EXPECT_READ32(DMA_ENABLED_MEMORY_RANGE_LIMIT_REG_OFFSET,
                kAddress + kSize - 1);

  uint32_t address = 0;
  size_t size = 0;
  EXPECT_DIF_OK(dif_dma_memory_range_get(&dma_, &address, &size));
  EXPECT_EQ(address, kAddress);
  EXPECT_EQ(size, kSize);
}

TEST_F(MemoryRangeTests, GetBadArg) {
  uint32_t address = 0;
  size_t size = 0;
  EXPECT_DIF_BADARG(dif_dma_memory_range_get(nullptr, &address, &size));
  EXPECT_DIF_BADARG(dif_dma_memory_range_get(&dma_, NULL, &size));
  EXPECT_DIF_BADARG(dif_dma_memory_range_get(&dma_, &address, NULL));
}

// DMA abort tests
class AbortTest : public DmaTestInitialized {};

TEST_F(AbortTest, Success) {
  EXPECT_READ32(DMA_CONTROL_REG_OFFSET,
                {{DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true}});
  EXPECT_WRITE32(DMA_CONTROL_REG_OFFSET,
                 {
                     {DMA_CONTROL_HARDWARE_HANDSHAKE_ENABLE_BIT, true},
                     {DMA_CONTROL_ABORT_BIT, true},
                 });

  EXPECT_DIF_OK(dif_dma_abort(&dma_));
}

TEST_F(AbortTest, BadArg) { EXPECT_DIF_BADARG(dif_dma_abort(nullptr)); }

// DMA Memory range lock tests
class MemoryRangeLockTest : public DmaTestInitialized {};

TEST_F(MemoryRangeLockTest, SetSuccess) {
  EXPECT_WRITE32(DMA_RANGE_REGWEN_REG_OFFSET, kMultiBitBool4False);

  EXPECT_DIF_OK(dif_dma_memory_range_lock(&dma_));
}

TEST_F(MemoryRangeLockTest, GetLocked) {
  bool locked = false;
  EXPECT_READ32(DMA_RANGE_REGWEN_REG_OFFSET, kMultiBitBool4False);

  EXPECT_DIF_OK(dif_dma_is_memory_range_locked(&dma_, &locked));
  EXPECT_TRUE(locked);
}

TEST_F(MemoryRangeLockTest, SetBadArg) {
  EXPECT_DIF_BADARG(dif_dma_memory_range_lock(nullptr));
}

TEST_F(MemoryRangeLockTest, GetBadArg) {
  bool dummy;
  EXPECT_DIF_BADARG(dif_dma_is_memory_range_locked(nullptr, &dummy));
  EXPECT_DIF_BADARG(dif_dma_is_memory_range_locked(&dma_, nullptr));
}

// DMA status tests
typedef struct status_reg {
  uint32_t reg;
  dif_dma_status_t status;
} status_reg_t;
class StatusGetTest : public DmaTestInitialized,
                      public testing::WithParamInterface<status_reg_t> {};

TEST_P(StatusGetTest, GetSuccess) {
  status_reg_t status_arg = GetParam();

  EXPECT_READ32(DMA_STATUS_REG_OFFSET, status_arg.reg);

  dif_dma_status_t status;

  EXPECT_DIF_OK(dif_dma_status_get(&dma_, &status));
  EXPECT_EQ(status, status_arg.status);
}

INSTANTIATE_TEST_SUITE_P(
    StatusGetTest, StatusGetTest,
    testing::ValuesIn(std::vector<status_reg_t>{{
        {1 << DMA_STATUS_BUSY_BIT, kDifDmaStatusBusy},
        {1 << DMA_STATUS_DONE_BIT, kDifDmaStatusDone},
        {1 << DMA_STATUS_ABORTED_BIT, kDifDmaStatusAborted},
        {1 << DMA_STATUS_ERROR_BIT, kDifDmaStatusError},
        {1 << DMA_STATUS_SHA2_DIGEST_VALID_BIT, kDifDmaStatusSha2DigestValid},
        {1 << DMA_STATUS_CHUNK_DONE_BIT, kDifDmaStatusChunkDone},
    }}));

TEST_F(StatusGetTest, GetBadArg) {
  dif_dma_status_t dummy;
  EXPECT_DIF_BADARG(dif_dma_status_get(nullptr, &dummy));
  EXPECT_DIF_BADARG(dif_dma_status_get(&dma_, nullptr));
}

class StatusWriteTest : public DmaTestInitialized,
                        public testing::WithParamInterface<status_reg_t> {};

TEST_P(StatusWriteTest, SetSuccess) {
  status_reg_t status_arg = GetParam();

  EXPECT_WRITE32(DMA_STATUS_REG_OFFSET, status_arg.reg);

  EXPECT_DIF_OK(dif_dma_status_write(&dma_, status_arg.status));
}

INSTANTIATE_TEST_SUITE_P(
    StatusWriteTest, StatusWriteTest,
    testing::ValuesIn(std::vector<status_reg_t>{{
        {1 << DMA_STATUS_DONE_BIT, kDifDmaStatusDone},
        {1 << DMA_STATUS_ABORTED_BIT, kDifDmaStatusAborted},
        {1 << DMA_STATUS_ERROR_BIT, kDifDmaStatusError},
        {1 << DMA_STATUS_SHA2_DIGEST_VALID_BIT, kDifDmaStatusSha2DigestValid},
        {1 << DMA_STATUS_CHUNK_DONE_BIT, kDifDmaStatusChunkDone},
    }}));

TEST_F(StatusWriteTest, GetBadArg) {
  dif_dma_status_t dummy = kDifDmaStatusDone;
  EXPECT_DIF_BADARG(dif_dma_status_write(nullptr, dummy));
}

class StatusClearTest : public DmaTestInitialized {};

TEST_F(StatusClearTest, SetSuccess) {
  EXPECT_WRITE32(DMA_STATUS_REG_OFFSET,
                 1 << DMA_STATUS_DONE_BIT | 1 << DMA_STATUS_ABORTED_BIT |
                     1 << DMA_STATUS_ERROR_BIT |
                     1 << DMA_STATUS_CHUNK_DONE_BIT);

  EXPECT_DIF_OK(dif_dma_status_clear(&dma_));
}

TEST_F(StatusClearTest, GetBadArg) {
  EXPECT_DIF_BADARG(dif_dma_status_clear(nullptr));
}
typedef struct error_code_reg {
  uint32_t reg;
  dif_dma_error_code_t error_code;
} error_code_reg_t;
class ErrorTest : public DmaTestInitialized,
                  public testing::WithParamInterface<error_code_reg_t> {};

TEST_P(ErrorTest, GetSuccess) {
  error_code_reg_t error_code_arg = GetParam();

  EXPECT_READ32(DMA_ERROR_CODE_REG_OFFSET, error_code_arg.reg);

  dif_dma_error_code error_code;

  EXPECT_DIF_OK(dif_dma_error_code_get(&dma_, &error_code));
  EXPECT_EQ(error_code, error_code_arg.error_code);
}

INSTANTIATE_TEST_SUITE_P(
    ErrorTest, ErrorTest,
    testing::ValuesIn(std::vector<error_code_reg_t>{{
        {1 << DMA_ERROR_CODE_SRC_ADDR_ERROR_BIT, kDifDmaErrorSourceAddress},
        {1 << DMA_ERROR_CODE_DST_ADDR_ERROR_BIT,
         kDifDmaErrorDestinationAddress},
        {1 << DMA_ERROR_CODE_OPCODE_ERROR_BIT, kDifDmaErrorOpcode},
        {1 << DMA_ERROR_CODE_SIZE_ERROR_BIT, kDifDmaErrorSize},
        {1 << DMA_ERROR_CODE_BUS_ERROR_BIT, kDifDmaErrorBus},
        {1 << DMA_ERROR_CODE_BASE_LIMIT_ERROR_BIT,
         kDifDmaErrorEnableMemoryConfig},
        {1 << DMA_ERROR_CODE_RANGE_VALID_ERROR_BIT, kDifDmaErrorRangeValid},
        {1 << DMA_ERROR_CODE_ASID_ERROR_BIT, kDifDmaErrorInvalidAsid},
    }}));

TEST_F(ErrorTest, GetErrorBadArg) {
  dif_dma_error_code_t dummy;
  EXPECT_DIF_BADARG(dif_dma_error_code_get(nullptr, &dummy));
  EXPECT_DIF_BADARG(dif_dma_error_code_get(&dma_, nullptr));
}

typedef struct status_poll_reg {
  uint32_t reg;
  dif_dma_status_code_t status;
} status_poll_reg_t;

class StatusPollTest : public DmaTestInitialized,
                       public testing::WithParamInterface<status_poll_reg_t> {};

TEST_P(StatusPollTest, GetSuccess) {
  status_poll_reg_t status_arg = GetParam();

  EXPECT_READ32(DMA_STATUS_REG_OFFSET, 0);
  EXPECT_READ32(DMA_STATUS_REG_OFFSET, 0);
  EXPECT_READ32(DMA_STATUS_REG_OFFSET, 0);
  EXPECT_READ32(DMA_STATUS_REG_OFFSET, status_arg.reg);

  EXPECT_DIF_OK(dif_dma_status_poll(&dma_, status_arg.status));
}

INSTANTIATE_TEST_SUITE_P(
    StatusPollTest, StatusPollTest,
    testing::ValuesIn(std::vector<status_poll_reg_t>{{
        {1 << DMA_STATUS_BUSY_BIT, kDifDmaStatusBusy},
        {1 << DMA_STATUS_DONE_BIT, kDifDmaStatusDone},
        {1 << DMA_STATUS_ABORTED_BIT, kDifDmaStatusAborted},
        {1 << DMA_STATUS_ERROR_BIT, kDifDmaStatusError},
        {1 << DMA_STATUS_SHA2_DIGEST_VALID_BIT, kDifDmaStatusSha2DigestValid},
    }}));

TEST_F(StatusPollTest, BadArg) {
  EXPECT_DIF_BADARG(dif_dma_status_poll(nullptr, kDifDmaStatusDone));
}

class GetDigestLenTest : public DmaTestInitialized {};

TEST_F(GetDigestLenTest, Success) {
  uint32_t digest_len;
  EXPECT_DIF_OK(dif_dma_get_digest_length(kDifDmaSha256Opcode, &digest_len));
  EXPECT_EQ(digest_len, 8);

  EXPECT_DIF_OK(dif_dma_get_digest_length(kDifDmaSha384Opcode, &digest_len));
  EXPECT_EQ(digest_len, 12);

  EXPECT_DIF_OK(dif_dma_get_digest_length(kDifDmaSha512Opcode, &digest_len));
  EXPECT_EQ(digest_len, 16);

  // Verify operations carry the same digest as their hash counterparts.
  EXPECT_DIF_OK(
      dif_dma_get_digest_length(kDifDmaVerifySha256Opcode, &digest_len));
  EXPECT_EQ(digest_len, 8);

  EXPECT_DIF_OK(
      dif_dma_get_digest_length(kDifDmaVerifySha384Opcode, &digest_len));
  EXPECT_EQ(digest_len, 12);

  EXPECT_DIF_OK(
      dif_dma_get_digest_length(kDifDmaVerifySha512Opcode, &digest_len));
  EXPECT_EQ(digest_len, 16);
}

TEST_F(GetDigestLenTest, BadArg) {
  uint32_t digest_len;
  EXPECT_DIF_BADARG(dif_dma_get_digest_length(kDifDmaSha256Opcode, nullptr));
  // Operations without a digest report no length.
  EXPECT_DIF_BADARG(dif_dma_get_digest_length(kDifDmaCopyOpcode, &digest_len));
  EXPECT_DIF_BADARG(dif_dma_get_digest_length(kDifDmaMemsetOpcode, &digest_len));
}

typedef struct digest_reg {
  dif_dma_transaction_opcode_t opcode;
  uint32_t num_digest_regs;
} digest_reg_t;

class GetDigestTest : public DmaTestInitialized,
                      public testing::WithParamInterface<digest_reg_t> {};

TEST_P(GetDigestTest, GetSuccess) {
  digest_reg_t digest_arg = GetParam();
  uint32_t digest[16] = {0};

  for (uint32_t i = 0; i < digest_arg.num_digest_regs; ++i) {
    EXPECT_READ32(DMA_SHA2_DIGEST_0_REG_OFFSET +
                      (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
                  i * 1024 + i);
  }

  EXPECT_DIF_OK(dif_dma_sha2_digest_get(&dma_, digest_arg.opcode, digest));

  for (uint32_t i = 0; i < 16; ++i) {
    if (i < digest_arg.num_digest_regs) {
      EXPECT_EQ(digest[i], i * 1024 + i);
    } else {
      EXPECT_EQ(digest[i], 0);
    }
  }
}

INSTANTIATE_TEST_SUITE_P(GetDigestTest, GetDigestTest,
                         testing::ValuesIn(std::vector<digest_reg_t>{{
                             {kDifDmaSha256Opcode, 8},
                             {kDifDmaSha384Opcode, 12},
                             {kDifDmaSha512Opcode, 16},
                         }}));

TEST_F(GetDigestTest, BadArg) {
  uint32_t digest[16];
  EXPECT_DIF_BADARG(
      dif_dma_sha2_digest_get(nullptr, kDifDmaSha256Opcode, digest));
  EXPECT_DIF_BADARG(
      dif_dma_sha2_digest_get(&dma_, kDifDmaSha256Opcode, nullptr));
  EXPECT_DIF_BADARG(dif_dma_sha2_digest_get(&dma_, kDifDmaCopyOpcode, digest));
}

// DMA handshake irq enable tests
class HandshakeEnableIrqTest : public DmaTestInitialized {};

TEST_F(HandshakeEnableIrqTest, Success) {
  EXPECT_WRITE32(DMA_HANDSHAKE_INTR_ENABLE_REG_OFFSET, 0x3);

  EXPECT_DIF_OK(dif_dma_handshake_irq_enable(&dma_, 0x3));
}

TEST_F(HandshakeEnableIrqTest, BadArg) {
  EXPECT_DIF_BADARG(dif_dma_handshake_irq_enable(nullptr, 0x3));
}

// DMA handshake irq clear tests
class HandshakeClearIrqTest : public DmaTestInitialized {};

TEST_F(HandshakeClearIrqTest, Success) {
  EXPECT_WRITE32(DMA_CLEAR_INTR_SRC_REG_OFFSET, 0x3);

  EXPECT_DIF_OK(dif_dma_handshake_clear_irq(&dma_, 0x3));
}

TEST_F(HandshakeClearIrqTest, BadArg) {
  EXPECT_DIF_BADARG(dif_dma_handshake_clear_irq(nullptr, 0x3));
}

// DMA handshake irq clear bus tests
class HandshakeClearBusTest : public DmaTestInitialized {};

TEST_F(HandshakeClearBusTest, Success) {
  EXPECT_WRITE32(DMA_CLEAR_INTR_ASID_0_REG_OFFSET + 8, kDifDmaAsid15);
  EXPECT_DIF_OK(dif_dma_handshake_clear_irq_asid(&dma_, 2, kDifDmaAsid15));
}

TEST_F(HandshakeClearBusTest, BadArg) {
  EXPECT_DIF_BADARG(dif_dma_handshake_clear_irq_asid(nullptr, 2, kDifDmaAsid0));
  EXPECT_DIF_BADARG(dif_dma_handshake_clear_irq_asid(
      &dma_, DMA_PARAM_NUM_INT_CLEAR_SOURCES, kDifDmaAsid0));
  EXPECT_DIF_BADARG(dif_dma_handshake_clear_irq_asid(
      &dma_, 0, static_cast<dif_dma_address_space_id_t>(0)));
  EXPECT_DIF_BADARG(dif_dma_handshake_clear_irq_asid(
      &dma_, 0, static_cast<dif_dma_address_space_id_t>(0xff)));
}

TEST_F(HandshakeClearBusTest, AllEncodingsAndSources) {
  constexpr dif_dma_address_space_id_t ids[] = {
      kDifDmaAsid0, kDifDmaAsid1, kDifDmaAsid2, kDifDmaAsid3,
      kDifDmaAsid4, kDifDmaAsid5, kDifDmaAsid6, kDifDmaAsid7,
      kDifDmaAsid8, kDifDmaAsid9, kDifDmaAsid10, kDifDmaAsid11,
      kDifDmaAsid12, kDifDmaAsid13, kDifDmaAsid14, kDifDmaAsid15};
  for (uint32_t source = 0; source < DMA_PARAM_NUM_INT_CLEAR_SOURCES; ++source) {
    for (uint32_t value = 0; value < 256; ++value) {
      bool valid = false;
      for (auto id : ids) valid |= value == static_cast<uint32_t>(id);
      auto asid = static_cast<dif_dma_address_space_id_t>(value);
      if (valid) {
        EXPECT_WRITE32(DMA_CLEAR_INTR_ASID_0_REG_OFFSET + 4 * source, value);
        EXPECT_DIF_OK(dif_dma_handshake_clear_irq_asid(&dma_, source, asid));
      } else {
        EXPECT_DIF_BADARG(dif_dma_handshake_clear_irq_asid(&dma_, source, asid));
      }
    }
  }
}

typedef struct dma_clear_irq_reg {
  uint32_t reg;
  dif_dma_intr_idx_t idx;
} dma_clear_irq_reg_t;

class HandshakeClearAddressTest
    : public DmaTestInitialized,
      public testing::WithParamInterface<dma_clear_irq_reg_t> {};

TEST_P(HandshakeClearAddressTest, GetSuccess) {
  dma_clear_irq_reg_t clear_irq_reg = GetParam();

  EXPECT_WRITE32(clear_irq_reg.reg, 0x123456);

  EXPECT_DIF_OK(dif_dma_intr_src_addr(&dma_, clear_irq_reg.idx, 0x123456));
}

INSTANTIATE_TEST_SUITE_P(
    HandshakeClearAddressTest, HandshakeClearAddressTest,
    testing::ValuesIn(std::vector<dma_clear_irq_reg_t>{{
        {DMA_INTR_SRC_ADDR_0_REG_OFFSET, kDifDmaIntrClearIdx0},
        {DMA_INTR_SRC_ADDR_1_REG_OFFSET, kDifDmaIntrClearIdx1},
        {DMA_INTR_SRC_ADDR_2_REG_OFFSET, kDifDmaIntrClearIdx2},
        {DMA_INTR_SRC_ADDR_3_REG_OFFSET, kDifDmaIntrClearIdx3},
        {DMA_INTR_SRC_ADDR_4_REG_OFFSET, kDifDmaIntrClearIdx4},
        {DMA_INTR_SRC_ADDR_5_REG_OFFSET, kDifDmaIntrClearIdx5},
        {DMA_INTR_SRC_ADDR_6_REG_OFFSET, kDifDmaIntrClearIdx6},
        {DMA_INTR_SRC_ADDR_7_REG_OFFSET, kDifDmaIntrClearIdx7},
        {DMA_INTR_SRC_ADDR_8_REG_OFFSET, kDifDmaIntrClearIdx8},
        {DMA_INTR_SRC_ADDR_9_REG_OFFSET, kDifDmaIntrClearIdx9},
        {DMA_INTR_SRC_ADDR_10_REG_OFFSET, kDifDmaIntrClearIdx10},
    }}));

TEST_F(HandshakeClearAddressTest, BadArg) {
  EXPECT_DIF_BADARG(
      dif_dma_intr_src_addr(nullptr, kDifDmaIntrClearIdx0, 0x12345));
}

class HandshakeClearValueTest
    : public DmaTestInitialized,
      public testing::WithParamInterface<dma_clear_irq_reg_t> {};

TEST_P(HandshakeClearValueTest, GetSuccess) {
  dma_clear_irq_reg_t clear_irq_reg = GetParam();

  EXPECT_WRITE32(clear_irq_reg.reg, 0x123456);

  EXPECT_DIF_OK(dif_dma_intr_write_value(&dma_, clear_irq_reg.idx, 0x123456));
}

INSTANTIATE_TEST_SUITE_P(
    HandshakeClearValueTest, HandshakeClearValueTest,
    testing::ValuesIn(std::vector<dma_clear_irq_reg_t>{{
        {DMA_INTR_SRC_WR_VAL_0_REG_OFFSET, kDifDmaIntrClearIdx0},
        {DMA_INTR_SRC_WR_VAL_1_REG_OFFSET, kDifDmaIntrClearIdx1},
        {DMA_INTR_SRC_WR_VAL_2_REG_OFFSET, kDifDmaIntrClearIdx2},
        {DMA_INTR_SRC_WR_VAL_3_REG_OFFSET, kDifDmaIntrClearIdx3},
        {DMA_INTR_SRC_WR_VAL_4_REG_OFFSET, kDifDmaIntrClearIdx4},
        {DMA_INTR_SRC_WR_VAL_5_REG_OFFSET, kDifDmaIntrClearIdx5},
        {DMA_INTR_SRC_WR_VAL_6_REG_OFFSET, kDifDmaIntrClearIdx6},
        {DMA_INTR_SRC_WR_VAL_7_REG_OFFSET, kDifDmaIntrClearIdx7},
        {DMA_INTR_SRC_WR_VAL_8_REG_OFFSET, kDifDmaIntrClearIdx8},
        {DMA_INTR_SRC_WR_VAL_9_REG_OFFSET, kDifDmaIntrClearIdx9},
        {DMA_INTR_SRC_WR_VAL_10_REG_OFFSET, kDifDmaIntrClearIdx10},
    }}));

TEST_F(HandshakeClearValueTest, BadArg) {
  EXPECT_DIF_BADARG(
      dif_dma_intr_write_value(nullptr, kDifDmaIntrClearIdx0, 0x4567));
}

// DMA inline-AES tests

class AesConfigureTest : public DmaTestInitialized {};

TEST_F(AesConfigureTest, Success) {
  dif_dma_aes_config_t config = {kDifDmaAesKey192, true, kDifDmaAesReseedPer64,
                                 3};
  EXPECT_WRITE32(
      DMA_AES_CTRL_REG_OFFSET,
      {
          {DMA_AES_CTRL_KEY_LEN_OFFSET, DMA_AES_CTRL_KEY_LEN_VALUE_AES_192},
          {DMA_AES_CTRL_SIDELOAD_BIT, true},
          {DMA_AES_CTRL_PRNG_RESEED_RATE_OFFSET,
           DMA_AES_CTRL_PRNG_RESEED_RATE_VALUE_PER_64},
          {DMA_AES_CTRL_AAD_BLOCKS_OFFSET, 3},
      });
  EXPECT_DIF_OK(dif_dma_aes_configure(&dma_, config));
}

TEST_F(AesConfigureTest, BadArg) {
  dif_dma_aes_config_t config = {kDifDmaAesKey128, false, kDifDmaAesReseedPer1,
                                 0};
  EXPECT_DIF_BADARG(dif_dma_aes_configure(nullptr, config));
}

class AesKeyTest : public DmaTestInitialized {};

TEST_F(AesKeyTest, Success) {
  uint32_t share0[8];
  uint32_t share1[8];
  for (uint32_t i = 0; i < 8; ++i) {
    share0[i] = 0xa0000000 + i;
    share1[i] = 0xb0000000 + i;
  }
  // The DIF writes the two shares interleaved per index (share0[i], share1[i]).
  for (uint32_t i = 0; i < DMA_KEY_SHARE0_MULTIREG_COUNT; ++i) {
    EXPECT_WRITE32(DMA_KEY_SHARE0_0_REG_OFFSET +
                       (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
                   share0[i]);
    EXPECT_WRITE32(DMA_KEY_SHARE1_0_REG_OFFSET +
                       (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
                   share1[i]);
  }
  EXPECT_DIF_OK(dif_dma_aes_key_set(&dma_, share0, share1));
}

TEST_F(AesKeyTest, BadArg) {
  uint32_t key[8] = {0};
  EXPECT_DIF_BADARG(dif_dma_aes_key_set(nullptr, key, key));
  EXPECT_DIF_BADARG(dif_dma_aes_key_set(&dma_, nullptr, key));
  EXPECT_DIF_BADARG(dif_dma_aes_key_set(&dma_, key, nullptr));
}

class AesIvTest : public DmaTestInitialized {};

TEST_F(AesIvTest, Success) {
  uint32_t iv[4] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};
  for (uint32_t i = 0; i < DMA_IV_MULTIREG_COUNT; ++i) {
    EXPECT_WRITE32(
        DMA_IV_0_REG_OFFSET + (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
        iv[i]);
  }
  EXPECT_DIF_OK(dif_dma_aes_iv_set(&dma_, iv));
}

TEST_F(AesIvTest, BadArg) {
  uint32_t iv[4] = {0};
  EXPECT_DIF_BADARG(dif_dma_aes_iv_set(nullptr, iv));
  EXPECT_DIF_BADARG(dif_dma_aes_iv_set(&dma_, nullptr));
}

class AesAadTest : public DmaTestInitialized {};

TEST_F(AesAadTest, Success) {
  uint32_t aad[4] = {0xaaaa0000, 0xaaaa0001, 0xaaaa0002, 0xaaaa0003};
  for (uint32_t i = 0; i < 4; ++i) {
    EXPECT_WRITE32(
        DMA_AAD_0_REG_OFFSET + (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
        aad[i]);
  }
  EXPECT_DIF_OK(dif_dma_aes_aad_set(&dma_, aad, 4));
}

TEST_F(AesAadTest, BadArg) {
  uint32_t aad[4] = {0};
  EXPECT_DIF_BADARG(dif_dma_aes_aad_set(nullptr, aad, 4));
  EXPECT_DIF_BADARG(dif_dma_aes_aad_set(&dma_, nullptr, 4));
  EXPECT_DIF_BADARG(
      dif_dma_aes_aad_set(&dma_, aad, DMA_AAD_MULTIREG_COUNT + 1));
}

class AesTagInTest : public DmaTestInitialized {};

TEST_F(AesTagInTest, Success) {
  uint32_t tag[4] = {0x7a900000, 0x7a900001, 0x7a900002, 0x7a900003};
  for (uint32_t i = 0; i < DMA_TAG_IN_MULTIREG_COUNT; ++i) {
    EXPECT_WRITE32(
        DMA_TAG_IN_0_REG_OFFSET + (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
        tag[i]);
  }
  EXPECT_DIF_OK(dif_dma_aes_tag_in_set(&dma_, tag));
}

TEST_F(AesTagInTest, BadArg) {
  uint32_t tag[4] = {0};
  EXPECT_DIF_BADARG(dif_dma_aes_tag_in_set(nullptr, tag));
  EXPECT_DIF_BADARG(dif_dma_aes_tag_in_set(&dma_, nullptr));
}

class AesTagOutTest : public DmaTestInitialized {};

TEST_F(AesTagOutTest, Success) {
  uint32_t tag[4] = {0};
  for (uint32_t i = 0; i < DMA_TAG_OUT_MULTIREG_COUNT; ++i) {
    EXPECT_READ32(
        DMA_TAG_OUT_0_REG_OFFSET + (ptrdiff_t)i * (ptrdiff_t)sizeof(uint32_t),
        0xc0de0000 + i);
  }
  EXPECT_DIF_OK(dif_dma_aes_tag_out_get(&dma_, tag));
  for (uint32_t i = 0; i < 4; ++i) {
    EXPECT_EQ(tag[i], 0xc0de0000 + i);
  }
}

TEST_F(AesTagOutTest, BadArg) {
  uint32_t tag[4];
  EXPECT_DIF_BADARG(dif_dma_aes_tag_out_get(nullptr, tag));
  EXPECT_DIF_BADARG(dif_dma_aes_tag_out_get(&dma_, nullptr));
}

class AesTagStatusTest : public DmaTestInitialized {};

TEST_F(AesTagStatusTest, ValidSet) {
  EXPECT_READ32(DMA_STATUS_REG_OFFSET, {{DMA_STATUS_TAG_VALID_BIT, true}});
  bool valid = false;
  bool failed = true;
  EXPECT_DIF_OK(dif_dma_aes_tag_status_get(&dma_, &valid, &failed));
  EXPECT_TRUE(valid);
  EXPECT_FALSE(failed);
}

TEST_F(AesTagStatusTest, FailedSet) {
  EXPECT_READ32(DMA_STATUS_REG_OFFSET, {{DMA_STATUS_TAG_FAILED_BIT, true}});
  bool valid = true;
  bool failed = false;
  EXPECT_DIF_OK(dif_dma_aes_tag_status_get(&dma_, &valid, &failed));
  EXPECT_FALSE(valid);
  EXPECT_TRUE(failed);
}

TEST_F(AesTagStatusTest, BadArg) {
  bool valid;
  bool failed;
  EXPECT_DIF_BADARG(dif_dma_aes_tag_status_get(nullptr, &valid, &failed));
  EXPECT_DIF_BADARG(dif_dma_aes_tag_status_get(&dma_, nullptr, &failed));
  EXPECT_DIF_BADARG(dif_dma_aes_tag_status_get(&dma_, &valid, nullptr));
}

}  // namespace dif_dma_test
