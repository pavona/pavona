/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

.text
.equ x5, t0

/**
 * Send a variable-length message to the Keccak core.
 *
 * Expects the Keccak core to have already received a `start` command matching
 * the desired hash function. After calling this routine, reading from the
 * KECCAK_DIGEST special register will return the hash digest.
 *
 * @param[in]   a1: len, byte-length of the message
 * @param[in]   a0: dptr_msg, pointer to message in DMEM
 * @param[in]   w31: all-zero
 * @param[in] dmem[dptr_msg..dptr_msg+len]: msg, hash function input
 *
 * clobbered registers: t0, a1, w0
 * clobbered flag groups: None
 */
.globl keccak_send_message
keccak_send_message:
  /* Compute the number of full 256-bit message chunks.
  t0 <= x11 >> 5 = floor(len / 32) */
  srli t0, x11, 5

  /* Write all full 256-bit sections of the test message. */
  beq  t0, zero, _no_full_wdr

#ifdef RTL_ISS_TEST
  loop t0, 5
#else
  loop t0, 2
#endif
      /* w0 <= dmem[x10..x10+32] = msg[32*i..32*i-1]
         x10 <= x10 + 32 */
      bn.lid  x0, 0(x10++)
      /* Write to the KECCAK_MSG wide special register (index 9).
         KECCAK_MSG <= w0 */
      bn.wsrw 0x9, w0
#ifdef RTL_ISS_TEST
      LOOPI 300, 1
        NOP
      NOP
#endif

_no_full_wdr:
  /* Compute the remaining message length.
       t0 <= x11 & 31 = len mod 32 */
  andi t0, x11, 31

  /* If the remaining length is zero, return early. */
  beq t0, x0, _keccak_send_message_end

  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0

  _keccak_send_message_end:
  ret
