/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text 
/* Register aliases */
.equ x0, zero
.equ x2, sp
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

#if (KYBER_K == 2)
  #define LOOP_GETNOISE_1 6
#elif (KYBER_K == 3 || KYBER_K == 4)
  #define LOOP_GETNOISE_1 4
#else
#endif

/* Macros */
.macro push reg
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
.endm

.macro pop reg
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
.endm

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
  .irp reg,t0,t1,t2,t3,t5,t6,a0,a1,a2,a3,a4,a5,a6
    push \reg
  .endr

  /* Initialize a SHAKE256 operation. */
  add s0, zero, a0 /* input seed */
  add s1, fp, a3   /* fp + STACK_NONCE */
  la  s2, context
  add s3, zero, t1 /* dmem_ptr to SHAKE256 result buffer */

  add a0, zero, s2
  li  a1, 32
  jal x1, sha3_init 

  add a0, zero, s2 
  add a1, zero, s0 
  li  a2, 32
  jal x1, sha3_update

  add a0, zero, s2
  add a1, zero, s1 
  li  a2, 1
  jal x1, sha3_update

  add a0, zero, s2 
  jal x1, shake_xof 

  li  s1, 0
  LOOPI LOOP_GETNOISE_1, 5
    add a0, zero, s2
    add a1, s1, s3 
    add a2, zero, 32 
    jal x1, shake_out
    add s1, s1, 32
  
  .irp reg,a6,a5,a4,a3,a2,a1,a0,t6,t5,t3,t2,t1,t0
    pop \reg
  .endr

  add a0, zero, t1 
  bn.xor w8, w8, w8
#if (KYBER_K == 2)
  jal x1, cbd3
#elif (KYBER_K == 3 || KYBER_K == 4)
  jal x1, cbd2
#endif 

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
  .irp reg,t0,t1,t2,t3,t5,t6,a0,a1,a2,a3,a4,a5,a6
    push \reg
  .endr

  /* Initialize a SHAKE256 operation. */
  add s0, zero, a0 /* input seed */
  add s1, fp, a3   /* fp + STACK_NONCE */
  la  s2, context
  add s3, zero, t1 /* dmem_ptr to SHAKE256 result buffer */

  add a0, zero, s2
  li  a1, 32
  jal x1, sha3_init 

  add a0, zero, s2 
  add a1, zero, s0 
  li  a2, 32
  jal x1, sha3_update

  add a0, zero, s2
  add a1, zero, s1 
  li  a2, 1
  jal x1, sha3_update

  add a0, zero, s2 
  jal x1, shake_xof 

  li  s1, 0
  LOOPI 4, 5
    add a0, zero, s2
    add a1, s1, s3 
    add a2, zero, 32 
    jal x1, shake_out
    add s1, s1, 32
  
  .irp reg,a6,a5,a4,a3,a2,a1,a0,t6,t5,t3,t2,t1,t0
    pop \reg
  .endr

  add a0, zero, t1 
  bn.xor w8, w8, w8

  jal x1, cbd2

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