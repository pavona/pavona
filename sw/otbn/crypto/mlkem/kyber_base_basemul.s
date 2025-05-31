/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text
/* Register aliases */
.equ x0, zero
.equ x2, sp
.equ x3, fp
  #define inpa w0 
  #define inpb w1
  #define coeff_a0 w2
  #define coeff_a1 w3
  #define coeff_a2 w4
  #define coeff_a3 w5
  #define coeff_b0 w6
  #define coeff_b1 w7
  #define coeff_b2 w8
  #define coeff_b3 w9
  #define mul0 w10
  #define mul1 w11
  #define wtmp w12
  #define mask w13
  #define wtmp3 w14
  #define tf1 w15
  #define bn0 w31
  #define bufres w16
  #define wtmp2 w17
  #define bufacc w18
  #define mask2 w19

  #define inp1 x29
  #define inp2 x11 
  #define outp x13
  #define twp x28
  
  /* GPRs with indices to access WDRs */
  #define inpa_idx x4
  #define inpb_idx x5
  #define coeff_a0_idx x6
  #define coeff_a1_idx x7
  #define coeff_a2_idx x8
  #define coeff_a3_idx x9
  #define coeff_b0_idx x14
  #define coeff_b1_idx x15
  #define coeff_b2_idx x16
  #define coeff_b3_idx x17
  #define mul0_idx x18
  #define mul1_idx x19
  #define wtmp_idx x20
  #define tmp_gpr  x21
  #define tmp_gpr2 x22
  #define mask_idx x23
  #define wtmp3_idx x24
  #define tf1_idx x25
  #define bn0_idx x31
  #define bufres_idx x26
  #define bufacc_idx x27

