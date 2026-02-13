// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/ip/aes/model/aes_modes.h"
#include "hw/top/dt/dt_acc.h"
#include "hw/top/dt/dt_aes.h"
#include "hw/top/dt/dt_csrng.h"
#include "hw/top/dt/dt_edn.h"
#include "hw/top/dt/dt_rv_core_ibex.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_acc.h"
#include "sw/device/lib/dif/dif_aes.h"
#include "sw/device/lib/dif/dif_csrng.h"
#include "sw/device/lib/dif/dif_edn.h"
#include "sw/device/lib/dif/dif_rv_core_ibex.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/acc_testutils.h"
#include "sw/device/lib/testing/aes_testutils.h"
#include "sw/device/lib/testing/edn_testutils.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/rand_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/tests/acc_randomness_impl.h"

#include "hw/top/edn_regs.h"  // Generated

enum {
  kTimeout = (10 * 1000 * 1000),
  kAccRounds = 2,
  kAccRandomnessIterations = 1,
  kTestProcedureRepetitions = 2,
};

static dif_csrng_t csrng;
static dif_edn_t edn0;
static dif_edn_t edn1;
static dif_aes_t aes;
static dif_acc_t acc;
static dif_rv_core_ibex_t rv_core_ibex;

// AES ECB encryption transaction.
static dif_aes_transaction_t transaction = {
    .operation = kDifAesOperationEncrypt,
    .mode = kDifAesModeEcb,
    .key_len = kDifAesKey256,
    .key_provider = kDifAesKeySoftwareProvided,
    .mask_reseeding = kDifAesReseedPerBlock,
    .manual_operation = kDifAesManualOperationAuto,
    .reseed_on_key_change = true,
    .ctrl_aux_lock = false,
};

OTTF_DEFINE_TEST_CONFIG();

// Initializes the peripherals used in this test.
static void init_peripherals(void) {
  CHECK_DIF_OK(dif_csrng_init_from_dt(kDtCsrng, &csrng));
  CHECK_DIF_OK(dif_edn_init_from_dt(kDtEdn0, &edn0));
  CHECK_DIF_OK(dif_edn_init_from_dt(kDtEdn1, &edn1));
  CHECK_DIF_OK(dif_aes_init_from_dt(kDtAes, &aes));
  CHECK_DIF_OK(dif_acc_init_from_dt(kDtAcc, &acc));
  CHECK_DIF_OK(dif_rv_core_ibex_init_from_dt(kDtRvCoreIbex, &rv_core_ibex));
}

static void configure_acc(void) {
  acc_randomness_test_prepare(&acc, kAccRandomnessIterations);
}

// configure the entropy complex
static void entropy_config(void) {
  dif_edn_auto_params_t edn_params0 =
      edn_testutils_auto_params_build(false, /*res_itval=*/0, /*glen_val=*/0);
  dif_edn_auto_params_t edn_params1 =
      edn_testutils_auto_params_build(false, /*res_itval=*/0, /*glen_val=*/0);
  // Disable the entropy complex
  CHECK_STATUS_OK(entropy_testutils_stop_all());
  // Enable ENTROPY_SRC in FIPS mode
  CHECK_STATUS_OK(entropy_testutils_entropy_src_init());
  // Enable CSRNG
  CHECK_DIF_OK(dif_csrng_configure(&csrng));
  // Enable EDNs in auto request mode
  CHECK_DIF_OK(dif_edn_set_auto_mode(&edn0, edn_params0));
  CHECK_DIF_OK(dif_edn_set_auto_mode(&edn1, edn_params1));
  CHECK_DIF_OK(dif_aes_reset(&aes));
}

static status_t stress_test_edns(void) {
  int acc_execute_rounds = kAccRounds;
  dif_rv_core_ibex_rnd_status_t ibex_rnd_status;
  dif_acc_status_t acc_status;
  uint32_t ibex_rnd_data;
  dif_aes_data_t out_data;
  // Start AES at least once.
  LOG_INFO("aes_testutils_setup_encryption round %d", acc_execute_rounds);
  CHECK_STATUS_OK(aes_testutils_setup_encryption(transaction, &aes));
  while (acc_execute_rounds) {
    LOG_INFO("dif_acc_get_status round %d", acc_execute_rounds);
    CHECK_DIF_OK(dif_acc_get_status(&acc, &acc_status));
    if (acc_status == kDifAccStatusIdle) {
      LOG_INFO("acc_testutils_execute round %d", acc_execute_rounds);
      CHECK_STATUS_OK(acc_testutils_execute(&acc));
      acc_execute_rounds--;
    }
    if (aes_testutils_get_status(&aes, kDifAesStatusOutputValid)) {
      LOG_INFO("dif_aes_read_output round %d", acc_execute_rounds);
      // Read out the produced cipher text.
      CHECK_DIF_OK(dif_aes_read_output(&aes, &out_data));
      LOG_INFO("aes_testutils_setup_encryption round %d", acc_execute_rounds);
      // Start a new AES encryption.
      CHECK_STATUS_OK(aes_testutils_setup_encryption(transaction, &aes));
    }

    CHECK_DIF_OK(
        dif_rv_core_ibex_get_rnd_status(&rv_core_ibex, &ibex_rnd_status));
    if (ibex_rnd_status == kDifRvCoreIbexRndStatusValid)
      CHECK_DIF_OK(
          dif_rv_core_ibex_read_rnd_data(&rv_core_ibex, &ibex_rnd_data));
  }
  // Verify that all entropy consuming endpoints can finish their operations
  // and do not hang.
  CHECK_STATUS_OK(acc_testutils_wait_for_done(&acc, kDifAccErrBitsNoError));
  AES_TESTUTILS_WAIT_FOR_STATUS(&aes, kDifAesStatusOutputValid, true, kTimeout);
  IBEX_TRY_SPIN_FOR(rv_core_ibex_testutils_is_rnd_data_valid(&rv_core_ibex),
                    kTimeout);

  return OK_STATUS();
}

bool test_main(void) {
  int repetitions = kTestProcedureRepetitions;
  LOG_INFO("init_peripherals start");
  init_peripherals();
  // Prepare the ACC for execution.
  configure_acc();
  // Start the procedure multiple times, with different EDN configurations.
  while (repetitions) {
    // Disable and restart the entropy complex.
    LOG_INFO("entropy_config start");
    entropy_config();
    // Trigger the execution of the ACC, AES and IBEX, consuming entropy
    // to stress test the EDNs.
    LOG_INFO("stress_test_edns start");
    stress_test_edns();
    repetitions--;
  }

  return true;
}
