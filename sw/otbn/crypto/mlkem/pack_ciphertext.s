/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

.text

#if (KYBER_K == 2)
#define KYBER_POLYVECCOMPRESSED_LOOP 4
#elif (KYBER_K == 3)
#define KYBER_POLYVECCOMPRESSED_LOOP 6
#endif

/*
 * Name:        poly_compress
 *
 * Description: Compression and subsequent serialization of a polynomial
 *
 * Arguments:   - uint8_t r: output byte array (of length KYBER_POLYCOMPRESSEDBYTES)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x11: dptr_input, dmem pointer to input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  x13 (w3): const_80635
 * @param[in]  x14 (w6): modulus_bn
 * @param[in]  x15 (w2): dptr_modulus_over_2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x0-x30, w0-w31
 */

poly_compress:
#if (KYBER_K == 2 || KYBER_K == 3)
  /* Multiply the constant 80635 with 2**4 so that later we shift to the right
   * 32 bits instead of 28 bits. This means we can return the high parts of
   * the 64-bit products within the multiplication instruction. */
  bn.subi w16, w5, 7 /* w16 = 80635 * 16 = 1290160 */
  LOOPI 4, 16
    LOOPI 4, 14
      bn.lid               x0, 0(x11++) /* Load input */
      bn.shv.16H           w0, w0 << 4 /* <= 4 */
      bn.addv.16H          w0, w0, w2 /* += 1665 */
      bn.trn1.16H          w1, w0, w31 /* Put even coeffs to 32-bit slots */
      bn.mulv.l.8S.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
      bn.mulv.l.8S.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
      bn.trn2.16H          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
      bn.mulv.l.8S.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
      bn.mulv.l.8S.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
      bn.trn1.16H          w1, w1, w0 /* Interleaving the results to original order */
      LOOPI 16, 2
        bn.rshi w4, w1, w4 >> 4
        bn.rshi w1, w31, w1 >> 16
      NOP
    bn.sid x4, 0(x12++)