.globl basemul_base_kyber
basemul_base_kyber:
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0

  /* Set up constants for input/twiddle factors */
  li inpa_idx, 0
  li inpb_idx, 1
  li mul0_idx, 10
  li mul1_idx, 11
  li tf1_idx, 15
  li bufres_idx, 16

  /* Zero out one register */
  bn.xor bn0, bn0, bn0
  /* 0xFFFFFFFF for masking */
  bn.addi mask, bn0, 1
  bn.rshi mask, mask, bn0 >> 224
  bn.subi mask, mask, 1 

  li     tmp_gpr2, 12 /* wtmp */
  /*Set zero quad word to 1/q % 2^32 */
  la     tmp_gpr, qinv
  bn.lid tmp_gpr2, 0(tmp_gpr)
  bn.or  wtmp3, bn0, wtmp
  /* Set second WLEN/4 quad word to modulus */
  la     tmp_gpr, modulus
  bn.lid tmp_gpr2, 0(tmp_gpr)
  bn.or  wtmp3, wtmp3, wtmp << 128
  /* Load alpha to wtmp3.1 */
  bn.addi wtmp, bn0, 1
  bn.or   wtmp3, wtmp3, wtmp << 64
  /* Load mask to wtmp3.3 */
  bn.or wtmp3, wtmp3, mask << 192

  /* 0xFFFF for masking */
  bn.addi wtmp2, bn0, 1
  bn.rshi wtmp2, wtmp2, bn0 >> 240
  bn.subi wtmp2, wtmp2, 1
  LOOPI 4, 1
    bn.rshi mask, wtmp2, mask >> 64

  /* Point to right Twiddle factors for basemul in the twiddles_ntt_base */
  addi twp, twp, 160

  LOOPI 16, 281
    bn.lid inpa_idx, 0(inp1++)
    bn.lid inpb_idx, 0(inp2++)
    bn.lid tf1_idx, 0(twp++) /* Load twiddle factors: 4 twds */

    bn.and  coeff_a0, mask, inpa /* a0, a4, a8, a12 */
    bn.and  coeff_a1, mask, inpa >> 16 /* a1, a5, a9, a13 */
    bn.and  coeff_a2, mask, inpa >> 32 /* a2, a6, a10, a14 */
    bn.and  coeff_a3, mask, inpa >> 48 /* a3, a7, a11, a15 */

    bn.and  coeff_b0, mask, inpb /* b0, b4, b8, b12 */
    bn.and  coeff_b1, mask, inpb >> 16 /* b1, b5, b9, b13 */
    bn.and  coeff_b2, mask, inpb >> 32 /* b2, b6, b10, b14 */
    bn.and  coeff_b3, mask, inpb >> 48 /* b3, b7, b11, b15 */

    /*-----------------------------------------*/
    /* Plantard multiplication: a0*b0 */
    bn.mulqacc.wo.z wtmp, coeff_a0.0, coeff_b0.0, 0 /* a0*b0 */
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192      /* a0*b0*qinv % 2^64 */
    bn.and          wtmp, wtmp, wtmp3               /* a0*b0*qinv % 2^32 */
    bn.add          wtmp, wtmp3, wtmp >> 144        
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a1*b1 */
    bn.mulqacc.wo.z wtmp, coeff_a1.0, coeff_b1.0, 0 
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192      
    bn.and          wtmp, wtmp, wtmp3               
    bn.add          wtmp, wtmp3, wtmp >> 144        
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a1*b1*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r0 = a1*b1*tf + a0*b0 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a0*b1 */
    bn.mulqacc.wo.z wtmp, coeff_a0.0, coeff_b1.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a1*b0 */
    bn.mulqacc.wo.z wtmp, coeff_a1.0, coeff_b0.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r1 = a0*b1 + a1*b0 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a2*b2 */
    bn.mulqacc.wo.z wtmp, coeff_a2.0, coeff_b2.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a3*b3 */
    bn.mulqacc.wo.z wtmp, coeff_a3.0, coeff_b3.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a3*b3 */
    bn.subm mul1, bn0, mul1 
    
    /* Plantard multiplication: a3*b3*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r2 = a3*b3*(-tf) + a2*b2 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a2*b3 */
    bn.mulqacc.wo.z wtmp, coeff_a2.0, coeff_b3.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a3*b2 */
    bn.mulqacc.wo.z wtmp, coeff_a3.0, coeff_b2.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r3 = a2*b3 + a3*b2 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a4*b4 */
    bn.mulqacc.wo.z wtmp, coeff_a0.1, coeff_b0.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a5*b5 */
    bn.mulqacc.wo.z wtmp, coeff_a1.1, coeff_b1.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a5*b5*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.1, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r4 = a5*b5*tf + a4*b4 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a4*b5 */
    bn.mulqacc.wo.z wtmp, coeff_a0.1, coeff_b1.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a5*b4 */
    bn.mulqacc.wo.z wtmp, coeff_a1.1, coeff_b0.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r5 = a4*b5 + a5*b4 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a6*b6 */
    bn.mulqacc.wo.z wtmp, coeff_a2.1, coeff_b2.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a7*b7 */
    bn.mulqacc.wo.z wtmp, coeff_a3.1, coeff_b3.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a7*b7 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a7*b7*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.1, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r6 = a7*b7*(-tf) + a6*b6 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a6*b7 */
    bn.mulqacc.wo.z wtmp, coeff_a2.1, coeff_b3.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a7*b6 */
    bn.mulqacc.wo.z wtmp, coeff_a3.1, coeff_b2.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r7 = a6*b7 + a7*b6 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a8*b8 */
    bn.mulqacc.wo.z wtmp, coeff_a0.2, coeff_b0.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a9*b9 */
    bn.mulqacc.wo.z wtmp, coeff_a1.2, coeff_b1.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a9*b9*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.2, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r8 = a9*b9*tf + a8*b8 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a8*b9 */
    bn.mulqacc.wo.z wtmp, coeff_a0.2, coeff_b1.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a9*b8 */
    bn.mulqacc.wo.z wtmp, coeff_a1.2, coeff_b0.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r9 = a8*b9 + a9*b8 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a10*b10 */
    bn.mulqacc.wo.z wtmp, coeff_a2.2, coeff_b2.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a11*b11 */
    bn.mulqacc.wo.z wtmp, coeff_a3.2, coeff_b3.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a11*b11 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a11*b11*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.2, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r10 = a11*b11*(-tf) + a10*b10 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a10*b11 */
    bn.mulqacc.wo.z wtmp, coeff_a2.2, coeff_b3.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a11*b10 */
    bn.mulqacc.wo.z wtmp, coeff_a3.2, coeff_b2.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r11 = a10*b11 + a11*b10 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a12*b12 */
    bn.mulqacc.wo.z wtmp, coeff_a0.3, coeff_b0.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a13*b13 */
    bn.mulqacc.wo.z wtmp, coeff_a1.3, coeff_b1.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a13*b13*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.3, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r12 = a13*b13*tf + a12*b12 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a12*b13 */
    bn.mulqacc.wo.z wtmp, coeff_a0.3, coeff_b1.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a13*b12 */
    bn.mulqacc.wo.z wtmp, coeff_a1.3, coeff_b0.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r13 = a12*b13 + a13*b12 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a14*b14 */
    bn.mulqacc.wo.z wtmp, coeff_a2.3, coeff_b2.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a15*b15 */
    bn.mulqacc.wo.z wtmp, coeff_a3.3, coeff_b3.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a15*b15 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a15*b15*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.3, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r14 = a15*b15*(-tf) + a14*b14 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a14*b15 */
    bn.mulqacc.wo.z wtmp, coeff_a2.3, coeff_b3.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a15*b14 */
    bn.mulqacc.wo.z wtmp, coeff_a3.3, coeff_b2.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r15 = a14*b15 + a15*b14 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    bn.sid bufres_idx, 0(outp++)

    /* Adjust Twiddle pointer */
    addi twp, twp, 32

  /* Zero w31 again */
  bn.xor w31, w31, w31

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw fp, 0(sp)
  addi sp, sp, 32
  ret

