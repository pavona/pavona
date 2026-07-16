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


/*
 * Name:        poly_compress
 *
 * Description: Compression and subsequent serialization of a polynomial
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out] x11: dptr_output, dmem pointer to output byte array
 * @param[in]  x12: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x0-x30, w0-w31
 */
.globl poly_compress
.type poly_compress, @function
poly_compress:
    /* Load const */
    la     t0, modulus_over_2
    addi   x4, x0, 2
    bn.lid x4, 0(t0) /* w2 = (0x681)^16 */
    la     t0, const_1290167
    addi   x4, x0, 5
    bn.lid x4, 0(t0) /* w5 = const_1290167 */

    addi x4, x0, 4
    beq  a2, x4, _handle_k4_poly_compress

_handle_kn4_poly_compress:

    /* Multiply the constant 80635 with 2**4 so that later we shift to the right
    * 32 bits instead of 28 bits. This means we can return the high parts of
    * the 64-bit products within the multiplication instruction. */
    bn.mov  w30, w16 /* Save w16 */
    bn.subi w16, w5, 7 /* w16 = 80635 * 16 = 1290160 */

    loopi 4, 16
        loopi 4, 14
            bn.lid               x0, 0(a0++) /* Load input */
            bn.shv.16h           w0, w0 << 4 /* <= 4 */
            bn.addv.16h          w0, w0, w2 /* += 1665 */
            bn.trn1.16h          w1, w0, w31 /* Put even coeffs to 32-bit slots */
            bn.mulv.l.8s.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
            bn.mulv.l.8s.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
            bn.trn2.16h          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
            bn.mulv.l.8s.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
            bn.mulv.l.8s.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
            bn.trn1.16h          w1, w1, w0 /* Interleaving the results to original order */
            loopi 16, 2
                bn.rshi w4, w1, w4 >> 4
                bn.rshi w1, w31, w1 >> 16
            endloop
            nop
        endloop
        bn.sid x4, 0(a1++)
    endloop
    bn.mov w16, w30 /* Restore w16. */
    ret

_handle_k4_poly_compress:

    bn.shv.8s w3, w2 >> 17 /* w3 = (0x340)^8 */
    bn.shv.8s w3, w3 << 1 /* w3 = (0x680)^8 */
    /* Multiply the constant 40318 with 2**5 (1290176) so that later we shift to the
    * right 32 bits instead of 28 bits. This means we can return the high parts of
    * the 64-bit products within the multiplication instruction. */
    bn.mov  w30, w16 /* Save w16 */
    bn.addi w16, w5, 9 /* w16 = 1290176 */

    /* First WDR: 80 bits (16 coeffs) + (Reload) 80 bits (16 coeffs) +
    * (Reload) 80 bits (16 coeffs) + (Reload) 15 bits (3 coeffs) + 1 bits */
    loopi 3, 6
    /* Load 1st + 2nd + 3rd batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_compress_16
        /* Pack 80 bits */
        loopi 16, 2
            bn.rshi w4, w1, w4 >> 5
            bn.rshi w1, w31, w1 >> 16
        endloop
        nop
    endloop
    /* Load 4th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_compress_16
    /* Pack 15 bits */
    loopi 3, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 1 bit */
    bn.rshi w4, w1, w4 >> 1
    bn.sid  x4, 0(a1++)

    /* Second WDR: 4 bits + 60 bits (12 coeffs) + (Reload) 80 bits + (Reload) 80 bits +
    * (Reload) 30 bits (6 coeffs) + 2 bits */
    /* Pack 4 bits + 60 bits */
    loopi 13, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    loopi 2, 6
        /* Load 5th + 6th batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_compress_16
        /* Pack 80 bits */
        loopi 16, 2
            bn.rshi w4, w1, w4 >> 5
            bn.rshi w1, w31, w1 >> 16
        endloop
        nop
    endloop
    /* Load 7th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_compress_16
    /* Pack 30 bits */
    loopi 6, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 2 bits */
    bn.rshi w4, w1, w4 >> 2
    bn.sid  x4, 0(a1++)

    /* Third WDR: 3 bits + 45 bits (9 coeffs) + (Reload) 80 bits (16 coeffs)
    * (Reload) 80 bits (16 coeffs) + (Reload) 45 bits (9 coeffs) + 3 bits */
    /* Pack 3 bits + 45 bits */
    loopi 10, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    loopi 2, 6
        /* Load 8th + 9th batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_compress_16
        /* Pack 80 bits */
        loopi 16, 2
            bn.rshi w4, w1, w4 >> 5
            bn.rshi w1, w31, w1 >> 16
        endloop
        nop
    endloop
    /* Load 10th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_compress_16
    /* Pack 45 bits */
    loopi 9, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 3 bits */
    bn.rshi w4, w1, w4 >> 3
    bn.sid  x4, 0(a1++)

    /* Fourth WDR: 2 bits + 30 bits (6 coeffs) + (Reload) 80 bits (16 coeffs) +
    * (Reload) 80 bits (16 coeffs) + (Reload) 60 bits (12 coeffs) + 4 bits */
    /* Pack 2 bits + 30 bits */
    loopi 7, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    loopi 2, 6
        /* Load 11th + 12th batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_compress_16
        /* Pack 80 bits */
        loopi 16, 2
            bn.rshi w4, w1, w4 >> 5
            bn.rshi w1, w31, w1 >> 16
        endloop
        nop
    endloop
    /* Load 13th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_compress_16
    /* Pack 60 bits */
    loopi 12, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 4 bits */
    bn.rshi w4, w1, w4 >> 4
    bn.sid  x4, 0(a1++)

    /* Fifth WDR: 1 bits + 15 bits (3 coeffs) + (Reload) 80 bits (16 coeffs) +
    * (Reload) 80 bits (16 coeffs) + (Reload) 80 bits (16 coeffs) */
    /* Pack 1 bits + 15 bits */
    loopi 4, 2
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 16
    endloop
    loopi 3, 6
    /* Load 14th + 15th + 16th batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_compress_16
        /* Pack 80 bits */
        loopi 16, 2
            bn.rshi w4, w1, w4 >> 5
            bn.rshi w1, w31, w1 >> 16
        endloop
        nop
    endloop
    bn.sid x4, 0(a1++)

    bn.mov w16, w30 /* Restore w16. */
    ret