#elif (KYBER_K == 4)
  bn.shv.8S w3, w2 >> 17 /* w3 = (0x340)^8 */
  bn.shv.8S w3, w3 << 1 /* w3 = (0x680)^8 */
  /* Multiply the constant 40318 with 2**5 (1290176) so that later we shift to the
   * right 32 bits instead of 28 bits. This means we can return the high parts of
   * the 64-bit products within the multiplication instruction. */
  bn.addi w16, w5, 9 /* w16 = 1290176 */
  /* First WDR: 80 bits (16 coeffs) + (Reload) 80 bits (16 coeffs) +
   * (Reload) 80 bits (16 coeffs) + (Reload) 15 bits (3 coeffs) + 1 bits */
  LOOPI 3, 6
  /* Load 1st + 2nd + 3rd batch */
    bn.lid x0, 0(x11++)
    jal    x1, poly_compress_16
    /* Pack 80 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 5
      bn.rshi w1, w31, w1 >> 16
    NOP
  /* Load 4th batch */
  bn.lid x0, 0(x11++)
  jal    x1, poly_compress_16
  /* Pack 15 bits */
  LOOPI 3, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  /* Pack 1 bit */
  bn.rshi w4, w1, w4 >> 1
  bn.sid  x4, 0(x12++)

  /* Second WDR: 4 bits + 60 bits (12 coeffs) + (Reload) 80 bits + (Reload) 80 bits +
   * (Reload) 30 bits (6 coeffs) + 2 bits */
  /* Pack 4 bits + 60 bits */
  LOOPI 13, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  LOOPI 2, 6
    /* Load 5th + 6th batch */
    bn.lid x0, 0(x11++)
    jal    x1, poly_compress_16
    /* Pack 80 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 5
      bn.rshi w1, w31, w1 >> 16
    NOP
  /* Load 7th batch */
  bn.lid x0, 0(x11++)
  jal    x1, poly_compress_16
  /* Pack 30 bits */
  LOOPI 6, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  /* Pack 2 bits */
  bn.rshi w4, w1, w4 >> 2
  bn.sid  x4, 0(x12++)

  /* Third WDR: 3 bits + 45 bits (9 coeffs) + (Reload) 80 bits (16 coeffs)
   * (Reload) 80 bits (16 coeffs) + (Reload) 45 bits (9 coeffs) + 3 bits */
  /* Pack 3 bits + 45 bits */
   LOOPI 10, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  LOOPI 2, 6
    /* Load 8th + 9th batch */
    bn.lid x0, 0(x11++)
    jal    x1, poly_compress_16
    /* Pack 80 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 5
      bn.rshi w1, w31, w1 >> 16
    NOP
  /* Load 10th batch */
  bn.lid x0, 0(x11++)
  jal    x1, poly_compress_16
  /* Pack 45 bits */
  LOOPI 9, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  /* Pack 3 bits */
  bn.rshi w4, w1, w4 >> 3
  bn.sid  x4, 0(x12++)

  /* Fourth WDR: 2 bits + 30 bits (6 coeffs) + (Reload) 80 bits (16 coeffs) +
   * (Reload) 80 bits (16 coeffs) + (Reload) 60 bits (12 coeffs) + 4 bits */
  /* Pack 2 bits + 30 bits */
   LOOPI 7, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  LOOPI 2, 6
    /* Load 11th + 12th batch */
    bn.lid x0, 0(x11++)
    jal    x1, poly_compress_16
    /* Pack 80 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 5
      bn.rshi w1, w31, w1 >> 16
    NOP
  /* Load 13th batch */
  bn.lid x0, 0(x11++)
  jal    x1, poly_compress_16
  /* Pack 60 bits */
  LOOPI 12, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  /* Pack 4 bits */
  bn.rshi w4, w1, w4 >> 4
  bn.sid  x4, 0(x12++)

  /* Fifth WDR: 1 bits + 15 bits (3 coeffs) + (Reload) 80 bits (16 coeffs) +
   * (Reload) 80 bits (16 coeffs) + (Reload) 80 bits (16 coeffs) */
  /* Pack 1 bits + 15 bits */
  LOOPI 4, 2
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 16
  LOOPI 3, 6
  /* Load 14th + 15th + 16th batch */
    bn.lid x0, 0(x11++)
    jal    x1, poly_compress_16
    /* Pack 80 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 5
      bn.rshi w1, w31, w1 >> 16
    NOP
  bn.sid  x4, 0(x12++)
#endif
  ret

/*
 * Name:        poly_compress_16
 *
 * Description: Subroutine of poly_compress for compressing 16 coefficients
 *
 * @param[in]   w0: input vector with 16 16-bit coefficients
 * @param[in]   w3: (0x680)^8
 * @param[in]  w16: const_1290176
 * @param[in]  w31: all-zero
 * @param[out]  w1: output vector with 16 compressed coefficients
 *
 * clobbered registers:
 */

poly_compress_16:
  bn.trn1.16H          w1, w0, w31 /* Put even coeffs to 32-bit slots */
  bn.shv.8S            w1, w1 << 5 /* << 5 */
  bn.addv.8S           w1, w1, w3 /* +1664 */
  bn.mulv.l.8S.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8S.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn2.16H          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
  bn.shv.8S            w0, w0 << 5 /* << 5 */
  bn.addv.8S           w0, w0, w3 /* +1664 */
  bn.mulv.l.8S.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8S.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn1.16H          w1, w1, w0 /* Interleaving the results to original order */
  ret

/*
 * Name:        polyvec_compress
 *
 * Description: Compress and serialize vector of polynomials
 *
 * Arguments:   - uint8_t r: output byte array (of length KYBER_POLYCOMPRESSEDBYTES)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  x13: const_1290167
 * @param[in]  x14: modulus_bn
 * @param[in]  x15: dptr_modulus_over_2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x0-x30, w0-w31
 */