.globl basemul_acc_base_kyber
basemul_acc_base_kyber:
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0

  /* Set up constants for input/twiddle factors */
  li inpa_idx, 0
  li inpb_idx, 1
  li mul0_idx, 10
  li mul1_idx, 11
  li tf1_idx, 15
  li bufres_idx, 16
  li bufacc_idx, 18

  /* Zero out one register */
  bn.xor bn0, bn0, bn0
  /* 0xFFFFFFFF for masking */
  bn.addi mask, bn0, 1
  bn.rshi mask, mask, bn0 >> 224
  bn.subi mask, mask, 1 

  li     tmp_gpr2, 12 /* wtmp */
  /*Set zero quad word to 1/q % 2^32 */
  la     tmp_gpr, qinv
  bn.lid tmp_gpr2, 0(tmp_gpr)
  bn.or  wtmp3, bn0, wtmp
  /* Set second WLEN/4 quad word to modulus */
  la     tmp_gpr, modulus
  bn.lid tmp_gpr2, 0(tmp_gpr)
  bn.or  wtmp3, wtmp3, wtmp << 128
  /* Load alpha to wtmp3.1 */
  bn.addi wtmp, bn0, 1
  bn.or   wtmp3, wtmp3, wtmp << 64
  /* Load mask to wtmp3.3 */
  bn.or wtmp3, wtmp3, mask << 192

  /* 0xFFFF for masking */
  bn.addi wtmp2, bn0, 1
  bn.rshi wtmp2, wtmp2, bn0 >> 240
  bn.subi wtmp2, wtmp2, 1
  bn.add  mask2, bn0, wtmp2
  LOOPI 4, 1
    bn.rshi mask, wtmp2, mask >> 64

  addi twp, twp, 160

  LOOPI 16, 283
    bn.lid inpa_idx, 0(inp1++)
    bn.lid inpb_idx, 0(inp2++)
    bn.lid tf1_idx, 0(twp++) /* Load twiddle factors: 4 twds */

    bn.and  coeff_a0, mask, inpa /* a0, a4, a8, a12 */
    bn.and  coeff_a1, mask, inpa >> 16 /* a1, a5, a9, a13 */
    bn.and  coeff_a2, mask, inpa >> 32 /* a2, a6, a10, a14 */
    bn.and  coeff_a3, mask, inpa >> 48 /* a3, a7, a11, a15 */

    bn.and  coeff_b0, mask, inpb /* b0, b4, b8, b12 */
    bn.and  coeff_b1, mask, inpb >> 16 /* b1, b5, b9, b13 */
    bn.and  coeff_b2, mask, inpb >> 32 /* b2, b6, b10, b14 */
    bn.and  coeff_b3, mask, inpb >> 48 /* b3, b7, b11, b15 */

    /*-----------------------------------------*/
    /* Plantard multiplication: a0*b0 */
    bn.mulqacc.wo.z wtmp, coeff_a0.0, coeff_b0.0, 0 /* a0*b0 */
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192      /* a0*b0*qinv % 2^64 */
    bn.and          wtmp, wtmp, wtmp3               /* a0*b0*qinv % 2^32 */
    bn.add          wtmp, wtmp3, wtmp >> 144        
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a1*b1 */
    bn.mulqacc.wo.z wtmp, coeff_a1.0, coeff_b1.0, 0 
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192      
    bn.and          wtmp, wtmp, wtmp3               
    bn.add          wtmp, wtmp3, wtmp >> 144        
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a1*b1*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r0 = a1*b1*tf + a0*b0 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a0*b1 */
    bn.mulqacc.wo.z wtmp, coeff_a0.0, coeff_b1.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a1*b0 */
    bn.mulqacc.wo.z wtmp, coeff_a1.0, coeff_b0.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r1 = a0*b1 + a1*b0 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a2*b2 */
    bn.mulqacc.wo.z wtmp, coeff_a2.0, coeff_b2.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a3*b3 */
    bn.mulqacc.wo.z wtmp, coeff_a3.0, coeff_b3.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a3*b3 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a3*b3*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r2 = a3*b3*(-tf) + a2*b2 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a2*b3 */
    bn.mulqacc.wo.z wtmp, coeff_a2.0, coeff_b3.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a3*b2 */
    bn.mulqacc.wo.z wtmp, coeff_a3.0, coeff_b2.0, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r3 = a2*b3 + a3*b2 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a4*b4 */
    bn.mulqacc.wo.z wtmp, coeff_a0.1, coeff_b0.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a5*b5 */
    bn.mulqacc.wo.z wtmp, coeff_a1.1, coeff_b1.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a5*b5*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.1, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r4 = a5*b5*tf + a4*b4 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a4*b5 */
    bn.mulqacc.wo.z wtmp, coeff_a0.1, coeff_b1.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a5*b4 */
    bn.mulqacc.wo.z wtmp, coeff_a1.1, coeff_b0.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r5 = a4*b5 + a5*b4 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a6*b6 */
    bn.mulqacc.wo.z wtmp, coeff_a2.1, coeff_b2.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a7*b7 */
    bn.mulqacc.wo.z wtmp, coeff_a3.1, coeff_b3.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a7*b7 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a7*b7*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.1, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r6 = a7*b7*(-tf) + a6*b6 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a6*b7 */
    bn.mulqacc.wo.z wtmp, coeff_a2.1, coeff_b3.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a7*b6 */
    bn.mulqacc.wo.z wtmp, coeff_a3.1, coeff_b2.1, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r7 = a6*b7 + a7*b6 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a8*b8 */
    bn.mulqacc.wo.z wtmp, coeff_a0.2, coeff_b0.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a9*b9 */
    bn.mulqacc.wo.z wtmp, coeff_a1.2, coeff_b1.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a9*b9*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.2, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r8 = a9*b9*tf + a8*b8 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a8*b9 */
    bn.mulqacc.wo.z wtmp, coeff_a0.2, coeff_b1.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a9*b8 */
    bn.mulqacc.wo.z wtmp, coeff_a1.2, coeff_b0.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r9 = a8*b9 + a9*b8 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a10*b10 */
    bn.mulqacc.wo.z wtmp, coeff_a2.2, coeff_b2.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a11*b11 */
    bn.mulqacc.wo.z wtmp, coeff_a3.2, coeff_b3.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a11*b11 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a11*b11*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.2, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r10 = a11*b11*(-tf) + a10*b10 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a10*b11 */
    bn.mulqacc.wo.z wtmp, coeff_a2.2, coeff_b3.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a11*b10 */
    bn.mulqacc.wo.z wtmp, coeff_a3.2, coeff_b2.2, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r11 = a10*b11 + a11*b10 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a12*b12 */
    bn.mulqacc.wo.z wtmp, coeff_a0.3, coeff_b0.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a13*b13 */
    bn.mulqacc.wo.z wtmp, coeff_a1.3, coeff_b1.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* Plantard multiplication: a13*b13*tf */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.3, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r12 = a13*b13*tf + a12*b12 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a12*b13 */
    bn.mulqacc.wo.z wtmp, coeff_a0.3, coeff_b1.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a13*b12 */
    bn.mulqacc.wo.z wtmp, coeff_a1.3, coeff_b0.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r13 = a12*b13 + a13*b12 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a14*b14 */
    bn.mulqacc.wo.z wtmp, coeff_a2.3, coeff_b2.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a15*b15 */
    bn.mulqacc.wo.z wtmp, coeff_a3.3, coeff_b3.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16
    
    /* -a15*b15 */
    bn.subm mul1, bn0, mul1  
    
    /* Plantard multiplication: a15*b15*(-tf) */
    bn.mulqacc.wo.z wtmp, mul1.0, tf1.3, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r14 = a15*b15*(-tf) + a14*b14 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* Plantard multiplication: a14*b15 */
    bn.mulqacc.wo.z wtmp, coeff_a2.3, coeff_b3.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul0, bn0, wtmp >> 16

    /* Plantard multiplication: a15*b14 */
    bn.mulqacc.wo.z wtmp, coeff_a3.3, coeff_b2.3, 0
    bn.mulqacc.wo.z wtmp, wtmp.0, wtmp3.0, 192
    bn.and          wtmp, wtmp, wtmp3
    bn.add          wtmp, wtmp3, wtmp >> 144
    bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0
    bn.rshi         mul1, bn0, wtmp >> 16

    /* r15 = a14*b15 + a15*b14 */
    bn.addm mul0, mul0, mul1 
    bn.rshi bufres, mul0, bufres >> 16

    /* accumulating */
    bn.lid bufacc_idx, 0(outp)
    bn.add bufres, bufres,bufacc
    bn.sid bufres_idx, 0(outp++)

    addi twp, twp, 32

  /* Zero w31 again */
  bn.xor w31, w31, w31

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw fp, 0(sp)
  addi sp, sp, 32
  ret