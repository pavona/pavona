// Copyright The mldsa-native project authors
//  Copyright zeroRISC Inc.
//  Licensed under the Apache License, Version 2.0, see LICENSE for details.
//  SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_MLDSA_NATIVE_CONFIG_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_MLDSA_NATIVE_CONFIG_H_

/**
 * MLD_CONFIG_MULTILEVEL_BUILD
 *
 * Set this if the build is part of a multi-level build supporting
 * multiple parameter sets.
 *
 * If you need only a single parameter set, keep this unset.
 *
 * To build mldsa-native with support for all parameter sets,
 * build it three times -- once per parameter set -- and set the
 * option MLD_CONFIG_MULTILEVEL_WITH_SHARED for exactly one of
 * them, and MLD_CONFIG_MULTILEVEL_NO_SHARED for the others.
 * MLD_CONFIG_MULTILEVEL_BUILD should be set for all of them.
 *
 * See examples/multilevel_build for an example.
 *
 * This can also be set using CFLAGS.
 */
#define MLD_CONFIG_MULTILEVEL_BUILD

/**
 * MLD_CONFIG_NAMESPACE_PREFIX
 *
 * The prefix to use to namespace global symbols from mldsa/.
 *
 * In a multi-level build, level-dependent symbols will
 * additionally be prefixed with the parameter set (44/65/87).
 *
 * This can also be set using CFLAGS.
 */
#define MLD_CONFIG_NAMESPACE_PREFIX mldsa

/**
 * MLD_CONFIG_NO_RANDOMIZED_API
 *
 * If this option is set, mldsa-native will be built without the
 * randomized API functions (keypair,
 * signature, and signature_extmu).
 * This allows users to build mldsa-native without providing a
 * randombytes() implementation if they only need the
 * internal deterministic API
 * (keypair_internal, signature_internal).
 *
 * @note This option is incompatible with MLD_CONFIG_KEYGEN_PCT
 * as the current PCT implementation requires
 * signature().
 */
#define MLD_CONFIG_NO_RANDOMIZED_API

/**
 * MLD_CONFIG_INTERNAL_API_QUALIFIER
 *
 * If set, this option provides an additional qualifier
 * to be added to declarations of internal API functions and data.
 *
 * The primary use case for this option are single-CU builds,
 * in which case this option can be set to `static`.
 */
#define MLD_CONFIG_INTERNAL_API_QUALIFIER static

/**
 * MLD_CONFIG_FIPS202_CUSTOM_HEADER
 *
 * Custom header to use for FIPS-202
 *
 * This should only be set if you intend to use a custom
 * FIPS-202 implementation, different from the one shipped
 * with mldsa-native.
 *
 * If set, it must be the name of a file serving as the
 * replacement for mldsa/src/fips202/fips202.h, and exposing
 * the same API (see FIPS202.md).
 */
#define MLD_CONFIG_FIPS202_CUSTOM_HEADER "fips202_glue.h"

/**
 * MLD_CONFIG_SERIAL_FIPS202_ONLY
 *
 * Set this to use a FIPS202 implementation with global state
 * that supports only one active Keccak computation at a time
 * (e.g. some hardware accelerators).
 *
 * If this option is set, ML-DSA will use FIPS202 operations
 * serially, ensuring that only one SHAKE context is active
 * at any given time.
 *
 * This allows offloading Keccak computations to a hardware
 * accelerator that holds only a single Keccak state locally,
 * rather than requiring support for multiple concurrent
 * Keccak states.
 *
 * @note Depending on the target CPU, this may reduce
 * performance when using software FIPS202 implementations.
 * Only enable this when you have to.
 */
#define MLD_CONFIG_SERIAL_FIPS202_ONLY