polyvec_compress:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.8S w3, w2 >> 16 /* w2 = (0x681)^8 */
  bn.mov    w16, w5 /* w16 = (1290167) */
  LOOPI KYBER_POLYVECCOMPRESSED_LOOP, 61
    /* First WDR: 160 bits (16 coeffs) + (Reload) 90 bits (9 coeffs) + 6 bits */
    /* Load the first batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 160 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the second batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 90 bits */
    LOOPI 9, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Pack 6 bits */
    bn.rshi w4, w1, w4 >> 6
    bn.sid  x4, 0(x12++)

    /* Second WDR: 4 bits + 60 bits (6 coeffs) + (Reload) 160 bits (16 coeffs) +
    * (Reload) 30 bits (3 coeffs) + 2 bits */
    /* Pack 4 + 60 bits */
    LOOPI 7, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the third batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 160 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the fourth batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 30 bits */
    LOOPI 3, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Pack 2 bits */
    bn.rshi w4, w1, w4 >> 2
    bn.sid  x4, 0(x12++)

    /* Third WDR: 8 bits + 120 bits (12 coeffs) + (Reload) 120 bits (12 coeffs) + 8 bits */
    /* Pack 8 + 120 bits */
    LOOPI 13, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the fifth batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 120 bits */
    LOOPI 12, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Pack 8 bits */
    bn.rshi w4, w1, w4 >> 8
    bn.sid  x4, 0(x12++)

    /* Fourth WDR: 2 bits + 30 bits (3 coeffs) + (Reload) 160 bits (16 coeffs) +
     * (Reload) 60 bits (6 coeffs) + 4 bits */
    /* Pack 2 + 30 bits */
    LOOPI 4, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the sixth batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 160 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the seventh batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 60 bits */
    LOOPI 6, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Pack 4 bits */
    bn.rshi w4, w1, w4 >> 4
    bn.sid  x4, 0(x12++)

    /* Fifth WDR: 6 bits + 90 bits (9 coeffs) + (Reload) 160 bits (16 coeffs) */
    /* Pack 6 + 90 bits */
    LOOPI 10, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    /* Load the eighth batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 160 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 10
      bn.rshi w1, w31, w1 >> 16
    bn.sid  x4, 0(x12++)
#elif (KYBER_K == 4)
  bn.shv.8S w3, w2 >> 17 /* w3 = (0x340)^8 */
  bn.shv.8S w3, w3 << 1 /* w3 = (0x680)^8 */
  /* Multiply the constant 645084 with 2 (1290168) so that later we shift to the
   * right 32 bits instead of 28 bits. This means we can return the high parts of
   * the 64-bit products within the multiplication instruction. */
  bn.addi w16, w5, 1 /* w16 = 1290168 */
  LOOPI KYBER_K, 130
    /* 1st WDR: 176 bits (16 bits) + (Reload) 77 bits + 3 bits */
    /* Load the 1st batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 176 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 2nd batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 77 bits */
    LOOPI 7, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 3 bits */
    bn.rshi w4, w1, w4 >> 3
    bn.sid  x4, 0(x12++)

    /* 2nd WDR: 8 bits + 88 bits (8 coeffs) + (Reload) 154 bits (14 coeffs) + 6 bits */
    /* Pack 8 bits + 88 bits */
    LOOPI 9, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 3rd batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 154 bits */
    LOOPI 14, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 6 bits */
    bn.rshi w4, w1, w4 >> 6
    bn.sid  x4, 0(x12++)

    /* 3rd WDR: 5 bits + 11 bits + (Reload) 176 bits (16 coeffs) + (Reload) 55 bits (5 coeffs) + 9 bits */
    /* Pack 5 bits + 11 bits */
    LOOPI 2, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 4th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 176 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 5th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 55 bits */
    LOOPI 5, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 9 bits */
    bn.rshi w4, w1, w4 >> 9
    bn.sid  x4, 0(x12++)

    /* 4th WDR: 2 bits + 110 bits (10 coeffs) + (Reload) 143 bits (13 coeffs) + 1 bits */
    /* Pack 2 bits + 110 bits */
    LOOPI 11, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 6th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 143 bits */
    LOOPI 13, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 1 bits */
    bn.rshi w4, w1, w4 >> 1
    bn.sid  x4, 0(x12++)

    /* 5th WDR: 10 bits + 22 bits (2 coeffs) + (Reload) 176 bits (16 coeffs) +
     * (Reload) 44 bits (4 coeffs) + 4 bits */
    /* Pack 10 bits + 22 bits */
    LOOPI 3, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 7th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 176 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 8th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 44 bits */
    LOOPI 4, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 4 bits */
    bn.rshi w4, w1, w4 >> 4
    bn.sid  x4, 0(x12++)

    /* 6th WDR: 7 bits + 121 bits (11 coeffs) + (Reload) 121 bits (11 coeffs) + 7 bits */
    /* Pack 7 bits + 121 bits */
    LOOPI 12, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 9th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 121 bits */
    LOOPI 11, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 7 bits */
    bn.rshi w4, w1, w4 >> 7
    bn.sid  x4, 0(x12++)

    /* 7th WDR: 4 bits + 44 bits (4 coeffs) + (Reload) 176 bits (16 coeffs) +
     * (Reload) 22 bits (2 coeffs) + 10 bits */
    /* Pack 4 bits + 44 bits */
    LOOPI 5, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 10th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 176 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 11th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 22 bits */
    LOOPI 2, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 10 bits */
    bn.rshi w4, w1, w4 >> 10
    bn.sid  x4, 0(x12++)

    /* 8th WDR: 1 bits + 143 bits (13 coeffs) + (Reload) 110 bits (10 coeffs) + 2 bits */
    /* Pack 1 bits + 143 bits */
    LOOPI 14, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 12th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 110 bits */
    LOOPI 10, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 2 bits */
    bn.rshi w4, w1, w4 >> 2
    bn.sid  x4, 0(x12++)

    /* 9th WDR: 9 bits + 55 bits (5 coeffs) + (Reload) 176 bits (16 coeffs)
     + (Reload) 11 bits + 5 bits */
    /* Pack 9 bits + 55 bits */
    LOOPI 6, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 13th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 176 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 14th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 11 bits */
    bn.rshi w4, w1, w4 >> 11
    bn.rshi w1, w31, w1 >> 16
    /* Pack 5 bits */
    bn.rshi w4, w1, w4 >> 5
    bn.sid  x4, 0(x12++)

    /* 10th WDR: 6 bits + 154 bits (14 coeffs) + (Reload) 88 bits (8 coeffs) + 8 bits */
    /* Pack 6 bits + 154 bits */
    LOOPI 15, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 15th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 88 bits */
    LOOPI 8, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Pack 8 bits */
    bn.rshi w4, w1, w4 >> 8
    bn.sid  x4, 0(x12++)

    /* 11th WDR: 3 bits + 77 bits (7 coeffs) + (Reload) 176 bits (16 coeffs) */
    /* Pack 3 bits + 77 bits */
    LOOPI 8, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    /* Load the 16th batch */
    bn.lid x0, 0(x10++)
    jal    x1, polyvec_compress_16
    /* Pack 176 bits */
    LOOPI 16, 2
      bn.rshi w4, w1, w4 >> 11
      bn.rshi w1, w31, w1 >> 16
    bn.sid x4, 0(x12++)