/*
 * Name:        _poly_compress_16
 *
 * Description: Subroutine of poly_compress for compressing 16 coefficients
 *
 * @param[in]  w0: input vector with 16 16-bit coefficients
 * @param[in]  w3: (0x680)^8
 * @param[in]  w16 (sw0): const_1290176
 * @param[in]  w31: all-zero register
 * @param[out] w1: output vector with 16 compressed coefficients
 *
 * clobbered registers: w0 to w1
 */

_poly_compress_16:
  bn.trn1.16h          w1, w0, w31 /* Put even coeffs to 32-bit slots */
  bn.shv.8s            w1, w1 << 5 /* << 5 */
  bn.addv.8s           w1, w1, w3 /* +1664 */
  bn.mulv.l.8s.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8s.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn2.16h          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
  bn.shv.8s            w0, w0 << 5 /* << 5 */
  bn.addv.8s           w0, w0, w3 /* +1664 */
  bn.mulv.l.8s.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8s.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn1.16h          w1, w1, w0 /* Interleaving the results to original order */
  ret

/*
 * Name:        poly_polyvec_compress
 *
 * Description: Compress and serialize a single polynomial of a vector of
 *              polynomials
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out] x11: dptr_output, dmem pointer to output byte array
 * @param[in]  x12: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x0-x30, w0-w31
 */
.globl poly_polyvec_compress
.type poly_polyvec_compress, @function
poly_polyvec_compress:
    li x4, 4
    li x5, 2
    li x6, 5

    /* Load const */
    la     t0, modulus_over_2
    addi   x4, x0, 2
    bn.lid x4, 0(t0) /* w2 = (0x681)^16 */
    la     t0, const_1290167
    addi   x4, x0, 5
    bn.lid x4, 0(t0) /* w5 = const_1290167 */

    addi x4, x0, 4
    beq  a2, x4, _handle_k4_poly_polyvec_compress

