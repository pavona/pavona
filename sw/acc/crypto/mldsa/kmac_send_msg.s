/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/**
 * Send a variable-length message to the Keccak core.
 *
 * Expects the Keccak core to have already received a `start` command matching
 * the desired hash function. After calling this routine, reading from the
 * KECCAK_DIGEST special register will return the hash digest.
 *
 * This function can be called repeatedly before reading the digest. On return,
 * dptr_msg is updated to point to the end of the source buffer.
 *
 * @param[in]  x11: len, byte-length of the message
 * @param[in]  x10: dptr_msg, pointer to message in DMEM
 * @param[in]  w31: all-zero
 * @param[in]  dmem[dptr_msg..dptr_msg+len]: msg, hash function input
 *
 * clobbered registers: x5, x10, w0
 * clobbered flag groups: none
 */
.globl keccak_send_message
.type keccak_send_message, @function
keccak_send_message:
  /* Compute the number of full 256-bit message chunks.
  x5 <= x11 >> 5 = floor(len / 32) */
  srli x5, x11, 5

  /* Write all full 256-bit sections of the test message. */
  beq x5, x0, _no_full_wdr

  loop x5, 2
    /* w0 <= dmem[x10..x10+32] = msg[32*i..32*i-1]
       x10 <= x10 + 32 */
    bn.lid  x0, 0(x10++)
    /* Write to the KECCAK_MSG wide special register (index 9).
       KECCAK_MSG <= w0 */
    bn.wsrw kmac_msg, w0
  endloop

_no_full_wdr:
  /* Compute the remaining message length.
       x5 <= x11 & 31 = len mod 32 */
  andi x5, x11, 31

  /* If the remaining length is zero, return early. */
  beq x5, x0, _keccak_send_message_end

  /* Send a partial-word write. */
  csrrw   x0, kmac_partial_write, x5
  bn.lid  x0, 0(x10)
  bn.wsrw kmac_msg, w0

  /* Increment the source pointer to reflect the partial write. */
  add x10, x10, x5

  _keccak_send_message_end:
  ret
