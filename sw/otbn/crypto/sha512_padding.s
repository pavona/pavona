/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Compute the padding suffix given the message length.
 *
 * Given a pointer into DMEM and the message length in bytes, appends padding
 * to the message as needed.
 *
 * The padding process results in the bytes:
 *   msg || 0x80 || <zeroes> || len(msg)
 *
 * ...where len(msg) is a 128-bit big-endian encoding of the message length in
 * bits, and the total padded message length is a multiple of 1024 bits.
 *
 * The length of the message itself is at most (2^125 - 1) bytes, because its
 * bit-length must fit in 128 bits. However, it is provided as 256 bits to
 * support wide-word reasoning, and the pointer must be 32-bit aligned.
 *
 * The caller must ensure that the start of the message block is 32-bit aligned
 * (even if that means dptr_pad is not) and that there is enough space in DMEM
 * at the end of the message for the padding.  Precisely, the padded length
 * will be the smallest multiple of 1024 bits (128 bytes) that will fit the
 * message plus 9 bytes.
 *
 * Note that 136 bytes after the message is always enough; this is the maximum
 * padding length.
 *
 * This routine runs in constant time relative to message content but variable
 * time relative to message length.
 *
 * @param[in]  x10: dptr_pad, pointer to end of message in DMEM
 * @param[in]  x11: dptr_len, pointer to message length in bytes (256 bits)
 * @param[in]  w31: all-zero
 * @param[out] x21: dptr_end, pointer to the end of the padding
 * @param[out] dmem[dptr_pad..dptr_end]: message padding
 *
 * clobbered registers: x2 to x5, x20 to x23, w27
 * clobbered flag groups: FG0
 */
.globl sha512_pad_message
sha512_pad_message:
  /* Align the address and compute the offset.
       x20 <= dptr_pad % 4
       x21 <= dptr_pad // 4 */
  andi    x20, x10, 3
  xor     x21, x10, x20

  /* Load the first word past the padding. Skip if the offset is zero, because
     the word might not be initialized and we don't need the data anyway.
       x2 <= if x20 == 0 then 0 else dmem[x21] */
  li      x2, 0
  beq     x0, x20, _sha512_pad_message_skip_load
  lw      x2, 0(x21)

  /* Clear the remaining (high) bytes of the loaded word.
       x2 <= (x2 << (8 * (4 - x20))) >> 8 * (4 - x20)
       x2 <= x2 & (2^(8 * x20) - 1) */
  li      x3, 4
  sub     x3, x3, x20
  slli    x3, x3, 3
  sll     x2, x2, x3
  srl     x2, x2, x3
  _sha512_pad_message_skip_load:

  /* Set the first (least significant, because OTBN is little-endian) padding
     byte to 0x80, and fill remainder of word with zeroes.
       dmem[x21] = x2 ^ (0x80 << (8 * x20) */
  slli    x3, x20, 3
  li      x4, 0x80
  sll     x4, x4, x3
  xor     x2, x2, x4
  sw      x2, 0(x21)
  addi    x21, x21, 4

  /* Compute the number of bytes we just set in the first word.
       x22 <= 4 - x20 = 4 - (dptr_pad % 4) */
  li      x2, 4
  sub     x22, x2, x20

  /* Get the number of 32b *words* in the block that are now set.
       x4 <= ((len + x22) mod 128) / 4  */
  lw      x4, 0(x11)
  add     x4, x4, x22
  andi    x4, x4, 127
  srli    x4, x4, 2

  /* Determine the number of additional zero words needed.
       x4 <= if x4 + 4 <= 32
             then 32 - x3 - 4
             else 64 - x3 - 4  */
  addi    x4, x4, 4
  srli    x3, x4, 5
  li      x5, 32
  beq     x0, x3, _sha512_pad_message_skip_add
  addi    x5, x5, 32
  _sha512_pad_message_skip_add:
  sub     x4, x5, x4

  /* Set the additional zero words. */
  loop    x4, 2
    sw      x0, 0(x21)
    addi    x21, x21, 4

  /* Convert the message byte-length to bit-length in-place.
       dmem[dptr_len] <= dmem[dptr_len] << 3 */
  li      x4, 27
  bn.lid  x4, 0(x11)
  bn.rshi w27, w27, w31 >> 253
  bn.sid  x4, 0(x11)

  /* Write the bit-length in reverse byte-order (big-endian). This forms the
     final 128 bits of the message block.
       dmem[x21..x21+16] <= byteswap(dmem[dptr_len][127:0]) */
  addi    x4, x11, 12
  loopi   4, 5
    lw      x23, 0(x4)
    addi    x4, x4, -4
    jal     x1, bswap32
    sw      x23, 0(x21)
    addi    x21, x21, 4

  ret

/**
 * Swap the bytes in a 32-bit word, in-place.
 *
 * The implementation is optimized for small code size rather than speed.
 *
 * This routine runs in constant time.
 *
 * @param[in]  x23: w, input word (w[0] || w[1] || w[2] || w[3])
 * @param[out] x23: result (w[3] || w[2] || w[1] || w[0])
 *
 * clobbered registers: x2, x3, x23
 * clobbered flag groups: FG0
 */
bswap32:
  /* x2 <= w[0] << 24 */
  andi    x2, x23, 255
  slli    x2, x2, 24
  /* x2 <= w[0] << 24 | w[1] << 16 */
  srli    x3, x23, 8
  andi    x3, x3, 255
  slli    x3, x3, 16
  or      x2, x2, x3
  /* x2 <= w[0] << 24 | w[1] << 16 | w[2] << 8 */
  srli    x3, x23, 16
  andi    x3, x3, 255
  slli    x3, x3, 8
  or      x2, x2, x3
  srli    x3, x23, 24
  /* x2 <= w[0] << 24 | w[1] << 16 | w[2] << 8 | w[3] */
  or      x23, x2, x3
  ret

.bss

/* number of chunks to process */
.globl n_chunks
.weak n_chunks
.balign 4
n_chunks:
  .zero 4

/* pointer to state (dptr_state) */
.globl dptr_state
.balign 4
dptr_state:
  .zero 4

/* pointer to msg (dptr_msg) */
.globl dptr_msg
.balign 4
dptr_msg:
  .zero 4