#endif
  ret

/*
 * Name:        polyvec_compress_16
 *
 * Description: Subroutine of polyvec_compress for compressing 16 coefficients
 *
 * @param[in]   w0: input vector with 16 16-bit coefficients
 * @param[in]   w3: (0x681)^8 or (0x680)^8
 * @param[in]  w16: const_1290167 or const_1290168
 * @param[in]  w31: all-zero
 * @param[out]  w1: output vector with 16 compressed coefficients
 *
 * clobbered registers:
 */

polyvec_compress_16:
  bn.trn1.16H          w1, w0, w31 /* Put even coeffs to 32-bit slots */
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.8S            w1, w1 << 10 /* << 10 */
#elif (KYBER_K == 4)
  bn.shv.8S            w1, w1 << 11 /* << 11 */
#endif
  bn.addv.8S           w1, w1, w3 /* +1665 or +1664 */
  bn.mulv.l.8S.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8S.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn2.16H          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.8S            w0, w0 << 10 /* << 10 */
#elif (KYBER_K == 4)
  bn.shv.8S            w0, w0 << 11 /* << 11 */
#endif
  bn.addv.8S           w0, w0, w3 /* +1665 or +1664 */
  bn.mulv.l.8S.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.mulv.l.8S.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
  bn.trn1.16H          w1, w1, w0 /* Interleaving the results to original order */
  ret

