// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/dif/dif_acc.h"

#include "gtest/gtest.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/base/mock_mmio.h"
#include "sw/device/lib/dif/dif_base.h"
#include "sw/device/lib/dif/dif_test_base.h"

#include "hw/top/acc_regs.h"  // Generated.

namespace dif_acc_unittest {
namespace {
using mock_mmio::MmioTest;
using mock_mmio::MockDevice;
using testing::Each;
using testing::Eq;
using testing::Test;

class AccTest : public Test, public MmioTest {
 protected:
  void ExpectDeviceReset() {
    EXPECT_WRITE32(ACC_INTR_ENABLE_REG_OFFSET, 0);
    EXPECT_WRITE32(ACC_INTR_STATE_REG_OFFSET,
                   std::numeric_limits<uint32_t>::max());
  }

  dif_acc_t dif_acc_ = {.base_addr = dev().region()};
};

class ResetTest : public AccTest {};

TEST_F(ResetTest, NullArgs) { EXPECT_DIF_BADARG(dif_acc_reset(nullptr)); }

TEST_F(ResetTest, Default) {
  ExpectDeviceReset();

  EXPECT_DIF_OK(dif_acc_reset(&dif_acc_));
}

class WriteCmdTest : public AccTest {};

TEST_F(WriteCmdTest, NullArgs) {
  EXPECT_DIF_BADARG(dif_acc_write_cmd(nullptr, kDifAccCmdExecute));
}

TEST_F(WriteCmdTest, Success) {
  // Set EXECUTE command.
  EXPECT_WRITE32(ACC_CMD_REG_OFFSET, kDifAccCmdExecute);

  EXPECT_DIF_OK(dif_acc_write_cmd(&dif_acc_, kDifAccCmdExecute));
}

class GetStatusTest : public AccTest {};

TEST_F(GetStatusTest, NullArgs) {
  EXPECT_DIF_BADARG(dif_acc_get_status(nullptr, nullptr));

  EXPECT_DIF_BADARG(dif_acc_get_status(&dif_acc_, nullptr));

  dif_acc_status_t status = kDifAccStatusBusySecWipeDmem;
  EXPECT_DIF_BADARG(dif_acc_get_status(nullptr, &status));
  EXPECT_EQ(status, kDifAccStatusBusySecWipeDmem);
}

TEST_F(GetStatusTest, Success) {
  EXPECT_READ32(ACC_STATUS_REG_OFFSET, kDifAccStatusBusyExecute);

  dif_acc_status_t status;
  EXPECT_DIF_OK(dif_acc_get_status(&dif_acc_, &status));
  EXPECT_EQ(status, kDifAccStatusBusyExecute);
}

class GetErrBitsTest : public AccTest {};

TEST_F(GetErrBitsTest, NullArgs) {
  EXPECT_DIF_BADARG(dif_acc_get_err_bits(nullptr, nullptr));

  EXPECT_DIF_BADARG(dif_acc_get_err_bits(&dif_acc_, nullptr));

  dif_acc_err_bits_t err_bits = kDifAccErrBitsBadDataAddr;
  EXPECT_DIF_BADARG(dif_acc_get_err_bits(nullptr, &err_bits));
  EXPECT_EQ(err_bits, kDifAccErrBitsBadDataAddr);
}

TEST_F(GetErrBitsTest, Success) {
  EXPECT_READ32(ACC_ERR_BITS_REG_OFFSET,
                kDifAccErrBitsIllegalInsn | kDifAccErrBitsRegIntgViolation);

  dif_acc_err_bits_t err_bits;
  EXPECT_DIF_OK(dif_acc_get_err_bits(&dif_acc_, &err_bits));
  EXPECT_EQ(err_bits,
            kDifAccErrBitsIllegalInsn | kDifAccErrBitsRegIntgViolation);
}

class GetInsnCntTest : public AccTest {};

TEST_F(GetInsnCntTest, NullArgs) {
  EXPECT_DIF_BADARG(dif_acc_get_insn_cnt(nullptr, nullptr));

  EXPECT_DIF_BADARG(dif_acc_get_insn_cnt(&dif_acc_, nullptr));

  uint32_t insn_cnt = 55;
  EXPECT_DIF_BADARG(dif_acc_get_insn_cnt(nullptr, &insn_cnt));
  EXPECT_EQ(insn_cnt, 55);
}

TEST_F(GetInsnCntTest, Success) {
  EXPECT_READ32(ACC_INSN_CNT_REG_OFFSET, 55);

  uint32_t insn_cnt;
  EXPECT_DIF_OK(dif_acc_get_insn_cnt(&dif_acc_, &insn_cnt));
  EXPECT_EQ(insn_cnt, 55);
}

class ImemWriteTest : public AccTest {};

TEST_F(ImemWriteTest, NullArgs) {
  uint32_t test_data[] = {0};

  EXPECT_DIF_BADARG(dif_acc_imem_write(nullptr, 0, nullptr, 4));

  EXPECT_DIF_BADARG(dif_acc_imem_write(nullptr, 0, test_data, 4));

  EXPECT_DIF_BADARG(dif_acc_imem_write(&dif_acc_, 0, nullptr, 4));
}

TEST_F(ImemWriteTest, BadLenBytes) {
  uint32_t test_data[] = {0};

  // `len_bytes` must be a multiple of 4 bytes.
  EXPECT_DIF_BADARG(dif_acc_imem_write(&dif_acc_, 0, test_data, 1));

  EXPECT_DIF_BADARG(dif_acc_imem_write(&dif_acc_, 0, test_data, 2));
}

TEST_F(ImemWriteTest, BadOffset) {
  uint32_t test_data[] = {0};

  // `offset` must be 32b-aligned.
  EXPECT_DIF_BADARG(dif_acc_imem_write(&dif_acc_, 1, test_data, 4));

  EXPECT_DIF_BADARG(dif_acc_imem_write(&dif_acc_, 2, test_data, 4));
}

TEST_F(ImemWriteTest, BadAddressBeyondMemorySize) {
  uint32_t test_data[] = {0};

  EXPECT_DIF_BADARG(
      dif_acc_imem_write(&dif_acc_, ACC_IMEM_SIZE_BYTES, test_data, 4));
}

TEST_F(ImemWriteTest, BadAddressIntegerOverflow) {
  uint32_t test_data[4] = {0};

  EXPECT_DIF_BADARG(dif_acc_imem_write(&dif_acc_, 0xFFFFFFFC, test_data, 16));
}

TEST_F(ImemWriteTest, SuccessWithoutOffset) {
  // Test assumption.
  ASSERT_GE(ACC_IMEM_SIZE_BYTES, 8);

  uint32_t test_data[2] = {0x12345678, 0xabcdef01};

  EXPECT_WRITE32(ACC_IMEM_REG_OFFSET, test_data[0]);
  EXPECT_WRITE32(ACC_IMEM_REG_OFFSET + 4, test_data[1]);

  EXPECT_DIF_OK(dif_acc_imem_write(&dif_acc_, 0, test_data, 8));
}

TEST_F(ImemWriteTest, SuccessWithOffset) {
  // Test assumption.
  ASSERT_GE(ACC_IMEM_SIZE_BYTES, 12);

  uint32_t test_data[2] = {0x12345678, 0xabcdef01};

  EXPECT_WRITE32(ACC_IMEM_REG_OFFSET + 4, test_data[0]);
  EXPECT_WRITE32(ACC_IMEM_REG_OFFSET + 8, test_data[1]);

  EXPECT_DIF_OK(dif_acc_imem_write(&dif_acc_, 4, test_data, 8));
}

class ImemReadTest : public AccTest {};

TEST_F(ImemReadTest, NullArgs) {
  uint32_t test_data[2] = {0x12345678, 0xabcdef01};

  EXPECT_DIF_BADARG(dif_acc_imem_read(nullptr, 0, nullptr, sizeof(test_data)));

  EXPECT_DIF_BADARG(
      dif_acc_imem_read(nullptr, 0, test_data, sizeof(test_data)));

  EXPECT_DIF_BADARG(
      dif_acc_imem_read(&dif_acc_, 0, nullptr, sizeof(test_data)));

  // No side effects are expected.
  EXPECT_EQ(test_data[0], 0x12345678);
  EXPECT_EQ(test_data[1], 0xabcdef01);
}

TEST_F(ImemReadTest, BadLenBytes) {
  uint32_t test_data[2] = {0};

  // `len_bytes` must be a multiple of 4 bytes.
  EXPECT_DIF_BADARG(dif_acc_imem_read(&dif_acc_, 0, test_data, 1));

  EXPECT_DIF_BADARG(dif_acc_imem_read(&dif_acc_, 0, test_data, 2));
}

TEST_F(ImemReadTest, BadOffset) {
  uint32_t test_data[2] = {0};

  // `offset` must be 32b-aligned.
  EXPECT_DIF_BADARG(
      dif_acc_imem_read(&dif_acc_, 1, test_data, sizeof(test_data)));

  EXPECT_DIF_BADARG(
      dif_acc_imem_read(&dif_acc_, 2, test_data, sizeof(test_data)));
}

TEST_F(ImemReadTest, SuccessWithoutOffset) {
  // Assumption in the test.
  ASSERT_GE(ACC_IMEM_SIZE_BYTES, 8);

  uint32_t test_data[2] = {0};

  EXPECT_READ32(ACC_IMEM_REG_OFFSET, 0x12345678);
  EXPECT_READ32(ACC_IMEM_REG_OFFSET + 4, 0xabcdef01);

  EXPECT_DIF_OK(dif_acc_imem_read(&dif_acc_, 0, test_data, 8));
  EXPECT_EQ(test_data[0], 0x12345678);
  EXPECT_EQ(test_data[1], 0xabcdef01);
}

TEST_F(ImemReadTest, SuccessWithOffset) {
  // Assumption in the test.
  ASSERT_GE(ACC_IMEM_SIZE_BYTES, 12);

  uint32_t test_data[2] = {0};

  EXPECT_READ32(ACC_IMEM_REG_OFFSET + 4, 0x12345678);
  EXPECT_READ32(ACC_IMEM_REG_OFFSET + 8, 0xabcdef01);

  EXPECT_DIF_OK(dif_acc_imem_read(&dif_acc_, 4, test_data, 8));
  EXPECT_EQ(test_data[0], 0x12345678);
  EXPECT_EQ(test_data[1], 0xabcdef01);
}

class DmemWriteTest : public AccTest {};

TEST_F(DmemWriteTest, NullArgs) {
  uint32_t test_data[1] = {0};

  EXPECT_DIF_BADARG(dif_acc_dmem_write(nullptr, 0, nullptr, 4));

  EXPECT_DIF_BADARG(dif_acc_dmem_write(nullptr, 0, test_data, 4));

  EXPECT_DIF_BADARG(dif_acc_dmem_write(&dif_acc_, 0, nullptr, 4));
}

TEST_F(DmemWriteTest, BadLenBytes) {
  uint32_t test_data[1] = {0};

  // `len_bytes` must be a multiple of 4 bytes.
  EXPECT_DIF_BADARG(dif_acc_dmem_write(&dif_acc_, 0, test_data, 1));

  EXPECT_DIF_BADARG(dif_acc_dmem_write(&dif_acc_, 0, test_data, 2));
}

TEST_F(DmemWriteTest, BadOffset) {
  uint32_t test_data[1] = {0};

  // `offset` must be 32b-aligned.
  EXPECT_DIF_BADARG(dif_acc_dmem_write(&dif_acc_, 1, test_data, 4));

  EXPECT_DIF_BADARG(dif_acc_dmem_write(&dif_acc_, 2, test_data, 4));
}

TEST_F(DmemWriteTest, SuccessWithoutOffset) {
  // Test assumption.
  ASSERT_GE(ACC_DMEM_SIZE_BYTES, 8);

  uint32_t test_data[2] = {0x12345678, 0xabcdef01};

  EXPECT_WRITE32(ACC_DMEM_REG_OFFSET, test_data[0]);
  EXPECT_WRITE32(ACC_DMEM_REG_OFFSET + 4, test_data[1]);

  EXPECT_DIF_OK(dif_acc_dmem_write(&dif_acc_, 0, test_data, 8));
}

TEST_F(DmemWriteTest, SuccessWithOffset) {
  // Test assumption.
  ASSERT_GE(ACC_DMEM_SIZE_BYTES, 12);

  uint32_t test_data[2] = {0x12345678, 0xabcdef01};

  EXPECT_WRITE32(ACC_DMEM_REG_OFFSET + 4, test_data[0]);
  EXPECT_WRITE32(ACC_DMEM_REG_OFFSET + 8, test_data[1]);

  EXPECT_DIF_OK(dif_acc_dmem_write(&dif_acc_, 4, test_data, 8));
}

class DmemReadTest : public AccTest {};

TEST_F(DmemReadTest, NullArgs) {
  uint32_t test_data[2] = {0x12345678, 0xabcdef01};

  EXPECT_DIF_BADARG(dif_acc_dmem_read(nullptr, 0, nullptr, sizeof(test_data)));

  EXPECT_DIF_BADARG(
      dif_acc_dmem_read(nullptr, 0, test_data, sizeof(test_data)));

  EXPECT_DIF_BADARG(
      dif_acc_dmem_read(&dif_acc_, 0, nullptr, sizeof(test_data)));

  // No side effects are expected.
  EXPECT_EQ(test_data[0], 0x12345678);
  EXPECT_EQ(test_data[1], 0xabcdef01);
}

TEST_F(DmemReadTest, BadLenBytes) {
  uint32_t test_data[2] = {0};

  // `len_bytes` must be a multiple of 4 bytes.
  EXPECT_DIF_BADARG(dif_acc_dmem_read(&dif_acc_, 0, test_data, 1));

  EXPECT_DIF_BADARG(dif_acc_dmem_read(&dif_acc_, 0, test_data, 2));
}

TEST_F(DmemReadTest, BadOffset) {
  uint32_t test_data[2] = {0};

  // `offset` must be 32b-aligned.
  EXPECT_DIF_BADARG(
      dif_acc_dmem_read(&dif_acc_, 1, test_data, sizeof(test_data)));

  EXPECT_DIF_BADARG(
      dif_acc_dmem_read(&dif_acc_, 2, test_data, sizeof(test_data)));
}

TEST_F(DmemReadTest, SuccessWithoutOffset) {
  // Assumption in the test.
  ASSERT_GE(ACC_DMEM_SIZE_BYTES, 8);

  uint32_t test_data[2] = {0};

  EXPECT_READ32(ACC_DMEM_REG_OFFSET, 0x12345678);
  EXPECT_READ32(ACC_DMEM_REG_OFFSET + 4, 0xabcdef01);

  EXPECT_DIF_OK(dif_acc_dmem_read(&dif_acc_, 0, test_data, 8));
  EXPECT_EQ(test_data[0], 0x12345678);
  EXPECT_EQ(test_data[1], 0xabcdef01);
}

TEST_F(DmemReadTest, SuccessWithOffset) {
  // Assumption in the test.
  ASSERT_GE(ACC_DMEM_SIZE_BYTES, 12);

  uint32_t test_data[2] = {0};

  EXPECT_READ32(ACC_DMEM_REG_OFFSET + 4, 0x12345678);
  EXPECT_READ32(ACC_DMEM_REG_OFFSET + 8, 0xabcdef01);

  EXPECT_DIF_OK(dif_acc_dmem_read(&dif_acc_, 4, test_data, 8));
  EXPECT_EQ(test_data[0], 0x12345678);
  EXPECT_EQ(test_data[1], 0xabcdef01);
}

class ControlSoftwareErrorsFatalTest : public AccTest {};

TEST_F(ControlSoftwareErrorsFatalTest, NullArgs) {
  EXPECT_DIF_BADARG(dif_acc_set_ctrl_software_errs_fatal(nullptr, false));
}

TEST_F(ControlSoftwareErrorsFatalTest, Success) {
  EXPECT_WRITE32(ACC_CTRL_REG_OFFSET, 0x1);
  EXPECT_READ32(ACC_CTRL_REG_OFFSET, 0x1);

  EXPECT_DIF_OK(dif_acc_set_ctrl_software_errs_fatal(&dif_acc_, true));
}

TEST_F(ControlSoftwareErrorsFatalTest, Failure) {
  EXPECT_WRITE32(ACC_CTRL_REG_OFFSET, 0x0);
  EXPECT_READ32(ACC_CTRL_REG_OFFSET, 0x1);

  EXPECT_EQ(dif_acc_set_ctrl_software_errs_fatal(&dif_acc_, false),
            kDifUnavailable);
}

}  // namespace
}  // namespace dif_acc_unittest
