/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Register aliases */
.equ sp, x2
.equ x3, fp
.equ x5, t0
.equ x6, t1
.equ x7, t2
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x18, s2
.equ x19, s3
.equ x20, s4
.equ x21, s5
.equ x22, s6
.equ x23, s7
.equ x24, s8
.equ x25, s9
.equ x26, s10
.equ x27, s11
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6



/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA

/*
 * Name:        poly_getnoise_eta_init
 *
 * Description: Prepares for polynomial CBD sampling via either of
 *              `poly_getnoise_eta_1` or `poly_getnoise_eta_2` given a seed and
 *              a nonce by initializing a SHAKE256 operation.
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x11: *nonce
 *
 * clobbered registers: x5, w0
 * clobbered flag groups: None
 */

.globl poly_getnoise_eta_init
.type poly_getnoise_eta_init, @function
poly_getnoise_eta_init:
  /* Initialize a SHAKE256 operation. */
  addi  t0, x0, 33
  slli  t0, t0, 5
  addi  t0, t0, SHAKE256_CFG
  csrrw x0, kmac_cfg, t0

  /* Send the message to the Keccak core. */
  bn.lid  x0, 0(a0)
  bn.wsrw kmac_msg, w0
  li      t0, 1
  csrrw   x0, kmac_partial_write, t0
  bn.lid  x0, 0(a1)
  bn.wsrw kmac_msg, w0
  ret

/*
 * Name:        poly_getnoise_eta_1
 *
 * Description: Sample a polynomial deterministically from a seed and a nonce,
 *              with output polynomial close to centered binomial
 *              distribution with parameter KYBER_ETA1; this function assumes
 *              `poly_getnoise_eta_init` has been called first with the
 *              appropriate seed and nonce
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: eta
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4 to x6, x10 to x11, x17, x19 to x21, w0 to w9, w11, w20 to w21
 * clobbered flag groups: FG0
 */

.globl poly_getnoise_eta_1
.type poly_getnoise_eta_1, @function
poly_getnoise_eta_1:
    addi x4, x0, 3
    beq  a0, x4, _handle_cbd3
    jal  x1, cbd2
    ret
_handle_cbd3:
    jal x1, cbd3
    ret

/*
 * Name:        poly_getnoise_eta_2
 *
 * Description: Sample a polynomial deterministically from a seed and a nonce,
 *              with output polynomial close to centered binomial distribution
 *              with parameter KYBER_ETA2; this function assumes
 *              `poly_getnoise_eta_init` has been called first with the
 *              appropriate seed and nonce
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: eta
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4 to x11, x17, w0 to w4, w6 to w8
 * clobbered flag groups: FG0
 */

.globl poly_getnoise_eta_2
.type poly_getnoise_eta_2, @function
poly_getnoise_eta_2:
  jal x1, cbd2
  ret

/*
 * Name:        cbd2
 *
 * Description: Given an array of uniformly random bytes, compute
 *              polynomial with coefficients distributed according to
 *              a centered binomial distribution with parameter eta=2
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 * @param[in]  kmac_digest: SHAKE-256 squeeze set up by poly_getnoise_eta_init
 * @param[in]  mod: R | Q
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: FG0
 */

.globl cbd2
.type cbd2, @function
cbd2:
    /* Load cbd2_const */
    la     t0, cbd2_const
    addi   x4, x0, 3
    bn.lid x4++, 0(t0)
    bn.lid x4, 32(t0)

    /* Create mask 0xff. */
    bn.subi    w8, w31, 1
    bn.shv.16h w8, w8 >> 12

    addi x4, x0, 2
    loopi 4, 19
        bn.wsrr w0, kmac_digest   /* Load input array of 2*256/4=128 bytes --> 4 wrs */
        bn.and  w1, w0, w3        /* Extract even bits */
        bn.rshi w0, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w0, w0, w3        /* Extract odd bits */
        bn.add  w0, w0, w1        /* Add even and odd bits */
        bn.and  w1, w0, w4        /* Extract even bit couple */
        bn.rshi w0, w31, w0 >> 2  /* w0 >> 2 */
        bn.and  w0, w0, w4        /* Extract odd bit couple */

        loopi 4,  9
            loopi 16, 4
                bn.rshi w6, w1, w6 >> 16
                bn.rshi w7, w0, w7 >> 16
                bn.rshi w1, w31, w1 >> 4
                bn.rshi w0, w31, w0 >> 4
            endloop
            bn.and       w6, w6, w8
            bn.and       w7, w7, w8
            bn.subvm.16h w2, w6, w7
            bn.sid       x4, 0(a1++)
        endloop
        nop
    endloop
    ret

