/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text
/*
 * Constant-time Kyber basemul
 *
 * Returns: NTT(a)*NTT(b)
 *
 * This implements the basemul for Kyber, where n=256, q=3329.
 *
 * Flags: -
 *
 * @param[in]  x29: dptr_input1, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to second word of input polynomial
 * @param[in]  x28: dptr_tw, dmem pointer to array of twiddles_basemul
 * @param[out] x13: dmem pointer to result
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */

.globl basemul_kyber
basemul_kyber:
  /* Set up wide registers for inputs*/
  li x4, 0
  li x5, 1 
  li x6, 2 
  li x7, 3 
  li x8, 4 
  li x9, 5 
  li x14, 6 
  li x15, 7 
  li x16, 8
  li x17, 9
  li x18, 10
  li x19, 11
  li x20, 12
  li x21, 13
  li x22, 14
  li x23, 15
  bn.xor w31, w31, w31

  LOOPI 2, 104
    /* Load input */
    bn.lid x4,  0(x29++)
    bn.lid x5,  0(x29++)
    bn.lid x6,  0(x29++)
    bn.lid x7,  0(x29++)
    bn.lid x8,  0(x29++)
    bn.lid x9,  0(x29++)
    bn.lid x14, 0(x29++)
    bn.lid x15, 0(x29++)

    bn.lid x16, 0(x11++)
    bn.lid x17, 0(x11++)
    bn.lid x18, 0(x11++)
    bn.lid x19, 0(x11++)
    bn.lid x20, 0(x11++)
    bn.lid x21, 0(x11++)
    bn.lid x22, 0(x11++)
    bn.lid x23, 0(x11++)

    /* Multiply ai*bi */
    bn.mulvm.16H w16, w0, w8
    bn.mulvm.16H w17, w1, w9
    bn.mulvm.16H w18, w2, w10
    bn.mulvm.16H w19, w3, w11
    bn.mulvm.16H w20, w4, w12
    bn.mulvm.16H w21, w5, w13
    bn.mulvm.16H w22, w6, w14
    bn.mulvm.16H w23, w7, w15

    /* Multiply ai*bi+1, ai+1*bi */
    bn.rshi      w24, w31, w8 >> 16  /*0||b_15||b_14||b_13||...||b3||b2||b1*/
    bn.trn1.16H  w8, w24, w8 /*b14||b15||...||b2||b3||b0||b1*/
    bn.mulvm.16H w8, w0, w8 

    bn.rshi      w24, w31, w9 >> 16  
    bn.trn1.16H  w9, w24, w9 
    bn.mulvm.16H w9, w1, w9 

    bn.rshi      w24, w31, w10 >> 16  
    bn.trn1.16H  w10, w24, w10 
    bn.mulvm.16H w10, w2, w10 

    bn.rshi      w24, w31, w11 >> 16  
    bn.trn1.16H  w11, w24, w11 
    bn.mulvm.16H w11, w3, w11

    bn.rshi      w24, w31, w12 >> 16  
    bn.trn1.16H  w12, w24, w12 
    bn.mulvm.16H w12, w4, w12 

    bn.rshi      w24, w31, w13 >> 16  
    bn.trn1.16H  w13, w24, w13 
    bn.mulvm.16H w13, w5, w13

    bn.rshi      w24, w31, w14 >> 16  
    bn.trn1.16H  w14, w24, w14 
    bn.mulvm.16H w14, w6, w14 

    bn.rshi      w24, w31, w15 >> 16  
    bn.trn1.16H  w15, w24, w15 
    bn.mulvm.16H w15, w7, w15 

    /* Load twiddle factors */
    bn.lid x4,  0(x28++)
    bn.lid x5,  0(x28++)
    bn.lid x6,  0(x28++)
    bn.lid x7,  0(x28++)

    /* Multiply ai*bi*zeta */
    bn.trn2.16H  w24, w16, w17
    bn.mulvm.16H w24, w24, w0 
    bn.trn1.16H  w16, w16, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w17, w17, w24

    bn.trn2.16H  w24, w18, w19
    bn.mulvm.16H w24, w24, w1 
    bn.trn1.16H  w18, w18, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w19, w19, w24

    bn.trn2.16H  w24, w20, w21
    bn.mulvm.16H w24, w24, w2 
    bn.trn1.16H  w20, w20, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w21, w21, w24

    bn.trn2.16H  w24, w22, w23
    bn.mulvm.16H w24, w24, w3 
    bn.trn1.16H  w22, w22, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w23, w23, w24 

    /* Add ai*bi + ai+1*bi */
    /* w0--w7: ai*bi*zeta */
    /* w8--w15: ai+1*bi */
    /* w16--w31: free */
    bn.trn1.16H  w0, w16, w8 
    bn.trn2.16H  w8, w16, w8 
    bn.trn1.16H  w1, w17, w9 
    bn.trn2.16H  w9, w17, w9 
    bn.trn1.16H  w2, w18, w10 
    bn.trn2.16H  w10, w18, w10 
    bn.trn1.16H  w3, w19, w11 
    bn.trn2.16H  w11, w19, w11 
    bn.trn1.16H  w4, w20, w12 
    bn.trn2.16H  w12, w20, w12 
    bn.trn1.16H  w5, w21, w13 
    bn.trn2.16H  w13, w21, w13 
    bn.trn1.16H  w6, w22, w14 
    bn.trn2.16H  w14, w22, w14 
    bn.trn1.16H  w7, w23, w15 
    bn.trn2.16H  w15, w23, w15 

    /* Return result */
    bn.addvm.16H w0, w0, w8
    bn.addvm.16H w1, w1, w9
    bn.addvm.16H w2, w2, w10
    bn.addvm.16H w3, w3, w11
    bn.addvm.16H w4, w4, w12
    bn.addvm.16H w5, w5, w13
    bn.addvm.16H w6, w6, w14
    bn.addvm.16H w7, w7, w15

    /* Store output */
    bn.sid x4,  0(x13++)
    bn.sid x5,  0(x13++)
    bn.sid x6,  0(x13++)
    bn.sid x7,  0(x13++)
    bn.sid x8,  0(x13++)
    bn.sid x9,  0(x13++)
    bn.sid x14, 0(x13++)
    bn.sid x15, 0(x13++)

  ret
    

