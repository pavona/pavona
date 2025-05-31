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

.equ w31, bn0

.globl ntt_base_kyber
ntt_base_kyber:
  #define coeff0 w0
  #define coeff1 w1
  #define coeff2 w2
  #define coeff3 w3
  #define coeff4 w4
  #define coeff5 w5
  #define coeff6 w6
  #define coeff7 w7

  #define coeff8 w8
  #define coeff9 w9
  #define coeff10 w10
  #define coeff11 w11
  #define coeff12 w12
  #define coeff13 w13
  #define coeff14 w14
  #define coeff15 w15

  #define buf0 w31
  #define buf1 w30
  #define buf2 w29
  #define buf3 w28
  #define buf4 w27
  #define buf5 w26
  #define buf6 w25
  #define buf7 w24
  #define buf8 w17
  #define buf9 w18
  #define buf10 w19

  /* Twiddle Factors */
  #define tf1 w16

  /* Other */
  #define wtmp w20
  #define buf11 w21
  #define wtmp3 w22
  #define buf12 w23
  
  /* GPRs with indices to access WDRs */
  #define buf0_idx x4
  #define buf1_idx x5
  #define buf2_idx x6
  #define buf3_idx x7
  #define buf4_idx x8
  #define buf5_idx x9
  #define buf6_idx x13
  #define buf7_idx x14
  #define inp x10
  #define twp x11
  #define outp x12
  #define coeff8_idx x15
  #define coeff9_idx x16
  #define coeff10_idx x17
  #define coeff11_idx x18
  #define coeff12_idx x19
  #define coeff13_idx x20
  #define coeff14_idx x21
  #define coeff15_idx x22
  #define tf1_idx x23
  #define buf8_idx x24
  #define buf9_idx x25
  #define buf10_idx x26
  #define tmp_gpr x27
  #define tmp_gpr2 x28
  #define buf11_idx x29
  #define buf12_idx x30
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0
    
  /* Adjust sp to accomodate local variables */
  addi sp, sp, -512

  /* Reserve space for tmp buffer to hold a WDR */
  #define STACK_WDR2GPR -416
  #define STACK_WDRTMP_1 -448
  #define STACK_WDRTMP_2 -480
  #define STACK_WDRTMP_3 -512

  /* Set up constants for input/twiddle factors */
  li tf1_idx, 16

  li coeff8_idx, 8
  li coeff9_idx, 9
  li coeff10_idx, 10
  li coeff11_idx, 11
  li coeff12_idx, 12
  li coeff13_idx, 13
  li coeff14_idx, 14
  li coeff15_idx, 15

  li buf0_idx, 31
  li buf1_idx, 30
  li buf2_idx, 29
  li buf3_idx, 28
  li buf4_idx, 27
  li buf5_idx, 26
  li buf6_idx, 25
  li buf7_idx, 24
  li buf8_idx, 17
  li buf9_idx, 18
  li buf10_idx, 19
  li buf11_idx, 21
  li buf12_idx, 23

  /* Zero out one register */
  bn.xor buf9, buf9, buf9
  /* 0xFFFFFFFF for masking */
  bn.addi buf8, buf9, 1
  bn.rshi buf8, buf8, buf9 >> 224
  bn.subi buf8, buf8, 1 

  /* Set second WLEN/4 quad word to modulus */
  la     tmp_gpr, modulus
  li     tmp_gpr2, 20 /* Load q to wtmp */
  bn.lid tmp_gpr2, 0(tmp_gpr)
  bn.and wtmp, wtmp, buf8
  bn.or  wtmp3, buf9, wtmp << 128
  /* Load alpha to wtmp3.1 */
  bn.addi wtmp, buf9, 1
  bn.or   wtmp3, wtmp3, wtmp << 64
  /* Load mask to wtmp3.3 */
  bn.or wtmp3, wtmp3, buf8 << 192

  /* We can process 16 coefficients each iteration and need to process N=256, meaning we require 16 iterations. */
  /* Load coefficients into buffer registers */
  bn.lid buf0_idx, 0(inp)
  bn.lid buf1_idx, 32(inp)
  bn.lid buf2_idx, 64(inp)
  bn.lid buf3_idx, 96(inp)
  bn.lid buf4_idx, 128(inp)
  bn.lid buf5_idx, 160(inp)
  bn.lid buf6_idx, 192(inp)
  bn.lid buf7_idx, 224(inp)
  bn.lid buf8_idx, 256(inp)
  bn.lid buf9_idx, 288(inp)
  bn.lid buf10_idx, 320(inp)
  bn.lid buf11_idx, 352(inp)
  bn.lid buf12_idx, 384(inp) 

  LOOPI 8, 555
    bn.lid tf1_idx, 0(twp)
    /* Extract coefficients from buffer registers into working state */
    bn.and coeff0, buf0, wtmp3 >> 208
    bn.and coeff1, buf1, wtmp3 >> 208
    bn.and coeff2, buf2, wtmp3 >> 208
    bn.and coeff3, buf3, wtmp3 >> 208
    bn.and coeff4, buf4, wtmp3 >> 208
    bn.and coeff5, buf5, wtmp3 >> 208
    bn.and coeff6, buf6, wtmp3 >> 208
    bn.and coeff7, buf7, wtmp3 >> 208
    bn.and coeff8, buf8, wtmp3 >> 208
    bn.and coeff9, buf9, wtmp3 >> 208
    bn.and coeff10, buf10, wtmp3 >> 208
    bn.and coeff11, buf11, wtmp3 >> 208
    bn.and coeff12, buf12, wtmp3 >> 208

    /* Load remaining coefficients using 32-bit loads */
    /* Coeff 13 */
    lw     tmp_gpr, 416(inp)
    sw     tmp_gpr, STACK_WDRTMP_1(fp)
    bn.lid coeff13_idx, STACK_WDRTMP_1(fp)
    bn.and coeff13, coeff13, wtmp3 >> 208

    /* Coeff 14 */
    lw     tmp_gpr, 448(inp)
    sw     tmp_gpr, STACK_WDRTMP_2(fp)
    bn.lid coeff14_idx, STACK_WDRTMP_2(fp)
    bn.and coeff14, coeff14, wtmp3 >> 208

    /* Coeff 15 */
    lw     tmp_gpr, 480(inp)
    sw     tmp_gpr, STACK_WDRTMP_3(fp)
    bn.lid coeff15_idx, STACK_WDRTMP_3(fp)
    bn.and coeff15, coeff15, wtmp3 >> 208

    /* Layer 1 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff8, coeff8.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff8, coeff8, wtmp3
    bn.add          coeff8, wtmp3, coeff8 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff8, coeff8.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff8 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff8, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff9, coeff9.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff9, coeff9, wtmp3
    bn.add          coeff9, wtmp3, coeff9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff9, coeff9.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff9, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff10, coeff10.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff10, coeff10, wtmp3
    bn.add          coeff10, wtmp3, coeff10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff10, coeff10.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff10, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff3, wtmp
    bn.addm coeff3, coeff3, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff12, coeff12.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff12, coeff12, wtmp3
    bn.add          coeff12, wtmp3, coeff12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff12, coeff12.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff12, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff5, wtmp
    bn.addm coeff5, coeff5, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff6, wtmp
    bn.addm coeff6, coeff6, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff7, wtmp
    bn.addm coeff7, coeff7, wtmp

    /* Layer 2 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff4, coeff4.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff4, coeff4, wtmp3
    bn.add          coeff4, wtmp3, coeff4 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff4, coeff4.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff4 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff4, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff5, coeff5.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff5, coeff5, wtmp3
    bn.add          coeff5, wtmp3, coeff5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff5, coeff5.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff5, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff6, coeff6.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff6, coeff6, wtmp3
    bn.add          coeff6, wtmp3, coeff6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff6, coeff6.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff6, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff3, wtmp
    bn.addm coeff3, coeff3, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff12, coeff12.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff12, coeff12, wtmp3
    bn.add          coeff12, wtmp3, coeff12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff12, coeff12.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff12, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff9, wtmp
    bn.addm coeff9, coeff9, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff10, wtmp
    bn.addm coeff10, coeff10, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff11, wtmp
    bn.addm coeff11, coeff11, wtmp

    /* Layer 3 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff2, coeff2.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff2, coeff2, wtmp3
    bn.add          coeff2, wtmp3, coeff2 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff2, coeff2.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff2 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff2, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff3, coeff3.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff3, coeff3, wtmp3
    bn.add          coeff3, wtmp3, coeff3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff3, coeff3.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff3, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    bn.lid tf1_idx, 32(twp)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff6, coeff6.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff6, coeff6, wtmp3
    bn.add          coeff6, wtmp3, coeff6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff6, coeff6.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff6, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff5, wtmp
    bn.addm coeff5, coeff5, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff10, coeff10.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff10, coeff10, wtmp3
    bn.add          coeff10, wtmp3, coeff10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff10, coeff10.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff10, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff9, wtmp
    bn.addm coeff9, coeff9, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff12, wtmp
    bn.addm coeff12, coeff12, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff13, wtmp
    bn.addm coeff13, coeff13, wtmp

    /* Layer 4 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff1, coeff1.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff1, coeff1, wtmp3
    bn.add          coeff1, wtmp3, coeff1 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff1, coeff1.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff1 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff1, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    bn.lid tf1_idx, 64(twp)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff3, coeff3.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff3, coeff3, wtmp3
    bn.add          coeff3, wtmp3, coeff3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff3, coeff3.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff3, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff5, coeff5.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff5, coeff5, wtmp3
    bn.add          coeff5, wtmp3, coeff5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff5, coeff5.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff5, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff6, wtmp
    bn.addm coeff6, coeff6, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff9, coeff9.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff9, coeff9, wtmp3
    bn.add          coeff9, wtmp3, coeff9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff9, coeff9.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff9, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    bn.lid tf1_idx, 96(twp)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff10, wtmp
    bn.addm coeff10, coeff10, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff12, wtmp
    bn.addm coeff12, coeff12, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff14, wtmp
    bn.addm coeff14, coeff14, wtmp

    /* Shift result values into the top of buffer registers */
    /* implicitly removes the old value */
    bn.rshi buf0, coeff0, buf0 >> 16
    bn.rshi buf1, coeff1, buf1 >> 16
    bn.rshi buf2, coeff2, buf2 >> 16
    bn.rshi buf3, coeff3, buf3 >> 16
    bn.rshi buf4, coeff4, buf4 >> 16
    bn.rshi buf5, coeff5, buf5 >> 16
    bn.rshi buf6, coeff6, buf6 >> 16
    bn.rshi buf7, coeff7, buf7 >> 16
    bn.rshi buf8, coeff8, buf8 >> 16
    bn.rshi buf9, coeff9, buf9 >> 16
    bn.rshi buf10, coeff10, buf10 >> 16
    bn.rshi buf11, coeff11, buf11 >> 16
    bn.rshi buf12, coeff12, buf12 >> 16

    /* Store unbuffered values */
    /* Coeff13 */
    bn.sid coeff13_idx, STACK_WDR2GPR(fp)
    lw     tmp_gpr, STACK_WDR2GPR(fp)
    sw     tmp_gpr, 416(outp)
    /* Coeff14 */
    bn.sid coeff14_idx, STACK_WDR2GPR(fp)
    lw     tmp_gpr, STACK_WDR2GPR(fp)
    sw     tmp_gpr, 448(outp)
    /* Coeff15 */
    bn.sid coeff15_idx, STACK_WDR2GPR(fp)
    lw     tmp_gpr, STACK_WDR2GPR(fp)
    sw     tmp_gpr, 480(outp)
    
    /* Go to next coefficient for the unbuffered loads/stores */
    bn.lid tf1_idx, 0(twp)
    /* Extract coefficients from buffer registers into working state */
    bn.and coeff0, buf0, wtmp3 >> 208
    bn.and coeff1, buf1, wtmp3 >> 208
    bn.and coeff2, buf2, wtmp3 >> 208
    bn.and coeff3, buf3, wtmp3 >> 208
    bn.and coeff4, buf4, wtmp3 >> 208
    bn.and coeff5, buf5, wtmp3 >> 208
    bn.and coeff6, buf6, wtmp3 >> 208
    bn.and coeff7, buf7, wtmp3 >> 208
    bn.and coeff8, buf8, wtmp3 >> 208
    bn.and coeff9, buf9, wtmp3 >> 208
    bn.and coeff10, buf10, wtmp3 >> 208
    bn.and coeff11, buf11, wtmp3 >> 208
    bn.and coeff12, buf12, wtmp3 >> 208

    /* Load remaining coefficients using 32-bit loads */
    /* Coeff 13 */
    bn.lid  coeff13_idx, STACK_WDRTMP_1(fp)
    bn.rshi coeff13, wtmp3, coeff13 >> 16

    /* Coeff 14 */
    bn.lid  coeff14_idx, STACK_WDRTMP_2(fp)
    bn.rshi coeff14, wtmp3, coeff14 >> 16

    /* Coeff 15 */
    bn.lid  coeff15_idx, STACK_WDRTMP_3(fp)
    bn.rshi coeff15, wtmp3, coeff15 >> 16

    /* Layer 1 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff8, coeff8.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff8, coeff8, wtmp3
    bn.add          coeff8, wtmp3, coeff8 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff8, coeff8.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff8 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff8, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff9, coeff9.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff9, coeff9, wtmp3
    bn.add          coeff9, wtmp3, coeff9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff9, coeff9.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff9, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff10, coeff10.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff10, coeff10, wtmp3
    bn.add          coeff10, wtmp3, coeff10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff10, coeff10.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff10, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff3, wtmp
    bn.addm coeff3, coeff3, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff12, coeff12.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff12, coeff12, wtmp3
    bn.add          coeff12, wtmp3, coeff12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff12, coeff12.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff12, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff5, wtmp
    bn.addm coeff5, coeff5, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff6, wtmp
    bn.addm coeff6, coeff6, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff7, wtmp
    bn.addm coeff7, coeff7, wtmp

    /* Layer 2 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff4, coeff4.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff4, coeff4, wtmp3
    bn.add          coeff4, wtmp3, coeff4 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff4, coeff4.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff4 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff4, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff5, coeff5.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff5, coeff5, wtmp3
    bn.add          coeff5, wtmp3, coeff5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff5, coeff5.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff5, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff6, coeff6.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff6, coeff6, wtmp3
    bn.add          coeff6, wtmp3, coeff6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff6, coeff6.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff6, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff3, wtmp
    bn.addm coeff3, coeff3, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff12, coeff12.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff12, coeff12, wtmp3
    bn.add          coeff12, wtmp3, coeff12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff12, coeff12.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff12, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff9, wtmp
    bn.addm coeff9, coeff9, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff10, wtmp
    bn.addm coeff10, coeff10, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff11, wtmp
    bn.addm coeff11, coeff11, wtmp

    /* Layer 3 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff2, coeff2.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff2, coeff2, wtmp3
    bn.add          coeff2, wtmp3, coeff2 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff2, coeff2.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff2 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff2, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff3, coeff3.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff3, coeff3, wtmp3
    bn.add          coeff3, wtmp3, coeff3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff3, coeff3.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff3, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    bn.lid tf1_idx, 32(twp)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff6, coeff6.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff6, coeff6, wtmp3
    bn.add          coeff6, wtmp3, coeff6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff6, coeff6.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff6, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff5, wtmp
    bn.addm coeff5, coeff5, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff10, coeff10.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff10, coeff10, wtmp3
    bn.add          coeff10, wtmp3, coeff10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff10, coeff10.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff10, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff9, wtmp
    bn.addm coeff9, coeff9, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff12, wtmp
    bn.addm coeff12, coeff12, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff13, wtmp
    bn.addm coeff13, coeff13, wtmp

    /* Layer 4 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff1, coeff1.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff1, coeff1, wtmp3
    bn.add          coeff1, wtmp3, coeff1 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff1, coeff1.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff1 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff1, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    bn.lid tf1_idx, 64(twp)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff3, coeff3.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff3, coeff3, wtmp3
    bn.add          coeff3, wtmp3, coeff3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff3, coeff3.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff3, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff5, coeff5.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff5, coeff5, wtmp3
    bn.add          coeff5, wtmp3, coeff5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff5, coeff5.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff5, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff6, wtmp
    bn.addm coeff6, coeff6, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff9, coeff9.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff9, coeff9, wtmp3
    bn.add          coeff9, wtmp3, coeff9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff9, coeff9.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff9, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    bn.lid tf1_idx, 96(twp)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff10, wtmp
    bn.addm coeff10, coeff10, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff12, wtmp
    bn.addm coeff12, coeff12, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff14, wtmp
    bn.addm coeff14, coeff14, wtmp

    /* Shift result values into the top of buffer registers */
    /* implicitly removes the old value */
    bn.rshi buf0, coeff0, buf0 >> 16
    bn.rshi buf1, coeff1, buf1 >> 16
    bn.rshi buf2, coeff2, buf2 >> 16
    bn.rshi buf3, coeff3, buf3 >> 16
    bn.rshi buf4, coeff4, buf4 >> 16
    bn.rshi buf5, coeff5, buf5 >> 16
    bn.rshi buf6, coeff6, buf6 >> 16
    bn.rshi buf7, coeff7, buf7 >> 16
    bn.rshi buf8, coeff8, buf8 >> 16
    bn.rshi buf9, coeff9, buf9 >> 16
    bn.rshi buf10, coeff10, buf10 >> 16
    bn.rshi buf11, coeff11, buf11 >> 16
    bn.rshi buf12, coeff12, buf12 >> 16

    /* Store unbuffered values */
    /* Coeff13 */
    bn.sid coeff13_idx, STACK_WDR2GPR(fp)
    lw     tmp_gpr, STACK_WDR2GPR(fp)
    sll    tmp_gpr, tmp_gpr, 16
    lw     tmp_gpr2, 416(outp)
    xor    tmp_gpr, tmp_gpr, tmp_gpr2
    sw     tmp_gpr, 416(outp)
  
    /* Coeff14 */
    bn.sid coeff14_idx, STACK_WDR2GPR(fp)
    lw     tmp_gpr, STACK_WDR2GPR(fp)
    sll    tmp_gpr, tmp_gpr, 16
    lw     tmp_gpr2, 448(outp)
    xor    tmp_gpr, tmp_gpr, tmp_gpr2
    sw     tmp_gpr, 448(outp)

    /* Coeff15 */
    bn.sid coeff15_idx, STACK_WDR2GPR(fp)
    lw     tmp_gpr, STACK_WDR2GPR(fp)
    sll    tmp_gpr, tmp_gpr, 16
    lw     tmp_gpr2, 480(outp)
    xor    tmp_gpr, tmp_gpr, tmp_gpr2
    sw     tmp_gpr, 480(outp)
    
    /* Go to next coefficient for the unbuffered loads/stores */
    addi inp, inp, 4
    addi outp, outp, 4
    /* Inner Loop End */

  addi outp, outp, -32
  addi inp, inp, 480 /* -32 + 512 : for next input poly */
  /* Subtract 32 from offset to account for the increment inside the LOOP 16 */
  bn.sid buf0_idx, 0(outp)
  bn.sid buf1_idx, 32(outp)
  bn.sid buf2_idx, 64(outp)
  bn.sid buf3_idx, 96(outp)
  bn.sid buf4_idx, 128(outp)
  bn.sid buf5_idx, 160(outp)
  bn.sid buf6_idx, 192(outp)
  bn.sid buf7_idx, 224(outp)
  bn.sid buf8_idx, 256(outp)
  bn.sid buf9_idx, 288(outp)
  bn.sid buf10_idx, 320(outp)
  bn.sid buf11_idx, 352(outp)
  bn.sid buf12_idx, 384(outp)

  /* Set the twiddle pointer for layer 5 */
  addi twp, twp, 128

  /* Set up constants for input/twiddle factors */
  li tf1_idx, 16

  bn.xor  buf9, buf9, buf9
  bn.addi buf8, buf9, 1
  bn.rshi buf8, buf8, buf9 >> 240
  bn.subi buf8, buf8, 1 

  LOOPI 16, 204
    /* Load layer 5 + 2 layer 6 + 1 layer 7 twiddle */
    bn.lid tf1_idx, 0(twp++)

    /* Load Data */
    bn.lid  buf0_idx, 0(outp)
    bn.and  coeff0, buf8, buf0 >> 0
    bn.and  coeff1, buf8, buf0 >> 16
    bn.and  coeff2, buf8, buf0 >> 32
    bn.and  coeff3, buf8, buf0 >> 48
    bn.and  coeff4, buf8, buf0 >> 64
    bn.and  coeff5, buf8, buf0 >> 80
    bn.and  coeff6, buf8, buf0 >> 96
    bn.and  coeff7, buf8, buf0 >> 112
    bn.and  coeff8, buf8, buf0 >> 128
    bn.and  coeff9, buf8, buf0 >> 144
    bn.and  coeff10, buf8, buf0 >> 160
    bn.and  coeff11, buf8, buf0 >> 176
    bn.and  coeff12, buf8, buf0 >> 192
    bn.and  coeff13, buf8, buf0 >> 208
    bn.and  coeff14, buf8, buf0 >> 224
    bn.and  coeff15, buf8, buf0 >> 240

    /* Layer 5 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff8, coeff8.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff8, coeff8, wtmp3
    bn.add          coeff8, wtmp3, coeff8 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff8, coeff8.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff8 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff8, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff9, coeff9.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff9, coeff9, wtmp3
    bn.add          coeff9, wtmp3, coeff9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff9, coeff9.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff9, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff10, coeff10.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff10, coeff10, wtmp3
    bn.add          coeff10, wtmp3, coeff10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff10, coeff10.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff10, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff3, wtmp
    bn.addm coeff3, coeff3, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff12, coeff12.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff12, coeff12, wtmp3
    bn.add          coeff12, wtmp3, coeff12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff12, coeff12.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff12, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff5, wtmp
    bn.addm coeff5, coeff5, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff6, wtmp
    bn.addm coeff6, coeff6, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff7, wtmp
    bn.addm coeff7, coeff7, wtmp

    /* Layer 6 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff4, coeff4.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff4, coeff4, wtmp3
    bn.add          coeff4, wtmp3, coeff4 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff4, coeff4.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff4 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff4, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff5, coeff5.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff5, coeff5, wtmp3
    bn.add          coeff5, wtmp3, coeff5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff5, coeff5.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff5, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff6, coeff6.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff6, coeff6, wtmp3
    bn.add          coeff6, wtmp3, coeff6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff6, coeff6.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff6, coeff2, wtmp
    bn.addm coeff2, coeff2, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff3, wtmp
    bn.addm coeff3, coeff3, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff12, coeff12.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff12, coeff12, wtmp3
    bn.add          coeff12, wtmp3, coeff12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff12, coeff12.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff12, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff13, coeff13.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff13, coeff13, wtmp3
    bn.add          coeff13, wtmp3, coeff13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff13, coeff13.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff13, coeff9, wtmp
    bn.addm coeff9, coeff9, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff10, wtmp
    bn.addm coeff10, coeff10, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff11, wtmp
    bn.addm coeff11, coeff11, wtmp

    /* Layer 7 */
    /* Load 4 factois of Layer 7 */
    bn.lid tf1_idx, 0(twp++)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff2, coeff2.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff2, coeff2, wtmp3
    bn.add          coeff2, wtmp3, coeff2 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff2, coeff2.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff2 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff2, coeff0, wtmp
    bn.addm coeff0, coeff0, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff3, coeff3.0, tf1.0, 192 /* a*bq' */
    bn.and          coeff3, coeff3, wtmp3
    bn.add          coeff3, wtmp3, coeff3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff3, coeff3.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff3, coeff1, wtmp
    bn.addm coeff1, coeff1, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff6, coeff6.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff6, coeff6, wtmp3
    bn.add          coeff6, wtmp3, coeff6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff6, coeff6.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff6, coeff4, wtmp
    bn.addm coeff4, coeff4, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff7, coeff7.0, tf1.1, 192 /* a*bq' */
    bn.and          coeff7, coeff7, wtmp3
    bn.add          coeff7, wtmp3, coeff7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff7, coeff7.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff7, coeff5, wtmp
    bn.addm coeff5, coeff5, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff10, coeff10.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff10, coeff10, wtmp3
    bn.add          coeff10, wtmp3, coeff10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff10, coeff10.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff10, coeff8, wtmp
    bn.addm coeff8, coeff8, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff11, coeff11.0, tf1.2, 192 /* a*bq' */
    bn.and          coeff11, coeff11, wtmp3
    bn.add          coeff11, wtmp3, coeff11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff11, coeff11.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff11, coeff9, wtmp
    bn.addm coeff9, coeff9, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff14, coeff14.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff14, coeff14, wtmp3
    bn.add          coeff14, wtmp3, coeff14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff14, coeff14.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff14, coeff12, wtmp
    bn.addm coeff12, coeff12, wtmp

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z coeff15, coeff15.0, tf1.3, 192 /* a*bq' */
    bn.and          coeff15, coeff15, wtmp3
    bn.add          coeff15, wtmp3, coeff15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z coeff15, coeff15.1, wtmp3.2, 0 /* *q */
    bn.rshi         wtmp, wtmp3, coeff15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm coeff15, coeff13, wtmp
    bn.addm coeff13, coeff13, wtmp

    /* Reassemble WDRs and store */
    bn.rshi buf0, coeff0, buf0 >> 16
    bn.rshi buf0, coeff1, buf0 >> 16
    bn.rshi buf0, coeff2, buf0 >> 16
    bn.rshi buf0, coeff3, buf0 >> 16
    bn.rshi buf0, coeff4, buf0 >> 16
    bn.rshi buf0, coeff5, buf0 >> 16
    bn.rshi buf0, coeff6, buf0 >> 16
    bn.rshi buf0, coeff7, buf0 >> 16
    bn.rshi buf0, coeff8, buf0 >> 16
    bn.rshi buf0, coeff9, buf0 >> 16
    bn.rshi buf0, coeff10, buf0 >> 16
    bn.rshi buf0, coeff11, buf0 >> 16
    bn.rshi buf0, coeff12, buf0 >> 16
    bn.rshi buf0, coeff13, buf0 >> 16
    bn.rshi buf0, coeff14, buf0 >> 16
    bn.rshi buf0, coeff15, buf0 >> 16
    bn.sid  buf0_idx, 0(outp++)

  /* Zero w31 again */
  bn.xor w31, w31, w31

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw fp, 0(sp)
  addi sp, sp, 32
  ret