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
 * kmac_digest special register returns the hash digest.
 *
 * Sends the message as full 32-byte chunks, followed by a single partial write
 * of the remaining len mod 32 bytes when the length is not a multiple of 32.
 *
 * On return, x10 points just past the last full 32-byte chunk sent; a trailing
 * partial chunk is read without advancing x10.
 *
 * @param[in]  x10: dmem pointer to the message
 * @param[in]  x11: byte length of the message
 *
 * clobbered registers: x5, x10, w0
 * clobbered flag groups: none
 */

.globl keccak_send_message
.type keccak_send_message, @function
keccak_send_message:
  /* Compute the number of full 256-bit message chunks. */
  srli x5, x11, 5
  beq  x5, x0, _no_full_wdr

  loop x5, 2
    bn.lid  x0, 0(x10++)
    bn.wsrw kmac_msg, w0
  endloop

_no_full_wdr:
  /* Compute the remaining message length. */
  andi x5, x11, 31
  /* If the remaining length is zero, return early. */
  beq  x5, x0, _keccak_send_message_end

  csrrw   x0, kmac_partial_write, x5
  bn.lid  x0, 0(x10)
  bn.wsrw kmac_msg, w0

_keccak_send_message_end:
  ret
