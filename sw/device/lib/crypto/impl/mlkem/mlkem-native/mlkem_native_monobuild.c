// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "mlkem_native_monobuild.h"

/* Three instances of mlkem-native for all security levels */

/* Include level-independent code */
#define MLK_CONFIG_MULTILEVEL_WITH_SHARED
/* Keep level-independent headers at the end of monobuild file */
#define MLK_CONFIG_MONOBUILD_KEEP_SHARED_HEADERS
#define MLK_CONFIG_PARAMETER_SET 512
#include "mlkem/mlkem_native.c"
#undef MLK_CONFIG_PARAMETER_SET
#undef MLK_CONFIG_MULTILEVEL_WITH_SHARED

/* Exclude level-independent code */
#define MLK_CONFIG_MULTILEVEL_NO_SHARED
#define MLK_CONFIG_PARAMETER_SET 768
#include "mlkem/mlkem_native.c"
#undef MLK_CONFIG_PARAMETER_SET
/* `#undef` all headers at the and of the monobuild file */
#undef MLK_CONFIG_MONOBUILD_KEEP_SHARED_HEADERS

#define MLK_CONFIG_PARAMETER_SET 1024
#include "mlkem/mlkem_native.c"
#undef MLK_CONFIG_PARAMETER_SET