_handle_kn4_poly_polyvec_compress:

    bn.shv.8s w3, w2 >> 16 /* w3 = (0x681)^8 */
    bn.mov    w30, w16 /* Save w16. */
    bn.mov    w16, w5 /* w16 = (1290167) */

    loopi 2, 61
        /* First WDR: 160 bits (16 coeffs) + (Reload) 90 bits (9 coeffs) + 6 bits */
        /* Load the first batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 160 bits */
        loopi 16, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the second batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 90 bits */
        loopi 9, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Pack 6 bits */
        bn.rshi w4, w1, w4 >> 6
        bn.sid  x4, 0(a1++)

        /* Second WDR: 4 bits + 60 bits (6 coeffs) + (Reload) 160 bits (16 coeffs) +
        * (Reload) 30 bits (3 coeffs) + 2 bits */
        /* Pack 4 + 60 bits */
        loopi 7, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the third batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 160 bits */
        loopi 16, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the fourth batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 30 bits */
        loopi 3, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Pack 2 bits */
        bn.rshi w4, w1, w4 >> 2
        bn.sid  x4, 0(a1++)

        /* Third WDR: 8 bits + 120 bits (12 coeffs) + (Reload) 120 bits (12 coeffs) + 8 bits */
        /* Pack 8 + 120 bits */
        loopi 13, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the fifth batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 120 bits */
        loopi 12, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Pack 8 bits */
        bn.rshi w4, w1, w4 >> 8
        bn.sid  x4, 0(a1++)

        /* Fourth WDR: 2 bits + 30 bits (3 coeffs) + (Reload) 160 bits (16 coeffs) +
        * (Reload) 60 bits (6 coeffs) + 4 bits */
        /* Pack 2 + 30 bits */
        loopi 4, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the sixth batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 160 bits */
        loopi 16, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the seventh batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 60 bits */
        loopi 6, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Pack 4 bits */
        bn.rshi w4, w1, w4 >> 4
        bn.sid  x4, 0(a1++)

        /* Fifth WDR: 6 bits + 90 bits (9 coeffs) + (Reload) 160 bits (16 coeffs) */
        /* Pack 6 + 90 bits */
        loopi 10, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        /* Load the eighth batch */
        bn.lid x0, 0(a0++)
        jal    x1, _poly_polyvec_compress_16_kn4
        /* Pack 160 bits */
        loopi 16, 2
        bn.rshi w4, w1, w4 >> 10
        bn.rshi w1, w31, w1 >> 16
        endloop
        bn.sid  x4, 0(a1++)
    endloop

    bn.mov w16, w30 /* Restore w16. */
    ret

