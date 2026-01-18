// Copyright The mlkem-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_ALLOC_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_ALLOC_H_

#include <stddef.h>
#include <stdint.h>

#include "mlkem/src/sys.h"

// Bump allocator context
typedef struct {
  uint32_t *base;       // Base pointer to start of buffer
  size_t size_words;    // Total size of buffer (in words)
  size_t offset_words;  // Current offset into buffer (in words)
} mlk_alloc_ctx_t;

/**
 * Allocate memory from bump allocator
 *
 * @param ctx Allocator context
 * @param size_bytes Number of bytes to allocate
 * @return Pointer to allocated memory, or NULL if out of space
 */
void *mlk_alloc(mlk_alloc_ctx_t *ctx, size_t size_bytes);

/**
 * Free memory from bump allocator
 *
 * Decrements the allocator offset. This is a simple bump allocator,
 * so freeing must be done in reverse order of allocation.
 *
 * @param ptr Pointer to free (may be NULL, in which case this is a no-op)
 * @param ctx Allocator context
 * @param size_bytes Number of bytes to free
 */
void mlk_free(void *ptr, mlk_alloc_ctx_t *ctx, size_t size_bytes);

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_IMPL_MLKEM_MLKEM_NATIVE_ALLOC_H_