/*
 * Name:        cbd3
 *
 * Description: Given an array of uniformly random bytes, compute
 *              polynomial with coefficients distributed according to
 *              a centered binomial distribution with parameter eta=3.
 *              This function is only needed for Kyber-512
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 * @param[in]  kmac_digest: SHAKE-256 squeeze set up by poly_getnoise_eta_init
 * @param[in]  mod: R | Q
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: FG0
 */

.globl cbd3
.type cbd3, @function
cbd3:
    /* Load cbd3_const */
    la     t0, cbd3_const
    addi   x4, x0, 20
    bn.lid x4++, 0(t0)
    bn.lid x4, 32(t0)

    /* Create mask 0x7. */
    #define wmask w10
    bn.subi    wmask, w31, 1
    bn.shv.16h wmask, wmask >> 13

    addi t0, x0, 11
    loopi 2, 114
        /* Load inpput array of 2*256/4=128 bytes --> 4 wrs */
        bn.wsrr w0, kmac_digest
        bn.wsrr w1, kmac_digest
        bn.wsrr w2, kmac_digest

        bn.and  w3, w0, w20       /* extract mod3=0 bit of w0 */
        bn.rshi w4, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w4, w4, w20       /* extract mod3=1 bit of w0 */
        bn.rshi w5, w31, w0 >> 2  /* w0 >> 1 */
        bn.and  w5, w5, w20       /* extract mod3=2 bit of w0 */
        bn.add  w3, w3, w4
        bn.add  w3, w3, w5        /* w3 stores 85 intermediate values */

        bn.rshi w0, w1, w0 >> 255 /* w0 stores last bit of old w0, and 255 bits of w1 */
        bn.and  w4, w0, w20       /* extract mod3=0 bit of w0 */
        bn.rshi w5, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w5, w5, w20       /* extract mod3=1 bit of w0 */
        bn.rshi w6, w31, w0 >> 2  /* w0 >> 2 */
        bn.and  w6, w6, w20       /* extract mod3=2 bit of w0 */
        bn.add  w4, w4, w5
        bn.add  w4, w4, w6        /* w4 stores 85 intermediate values */

        bn.rshi w0, w2, w1 >> 254 /* w0 stores 2 last bits of w1, and 254 bits of w2 */
        bn.and  w5, w0, w20       /* extract mod3=0 bit of w0 */
        bn.rshi w6, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w6, w6, w20       /* extract mod3=1 bit of w0 */
        bn.rshi w7, w31, w0 >> 2  /* w0 >> 2 */
        bn.and  w7, w7, w20       /* extract mod3=2 bit of w0 */
        bn.add  w5, w5, w6
        bn.add  w5, w5, w7        /* w5 stores 85 intermediate values */

        bn.rshi w0, w31, w2 >> 253 /* w0 stores 3 last bits of w2 */
        bn.and  w6, w0, w20       /* extract first bit of w0 */
        bn.rshi w0, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w7, w0, w20       /* extract second bit of w0 */
        bn.rshi w0, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w0, w0, w20       /* extract third bit of w0 */
        bn.add  w6, w6, w7
        bn.add  w6, w6, w0        /* w6 stores 1 intermediate value */

        bn.and  w0, w3, w21       /* and 0x000111 */
        bn.rshi w3, w31, w3 >> 3  /* w3 >> 3 */
        bn.and  w3, w3, w21       /* and 0x000111 */

        bn.and  w1, w4, w21       /* and 0x000111 */
        bn.rshi w4, w31, w4 >> 3  /* w4 >> 3 */
        bn.and  w4, w4, w21       /* and 0x000111 */

        bn.and  w2, w5, w21       /* and 0x000111 */
        bn.rshi w5, w31, w5 >> 3  /* w5 >> 3 */
        bn.and  w5, w5, w21       /* and 0x000111 */

        /* Compute 16*3=48 coeffs */
        loopi 2, 9
            loopi 16, 4
                bn.rshi w8, w0, w8 >> 16
                bn.rshi w9, w3, w9 >> 16
                bn.rshi w0, w31, w0 >> 6
                bn.rshi w3, w31, w3 >> 6
            endloop
            bn.and       w8, w8, wmask
            bn.and       w9, w9, wmask
            bn.subvm.16h w11, w8, w9
            bn.sid t0, 0(a1++)
        endloop
        loopi 10, 4
            bn.rshi w8, w0, w8 >> 16
            bn.rshi w9, w3, w9 >> 16
            bn.rshi w0, w31, w0 >> 6
            bn.rshi w3, w31, w3 >> 6
        endloop
        bn.rshi w8, w0, w8 >> 16
        bn.rshi w9, w1, w9 >> 16
        bn.rshi w1, w31, w1 >> 6
        loopi 5, 4
            bn.rshi w8, w4, w8 >> 16
            bn.rshi w9, w1, w9 >> 16
            bn.rshi w1, w31, w1 >> 6
            bn.rshi w4, w31, w4 >> 6
        endloop
        bn.and       w8, w8, wmask
        bn.and       w9, w9, wmask
        bn.subvm.16h w11, w8, w9
        bn.sid       t0, 0(a1++)

        /* Compute 16*3=48 coeffs */
        loopi 2, 9
            loopi 16, 4
                bn.rshi w8, w4, w8 >> 16
                bn.rshi w9, w1, w9 >> 16
                bn.rshi w1, w31, w1 >> 6
                bn.rshi w4, w31, w4 >> 6
            endloop
            bn.and       w8, w8, wmask
            bn.and       w9, w9, wmask
            bn.subvm.16h w11, w8, w9
            bn.sid       t0, 0(a1++)
        endloop
        loopi 5, 4
            bn.rshi w8, w4, w8 >> 16
            bn.rshi w9, w1, w9 >> 16
            bn.rshi w1, w31, w1 >> 6
            bn.rshi w4, w31, w4 >> 6
        endloop
        loopi 11, 4
            bn.rshi w8, w2, w8 >> 16
            bn.rshi w9, w5, w9 >> 16
            bn.rshi w2, w31, w2 >> 6
            bn.rshi w5, w31, w5 >> 6
        endloop
        bn.and       w8, w8, wmask
        bn.and       w9, w9, wmask
        bn.subvm.16h w11, w8, w9
        bn.sid       t0, 0(a1++)

        /* Compute 16*2=32 coeffs */
        loopi 16, 4
            bn.rshi w8, w2, w8 >> 16
            bn.rshi w9, w5, w9 >> 16
            bn.rshi w2, w31, w2 >> 6
            bn.rshi w5, w31, w5 >> 6
        endloop
        bn.and       w8, w8, wmask
        bn.and       w9, w9, wmask
        bn.subvm.16h w11, w8, w9
        bn.sid       t0, 0(a1++)
        loopi 15, 4
            bn.rshi w8, w2, w8 >> 16
            bn.rshi w9, w5, w9 >> 16
            bn.rshi w2, w31, w2 >> 6
            bn.rshi w5, w31, w5 >> 6
        endloop
        bn.rshi      w8, w2, w8 >> 16
        bn.rshi      w9, w6, w9 >> 16
        bn.and       w8, w8, wmask
        bn.and       w9, w9, wmask
        bn.subvm.16h w11, w8, w9
        bn.sid       t0, 0(a1++)
    endloop
    ret
