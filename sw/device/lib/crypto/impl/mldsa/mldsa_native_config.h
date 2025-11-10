// Copyright The mldsa-native project authors
//  Copyright zeroRISC Inc.
//  Licensed under the Apache License, Version 2.0, see LICENSE for details.
//  SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_CONFIG_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_CONFIG_H_

/******************************************************************************
 * Name:        MLD_CONFIG_MULTILEVEL_BUILD
 *
 * Description: Set this if the build is part of a multi-level build supporting
 *              multiple parameter sets.
 *
 *              If you need only a single parameter set, keep this unset.
 *
 *              To build mldsa-native with support for all parameter sets,
 *              build it three times -- once per parameter set -- and set the
 *              option MLD_CONFIG_MULTILEVEL_WITH_SHARED for exactly one of
 *              them, and MLD_CONFIG_MULTILEVEL_NO_SHARED for the others.
 *              MLD_CONFIG_MULTILEVEL_BUILD should be set for all of them.
 *
 *              See examples/multilevel_build for an example.
 *
 *              This can also be set using CFLAGS.
 *
 *****************************************************************************/
#define MLD_CONFIG_MULTILEVEL_BUILD

/******************************************************************************
 * Name:        MLD_CONFIG_NAMESPACE_PREFIX
 *
 * Description: The prefix to use to namespace global symbols from mldsa/.
 *
 *              In a multi-level build (that is, if either
 *              - MLD_CONFIG_MULTILEVEL_WITH_SHARED, or
 *              - MLD_CONFIG_MULTILEVEL_NO_SHARED,
 *              are set, level-dependent symbols will additionally be prefixed
 *              with the parameter set (44/65/87).
 *
 *              This can also be set using CFLAGS.
 *
 *****************************************************************************/
#define MLD_CONFIG_NAMESPACE_PREFIX mldsa

/******************************************************************************
 * Name:        MLD_CONFIG_NO_RANDOMIZED_API
 *
 * Description: If this option is set, mldsa-native will be built without the
 *              randomized API functions (crypto_sign_keypair,
 *              crypto_sign, crypto_sign_signature, and
 *              crypto_sign_signature_extmu).
 *              This allows users to build mldsa-native without providing a
 *              randombytes() implementation if they only need the
 *              internal deterministic API
 *              (crypto_sign_keypair_internal, crypto_sign_signature_internal).
 *
 *              NOTE: This option is incompatible with MLD_CONFIG_KEYGEN_PCT
 *              as the current PCT implementation requires
 *              crypto_sign_signature().
 *
 *****************************************************************************/
#define MLD_CONFIG_NO_RANDOMIZED_API

/******************************************************************************
 * Name:        MLD_CONFIG_NO_SUPERCOP
 *
 * Description: By default, mldsa_native.h exposes the mldsa-native API in the
 *              SUPERCOP naming convention (crypto_sign_xxx). If you don't need
 *              this, set MLD_CONFIG_NO_SUPERCOP.
 *
 *              NOTE: You must set this for a multi-level build as the SUPERCOP
 *              naming does not disambiguate between the parameter sets.
 *
 *****************************************************************************/
#define MLD_CONFIG_NO_SUPERCOP

/******************************************************************************
 * Name:        MLD_CONFIG_INTERNAL_API_QUALIFIER
 *
 * Description: If set, this option provides an additional function
 *              qualifier to be added to declarations of internal API.
 *
 *              The primary use case for this option are single-CU builds,
 *              in which case this option can be set to `static`.
 *
 *****************************************************************************/
#define MLD_CONFIG_INTERNAL_API_QUALIFIER static

/******************************************************************************
 * Name:        MLD_CONFIG_FIPS202_CUSTOM_HEADER
 *
 * Description: Custom header to use for FIPS-202
 *
 *              This should only be set if you intend to use a custom
 *              FIPS-202 implementation, different from the one shipped
 *              with mldsa-native.
 *
 *              If set, it must be the name of a file serving as the
 *              replacement for mldsa/src/fips202/fips202.h, and exposing
 *              the same API (see FIPS202.md).
 *
 *****************************************************************************/
