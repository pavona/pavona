// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_MONOBUILD_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_MONOBUILD_H_

/* API for MLKEM-512 */
#define MLK_CONFIG_PARAMETER_SET 512
#include "mlkem/mlkem_native.h"
#undef MLK_CONFIG_PARAMETER_SET
#undef MLK_H

/* API for MLKEM-768 */
#define MLK_CONFIG_PARAMETER_SET 768
#include "mlkem/mlkem_native.h"
#undef MLK_CONFIG_PARAMETER_SET
#undef MLK_H

/* API for MLKEM-1024 */
#define MLK_CONFIG_PARAMETER_SET 1024
#include "mlkem/mlkem_native.h"
#undef MLK_CONFIG_PARAMETER_SET
#undef MLK_H

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_MONOBUILD_H_
