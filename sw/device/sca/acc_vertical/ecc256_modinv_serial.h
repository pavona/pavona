// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SCA_ACC_VERTICAL_ECC256_MODINV_SERIAL_H_
#define OPENTITAN_SW_DEVICE_SCA_ACC_VERTICAL_ECC256_MODINV_SERIAL_H_

#include "sw/device/lib/crypto/drivers/acc.h"

/**
 * App configuration for p256_mod_inv_sca
 */
ACC_DECLARE_APP_SYMBOLS(p256_mod_inv_sca);

ACC_DECLARE_SYMBOL_ADDR(p256_mod_inv_sca, k0);
ACC_DECLARE_SYMBOL_ADDR(p256_mod_inv_sca, k1);
ACC_DECLARE_SYMBOL_ADDR(p256_mod_inv_sca, kalpha_inv);
ACC_DECLARE_SYMBOL_ADDR(p256_mod_inv_sca, alpha);

extern const acc_app_t kAccAppP256ModInv;

static const acc_addr_t kAccVarModInvK0;
static const acc_addr_t kAccVarModInvK1;
static const acc_addr_t kAccVarModInvKAplhaInv;
static const acc_addr_t kAccVarModInvAlpha;

/**
 * Computes the modular inverse of a certain input.
 *
 * The input must be `kEcc256ModInvInputShareNumWords` words long.
 *
 * @param[in] input  Input for modular inverse computation.
 */
void ecc256_modinv(const uint8_t *k0_k1, size_t k0_k1_len);

#endif  // OPENTITAN_SW_DEVICE_SCA_ACC_VERTICAL_ECC256_MODINV_SERIAL_H_
