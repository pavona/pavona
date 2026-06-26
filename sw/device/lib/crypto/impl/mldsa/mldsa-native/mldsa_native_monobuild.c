// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "mldsa_native_monobuild.h"

/* Three instances of mldsa-native for ML-DSA-44, ML-DSA-65, and ML-DSA-87 */

/* Include level-independent code */
#define MLD_CONFIG_MULTILEVEL_WITH_SHARED
/* Keep level-independent headers at the end of monobuild file */
#define MLD_CONFIG_MONOBUILD_KEEP_SHARED_HEADERS
#define MLD_CONFIG_PARAMETER_SET 44
#include "mldsa/mldsa_native.c"
#undef MLD_CONFIG_PARAMETER_SET
#undef MLD_CONFIG_MULTILEVEL_WITH_SHARED

/* Exclude level-independent code */
#define MLD_CONFIG_MULTILEVEL_NO_SHARED
#define MLD_CONFIG_PARAMETER_SET 65
#include "mldsa/mldsa_native.c"
#undef MLD_CONFIG_PARAMETER_SET

/* `#undef` all headers at the end of the monobuild file */
#undef MLD_CONFIG_MONOBUILD_KEEP_SHARED_HEADERS

#define MLD_CONFIG_PARAMETER_SET 87
#include "mldsa/mldsa_native.c"
#undef MLD_CONFIG_PARAMETER_SET