/**
 * MLD_CONFIG_CONTEXT_PARAMETER
 *
 * Set this to add a caller-supplied context parameter to the public API
 * functions, which is then forwarded unchanged to the custom callbacks
 * (allocation, and signing hooks below).
 *
 * When this option is set, every public API function gains a trailing
 * parameter
 *
 *   MLD_CONFIG_CONTEXT_PARAMETER_TYPE context
 *
 * as its last argument; its type is configured via
 * MLD_CONFIG_CONTEXT_PARAMETER_TYPE (see below). mldsa-native treats this
 * value as opaque: it never dereferences it and only passes it on to the
 * configurable hook macros. It is meant to carry per-caller state -- e.g. a
 * pointer to a memory pool for the allocation hooks, or the resume state for
 * the signing hooks -- into those hooks.
 *
 * When this option is unset (the default), no extra parameter is added and
 * the hook macros never receive a context argument.
 *
 * The hooks that receive the context are the allocation hooks (see
 * MLD_CONFIG_CUSTOM_ALLOC_FREE) and the signing hooks (see
 * MLD_CONFIG_SIGN_HOOK_RESUME / _ATTEMPT / _FINISH); each is documented with
 * its own option below.
 */
#define MLD_CONFIG_CONTEXT_PARAMETER

#if !defined(__ASSEMBLER__)
#include "sw/device/lib/crypto/impl/mldsa/mldsa-native/mldsa_native_alloc.h"

/**
 * MLD_CONFIG_CONTEXT_PARAMETER_TYPE
 *
 * Set this to define the type of the context parameter added by
 * MLD_CONFIG_CONTEXT_PARAMETER. It can be any C type usable as a function
 * parameter, e.g. `void *` or a pointer to a caller-defined struct such as
 * `struct my_ctx *`.
 *
 * This option must be defined if and only if MLD_CONFIG_CONTEXT_PARAMETER is
 * defined; defining one without the other is a compile-time error.
 */
#define MLD_CONFIG_CONTEXT_PARAMETER_TYPE mld_alloc_ctx_t *

/**
 * MLD_CONFIG_CUSTOM_ALLOC_FREE
 *
 * Set this option and define `MLD_CUSTOM_ALLOC` and
 * `MLD_CUSTOM_FREE` if you want to use custom allocation for
 * large local structures or buffers.
 *
 * By default, all buffers/structures are allocated on the stack.
 * If this option is set, most of them will be allocated via
 * MLD_CUSTOM_ALLOC.
 *
 * Parameters to MLD_CUSTOM_ALLOC:
 * - T* v: Target pointer to declare.
 * - T: Type of structure to be allocated
 * - N: Number of elements to be allocated.
 *
 * Parameters to MLD_CUSTOM_FREE:
 * - T* v: Target pointer to free. May be NULL.
 * - T: Type of structure to be freed.
 * - N: Number of elements to be freed.
 *
 * If MLD_CONFIG_CONTEXT_PARAMETER is set, both macros receive the
 * context as a fourth parameter, e.g. MLD_CUSTOM_ALLOC(v, T, N, context):
 * - context: The context passed to the public API function, of type
 *   MLD_CONFIG_CONTEXT_PARAMETER_TYPE.
 *
 * @note Even if this option is set, some allocations further down
 * the call stack will still be made from the stack. Those will
 * likely be added to the scope of this option in the future.
 *
 * @note MLD_CUSTOM_ALLOC need not guarantee a successful
 * allocation nor include error handling. Upon failure, the
 * target pointer should simply be set to NULL. The calling
 * code will handle this case and invoke MLD_CUSTOM_FREE.
 */
#define MLD_CONFIG_CUSTOM_ALLOC_FREE

/** Custom allocator, see MLD_CONFIG_CUSTOM_ALLOC_FREE. */
#define MLD_CUSTOM_ALLOC(v, T, N, context) \
  T *(v) = (T *)mld_alloc((context), sizeof(T) * (N))

/** Custom deallocator, see MLD_CONFIG_CUSTOM_ALLOC_FREE. */
#define MLD_CUSTOM_FREE(v, T, N, context) \
  mld_free((void *)(v), (context), sizeof(T) * (N))

#endif

/**
 * MLD_CONFIG_REDUCE_RAM
 *
 * Set this to reduce RAM usage. This trades memory for performance.
 *
 * For expected memory usage, see the MLD_TOTAL_ALLOC_* constants defined in
 * mldsa_native.h.
 *
 * This option is useful for embedded systems with tight RAM constraints but
 * relaxed performance requirements.
 *
 */
#define MLD_CONFIG_REDUCE_RAM

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLDSA_MLDSA_NATIVE_MLDSA_NATIVE_CONFIG_H_
