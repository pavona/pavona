/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
#define t1 x6
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

#ifndef NSHARES
  #define NSHARES 2
#endif

#define KBITS    23
#define CRHBYTES 64

#ifndef DILITHIUM_MODE
  #error "masked_poly_uniform_gamma_1 requires DILITHIUM_MODE"
#endif

#if DILITHIUM_MODE == 2
  #define POLYZ_BITS    18
  #define SQUEEZE_WORDS 18
  #define RAW0_OFFSET   448    /* 1024 - 18*32 */
  #define RAW1_OFFSET   1472   /* 2048 - 18*32 */
#elif DILITHIUM_MODE == 3 || DILITHIUM_MODE == 5
  #define POLYZ_BITS    20
  #define SQUEEZE_WORDS 20
  #define RAW0_OFFSET   384    /* 1024 - 20*32 */
  #define RAW1_OFFSET   1408   /* 2048 - 20*32 */
#else
  #error "masked_poly_uniform_gamma_1: unsupported DILITHIUM_MODE"
#endif

#define SHAKE256_CFG 0xA

#define SP_FRAME 32

/*
 * Name: masked_poly_uniform_gamma_1 (PINI, d=2)
 *
 * Masked version of poly_uniform_gamma_1: sample a 2-share arithmetic
 * sharing of y mod q with y = gamma1 - u, u uniform in [0, 2^POLYZ_BITS).
 * Differs from the unmasked version in that rho'|nonce go through the
 * masked KMAC interface and the squeezed u stays masked through
 * bitslice -> secb2amodq_bc22 -> unbitslice before the gamma1 - u step.
 *
 * @param[out]  a0: dptr_out, 2 * 1024 B output.
 * @param[in]   a1: dptr_seed, 2 * CRHBYTES.
 * @param[in]   a2: nonce (uint16_t).
 * @param[in]   a3: dptr_scratch, 1536 B for internal seca2bmodq_bc22.
 * @param[in]   a4: dptr_buf, 1536 B bitsliced-u staging buffer.
 * @param[in]  w31: all-zero.
 *
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl masked_poly_uniform_gamma_1
masked_poly_uniform_gamma_1:
    addi sp, sp, -SP_FRAME
    sw   a0, 0(sp)                 /* save out pointer */
    sw   a3, 8(sp)                 /* save scratch_ptr for b2a */
    sw   a4, 12(sp)                /* save bitslice buffer ptr */

    bn.mov w28, w16
    bn.mov w29, w22
    bn.mov w30, w23

    /* Init masked SHAKE256, send rho'. */
    addi  a3, x0, CRHBYTES
    addi  a3, a3, 2
    slli  t0, a3, 5
    addi  t0, t0, SHAKE256_CFG
    addi  a3, x0, 1
    slli  a3, a3, 20
    add   t0, t0, a3
    csrrw x0, kmac_cfg, t0

    bn.lid  x0, 0(a1)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.lid  x0, 64(a1)
    bn.wsrw kmac_msg1, w0
    bn.lid  x0, 32(a1)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.lid  x0, 96(a1)
    bn.wsrw kmac_msg1, w0

    /* Send nonce (out[0..31] as scratch, overwritten later). */
    bn.sid  x0, 0(a0)
    sw      a2, 0(a0)
    bn.lid  x0, 0(a0)
    li      t0, 2
    csrrw   x0, kmac_partial_write, t0
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.wsrw kmac_msg1, w0

    /* Squeeze raw into the tail of each share's output slot so the
     * forward in-place unpack keeps writes below reads. */
    addi t1, a0, RAW0_OFFSET
    addi t2, a0, RAW1_OFFSET
    li   t3, 0
    li   t4, 1
    loopi SQUEEZE_WORDS, 4
        bn.wsrr w0, kmac_digest
        bn.wsrr w1, kmac_digest1
        bn.sid  t3, 0(t1++)
        bn.sid  t4, 0(t2++)

    /* Unpack each share in place (out[RAW..1023] -> out[0..1023]). */
    li   t0, 5
    la   t1, polyz_unpack_mask
    bn.lid t0, 0(t1)

    addi a1, a0, RAW0_OFFSET
    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    jal  ra, _unpack_share

    lw   a0, 0(sp)
    addi a1, a0, RAW1_OFFSET
    addi a0, a0, 1024
    /* Whitening */
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w6, w6, w6
    jal  ra, _unpack_share

    /* Bitslice each share to caller's buffer (top bit zeroed for k+1). */
    lw   a1, 0(sp)
    lw   a0, 12(sp)
    li   a2, 32
    jal  ra, bitslice
    lw   t1, 12(sp)
    addi t1, t1, 736
    li   t0, 31
    bn.sid t0, 0(t1)

    lw   a1, 0(sp)
    addi a1, a1, 1024
    lw   a0, 12(sp)
    addi a0, a0, 768
    li   a2, 32
    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w4, w4, w4
    bn.xor w5, w5, w5
    bn.xor w6, w6, w6
    bn.xor w7, w7, w7
    bn.xor w8, w8, w8
    bn.xor w9, w9, w9
    bn.xor w10, w10, w10
    bn.xor w11, w11, w11
    bn.xor w12, w12, w12
    bn.xor w13, w13, w13
    bn.xor w14, w14, w14
    bn.xor w15, w15, w15
    bn.xor w16, w16, w16
    bn.xor w17, w17, w17
    bn.xor w18, w18, w18
    bn.xor w19, w19, w19
    bn.xor w20, w20, w20
    bn.xor w21, w21, w21
    bn.xor w22, w22, w22
    bn.xor w23, w23, w23
    bn.xor w24, w24, w24
    bn.xor w25, w25, w25
    bn.xor w26, w26, w26
    bn.xor w27, w27, w27
    jal  ra, bitslice
    lw   t1, 12(sp)
    addi t1, t1, 1504
    li   t0, 31
    bn.sid t0, 0(t1)

    /* B2A: u^{B,k} (buffer) -> u^{A_p} at caller out. */
    lw   a1, 12(sp)
    lw   a0, 0(sp)
    lw   a3, 8(sp)
    jal  ra, secb2amodq_bc22

    /* Unbitslice each share in place; share 1 first so its overlapping
     * write [1024..1503] doesn't clobber share 0's source. */
    lw   a0, 0(sp)
    addi a1, a0, 768
    addi a0, a0, 1024
    jal  ra, unbitslice

    lw   a0, 0(sp)
    addi a1, a0, 0
    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w4, w4, w4
    bn.xor w5, w5, w5
    bn.xor w6, w6, w6
    bn.xor w7, w7, w7
    bn.xor w8, w8, w8
    bn.xor w9, w9, w9
    bn.xor w10, w10, w10
    bn.xor w11, w11, w11
    bn.xor w12, w12, w12
    bn.xor w13, w13, w13
    bn.xor w14, w14, w14
    bn.xor w15, w15, w15
    bn.xor w16, w16, w16
    bn.xor w17, w17, w17
    bn.xor w18, w18, w18
    bn.xor w19, w19, w19
    jal  ra, unbitslice

    /* y = gamma1 - u on share 0, -u on share 1. */
    li     t0, 4
    la     t2, gamma1_vec_const
    bn.lid t0, 0(t2)

    lw   a0, 0(sp)
    li   t0, 0
    addi t1, a0, 0
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w4, w0
        bn.sid t0, 0(t1++)

    /* Whitening */
    bn.xor w0, w0, w0
    lw   a0, 0(sp)
    addi t1, a0, 1024
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w31, w0
        bn.sid t0, 0(t1++)

    bn.mov w16, w28
    bn.mov w22, w29
    bn.mov w23, w30

    addi sp, sp, SP_FRAME
    ret


