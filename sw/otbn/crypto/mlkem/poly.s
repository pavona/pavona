/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

.text

#ifndef KYBER_K
#define KYBER_K 3
#endif

#if (KYBER_K == 2)
  #define LOOP_GETNOISE_1 6
#elif (KYBER_K == 3 || KYBER_K == 4)
  #define LOOP_GETNOISE_1 4
#else
#endif

/* Index of the Keccak command special register. */
#define KECCAK_CFG_REG 0x7d9
/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/*
 * Name:        poly_frommsg
 *
 * Description: Convert 32-byte message to polynomial
 *
 * Arguments:   - uint8_t r: input byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x11: dptr_modulus_over_2
 * @param[out] x12: dptr_output, dmem pointer to output
 *
 * clobbered registers: x4-x6, w0-w3
 * clobbered flag groups: None
 */

.globl poly_frommsg
poly_frommsg:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 3

  /* Load input */
  bn.lid x4, 0(x10)
  bn.lid x6, 0(x11)

  LOOPI 16, 7
    LOOPI 16, 3
      bn.rshi w1, w0, w1 >> 1
      bn.rshi w1, w31, w1 >> 15
      bn.rshi w0, w31, w0 >> 1
    bn.subv.16H w1, w31, w1
    bn.and      w1, w1, w3
    bn.sid      x5, 0(x12++)

  ret

/*
 * Name:        poly_tomsg
 *
 * Description: Convert polynomial to 32-byte message
 *
 * Arguments:   - uint8_t r: output byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[in]  x11: modulus_over_2
 * @param[in]  x13: const_1290167
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 *
 * clobbered registers: x4-x8, w0-w4
 * clobbered flag groups: None
 */

.globl poly_tomsg
poly_tomsg:
  /* Set up registers for input and output */
  li x4, 0
  li x5, 2
  li x7, 16

  /* Load const */
  bn.lid x5++, 0(x11) /* w2 = (0x681)^16 */
  bn.lid x7, 0(x13) /* w16 = 1290167 */

  /* Multiply the constant 80635 with 2**4 so that later we shift to the right
   * 32 bits instead of 28 bits. This means we can return the high parts of
   * the 64-bit products within the multiplication instruction. */
  bn.subi w16, w16, 7 /* w16 = 1290160 = 80635 << 4 */
  /* Zeroize w31 */
  bn.xor  w31, w31, w31
  LOOPI 16, 14
    bn.lid               x4, 0(x10++)  /* Load input */
    bn.shv.16H           w0, w0 << 1   /* <= 1 */
    bn.addv.16H          w0, w0, w2    /* += 1665 */
    bn.trn1.16H          w1, w0, w31 /* Put even coeffs in 32-bit slots */
    bn.mulv.l.8S.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.mulv.l.8S.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.trn2.16H          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
    bn.mulv.l.8S.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.mulv.l.8S.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.trn1.16H          w0, w1, w0 /* Interleaving the results to original order */
    LOOPI 16, 2
      bn.rshi w3, w0, w3 >> 1
      bn.rshi w0, w31, w0 >> 16
    NOP
  bn.sid x5, 0(x12)

  ret

/*
 * Name:        poly_getnoise_eta1
 *
 * Description: Sample a polynomial deterministically from a seed and a nonce,
 *              with output polynomial close to centered binomial distribution
 *              with parameter KYBER_ETA1
 *
 * Arguments:   - poly *r: pointer to output polynomial
 *              - const uint8_t *seed: pointer to input seed (of length KYBER_SYMBYTES bytes)
 *              - uint8_t nonce: one-byte input nonce
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x13: STACK_NONCE
 * @param[in]  x6: dmem_ptr to SHAKE256 results
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */

.globl poly_getnoise_eta_1
poly_getnoise_eta_1:
  addi x2, x2, -8
  sw   x11, 4(x2)
  sw   x6, 0(x2)

  /* Initialize a SHAKE256 operation. */
  addi  x5, x0, 33
  slli  x5, x5, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the message to the Keccak core. */
  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0
  add     x10, x3, x13
  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0

  li x5, 8
  LOOPI LOOP_GETNOISE_1, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  x5, 0(x6++) /* Store into buffer */

  lw     x10, 0(x2)
  lw     x11, 4(x2)
  bn.add w8, w0, w0
#if (KYBER_K == 2)
  jal x1, cbd3
#elif (KYBER_K == 3 || KYBER_K == 4)
  jal x1, cbd2
#endif

  addi x2, x2, 8

  ret

/*
 * Name:        poly_getnoise_eta2
 *
 * Description: Sample a polynomial deterministically from a seed and a nonce,
 *              with output polynomial close to centered binomial distribution
 *              with parameter KYBER_ETA2
 *
 * Arguments:   - poly *r: pointer to output polynomial
 *              - const uint8_t *seed: pointer to input seed (of length KYBER_SYMBYTES bytes)
 *              - uint8_t nonce: one-byte input nonce
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x13: STACK_NONCE
 * @param[in]  x6: dmem_ptr to SHAKE256 results
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */

.globl poly_getnoise_eta_2
poly_getnoise_eta_2:
  addi x2, x2, -8
  sw   x11, 4(x2)
  sw   x6, 0(x2)

  /* Initialize a SHAKE256 operation. */
  addi  x5, x0, 33
  slli  x5, x5, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the message to the Keccak core. */
  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0
  add     x10, x3, x13
  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0

  li x5, 8
  LOOPI 4, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  x5, 0(x6++) /* Store into buffer */

  lw     x10, 0(x2)
  lw     x11, 4(x2)
  bn.add w8, w0, w0
  jal    x1, cbd2

  addi x2, x2, 8

  ret

/*
 * Name:        poly_add
 *
 * Description: Add 2 vectors
 *
 * Arguments:   -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[in]  x12: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */
.globl poly_add
poly_add:
  li x4, 1

  LOOPI 16, 4
    bn.lid       x0, 0(x10++)
    bn.lid       x4, 0(x11++)
    bn.addvm.16H w0, w0, w1
    bn.sid       x0, 0(x12++)
  ret

/*
 * Name:        poly_sub
 *
 * Description: Sub 2 vectors
 *
 * Arguments:   -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[out] x12: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */
.globl poly_sub
poly_sub:
  li x4, 1

  LOOPI 16, 4
    bn.lid       x0, 0(x10++)
    bn.lid       x4, 0(x11++)
    bn.subvm.16H w0, w0, w1
    bn.sid       x0, 0(x12++)
  ret

/*
 * Name:        poly_tomont
 *
 * Description: Put the input polynomial out of Montgomery domain
 *
 * Arguments:   -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in/out]  x10: dptr_input, dmem pointer to first poly
 * @param[in]      x11: ptr to const_tomont = 2^32 % Q
 * @param[in]      w16: sw0, where sw0.2 = Q^-1 mod 2^32, sw0.0 = Q
 * @param[in]      w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */
.globl poly_tomont
poly_tomont:
  /* Load const_tomont */
  li     x4, 0
  bn.lid x4++, 0(x11)

  LOOPI 16, 6
    bn.lid               x4, 0(x10)
    bn.mulv.16H.acc.z.lo w1, w0, w1
    bn.mulv.l.16H.lo     w1, w1, sw0.2
    bn.mulv.l.16H.acc.hi w1, w1, sw0.0
    bn.addvm.16H         w1, w1, w31
    bn.sid               x4, 0(x10++)
  ret
