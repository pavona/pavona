// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_MONOBUILD_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_MONOBUILD_H_

/* API for MLDSA-44 */
#define MLD_CONFIG_PARAMETER_SET 44
#include "mldsa/mldsa_native.h"
#undef MLD_CONFIG_PARAMETER_SET
#undef MLD_H

/* API for MLDSA-65 */
#define MLD_CONFIG_PARAMETER_SET 65
#include "mldsa/mldsa_native.h"
#undef MLD_CONFIG_PARAMETER_SET
#undef MLD_H

/* API for MLDSA-87 */
#define MLD_CONFIG_PARAMETER_SET 87
#include "mldsa/mldsa_native.h"
#undef MLD_CONFIG_PARAMETER_SET
#undef MLD_H

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_MONOBUILD_H_