/* Per-share unpack (caller pre-loads w5 = polyz_unpack_mask). */
_unpack_share:
    addi t1, a0, 0
    addi t6, a1, 0
    li   t2, 2
    li   t0, 6
    li   t3, 3

#if POLYZ_BITS == 18
    /* L2: 2 outer x 16 inner unpacks (144 raw bits each). */
    loopi 2, 42
        bn.lid  t0, 0(t6++)
        bn.mov  w1, w6
        jal     x1, _unpack_inner

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 144
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w3 >> 32
        jal     x1, _unpack_inner

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 176
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w6 >> 64
        jal     x1, _unpack_inner

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 208
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w3 >> 96
        jal     x1, _unpack_inner

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 240
        jal     x1, _unpack_inner

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w3 >> 16
        jal     x1, _unpack_inner

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 160
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w6 >> 48
        jal     x1, _unpack_inner

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 192
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w3 >> 80
        jal     x1, _unpack_inner

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w6 >> 112
        jal     x1, _unpack_inner
        nop

    ret

#elif POLYZ_BITS == 20
    /* L3/L5: 4 outer x 8 inner unpacks (160 raw bits each). */
    loopi 4, 22
        bn.lid  t0, 0(t6++)
        bn.mov  w1, w6
        jal     x1, _unpack_inner

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 160
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w3 >> 64
        jal     x1, _unpack_inner

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _unpack_inner

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w3 >> 32
        jal     x1, _unpack_inner

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 192
        jal     x1, _unpack_inner

        bn.rshi w1, w31, w6 >> 96
        jal     x1, _unpack_inner
        nop

    ret
#endif

/* Inner: extract 8 coefs from w1, mask, store at t1++. */
_unpack_inner:
    loopi 8, 2
        bn.rshi w2, w1, w2 >> 32
        bn.rshi w1, w31, w1 >> POLYZ_BITS
    bn.and w2, w2, w5
    bn.sid t2, 0(t1++)
    ret
