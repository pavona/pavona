// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_CONFIG_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_CONFIG_H_

/******************************************************************************
 * Name:        MLK_CONFIG_MULTILEVEL_BUILD
 *
 * Description: Set this if the build is part of a multi-level build supporting
 *              multiple parameter sets.
 *
 *              If you need only a single parameter set, keep this unset.
 *
 *              To build mlkem-native with support for all parameter sets,
 *              build it three times -- once per parameter set -- and set the
 *              option MLK_CONFIG_MULTILEVEL_WITH_SHARED for exactly one of
 *              them, and MLK_CONFIG_MULTILEVEL_NO_SHARED for the others.
 *              MLK_CONFIG_MULTILEVEL_BUILD should be set for all of them.
 *
 *              See examples/multilevel_build for an example.
 *
 *              This can also be set using CFLAGS.
 *
 *****************************************************************************/
#define MLK_CONFIG_MULTILEVEL_BUILD

/******************************************************************************
 * Name:        MLK_CONFIG_NAMESPACE_PREFIX
 *
 * Description: The prefix to use to namespace global symbols from mlkem/.
 *
 *              In a multi-level build (that is, if either
 *              - MLK_CONFIG_MULTILEVEL_WITH_SHARED, or
 *              - MLK_CONFIG_MULTILEVEL_NO_SHARED,
 *              are set, level-dependent symbols will additionally be prefixed
 *              with the parameter set (512/768/1024).
 *
 *              This can also be set using CFLAGS.
 *
 *****************************************************************************/
#define MLK_CONFIG_NAMESPACE_PREFIX mlkem

/******************************************************************************
 * Name:        MLK_CONFIG_NO_RANDOMIZED_API
 *
 * Description: If this option is set, mlkem-native will be built without the
 *              randomized API functions (crypto_kem_keypair and
 *              crypto_kem_enc).
 *.             This allows users to build mlkem-native without providing a
 *              randombytes() implementation if they only need the
 *              deterministic API
 *              (crypto_kem_keypair_derand, crypto_kem_enc_derand,
 *              crypto_kem_dec).
 *
 *              NOTE: This option is incompatible with MLK_CONFIG_KEYGEN_PCT
 *              as the current PCT implementation requires crypto_kem_enc().
 *
 *****************************************************************************/
#define MLK_CONFIG_NO_RANDOMIZED_API

/******************************************************************************
 * Name:        MLK_CONFIG_NO_SUPERCOP
 *
 * Description: By default, mlkem_native.h exposes the mlkem-native API in the
 *              SUPERCOP naming convention (crypto_kem_xxx). If you don't need
 *              this, set MLK_CONFIG_NO_SUPERCOP.
 *
 *              NOTE: You must set this for a multi-level build as the SUPERCOP
 *              naming does not disambiguate between the parameter sets.
 *
 *****************************************************************************/
#define MLK_CONFIG_NO_SUPERCOP

/******************************************************************************
 * Name:        MLK_CONFIG_INTERNAL_API_QUALIFIER
 *
 * Description: If set, this option provides an additional function
 *              qualifier to be added to declarations of internal API.
 *
 *              The primary use case for this option are single-CU builds,
 *              in which case this option can be set to `static`.
 *
 *****************************************************************************/
#define MLK_CONFIG_INTERNAL_API_QUALIFIER static

/******************************************************************************
 * Name:        MLK_CONFIG_FIPS202_CUSTOM_HEADER
 *
 * Description: Custom header to use for FIPS-202
 *
 *              This should only be set if you intend to use a custom
 *              FIPS-202 implementation, different from the one shipped
 *              with mlkem-native.
 *
 *              If set, it must be the name of a file serving as the
 *              replacement for mlkem/fips202/fips202.h, and exposing
 *              the same API (see FIPS202.md).
 *
 *****************************************************************************/
#define MLK_CONFIG_FIPS202_CUSTOM_HEADER "fips202_glue.h"

/******************************************************************************
 * Name:        MLK_CONFIG_SERIAL_FIPS202_ONLY
 *
 * Description: If this option is set, batched Keccak operations will be
 *              disabled for rejection sampling during matrix generation.
 *              Instead, matrix entries will be generated one at a time.
 *
 *              This allows offloading Keccak computations to a hardware
 *              accelerator that holds only a single Keccak state locally,
 *              rather than requiring support for batched (4x) Keccak states.
 *
 *              NOTE: Depending on the target CPU, disabling batched Keccak
 *              may reduce performance when using software FIPS202
 *              implementations. Only enable this when you have to.
 *
 *****************************************************************************/
#define MLK_CONFIG_SERIAL_FIPS202_ONLY

/******************************************************************************
 * Name:        MLK_CONFIG_CONTEXT_PARAMETER
 *
 * Description: Set this to add a context parameter that is provided to public
 *              API functions and is then available in custom callbacks.
 *
 *              The type of the context parameter is configured via
 *              MLK_CONFIG_CONTEXT_PARAMETER_TYPE.
 *
 *****************************************************************************/
#define MLK_CONFIG_CONTEXT_PARAMETER

/******************************************************************************
 * Name:        MLK_CONFIG_CONTEXT_PARAMETER_TYPE
 *
 * Description: Set this to define the type for the context parameter used by
 *              MLK_CONFIG_CONTEXT_PARAMETER.
 *
 *              This is only relevant if MLK_CONFIG_CONTEXT_PARAMETER is set.
 *
 *****************************************************************************/
#if !defined(__ASSEMBLER__)
#include "sw/device/lib/crypto/impl/mlkem/mlkem_native_alloc.h"

#define MLK_CONFIG_CONTEXT_PARAMETER_TYPE mlk_alloc_ctx_t *

/******************************************************************************
 * Name:        MLK_CONFIG_CUSTOM_ALLOC_FREE [EXPERIMENTAL]
 *
 * Description: Set this option and define `MLK_CUSTOM_ALLOC` and
 *              `MLK_CUSTOM_FREE` if you want to use custom allocation for
 *              large local structures or buffers.
 *
 *              By default, all buffers/structures are allocated on the stack.
 *              If this option is set, most of them will be allocated via
 *              MLK_CUSTOM_ALLOC.
 *
 *              Parameters to MLK_CUSTOM_ALLOC:
 *              - T* v: Target pointer to declare.
 *              - T: Type of structure to be allocated
 *              - N: Number of elements to be allocated.
 *
 *              Parameters to MLK_CUSTOM_FREE:
 *              - T* v: Target pointer to free. May be NULL.
 *              - T: Type of structure to be freed.
 *              - N: Number of elements to be freed.
 *
 *              WARNING: This option is experimental!
 *              Its scope, configuration and function/macro signatures may
 *              change at any time. We expect a stable API for v2.
 *
 *              NOTE: Even if this option is set, some allocations further down
 *              the call stack will still be made from the stack. Those will
 *              likely be added to the scope of this option in the future.
 *
 *              NOTE: MLK_CUSTOM_ALLOC need not guarantee a successful
 *              allocation nor include error handling. Upon failure, the
 *              target pointer should simply be set to NULL. The calling
 *              code will handle this case and invoke MLK_CUSTOM_FREE.
 *
 *****************************************************************************/
#define MLK_CONFIG_CUSTOM_ALLOC_FREE

#define MLK_CUSTOM_ALLOC(v, T, N, context) \
  T *(v) = (T *)mlk_alloc((context), sizeof(T) * (N))

#define MLK_CUSTOM_FREE(v, T, N, context) \
  mlk_free((void *)(v), (context), sizeof(T) * (N))

#endif

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_CONFIG_H_
