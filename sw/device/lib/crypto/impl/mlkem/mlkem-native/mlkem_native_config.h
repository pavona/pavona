// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_MLKEM_NATIVE_CONFIG_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_MLKEM_NATIVE_CONFIG_H_

/**
 * MLK_CONFIG_MULTILEVEL_BUILD
 *
 * Set this if the build is part of a multi-level build supporting multiple
 * parameter sets.
 *
 * If you need only a single parameter set, keep this unset.
 *
 * To build mlkem-native with support for all parameter sets, build it three
 * times -- once per parameter set -- and set the option
 * MLK_CONFIG_MULTILEVEL_WITH_SHARED for exactly one of them, and
 * MLK_CONFIG_MULTILEVEL_NO_SHARED for the others.
 * MLK_CONFIG_MULTILEVEL_BUILD should be set for all of them.
 *
 * See examples/multilevel_build for an example.
 *
 * This can also be set using CFLAGS.
 */
#define MLK_CONFIG_MULTILEVEL_BUILD

/**
 * The prefix to use to namespace global symbols from mlkem/.
 *
 * In a multi-level build, level-dependent symbols will additionally be
 * prefixed with the parameter set (512/768/1024).
 *
 * This can also be set using CFLAGS.
 */
#define MLK_CONFIG_NAMESPACE_PREFIX mlkem

/**
 * MLK_CONFIG_NO_RANDOMIZED_API
 *
 * If this option is set, mlkem-native will be built without the randomized
 * API functions (keypair and enc). This allows users
 * to build mlkem-native without providing a randombytes() implementation
 * if they only need the deterministic API (keypair_derand,
 * enc_derand, dec).
 *
 * @note This option is incompatible with MLK_CONFIG_KEYGEN_PCT as the
 *       current PCT implementation requires enc().
 */
#define MLK_CONFIG_NO_RANDOMIZED_API

/**
 * MLK_CONFIG_INTERNAL_API_QUALIFIER
 *
 * If set, this option provides an additional qualifier to be added to
 * declarations of internal API functions and data.
 *
 * The primary use case for this option are single-CU builds, in which case
 * this option can be set to `static`.
 */
#define MLK_CONFIG_INTERNAL_API_QUALIFIER static

/**
 * MLK_CONFIG_FIPS202_CUSTOM_HEADER
 *
 * Custom header to use for FIPS-202.
 *
 * This should only be set if you intend to use a custom FIPS-202
 * implementation, different from the one shipped with mlkem-native.
 *
 * If set, it must be the name of a file serving as the replacement for
 * mlkem/src/fips202/fips202.h, and exposing the same API (see FIPS202.md).
 */
#define MLK_CONFIG_FIPS202_CUSTOM_HEADER "fips202_glue.h"

/**
 * MLK_CONFIG_SERIAL_FIPS202_ONLY
 *
 * Set this to use a FIPS202 implementation with global state that supports
 * only one active Keccak computation at a time (e.g. some hardware
 * accelerators).
 *
 * If this option is set, batched Keccak operations are disabled for
 * rejection sampling during matrix generation. Instead, matrix entries
 * will be generated one at a time.
 *
 * This allows offloading Keccak computations to a hardware accelerator
 * that holds only a single Keccak state locally, rather than requiring
 * support for batched (4x) Keccak states.
 *
 * @note Depending on the target CPU, disabling batched Keccak may reduce
 *       performance when using software FIPS202 implementations. Only
 *       enable this when you have to.
 */
#define MLK_CONFIG_SERIAL_FIPS202_ONLY

/**
 * MLK_CONFIG_CONTEXT_PARAMETER
 *
 * Set this to add a context parameter that is provided to public API
 * functions and is then available in custom callbacks.
 *
 * The type of the context parameter is configured via
 * MLK_CONFIG_CONTEXT_PARAMETER_TYPE.
 *
 * The context is passed to MLK_CUSTOM_ALLOC and MLK_CUSTOM_FREE; see
 * MLK_CONFIG_CUSTOM_ALLOC_FREE.
 */
#define MLK_CONFIG_CONTEXT_PARAMETER

#if !defined(__ASSEMBLER__)
#include "sw/device/lib/crypto/impl/mlkem/mlkem-native/mlkem_native_alloc.h"

/**
 * MLK_CONFIG_CONTEXT_PARAMETER_TYPE
 *
 * Set this to define the type for the context parameter used by
 * MLK_CONFIG_CONTEXT_PARAMETER.
 *
 * This is only relevant if MLK_CONFIG_CONTEXT_PARAMETER is set.
 */
#define MLK_CONFIG_CONTEXT_PARAMETER_TYPE mlk_alloc_ctx_t *

/**
 * MLK_CONFIG_CUSTOM_ALLOC_FREE
 *
 * Set this option and define `MLK_CUSTOM_ALLOC` and `MLK_CUSTOM_FREE` if
 * you want to use custom allocation for large local structures or buffers.
 *
 * By default, all buffers/structures are allocated on the stack. If this
 * option is set, most of them will be allocated via MLK_CUSTOM_ALLOC.
 *
 * Parameters to MLK_CUSTOM_ALLOC:
 *  - T* v: Target pointer to declare.
 *  - T: Type of structure to be allocated.
 *  - N: Number of elements to be allocated.
 *
 * Parameters to MLK_CUSTOM_FREE:
 *  - T* v: Target pointer to free. May be NULL.
 *  - T: Type of structure to be freed.
 *  - N: Number of elements to be freed.
 *
 * If MLK_CONFIG_CONTEXT_PARAMETER is set, both macros receive the
 * context as a fourth parameter, e.g. MLK_CUSTOM_ALLOC(v, T, N, context):
 *  - context: The context passed to the public API function, of type
 *    MLK_CONFIG_CONTEXT_PARAMETER_TYPE.
 *
 * @note Even if this option is set, some allocations further down the call
 *       stack will still be made from the stack, consuming up to 3KB of
 *       stack space. Those will likely be added to the scope of this
 *       option in the future.
 *
 * @note MLK_CUSTOM_ALLOC need not guarantee a successful allocation nor
 *       include error handling. Upon failure, the target pointer should
 *       simply be set to NULL. The calling code will handle this case and
 *       invoke MLK_CUSTOM_FREE.
 */
#define MLK_CONFIG_CUSTOM_ALLOC_FREE

/** Custom allocator, see MLK_CONFIG_CUSTOM_ALLOC_FREE. */
#define MLK_CUSTOM_ALLOC(v, T, N, context) \
  T *(v) = (T *)mlk_alloc((context), sizeof(T) * (N))

/** Custom deallocator, see MLK_CONFIG_CUSTOM_ALLOC_FREE. */
#define MLK_CUSTOM_FREE(v, T, N, context) \
  mlk_free((void *)(v), (context), sizeof(T) * (N))

#endif

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_MLKEM_NATIVE_CONFIG_H_