/*
 * basemull_acc_kyber
 *
 * Returns: NTT(a)*NTT(b) 
 *
 * This implements the accumulating basemul for Kyber, where n=256, q=3329.
 *
 * Flags: -
 *
 * @param[in]  x29: dptr_input1, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to second word of input polynomial
 * @param[in]  x28: dptr_tw, dmem pointer to array of twiddles_basemul
 * @param[out] x13: dmem pointer to result
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */

.globl basemul_acc_kyber
basemul_acc_kyber:
  /* Set up wide registers for inputs*/
  li x4, 0
  li x5, 1 
  li x6, 2 
  li x7, 3 
  li x8, 4 
  li x9, 5 
  li x14, 6 
  li x15, 7 
  li x16, 8
  li x17, 9
  li x18, 10
  li x19, 11
  li x20, 12
  li x21, 13
  li x22, 14
  li x23, 15
  bn.xor w31, w31, w31

  LOOPI 2, 121
    /* Load input */
    bn.lid x4,  0(x29++)
    bn.lid x5,  0(x29++)
    bn.lid x6,  0(x29++)
    bn.lid x7,  0(x29++)
    bn.lid x8,  0(x29++)
    bn.lid x9,  0(x29++)
    bn.lid x14, 0(x29++)
    bn.lid x15, 0(x29++)

    bn.lid x16, 0(x11++)
    bn.lid x17, 0(x11++)
    bn.lid x18, 0(x11++)
    bn.lid x19, 0(x11++)
    bn.lid x20, 0(x11++)
    bn.lid x21, 0(x11++)
    bn.lid x22, 0(x11++)
    bn.lid x23, 0(x11++)

    /* Multiply ai*bi */
    bn.mulvm.16H w16, w0, w8
    bn.mulvm.16H w17, w1, w9
    bn.mulvm.16H w18, w2, w10
    bn.mulvm.16H w19, w3, w11
    bn.mulvm.16H w20, w4, w12
    bn.mulvm.16H w21, w5, w13
    bn.mulvm.16H w22, w6, w14
    bn.mulvm.16H w23, w7, w15

    /* Multiply ai*bi+1, ai+1*bi */
    bn.rshi      w24, w31, w8 >> 16  /*0||b_15||b_14||b_13||...||b3||b2||b1*/
    bn.trn1.16H  w8, w24, w8 /*b14||b15||...||b2||b3||b0||b1*/
    bn.mulvm.16H w8, w0, w8 

    bn.rshi      w24, w31, w9 >> 16  
    bn.trn1.16H  w9, w24, w9 
    bn.mulvm.16H w9, w1, w9 

    bn.rshi      w24, w31, w10 >> 16  
    bn.trn1.16H  w10, w24, w10 
    bn.mulvm.16H w10, w2, w10 

    bn.rshi      w24, w31, w11 >> 16  
    bn.trn1.16H  w11, w24, w11 
    bn.mulvm.16H w11, w3, w11

    bn.rshi      w24, w31, w12 >> 16  
    bn.trn1.16H  w12, w24, w12 
    bn.mulvm.16H w12, w4, w12 

    bn.rshi      w24, w31, w13 >> 16  
    bn.trn1.16H  w13, w24, w13 
    bn.mulvm.16H w13, w5, w13

    bn.rshi      w24, w31, w14 >> 16  
    bn.trn1.16H  w14, w24, w14 
    bn.mulvm.16H w14, w6, w14 

    bn.rshi      w24, w31, w15 >> 16  
    bn.trn1.16H  w15, w24, w15 
    bn.mulvm.16H w15, w7, w15 

    /* Load twiddle factors */
    bn.lid x4,  0(x28++)
    bn.lid x5,  0(x28++)
    bn.lid x6,  0(x28++)
    bn.lid x7,  0(x28++)

    /* Multiply ai*bi*zeta */
    bn.trn2.16H  w24, w16, w17
    bn.mulvm.16H w24, w24, w0 
    bn.trn1.16H  w16, w16, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w17, w17, w24

    bn.trn2.16H  w24, w18, w19
    bn.mulvm.16H w24, w24, w1 
    bn.trn1.16H  w18, w18, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w19, w19, w24

    bn.trn2.16H  w24, w20, w21
    bn.mulvm.16H w24, w24, w2 
    bn.trn1.16H  w20, w20, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w21, w21, w24

    bn.trn2.16H  w24, w22, w23
    bn.mulvm.16H w24, w24, w3 
    bn.trn1.16H  w22, w22, w24 
    bn.rshi      w24, w31, w24 >> 16
    bn.trn1.16H  w23, w23, w24 

    /* Add ai*bi + ai+1*bi */
    /* w0--w7: ai*bi*zeta */
    /* w8--w15: ai+1*bi */
    /* w16--w31: free */
    bn.trn1.16H  w0, w16, w8 
    bn.trn2.16H  w8, w16, w8 
    bn.trn1.16H  w1, w17, w9 
    bn.trn2.16H  w9, w17, w9 
    bn.trn1.16H  w2, w18, w10 
    bn.trn2.16H  w10, w18, w10 
    bn.trn1.16H  w3, w19, w11 
    bn.trn2.16H  w11, w19, w11 
    bn.trn1.16H  w4, w20, w12 
    bn.trn2.16H  w12, w20, w12 
    bn.trn1.16H  w5, w21, w13 
    bn.trn2.16H  w13, w21, w13 
    bn.trn1.16H  w6, w22, w14 
    bn.trn2.16H  w14, w22, w14 
    bn.trn1.16H  w7, w23, w15 
    bn.trn2.16H  w15, w23, w15 

    /* Return result */
    bn.addvm.16H w0, w0, w8
    bn.addvm.16H w1, w1, w9
    bn.addvm.16H w2, w2, w10
    bn.addvm.16H w3, w3, w11
    bn.addvm.16H w4, w4, w12
    bn.addvm.16H w5, w5, w13
    bn.addvm.16H w6, w6, w14
    bn.addvm.16H w7, w7, w15

    /* Load inputs at dmem_result */
    bn.lid x16, 0(x13++)
    bn.lid x17, 0(x13++)
    bn.lid x18, 0(x13++)
    bn.lid x19, 0(x13++)
    bn.lid x20, 0(x13++)
    bn.lid x21, 0(x13++)
    bn.lid x22, 0(x13++)
    bn.lid x23, 0(x13++)

    /* Accumulate */
    bn.addvm.16H w0, w0, w8
    bn.addvm.16H w1, w1, w9
    bn.addvm.16H w2, w2, w10
    bn.addvm.16H w3, w3, w11
    bn.addvm.16H w4, w4, w12
    bn.addvm.16H w5, w5, w13
    bn.addvm.16H w6, w6, w14
    bn.addvm.16H w7, w7, w15

    /* Reset dmem_result */
    addi x13, x13, -256

    /* Store output */
    bn.sid x4,  0(x13++)
    bn.sid x5,  0(x13++)
    bn.sid x6,  0(x13++)
    bn.sid x7,  0(x13++)
    bn.sid x8,  0(x13++)
    bn.sid x9,  0(x13++)
    bn.sid x14, 0(x13++)
    bn.sid x15, 0(x13++)

  ret
