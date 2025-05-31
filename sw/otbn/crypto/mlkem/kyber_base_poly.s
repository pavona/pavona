/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text 

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
 * Name:        poly_frommsg_base
 *
 * Description: Convert 32-byte message to polynomial
 *
 * Arguments:   - uint8_t r: input byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x11: dptr_modulus_over_2
 * @param[out] x12: dptr_output, dmem pointer to output
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_frommsg_base
poly_frommsg_base:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 2
  li x6, 3

  /* Load input */
  bn.lid x4, 0(x10)
  bn.lid x6, 0(x11)
  
  LOOPI 16, 8
    LOOPI 16, 5
      bn.rshi w1, w0, w31 >> 1
      bn.rshi w1, w31, w1 >> 255
      bn.sub  w1, w31, w1 
      bn.rshi w2, w1, w2 >> 16
      bn.rshi w0, w31, w0 >> 1
    bn.and w2, w2, w3
    bn.sid x5, 0(x12++)

  ret

/*
 * Name:        poly_tomsg_base
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
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_tomsg_base
poly_tomsg_base:
  /* Set up registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x8, 4

  /* Load const */
  bn.lid x6, 0(x11)
  bn.lid x7, 0(x13)
  
  bn.xor  w31, w31, w31
  bn.rshi w3, w31, w3 >> 4 /* 80635 */
  bn.addi w5, w31, 1
  bn.rshi w5, w5, w31 >> 240
  bn.subi w5, w5, 1 /* mask = 0xffff */
  LOOPI 16, 10
    bn.lid       x4, 0(x10++)  /* Load input */
    bn.rshi      w0, w0, w31 >> 255 /* <= 1 */
    bn.add       w0, w0, w2
    LOOPI 16, 5
      bn.and          w1, w0, w5          
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *80635 */
      bn.rshi         w1, w31, w1 >> 28  /* >= 28 */
      bn.rshi         w4, w1, w4 >> 1   /* save one bit */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    NOP
  bn.sid x8, 0(x12)

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
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x13: STACK_NONCE
 * @param[in]  x6: dmem_ptr to SHAKE256 results
 * @param[in]  w31: all-zero
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
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
  bn.lid x0, 0(x10)
  bn.wsrw 0x9, w0
  add  x10, x3, x13
  bn.lid x0, 0(x10)
  bn.wsrw 0x9, w0

  li x5, 8
  LOOPI LOOP_GETNOISE_1, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  x5, 0(x6++) /* Store into buffer */

  lw  x10, 0(x2)
  lw  x11, 4(x2)
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
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x13: STACK_NONCE
 * @param[in]  x6: dmem_ptr to SHAKE256 results
 * @param[in]  w31: all-zero
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_getnoise_eta_2
poly_getnoise_eta_2:
  addi x2, x2, -8
  sw   x11, 4(x2)
  sw   x6, 0(x2)

  /* Initialize a SHAKE256 operation. */
  addi x5, x0, 33
  slli x5, x5, 5
  addi x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the message to the Keccak core. */
  bn.lid x0, 0(x10)
  bn.wsrw 0x9, w0
  add  x10, x3, x13
  bn.lid x0, 0(x10)
  bn.wsrw 0x9, w0

  li x5, 8
  LOOPI 4, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  x5, 0(x6++) /* Store into buffer */

  lw  x10, 0(x2)
  lw  x11, 4(x2)
  bn.add w8, w0, w0
  jal x1, cbd2

  addi x2, x2, 8

  ret

/*
 * Name:        poly_add_base
 *
 * Description: Add 2 vectors
 *
 * Arguments:   - 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[out] x12: dptr_output, dmem pointer to output polynomial
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
.globl poly_add_base
poly_add_base:
  li x4, 0
  li x5, 1
  li x6, 2

  bn.addi w2, w31, 1
  bn.rshi w2, w2, w31 >> 240
  bn.subi w2, w2, 1 /* mask = 0xffff */

  LOOPI 16, 9
    bn.lid x4,  0(x10++)
    bn.lid x5,  0(x11++)
    LOOPI 16, 5
      bn.and  w3, w0, w2 
      bn.and  w4, w1, w2 
      bn.addm w3, w3, w4 
      bn.rshi w0, w3, w0 >> 16
      bn.rshi w1, w31, w1 >> 16
    bn.sid x4,  0(x12++)
  ret

/*
 * Name:        poly_sub_base
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
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
.globl poly_sub_base
poly_sub_base:
  li x4, 0
  li x5, 1
  li x6, 2

  la     x7, modulus_bn
  bn.lid x6, 0(x7)
  
  LOOPI 16, 5
    bn.lid x4,  0(x10++)
    bn.lid x5,  0(x11++)
    bn.add w0, w0, w2 
    bn.sub w0, w0, w1
    bn.sid x4, 0(x12++)
  ret

/*
 * Name:        poly_reduce
 *
 * Description: Inplace Plantard reduction
 *
 * Arguments:   - 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in/out]  x10: dptr_input/output, dmem pointer to input/output poly
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
.globl poly_reduce
poly_reduce:
  li x4, 0
  li x7, 5

  bn.lid x7, 0(x12)
  bn.addi w5, w5, 1
  bn.addi w2, w31, 1
  bn.rshi w2, w2, w31 >> 224
  bn.subi w2, w2, 1 /* mask = 0xffffffff */

  /* Set second WLEN/4 quad word to modulus */
  la     x8, modulus
  li     x9, 20 /* Load q to w6.2*/
  bn.lid x9, 0(x8)
  bn.or  w6, w31, w20 << 128
  /* Load alpha to w6.1 */
  bn.addi w20, w31, 8
  bn.or   w6, w6, w20 << 64
  /* Load mask to w6.3 */
  bn.or w6, w6, w2 << 192

  LOOPI 16, 10
    bn.lid x4, 0(x10)
    LOOPI 16, 7
      bn.and          w1, w0, w2 >> 16
      bn.mulqacc.wo.z w1, w1.0, w5.0, 192 /* a*bq' */
      bn.and          w1, w1, w6
      bn.add          w1, w6, w1 >> 144 /* + 2^alpha = 2^8 */
      bn.mulqacc.wo.z w1, w1.1, w6.2, 0 /* *q */
      bn.rshi         w3, w31, w1 >> 16 /* >> l */
      bn.rshi         w0, w3, w0 >> 16
    bn.sid x4, 0(x10++)
  ret
