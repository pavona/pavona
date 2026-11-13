// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top/dt/dma.h"
#include "hw/top/dt/pinmux.h"
#include "hw/top/dt/spi_host.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_base.h"
#include "sw/device/lib/dif/dif_dma.h"
#include "sw/device/lib/dif/dif_spi_host.h"
#include "sw/device/lib/runtime/hart.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/dma_testutils.h"
#include "sw/device/lib/testing/pinmux_testutils.h"
#include "sw/device/lib/testing/rand_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/lib/testing/test_framework/status.h"

// The TX_SIZE must be in sync with the data size in spi_device_dma_seq.sv
// 1 SPI segment can only transfer at maximum 512 bytes
#define TX_SIZE 512
#define CHUNK_SIZE 32 * 4  // Half the SPI host FIFO size

OTTF_DEFINE_TEST_CONFIG();

enum {
  kSoftwareBarrierTimeoutUsec = 500,
};

// This location will be update from SV
static volatile const uint8_t kSoftwareBarrier = 0;

// Expected digest value gets backdoor'ed from the hardware.
//
// const places the array with the read only data loaded from the test image,
// which the testbench can write. A writable copy would sit in main SRAM, where
// the backdoor write does not survive the memory scrambling. used and retain
// keep the symbol, which nothing else does here because the array is only read.
static volatile const uint32_t kShaDigestExpData[16] OT_USED
    __attribute__((retain));
static volatile const uint8_t kShaMode;

uint32_t digest[16];
uint8_t received_data[TX_SIZE] __attribute__((aligned(4)));

static dif_spi_host_t spi_host;
static dif_pinmux_t pinmux;
static dif_dma_t dma;

bool test_main(void) {
  // Initialize the pinmux.
  CHECK_DIF_OK(dif_pinmux_init_from_dt(kDtPinmuxAon, &pinmux));
  pinmux_testutils_init(&pinmux);

  // Initialise DMA.
  CHECK_DIF_OK(dif_dma_init_from_dt(kDtDma, &dma));

  // Setup pinmux if required, enable weak pull-up on relevant pads
  setup_pads_spi_host0(&pinmux);  // direct

  // Setup spi host configuration
  CHECK_DIF_OK(dif_spi_host_init_from_dt((dt_spi_host_t)0, &spi_host));
  init_spi_host(&spi_host, (uint32_t)kClockFreqHiSpeedPeripheralHz,
                CHUNK_SIZE / 4);

  // DV sync message
  LOG_INFO("spi host configuration complete");

  setup_spi_dma_transaction(&spi_host, &dma, &received_data[0], CHUNK_SIZE,
                            TX_SIZE);

  CHECK_DIF_OK(dif_dma_start(&dma, kShaMode));

  // Wait until the DMA has started to abort the transfer
  IBEX_SPIN_FOR(kSoftwareBarrier == 1, kSoftwareBarrierTimeoutUsec);

  CHECK_DIF_OK(dif_dma_abort(&dma));

  // The abort is not complete when the write returns: the hardware first
  // finishes the access it has in flight. Wait for the status rather than
  // sampling it once.
  CHECK_DIF_OK(dif_dma_status_poll(&dma, kDifDmaStatusAborted));

  // Reset and re-init the SPI
  init_spi_host(&spi_host, (uint32_t)kClockFreqHiSpeedPeripheralHz,
                CHUNK_SIZE / 4);
  LOG_INFO("spi host re-configuration complete");

  // Do the second transaction
  setup_spi_dma_transaction(&spi_host, &dma, &received_data[0], CHUNK_SIZE,
                            TX_SIZE);
  CHECK_DIF_OK(dif_dma_start(&dma, kShaMode));
  CHECK_DIF_OK(dif_dma_status_poll(&dma, kDifDmaStatusDone));

  CHECK_DIF_OK(dif_dma_sha2_digest_get(&dma, kShaMode, digest));

  uint32_t digest_len;
  CHECK_DIF_OK(dif_dma_get_digest_length(kShaMode, &digest_len));

  // Copy the expected digest out first. Only the testbench writes the array, so
  // the compiler treats it as a const nothing initializes and folds reads that
  // drop the volatile qualifier, which is what the comparison below does when
  // it casts to a byte pointer. Reading each word volatile forces a real load.
  uint32_t expected_digest[ARRAYSIZE(digest)];
  for (size_t i = 0; i < ARRAYSIZE(expected_digest); ++i) {
    expected_digest[i] = kShaDigestExpData[i];
  }

  CHECK_ARRAYS_EQ((uint8_t *)digest, (uint8_t *)expected_digest, digest_len);

  return true;
}