/*
 * Name:        pack_ciphertext
 *
 * Description: Serialize the ciphertext as concatenation of the
 *              compressed and serialized vector of polynomials b
 *              and the compressed and serialized polynomial v
 *
 * Arguments:   - uint8_t *r: pointer to the output serialized ciphertext
 *              - polyvec *b: pointer to the input vector of polynomials b
 *              - poly *v: pointer to the input polynomial v
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_b, dmem pointer to first input polynomial
 * @param[in]  x11: dptr_v, dmem pointer to second input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  x13: const_1290167
 * @param[in]  x15: dptr_modulus_over_2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x0-x30, w0-w31
 */

.globl pack_ciphertext
pack_ciphertext:
  /* Set up registers for input and output */
  li x4, 4
  li x5, 2
  li x6, 5

  /* Load const */
  bn.lid  x5, 0(x15) /* w2 = modulus_over_2 = (0x681)^16 */
  bn.lid  x6, 0(x13) /* w5 = const_1290167 */

  /* Zeroize w31 */
  bn.xor w31, w31, w31
  jal    x1, polyvec_compress
  jal    x1, poly_compress

  ret


/*
 * Name:        poly_decompress
 *
 * Description: De-serialization and subsequent decompression of a polynomial;
 *              approximate inverse of poly_compress
 *
 * Arguments:   - uint8_t r: input byte array (of length KYBER_POLYCOMPRESSEDBYTES)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x12: dptr_output, dmem pointer to output polynomial
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x0-x30, w0-w31
 */

poly_decompress:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.16H w2, w2 >> 8 /* 0xf */
  LOOPI 4, 11
    bn.lid x0, 0(x10++)
    LOOPI 4, 8
      LOOPI 16, 2
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w0, w31, w0 >> 4
      bn.and           w1, w1, w2
      bn.mulv.l.16H.lo w1, w1, sw0.0
      bn.addv.16H      w1, w1, w5
      bn.shv.16H       w1, w1 >> 4
      bn.sid           x4, 0(x12++)
    NOP