#define MLD_CONFIG_FIPS202_CUSTOM_HEADER "fips202_glue.h"

/******************************************************************************
 * Name:        MLD_CONFIG_SERIAL_FIPS202_ONLY
 *
 * Description: Set this to use a FIPS202 implementation with global state
 *              that supports only one active Keccak computation at a time
 *              (e.g. some hardware accelerators).
 *
 *              If this option is set, ML-DSA will use FIPS202 operations
 *              serially, ensuring that only one SHAKE context is active
 *              at any given time.
 *
 *              This allows offloading Keccak computations to a hardware
 *              accelerator that holds only a single Keccak state locally,
 *              rather than requiring support for multiple concurrent
 *              Keccak states.
 *
 *              NOTE: Depending on the target CPU, this may reduce
 *              performance when using software FIPS202 implementations.
 *              Only enable this when you have to.
 *
 *****************************************************************************/
#define MLD_CONFIG_SERIAL_FIPS202_ONLY

/******************************************************************************
 * Name:        MLD_CONFIG_CONTEXT_PARAMETER
 *
 * Description: Set this to add a context parameter that is provided to public
 *              API functions and is then available in custom callbacks.
 *
 *              The type of the context parameter is configured via
 *              MLD_CONFIG_CONTEXT_PARAMETER_TYPE.
 *
 *****************************************************************************/
#define MLD_CONFIG_CONTEXT_PARAMETER

/******************************************************************************
 * Name:        MLD_CONFIG_CONTEXT_PARAMETER_TYPE
 *
 * Description: Set this to define the type for the context parameter used by
 *              MLD_CONFIG_CONTEXT_PARAMETER.
 *
 *              This is only relevant if MLD_CONFIG_CONTEXT_PARAMETER is set.
 *
 *****************************************************************************/
#if !defined(__ASSEMBLER__)
#include "sw/device/lib/crypto/impl/mldsa/mldsa_native_alloc.h"

#define MLD_CONFIG_CONTEXT_PARAMETER_TYPE mld_alloc_ctx_t *

/******************************************************************************
 * Name:        MLD_CONFIG_CUSTOM_ALLOC_FREE [EXPERIMENTAL]
 *
 * Description: Set this option and define `MLD_CUSTOM_ALLOC` and
 *              `MLD_CUSTOM_FREE` if you want to use custom allocation for
 *              large local structures or buffers.
 *
 *              By default, all buffers/structures are allocated on the stack.
 *              If this option is set, most of them will be allocated via
 *              MLD_CUSTOM_ALLOC.
 *
 *              Parameters to MLD_CUSTOM_ALLOC:
 *              - T* v: Target pointer to declare.
 *              - T: Type of structure to be allocated
 *              - N: Number of elements to be allocated.
 *
 *              Parameters to MLD_CUSTOM_FREE:
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
 *              NOTE: MLD_CUSTOM_ALLOC need not guarantee a successful
 *              allocation nor include error handling. Upon failure, the
 *              target pointer should simply be set to NULL. The calling
 *              code will handle this case and invoke MLD_CUSTOM_FREE.
 *
 *****************************************************************************/
#define MLD_CONFIG_CUSTOM_ALLOC_FREE

#define MLD_CUSTOM_ALLOC(v, T, N, context) \
  T *(v) = (T *)mld_alloc((context), sizeof(T) * (N))

#define MLD_CUSTOM_FREE(v, T, N, context) \
  mld_free((void *)(v), (context), sizeof(T) * (N))

#endif

/******************************************************************************
 * Name:        MLD_CONFIG_REDUCE_RAM [EXPERIMENTAL]
 *
 * Description: Set this to reduce RAM usage.
 *              This trades memory for performance.
 *
 *              For expected memory usage, see the MLD_TOTAL_ALLOC_* constants
 *              defined in mldsa_native.h.
 *
 *              This option is useful for embedded systems with tight RAM
 *              constraints but relaxed performance requirements.
 *
 *              WARNING: This option is experimental!
 *              CBMC proofs do not currently cover this configuration option.
 *              Its scope and configuration may change at any time.
 *
 *****************************************************************************/
#define MLD_CONFIG_REDUCE_RAM

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_CONFIG_H_
