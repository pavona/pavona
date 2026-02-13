// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_TESTING_ACC_TESTUTILS_RSA_H_
#define OPENTITAN_SW_DEVICE_LIB_TESTING_ACC_TESTUTILS_RSA_H_

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_acc.h"

/**
 * @file Run RSA on ACC as a testing tool.
 * @brief This library is based on the DIF instead of a full ACC driver, and
 * should be used for testing only. The library does not include message
 * hashing or encoding.
 */

/**
 * Load the RSA application into ACC.
 *
 * @param acc The ACC context object.
 */
status_t acc_testutils_rsa_load(dif_acc_t *acc);

/**
 * Start running modular exponentiation with the exponent 65537.
 *
 * Computes (in^65537) mod n. This corresponds to the core step in encryption
 * or signature verification, and is much faster than a general modular
 * exponentiation. 65537 is also called "F4" because it is the 4th Fermat
 * number (2^16 + 1).
 *
 * The RSA app should be loaded into ACC with `acc_testutils_rsa_load` before
 * calling this function.
 *
 * @param acc The ACC context object.
 * @param modulus The modulus (n).
 * @param in The plaintext message.
 * @param size_bytes The size of all buffers in bytes, i.e. the key/modulus
 *                   length (i.e. 128 for RSA 1024). Valid range: 32..512 in
 *                   32 byte-steps (i.e. RSA 256 to RSA 4096).
 */
status_t acc_testutils_rsa_modexp_f4_start(dif_acc_t *acc,
                                            const uint8_t *modulus,
                                            const uint8_t *in,
                                            size_t size_bytes);

/**
 * Finish modular exponentiation with the exponent 65537.
 *
 * Waits for ACC to complete and reads back the result of modular
 * exponentiation. Call only after `acc_testutils_rsa_modexp_f4_start`.
 *
 * @param acc The ACC context object.
 * @param out The encrypted message.
 * @param size_bytes The size of all buffers in bytes, i.e. the key/modulus
 *                   length (i.e. 128 for RSA 1024). Valid range: 32..512 in
 *                   32 byte-steps (i.e. RSA 256 to RSA 4096).
 */
status_t acc_testutils_rsa_modexp_f4_finalize(dif_acc_t *acc, uint8_t *out,
                                               size_t size_bytes);

/**
 * Start a constant-time modular exponentiation.
 *
 * Computes (in^d) mod n. This corresponds to the core step in decryption or
 * signature generation and can be very slow.
 *
 * The RSA app should be loaded into ACC with `acc_testutils_rsa_load` before
 * calling this function.
 *
 * @param acc The ACC context object.
 * @param modulus The modulus (n).
 * @param private_exponent The private exponent (d).
 * @param in The encrypted message.
 * @param out The decrypted (plaintext) message.
 * @param size_bytes The size of all buffers in bytes, i.e. the key/modulus
 *                   length (i.e. 128 for RSA 1024). Valid range: 32..512 in
 *                   32 byte-steps (i.e. RSA 256 to RSA 4096).
 */
status_t acc_testutils_rsa_modexp_consttime_start(
    dif_acc_t *acc, const uint8_t *modulus, const uint8_t *private_exponent,
    const uint8_t *in, size_t size_bytes);
/**
 * Finish modular exponentiation with the exponent 65537.
 *
 * Waits for ACC to complete and reads back the result of modular
 * exponentiation. Call only after `acc_testutils_rsa_modexp_consttime_start`.
 *
 * @param acc The ACC context object.
 * @param out The encrypted message.
 * @param size_bytes The size of all buffers in bytes, i.e. the key/modulus
 *                   length (i.e. 128 for RSA 1024). Valid range: 32..512 in
 *                   32 byte-steps (i.e. RSA 256 to RSA 4096).
 */
status_t acc_testutils_rsa_modexp_consttime_finalize(dif_acc_t *acc,
                                                      uint8_t *out,
                                                      size_t size_bytes);

#endif  // OPENTITAN_SW_DEVICE_LIB_TESTING_ACC_TESTUTILS_RSA_H_