#elif (KYBER_K == 4)
  /* Before, we used bn.mulv.l.8S.{even,odd}.lo to compute 16 16x16-bit
   * multiplications, because we need the full 32-bit results to shift them by
   * a certain number of bits. The computation is:
   * (((a & mask_num_bits) * KYBER_Q) + const) >> num_bits
   * To use compute 16 16x16-bit multiplications and adding with const at once,
   * we do the following trick:
   * ((((a*mask_num_bits)<<(16-num_bits))* KYBER_Q)+(const<<(16-num_bits)))>>16
   * The addition is the accumulation to ACC(H), so we need to write
   * (const<<(16-num_bits)) to ACC(H) before the multiplication. The final shift
   * to the right 16 bits is taking the high parts of the multiplication
   * results. All of this can be done in bn.mulv.l.16H.acc.hi. */
  /* 1st+2nd+3rd WDRs: 3*80 bits */
  bn.lid x0, 0(x10++)
  LOOPI 3, 5
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    jal    x1, poly_decompress_16
    bn.sid x4, 0(x12++)

  /* 4th WDR: 15 bits + 1 bit + (Reload) 4 bits + 60 bits*/
  LOOPI 3, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 1
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 15
  bn.rshi w0, w31, w0 >> 4
  LOOPI 12, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  jal    x1, poly_decompress_16
  bn.sid x4, 0(x12++)

  /* 5th+6th WDR: 2*80 bits */
  LOOPI 2, 5
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    jal    x1, poly_decompress_16
    bn.sid x4, 0(x12++)

  /* 7th WDR: 30 bits + 2 bits + (Reload) 3 bits + 45 bits */
  LOOPI 6, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 2
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 14
  bn.rshi w0, w31, w0 >> 3
  LOOPI 9, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  jal    x1, poly_decompress_16
  bn.sid x4, 0(x12++)

  /* 8th+9th WDR: 2*80 bits */
  LOOPI 2, 5
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    jal    x1, poly_decompress_16
    bn.sid x4, 0(x12++)

  /* 10th WDR: 45 bits + 3 bits + (Reload) 2 bits + 30 bits */
  LOOPI 9, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 3
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 13
  bn.rshi w0, w31, w0 >> 2
  LOOPI 6, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  jal    x1, poly_decompress_16
  bn.sid x4, 0(x12++)

  /* 11th+12th WDR: 2*80 bits */
  LOOPI 2, 5
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    jal    x1, poly_decompress_16
    bn.sid x4, 0(x12++)

  /* 13th WDR: 60 bits + 4 bits + (Reload) 1 bit + 15 bits */
  LOOPI 12, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 4
  bn.lid  x0, 0(x10++)
  bn.rshi w1, w0, w1 >> 12
  bn.rshi w0, w31, w0 >> 1
  LOOPI 3, 2
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 5
  jal    x1, poly_decompress_16
  bn.sid x4, 0(x12++)

  /* 14th+15th+16th WDRs: 3*80 bits */
  LOOPI 3, 5
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 5
    jal    x1, poly_decompress_16
    bn.sid x4, 0(x12++)
#endif
  ret

/*
 * Name:        poly_decompress_16
 *
 * Description: Subroutine of poly_decompress for decompressing 16 coefficients
 *
 * @param[inout]   w1: input/output vector with 16 16-bit coefficients
 * @param[in]      w4: (0x03ff)^16 or (0x07ff)^16
 * @param[in]     w16: KYBER_Q
 * @param[in]     w31: all-zero
 *
 * clobbered registers:
 */
poly_decompress_16:
  bn.shv.16H           w1, w1 << 11 /* << 11 */
  bn.wsrw              0x3, w3 /* Write w3 to ACC */
  bn.wsrw              0xb, w3 /* Write w3 to ACCH */
  bn.mulv.l.16H.acc.hi w1, w1, sw0.0 /* *KYBER_Q + ACC */
  ret

/*
 * Name:        polyvec_decompress
 *
 * Description: De-serialize and decompress vector of polynomials;
 *              approximate inverse of polyvec_compress
 *
 * Arguments:   - polyvec *r:       pointer to output vector of polynomials
 *              - const uint8_t *a: pointer to input byte array
 *                                  (of length KYBER_POLYVECCOMPRESSEDBYTES)
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  w31: all-zero
 * @param[in]  w2: const_0x0fff
 * @param[in]  w3: (0x00008000)^8
 * @param[out] x12: dptr_output, dmem pointer to output polynomials
 *
 * clobbered registers: x0-x30, w0-w31
 */

polyvec_decompress:
  /* Before, we used bn.mulv.l.8S.{even,odd}.lo to compute 16 16x16-bit
   * multiplications, because we need the full 32-bit results to shift them by
   * a certain number of bits. The computation is:
   * (((a & mask_num_bits) * KYBER_Q) + const) >> num_bits
   * To use compute 16 16x16-bit multiplications and adding with const at once,
   * we do the following trick:
   * ((((a*mask_num_bits)<<(16-num_bits))* KYBER_Q)+(const<<(16-num_bits)))>>16
   * The addition is the accumulation to ACC(H), so we need to write
   * (const<<(16-num_bits)) to ACC(H) before the multiplication. The final shift
   * to the right 16 bits is taking the high parts of the multiplication
   * results. All of this can be done in bn.mulv.l.16H.acc.hi. */