_handle_k4_poly_polyvec_compress:

    bn.shv.8s w3, w2 >> 17 /* w3 = (0x340)^8 */
    bn.shv.8s w3, w3 << 1 /* w3 = (0x680)^8 */
    /* Multiply the constant 645084 with 2 (1290168) so that later we shift to the
    * right 32 bits instead of 28 bits. This means we can return the high parts of
    * the 64-bit products within the multiplication instruction. */
    bn.mov  w30, w16 /* Save w16. */
    bn.addi w16, w5, 1 /* w16 = 1290168 */

    /* 1st WDR: 176 bits (16 bits) + (Reload) 77 bits + 3 bits */
    /* Load the 1st batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 176 bits */
    loopi 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 2nd batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 77 bits */
    loopi 7, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 3 bits */
    bn.rshi w4, w1, w4 >> 3
    bn.sid  x4, 0(a1++)

    /* 2nd WDR: 8 bits + 88 bits (8 coeffs) + (Reload) 154 bits (14 coeffs) + 6 bits */
    /* Pack 8 bits + 88 bits */
    loopi 9, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 3rd batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 154 bits */
    loopi 14, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 6 bits */
    bn.rshi w4, w1, w4 >> 6
    bn.sid  x4, 0(a1++)

    /* 3rd WDR: 5 bits + 11 bits + (Reload) 176 bits (16 coeffs) + (Reload) 55 bits (5 coeffs) + 9 bits */
    /* Pack 5 bits + 11 bits */
    loopi 2, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 4th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 176 bits */
    loopi 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 5th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 55 bits */
    loopi 5, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 9 bits */
    bn.rshi w4, w1, w4 >> 9
    bn.sid  x4, 0(a1++)

    /* 4th WDR: 2 bits + 110 bits (10 coeffs) + (Reload) 143 bits (13 coeffs) + 1 bits */
    /* Pack 2 bits + 110 bits */
    loopi 11, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 6th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 143 bits */
    loopi 13, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 1 bits */
    bn.rshi w4, w1, w4 >> 1
    bn.sid  x4, 0(a1++)

    /* 5th WDR: 10 bits + 22 bits (2 coeffs) + (Reload) 176 bits (16 coeffs) +
     * (Reload) 44 bits (4 coeffs) + 4 bits */
    /* Pack 10 bits + 22 bits */
    loopi 3, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 7th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 176 bits */
    loopi 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 8th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 44 bits */
    loopi 4, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 4 bits */
    bn.rshi w4, w1, w4 >> 4
    bn.sid  x4, 0(a1++)

    /* 6th WDR: 7 bits + 121 bits (11 coeffs) + (Reload) 121 bits (11 coeffs) + 7 bits */
    /* Pack 7 bits + 121 bits */
    loopi 12, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 9th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 121 bits */
    loopi 11, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 7 bits */
    bn.rshi w4, w1, w4 >> 7
    bn.sid  x4, 0(a1++)

    /* 7th WDR: 4 bits + 44 bits (4 coeffs) + (Reload) 176 bits (16 coeffs) +
     * (Reload) 22 bits (2 coeffs) + 10 bits */
    /* Pack 4 bits + 44 bits */
    loopi 5, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 10th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 176 bits */
    loopi 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 11th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 22 bits */
    loopi 2, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 10 bits */
    bn.rshi w4, w1, w4 >> 10
    bn.sid  x4, 0(a1++)

    /* 8th WDR: 1 bits + 143 bits (13 coeffs) + (Reload) 110 bits (10 coeffs) + 2 bits */
    /* Pack 1 bits + 143 bits */
    loopi 14, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 12th batch */
    bn.lid x0, 0(a0++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 110 bits */
    loopi 10, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 2 bits */
    bn.rshi w4, w1, w4 >> 2
    bn.sid  x4, 0(a1++)

    /* 9th WDR: 9 bits + 55 bits (5 coeffs) + (Reload) 176 bits (16 coeffs)
     + (Reload) 11 bits + 5 bits */
    /* Pack 9 bits + 55 bits */
    loopi 6, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 13th batch */
    bn.lid x0, 0(x10++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 176 bits */
    loopi 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 14th batch */
    bn.lid x0, 0(x10++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 11 bits */
    bn.rshi w4, w1, w4 >> 11
    bn.rshi w1, w31, w1 >> 16
    /* Pack 5 bits */
    bn.rshi w4, w1, w4 >> 5
    bn.sid  x4, 0(a1++)

    /* 10th WDR: 6 bits + 154 bits (14 coeffs) + (Reload) 88 bits (8 coeffs) + 8 bits */
    /* Pack 6 bits + 154 bits */
    loopi 15, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 15th batch */
    bn.lid x0, 0(x10++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 88 bits */
    loopi 8, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Pack 8 bits */
    bn.rshi w4, w1, w4 >> 8
    bn.sid  x4, 0(a1++)

    /* 11th WDR: 3 bits + 77 bits (7 coeffs) + (Reload) 176 bits (16 coeffs) */
    /* Pack 3 bits + 77 bits */
    loopi 8, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    /* Load the 16th batch */
    bn.lid x0, 0(x10++)
    jal    x1, _poly_polyvec_compress_16_k4
    /* Pack 176 bits */
    loopi 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    endloop
    bn.sid x4, 0(a1++)

    bn.mov w16, w30 /* Restore w16. */
    ret

/*
 * Name:        _poly_polyvec_compress_16_kn4
 *
 * Description: Subroutine of poly_polyvec_compress for compressing 16
 *              coefficients
 *
 * @param[in]  w0: input vector with 16 16-bit coefficients
 * @param[in]  w3: (0x681)^8
 * @param[in]  w16 (sw0): const_1290167
 * @param[in]  w31: all-zero register
 * @param[out] w1: output vector with 16 compressed coefficients
 *
 * clobbered registers: w0 to w1
 */

_poly_polyvec_compress_16_kn4:
  bn.trn1.16h          w1, w0, w31 /* Put even coeffs to 32-bit slots */
  bn.shv.8s            w1, w1 << 10 /* << 10 */
  bn.addv.8s           w1, w1, w3 /* +1665 */
  bn.mulv.l.8s.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8s.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn2.16h          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
  bn.shv.8s            w0, w0 << 10 /* << 10 */
  bn.addv.8s           w0, w0, w3 /* +1665 */
  bn.mulv.l.8s.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8s.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn1.16h          w1, w1, w0 /* Interleaving the results to original order */
  ret


/*
 * Name:        _poly_polyvec_compress_16_k4
 *
 * Description: Subroutine of poly_polyvec_compress for compressing 16
 *              coefficients
 *
 * @param[in]  w0: input vector with 16 16-bit coefficients
 * @param[in]  w3: (0x680)^8
 * @param[in]  w16 (sw0): const_1290168
 * @param[in]  w31: all-zero register
 * @param[out] w1: output vector with 16 compressed coefficients
 *
 * clobbered registers: w0 to w1
 */

_poly_polyvec_compress_16_k4:
  bn.trn1.16h          w1, w0, w31 /* Put even coeffs to 32-bit slots */
  bn.shv.8s            w1, w1 << 11 /* << 11 */
  bn.addv.8s           w1, w1, w3 /* +1664 */
  bn.mulv.l.8s.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8s.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn2.16h          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
  bn.shv.8s            w0, w0 << 11 /* << 11 */
  bn.addv.8s           w0, w0, w3 /* +1664 */
  bn.mulv.l.8s.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8s.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn1.16h          w1, w1, w0 /* Interleaving the results to original order */
  ret
