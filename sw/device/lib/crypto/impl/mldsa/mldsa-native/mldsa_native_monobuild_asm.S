// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/* Assembly counterpart of mldsa_native_monobuild.c
 *
 * The RV32-IM kernels are level-independent, so the assembly is included
 * once, for the parameter set that carries the shared code.
 */

#define MLD_CONFIG_MULTILEVEL_WITH_SHARED
#define MLD_CONFIG_PARAMETER_SET 44
#include "mldsa/mldsa_native_asm.S"