#if (KYBER_K == 2 || KYBER_K == 3)
  LOOPI KYBER_POLYVECCOMPRESSED_LOOP, 69
    /* First WDR: 160 bits of w0 */
    bn.lid x0, 0(x10++)
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16  /* Extract 10 bit from input to a 16-bit vector slot */
      bn.rshi w0, w31, w0 >> 10 /* Shift out used bits */
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Second WDR: 90 bits + 6 bits + (Reload) 4 bits + 60 bits */
    LOOPI 9, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    bn.rshi w1, w0, w1 >> 6 /* Move the final 6 bits of w0 to w1 */
    bn.lid  x0, 0(x10++) /* Load the second batch of input to w0 */
    bn.rshi w1, w0, w1 >> 10 /* Move the first 4 bits of w0 to w1 to form 10 bits */
    bn.rshi w0, w31, w0 >> 4 /* Shift out the used 4 bits */
    LOOPI 6, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Third WDR: 160 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Fourth WDR: 30 bits + 2 bits + (Reload) 8 bits + 120 bits */
    LOOPI 3, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    bn.rshi w1, w0, w1 >> 2 /* Move the final 2 bits of w0 to w1 */
    bn.lid  x0, 0(x10++) /* Load the third batch of input */
    bn.rshi w1, w0, w1 >> 14 /* Move the first 8 bits of w0 to w1 to form 10 bits */
    bn.rshi w0, w31, w0 >> 8 /* Shift out used bits */
    LOOPI 12, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Fifth WDR: 120 bits + 8 bits + (Reload) 2 bits + 30 bits */
    LOOPI 12, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    bn.rshi w1, w0, w1 >> 8 /* Move the final 8 bits of w0 to w1 */
    bn.lid  x0, 0(x10++) /* Load the fourth batch of input to w0 */
    bn.rshi w1, w0, w1 >> 8 /* Move the first 2 bits of w0 to w1 to form 10 bits */
    bn.rshi w0, w31, w0 >> 2 /* Shift out used bits */
    LOOPI 3, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Sixth WDR: 160 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Seventh WDR: 60 bits + 4 bits + (Reload) 6 bits + 90 bits */
    LOOPI 6, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    bn.rshi      w1, w0, w1 >> 4 /* Move the final 4 bits of w0 to w1 */
    bn.lid       x0, 0(x10++) /* Load the fifth batch of input to w0 */
    bn.rshi      w1, w0, w1 >> 12 /* Move the first 6 bits of w0 to w1 to form 10 bits */
    bn.rshi      w0, w31, w0 >> 6 /* Shift out used bits */
    LOOPI 9, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Eigth WDR: 160 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 10
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)
#elif (KYBER_K == 4)
  LOOPI KYBER_K, 149
    /* First WDR: 176 bits */
    bn.lid x0, 0(x10++)
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 2nd WDR: 77 bits + 3 bits + (Reload) 8 bits + 88 bits */
    LOOPI 7, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 3
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 13
    bn.rshi w0, w31, w0 >> 8
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* Third WDR: 154 bits + 6 bits + (Reload) 5 bits + 11 bits */
    LOOPI 14, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi              w1, w0, w1 >> 6
    bn.lid               x0, 0(x10++)
    bn.rshi              w1, w0, w1 >> 10
    bn.rshi              w0, w31, w0 >> 5
    bn.rshi              w1, w0, w1 >> 16
    bn.rshi              w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 4th WDR: 176 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 5th WDR: 55 bits + 9 bits + (Reload) 2 bits + 110 bits*/
    LOOPI 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 9
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 7
    bn.rshi w0, w31, w0 >> 2
    LOOPI 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 6th WDR:  143 bits + 1 bits + (Reload) 10 bits + 22 bits */
    LOOPI 13, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 15
    bn.rshi w0, w31, w0 >> 10
    LOOPI 2, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 7th WDR: 176 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 8th WDR: 44 bits + 4 bits + (Reload) 7 bits + 121 bits */
    LOOPI 4, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 12
    bn.rshi w0, w31, w0 >> 7
    LOOPI 11, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 9th WDR: 121 bits + 7 bits + (Reload) 4 bits + 44 bits */
    LOOPI 11, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 7
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 9
    bn.rshi w0, w31, w0 >> 4
    LOOPI 4, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 10th WDR: 176 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 11th WDR: 22 bits + 10 bits + (Reload) 1 bits + 143 bits */
    LOOPI 2, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 10
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 6
    bn.rshi w0, w31, w0 >> 1
    LOOPI 13, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 12th WDR: 110 bits + 2 bits + (Reload) 9 bits + 55 bits */
    LOOPI 10, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 2
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 14
    bn.rshi w0, w31, w0 >> 9
    LOOPI 5, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 13th WDR: 176 bits*/
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 14th WDR: 11 bits + 5 bits + (Reload) 6 bits + 154 bits */
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 5
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 11
    bn.rshi w0, w31, w0 >> 6
    LOOPI 14, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 15th WDR: 88 bits + 8 bits + (Reload) 3 bits + 77 bits */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w0, w1 >> 8
    bn.rshi w0, w31, w0 >> 3
    LOOPI 7, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)

    /* 16th WDR: 176 bits */
    LOOPI 16, 2
      bn.rshi w1, w0, w1 >> 16
      bn.rshi w0, w31, w0 >> 11
    jal    x1, polyvec_decompress_16
    bn.sid x4, 0(x12++)
