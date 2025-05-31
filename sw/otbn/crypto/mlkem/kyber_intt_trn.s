/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/*
 * Constant-time Kyber inverse INTT
 *
 * Returns: INTT(input)
 *
 * This implements the in-place INTT for Kyber, where n=256, q=3329.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_tw, dmem pointer to array of twiddle factors,
          last element is n^{-1} mod q
 * @param[in]  x12: dptr_output, dmem pointer to output polynomial
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */

.globl intt_kyber
intt_kyber:
  /* Set up wide registers for input and intermediate states */
  li x4, 0
  li x5, 1 
  li x6, 2 
  li x7, 3 
  li x8, 4 
  li x9, 5 
  li x13, 6 
  li x14, 7 
  li x15, 8
  li x16, 9
  li x17, 10
  li x18, 11
  li x19, 12
  li x20, 13
  li x21, 14
  li x22, 15

  /* Set up wide registers for input and twiddle factors */
  li x23, 16
  li x24, 17
  li x25, 18
  li x26, 19
  li x31, 20
  li x28, 21
  li x29, 22
  li x30, 23

  /* Load input */
  bn.lid x4,  0(x10++)
  bn.lid x5,  0(x10++)
  bn.lid x6,  0(x10++)
  bn.lid x7,  0(x10++)
  bn.lid x8,  0(x10++)
  bn.lid x9,  0(x10++)
  bn.lid x13, 0(x10++)
  bn.lid x14, 0(x10++)
  bn.lid x15, 0(x10++)
  bn.lid x16, 0(x10++)
  bn.lid x17, 0(x10++)
  bn.lid x18, 0(x10++)
  bn.lid x19, 0(x10++)
  bn.lid x20, 0(x10++)
  bn.lid x21, 0(x10++)
  bn.lid x22, 0(x10++)

  /* Transpose for Layers 7--5 */
  /* First trans w24-w31 */
  bn.trn1.8S w24, w0, w1
  bn.trn2.8S w25, w0, w1 
  bn.trn1.8S w26, w2, w3  
  bn.trn2.8S w27, w2, w3
  bn.trn1.8S w28, w4, w5
  bn.trn2.8S w29, w4, w5
  bn.trn1.8S w30, w6, w7
  bn.trn2.8S w31, w6, w7 
  
  bn.trn1.4D w0, w24, w26
  bn.trn2.4D w2, w24, w26 
  bn.trn1.4D w1, w25, w27
  bn.trn2.4D w3, w25, w27 
  bn.trn1.4D w4, w28, w30 
  bn.trn2.4D w6, w28, w30 
  bn.trn1.4D w5, w29, w31
  bn.trn2.4D w7, w29, w31 
  
  bn.trn1.2Q w24, w0, w4 
  bn.trn2.2Q w28, w0, w4 
  bn.trn1.2Q w25, w1, w5 
  bn.trn2.2Q w29, w1, w5 
  bn.trn1.2Q w26, w2, w6
  bn.trn2.2Q w30, w2, w6
  bn.trn1.2Q w27, w3, w7
  bn.trn2.2Q w31, w3, w7  

  /* Second trans w0-w7 */
  bn.trn1.8S w0, w8, w9
  bn.trn2.8S w1, w8, w9 
  bn.trn1.8S w2, w10, w11  
  bn.trn2.8S w3, w10, w11
  bn.trn1.8S w4, w12, w13
  bn.trn2.8S w5, w12, w13
  bn.trn1.8S w6, w14, w15
  bn.trn2.8S w7, w14, w15 

  bn.trn1.4D w8, w0, w2
  bn.trn2.4D w10, w0, w2 
  bn.trn1.4D w9, w1, w3
  bn.trn2.4D w11, w1, w3 
  bn.trn1.4D w12, w4, w6 
  bn.trn2.4D w14, w4, w6 
  bn.trn1.4D w13, w5, w7
  bn.trn2.4D w15, w5, w7 

  bn.trn1.2Q w0, w8, w12 
  bn.trn2.2Q w4, w8, w12 
  bn.trn1.2Q w1, w9, w13 
  bn.trn2.2Q w5, w9, w13 
  bn.trn1.2Q w2, w10, w14
  bn.trn2.2Q w6, w10, w14
  bn.trn1.2Q w3, w11, w15
  bn.trn2.2Q w7, w11, w15 

  /* Layer 7, stride 2 */
  #define wtmp w8
  /*Load twiddle factors */
  bn.lid x23, 0(x11)
  bn.lid x24, 32(x11)
  bn.lid x25, 64(x11)
  bn.lid x26, 96(x11)
  bn.lid x31, 128(x11)
  bn.lid x28, 160(x11)
  bn.lid x29, 192(x11)
  bn.lid x30, 224(x11)  

  /* Butterflies */
  bn.subvm.16H wtmp, w24, w25
  bn.addvm.16H w24, w24, w25
  bn.mulvm.16H w25, wtmp, w16
  bn.subvm.16H wtmp, w26, w27
  bn.addvm.16H w26, w26, w27
  bn.mulvm.16H w27, wtmp, w17
  bn.subvm.16H wtmp, w28, w29
  bn.addvm.16H w28, w28, w29
  bn.mulvm.16H w29, wtmp, w18
  bn.subvm.16H wtmp, w30, w31
  bn.addvm.16H w30, w30, w31
  bn.mulvm.16H w31, wtmp, w19
  bn.subvm.16H wtmp, w0, w1
  bn.addvm.16H w0, w0, w1
  bn.mulvm.16H w1, wtmp, w20
  bn.subvm.16H wtmp, w2, w3
  bn.addvm.16H w2, w2, w3
  bn.mulvm.16H w3, wtmp, w21
  bn.subvm.16H wtmp, w4, w5
  bn.addvm.16H w4, w4, w5
  bn.mulvm.16H w5, wtmp, w22
  bn.subvm.16H wtmp, w6, w7
  bn.addvm.16H w6, w6, w7
  bn.mulvm.16H w7, wtmp, w23

  /* Layer 6, stride 4 */
  /* Load twiddle factors */
  bn.lid x23, 256(x11)
  bn.lid x24, 288(x11)
  bn.lid x25, 320(x11)
  bn.lid x26, 352(x11)
  
   /* Butterflies */
  bn.subvm.16H wtmp, w24, w26
  bn.addvm.16H w24, w24, w26
  bn.mulvm.16H w26, wtmp, w16
  bn.subvm.16H wtmp, w25, w27
  bn.addvm.16H w25, w25, w27
  bn.mulvm.16H w27, wtmp, w16
  bn.subvm.16H wtmp, w28, w30
  bn.addvm.16H w28, w28, w30
  bn.mulvm.16H w30, wtmp, w17
  bn.subvm.16H wtmp, w29, w31
  bn.addvm.16H w29, w29, w31
  bn.mulvm.16H w31, wtmp, w17
  bn.subvm.16H wtmp, w0, w2
  bn.addvm.16H w0, w0, w2
  bn.mulvm.16H w2, wtmp, w18
  bn.subvm.16H wtmp, w1, w3
  bn.addvm.16H w1, w1, w3
  bn.mulvm.16H w3, wtmp, w18
  bn.subvm.16H wtmp, w4, w6
  bn.addvm.16H w4, w4, w6
  bn.mulvm.16H w6, wtmp, w19
  bn.subvm.16H wtmp, w5, w7
  bn.addvm.16H w5, w5, w7
  bn.mulvm.16H w7, wtmp, w19

  /* Layer 5, stride 8 */
  /* Load twiddle factors */
  bn.lid x23, 384(x11)
  bn.lid x24, 416(x11)

   /* Butterflies */
  bn.subvm.16H wtmp, w24, w28
  bn.addvm.16H w24, w24, w28
  bn.mulvm.16H w28, wtmp, w16
  bn.subvm.16H wtmp, w25, w29
  bn.addvm.16H w25, w25, w29
  bn.mulvm.16H w29, wtmp, w16
  bn.subvm.16H wtmp, w26, w30
  bn.addvm.16H w26, w26, w30
  bn.mulvm.16H w30, wtmp, w16
  bn.subvm.16H wtmp, w27, w31
  bn.addvm.16H w27, w27, w31
  bn.mulvm.16H w31, wtmp, w16
  bn.subvm.16H wtmp, w0, w4
  bn.addvm.16H w0, w0, w4
  bn.mulvm.16H w4, wtmp, w17
  bn.subvm.16H wtmp, w1, w5
  bn.addvm.16H w1, w1, w5
  bn.mulvm.16H w5, wtmp, w17
  bn.subvm.16H wtmp, w2, w6
  bn.addvm.16H w2, w2, w6
  bn.mulvm.16H w6, wtmp, w17
  bn.subvm.16H wtmp, w3, w7
  bn.addvm.16H w3, w3, w7
  bn.mulvm.16H w7, wtmp, w17

  /* Transpose back */
  /* First trans w8-w15 */
  bn.trn1.8S w8, w0, w1
  bn.trn2.8S w9, w0, w1 
  bn.trn1.8S w10, w2, w3  
  bn.trn2.8S w11, w2, w3
  bn.trn1.8S w12, w4, w5
  bn.trn2.8S w13, w4, w5
  bn.trn1.8S w14, w6, w7
  bn.trn2.8S w15, w6, w7 
  
  bn.trn1.4D w0, w8, w10
  bn.trn2.4D w2, w8, w10 
  bn.trn1.4D w1, w9, w11
  bn.trn2.4D w3, w9, w11 
  bn.trn1.4D w4, w12, w14 
  bn.trn2.4D w6, w12, w14 
  bn.trn1.4D w5, w13, w15
  bn.trn2.4D w7, w13, w15 
  
  bn.trn1.2Q w8, w0, w4 
  bn.trn2.2Q w12, w0, w4 
  bn.trn1.2Q w9, w1, w5 
  bn.trn2.2Q w13, w1, w5 
  bn.trn1.2Q w10, w2, w6
  bn.trn2.2Q w14, w2, w6
  bn.trn1.2Q w11, w3, w7
  bn.trn2.2Q w15, w3, w7  

  /* Second trans w0-w7 */
  bn.trn1.8S w0, w24, w25
  bn.trn2.8S w1, w24, w25 
  bn.trn1.8S w2, w26, w27  
  bn.trn2.8S w3, w26, w27
  bn.trn1.8S w4, w28, w29
  bn.trn2.8S w5, w28, w29
  bn.trn1.8S w6, w30, w31
  bn.trn2.8S w7, w30, w31 

  bn.trn1.4D w24, w0, w2
  bn.trn2.4D w26, w0, w2 
  bn.trn1.4D w25, w1, w3
  bn.trn2.4D w27, w1, w3 
  bn.trn1.4D w28, w4, w6 
  bn.trn2.4D w30, w4, w6 
  bn.trn1.4D w29, w5, w7
  bn.trn2.4D w31, w5, w7 

  bn.trn1.2Q w0, w24, w28 
  bn.trn2.2Q w4, w24, w28 
  bn.trn1.2Q w1, w25, w29 
  bn.trn2.2Q w5, w25, w29 
  bn.trn1.2Q w2, w26, w30
  bn.trn2.2Q w6, w26, w30
  bn.trn1.2Q w3, w27, w31
  bn.trn2.2Q w7, w27, w31 

  /* Layer 4, stride 16 */
  /* Load twiddle factors */
  bn.lid x23, 448(x11) 

  /* Butterflies */
  bn.subvm.16H   w30, w0, w1
  bn.addvm.16H   w0, w0, w1
  bn.mulvm.l.16H w1, w30, w16, 0
  bn.subvm.16H   w30, w2, w3
  bn.addvm.16H   w2, w2, w3
  bn.mulvm.l.16H w3, w30, w16, 1
  bn.subvm.16H   w30, w4, w5
  bn.addvm.16H   w4, w4, w5
  bn.mulvm.l.16H w5, w30, w16, 2
  bn.subvm.16H   w30, w6, w7
  bn.addvm.16H   w6, w6, w7
  bn.mulvm.l.16H w7, w30, w16, 3
  bn.subvm.16H   w30, w8, w9
  bn.addvm.16H   w8, w8, w9
  bn.mulvm.l.16H w9, w30, w16, 4
  bn.subvm.16H   w30, w10, w11
  bn.addvm.16H   w10, w10, w11
  bn.mulvm.l.16H w11, w30, w16, 5
  bn.subvm.16H   w30, w12, w13
  bn.addvm.16H   w12, w12, w13
  bn.mulvm.l.16H w13, w30, w16, 6
  bn.subvm.16H   w30, w14, w15
  bn.addvm.16H   w14, w14, w15
  bn.mulvm.l.16H w15, w30, w16, 7

  /* Layer 3, stride 32 */
  bn.subvm.16H   w30, w0, w2
  bn.addvm.16H   w0, w0, w2
  bn.mulvm.l.16H w2, w30, w16, 8
  bn.subvm.16H   w30, w1, w3
  bn.addvm.16H   w1, w1, w3
  bn.mulvm.l.16H w3, w30, w16, 8
  bn.subvm.16H   w30, w4, w6
  bn.addvm.16H   w4, w4, w6
  bn.mulvm.l.16H w6, w30, w16, 9
  bn.subvm.16H   w30, w5, w7
  bn.addvm.16H   w5, w5, w7
  bn.mulvm.l.16H w7, w30, w16, 9
  bn.subvm.16H   w30, w8, w10
  bn.addvm.16H   w8, w8, w10
  bn.mulvm.l.16H w10, w30, w16, 10
  bn.subvm.16H   w30, w9, w11
  bn.addvm.16H   w9, w9, w11
  bn.mulvm.l.16H w11, w30, w16, 10
  bn.subvm.16H   w30, w12, w14
  bn.addvm.16H   w12, w12, w14
  bn.mulvm.l.16H w14, w30, w16, 11
  bn.subvm.16H   w30, w13, w15
  bn.addvm.16H   w13, w13, w15
  bn.mulvm.l.16H w15, w30, w16, 11

  /* Layer 2, stride 64 */
  bn.subvm.16H   w30, w0, w4
  bn.addvm.16H   w0, w0, w4
  bn.mulvm.l.16H w4, w30, w16, 12
  bn.subvm.16H   w30, w1, w5
  bn.addvm.16H   w1, w1, w5
  bn.mulvm.l.16H w5, w30, w16, 12
  bn.subvm.16H   w30, w2, w6
  bn.addvm.16H   w2, w2, w6
  bn.mulvm.l.16H w6, w30, w16, 12
  bn.subvm.16H   w30, w3, w7
  bn.addvm.16H   w3, w3, w7
  bn.mulvm.l.16H w7, w30, w16, 12
  bn.subvm.16H   w30, w8, w12
  bn.addvm.16H   w8, w8, w12
  bn.mulvm.l.16H w12, w30, w16, 13
  bn.subvm.16H   w30, w9, w13
  bn.addvm.16H   w9, w9, w13
  bn.mulvm.l.16H w13, w30, w16, 13
  bn.subvm.16H   w30, w10, w14
  bn.addvm.16H   w10, w10, w14
  bn.mulvm.l.16H w14, w30, w16, 13
  bn.subvm.16H   w30, w11, w15
  bn.addvm.16H   w11, w11, w15
  bn.mulvm.l.16H w15, w30, w16, 13

  /* Layer 1, stride 128 */
  bn.subvm.16H   w30, w0, w8
  bn.addvm.16H   w0, w0, w8
  bn.mulvm.l.16H w8, w30, w16, 14
  bn.subvm.16H   w30, w1, w9
  bn.addvm.16H   w1, w1, w9
  bn.mulvm.l.16H w9, w30, w16, 14
  bn.subvm.16H   w30, w2, w10
  bn.addvm.16H   w2, w2, w10
  bn.mulvm.l.16H w10, w30, w16, 14
  bn.subvm.16H   w30, w3, w11
  bn.addvm.16H   w3, w3, w11
  bn.mulvm.l.16H w11, w30, w16, 14
  bn.subvm.16H   w30, w4, w12
  bn.addvm.16H   w4, w4, w12
  bn.mulvm.l.16H w12, w30, w16, 14
  bn.subvm.16H   w30, w5, w13
  bn.addvm.16H   w5, w5, w13
  bn.mulvm.l.16H w13, w30, w16, 14
  bn.subvm.16H   w30, w6, w14
  bn.addvm.16H   w6, w6, w14
  bn.mulvm.l.16H w14, w30, w16, 14
  bn.subvm.16H   w30, w7, w15
  bn.addvm.16H   w7, w7, w15
  bn.mulvm.l.16H w15, w30, w16, 14

  /* Multiply n^{-1} */
  bn.mulvm.l.16H w0, w0, w16, 15
  bn.mulvm.l.16H w1, w1, w16, 15
  bn.mulvm.l.16H w2, w2, w16, 15
  bn.mulvm.l.16H w3, w3, w16, 15
  bn.mulvm.l.16H w4, w4, w16, 15
  bn.mulvm.l.16H w5, w5, w16, 15
  bn.mulvm.l.16H w6, w6, w16, 15
  bn.mulvm.l.16H w7, w7, w16, 15

 
  /* Store output */
  bn.sid x4, 0(x12++)
  bn.sid x5, 0(x12++)
  bn.sid x6, 0(x12++)
  bn.sid x7, 0(x12++)
  bn.sid x8, 0(x12++)
  bn.sid x9, 0(x12++)
  bn.sid x13, 0(x12++)
  bn.sid x14, 0(x12++)
  bn.sid x15, 0(x12++)
  bn.sid x16, 0(x12++)
  bn.sid x17, 0(x12++)
  bn.sid x18, 0(x12++)
  bn.sid x19, 0(x12++)
  bn.sid x20, 0(x12++)
  bn.sid x21, 0(x12++)
  bn.sid x22, 0(x12++)

  ret


