// Copyright The mldsa-native project authors
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/impl/mldsa/mldsa_native_alloc.h"

#include "sw/device/lib/base/hardened.h"

void *mld_alloc(mld_alloc_ctx_t *ctx, size_t size_bytes) {
  size_t size_words = MLD_ALIGN_UP(size_bytes) / sizeof(uint32_t);
  size_t bytes_available =
      sizeof(uint32_t) * (ctx->size_words - ctx->offset_words);

  if (size_bytes > bytes_available) {
    return NULL;  // Out of space
  }

  void *ptr = (void *)(ctx->base + ctx->offset_words);
  ctx->offset_words += size_words;
  return ptr;
}

void mld_free(void *ptr, mld_alloc_ctx_t *ctx, size_t size_bytes) {
  if (ptr == NULL) {
    return;  // No-op if NULL
  }

  size_t size_words = MLD_ALIGN_UP(size_bytes) / sizeof(uint32_t);

  // Ensure freeing in reverse allocation order
  void *expected_ptr = (void *)(ctx->base + ctx->offset_words - size_words);
  HARDENED_CHECK_EQ(ptr, expected_ptr);

  ctx->offset_words -= size_words;
}