#endif
  ret

/*
 * Name:        polyvec_decompress_16
 *
 * Description: Subroutine of polyvec_decompress for decompressing 16 coefficients
 *
 * @param[inout]   w1: input/output vector with 16 16-bit coefficients
 * @param[in]     w16: KYBER_Q
 * @param[in]     w31: all-zero
 *
 * clobbered registers:
 */
polyvec_decompress_16:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.16H           w1, w1 << 6 /* *(2**6) */
#elif (KYBER_K == 4)
  bn.shv.16H           w1, w1 << 5 /* *(2**5) */
#endif
  bn.wsrw              0x3, w3 /* Write w3 to ACC */
  bn.wsrw              0xb, w3 /* Write w3 to ACCH */
  bn.mulv.l.16H.acc.hi w1, w1, sw0.0 /* *KYBER_Q + ACC */
  ret

/*
 * Name:        unpack_ciphertext
 *
 * Description: Serialize the secret key
 *
 * Arguments:   - uint8_t *r: pointer to output serialized secret key
 *              - polyvec *sk: pointer to input vector of polynomials (secret key)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first input byte array
 * @param[in]  x13: const_8
 * @param[in]  x14: modulus_bn
 * @param[in]  x15: const_0x0fff
 * @param[out] x12: dptr_output, dmem pointer to output ciphertext
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x0-x30, w0-w31
 */

.globl unpack_ciphertext
unpack_ciphertext:
  /* Set up registers for input and output */
  li x4, 1
  li x5, 2

  /* Load const */
  bn.lid  x5++, 0(x15) /* w2 = const_0x0fff (w2) */
  bn.lid  x5, 0(x13) /* w3 = const_8 (w3) */

  /* For polyvec_decompress:
   * When K == 2 or K == 3: w3 = 512 * (2**6)
   * When K == 4: w3 = 1024 * (2**5)
   * For poly_decompress:
   * When K == 4: w3 = 16 * (2**11) */
  bn.mov    w5, w3 /* Save w3 */
  bn.shv.8S w3, w3 << 16 /* w3 = (0x00080000)^8 */
  bn.shv.8S w3, w3 >> 4  /* w3 = (0x00008000)^8 */

  /* KYBER_Q is in the first half word of w16 (sw0.0) */
  bn.wsrr w16, 0x0

  /* Zeroize w31 */
  bn.xor     w31, w31, w31

  jal        x1, polyvec_decompress
  jal        x1, poly_decompress

  ret
