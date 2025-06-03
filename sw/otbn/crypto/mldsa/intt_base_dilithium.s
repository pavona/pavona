/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Macros */
.macro push reg
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
.endm

.macro pop reg
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
.endm

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

/**
 * Constant Time Dilithium inverse NTT (base)
 *
 * Returns: INTT(input)
 *
 * This implements the in-place INTT for Dilithium, where n=256, q=8380417.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_tw, dmem pointer to array of twiddle factors,
                    last element is n^{-1} mod q
 * @param[in]  w31: all-zero
 * @param[out] x10: dmem pointer to result
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */
.global intt_base_dilithium
intt_base_dilithium:
/* 32 byte align the sp */
    andi x6, sp, 31
    beq  x6, zero, _aligned
    sub  sp, sp, x6
_aligned:
    push x6
    addi sp, sp, -28
    /* save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -32

    /* Reserve space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32

    /* clear STACK_WDR2GPR */
    li t0, 31
    bn.sid t0, STACK_WDR2GPR(fp)

    /* Save callee-saved registers */
    .irp reg,s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11
        push \reg
    .endr
    
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
    /* Twiddle Factors */
    #define tf1 w16
    #define buf8 w17
    #define buf9 w18
    #define buf10 w19

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

    /* In place */
    addi outp, inp, 0

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
    la tmp_gpr, modulus
    li tmp_gpr2, 20 /* Load q to wtmp */
    bn.lid tmp_gpr2, 0(tmp_gpr)
    bn.and wtmp, wtmp, buf8
    bn.or wtmp3, buf9, wtmp << 128
    /* Load alpha to wtmp3.1 */
    bn.addi wtmp, buf9, 1
    bn.or wtmp3, wtmp3, wtmp << 64
    /* Load mask to wtmp3.3 */
    bn.or wtmp3, wtmp3, buf8 << 192   

    bn.xor buf9, buf9, buf9
    bn.addi buf8, buf9, 1
    bn.rshi buf8, buf8, buf9 >> 224
    bn.subi buf8, buf8, 1 

    LOOPI 16, 232
        /* Load Data */
        bn.lid buf0_idx, 0(inp)
        bn.and  coeff0, buf8, buf0 >> 0
        bn.and  coeff1, buf8, buf0 >> 32
        bn.and  coeff2, buf8, buf0 >> 64
        bn.and  coeff3, buf8, buf0 >> 96
        bn.and  coeff4, buf8, buf0 >> 128
        bn.and  coeff5, buf8, buf0 >> 160
        bn.and  coeff6, buf8, buf0 >> 192
        bn.and  coeff7, buf8, buf0 >> 224

        bn.lid buf0_idx, 32(inp)
        bn.and  coeff8, buf8, buf0 >> 0
        bn.and  coeff9, buf8, buf0 >> 32
        bn.and  coeff10, buf8, buf0 >> 64
        bn.and  coeff11, buf8, buf0 >> 96
        bn.and  coeff12, buf8, buf0 >> 128
        bn.and  coeff13, buf8, buf0 >> 160
        bn.and  coeff14, buf8, buf0 >> 192
        bn.and  coeff15, buf8, buf0 >> 224

        /* Load layer 8 twiddle 4x */
        bn.lid tf1_idx, 0(twp++)

        /* Layer 8, stride 1 */            
        bn.subm wtmp, coeff0, coeff1
        bn.addm coeff0, coeff0, coeff1
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff1, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff2, coeff3
        bn.addm coeff2, coeff2, coeff3
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff3, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff4, coeff5
        bn.addm coeff4, coeff4, coeff5
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff5, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff6, coeff7
        bn.addm coeff6, coeff6, coeff7
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */
            
        /* Load layer 8 twiddle 4x */
        bn.lid tf1_idx, 0(twp++)

        bn.subm wtmp, coeff8, coeff9
        bn.addm coeff8, coeff8, coeff9
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff9, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff10, coeff11
        bn.addm coeff10, coeff10, coeff11
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff11, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff12, coeff13
        bn.addm coeff12, coeff12, coeff13
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff13, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff14, coeff15
        bn.addm coeff14, coeff14, coeff15
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

        /* Layer 7, stride 2 */
        /* Load layer 7 4x */
        bn.lid tf1_idx, 0(twp++)

        bn.subm wtmp, coeff0, coeff2
        bn.addm coeff0, coeff0, coeff2
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff2, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff1, coeff3
        bn.addm coeff1, coeff1, coeff3
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff3, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff4, coeff6
        bn.addm coeff4, coeff4, coeff6
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff6, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff5, coeff7
        bn.addm coeff5, coeff5, coeff7
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff8, coeff10
        bn.addm coeff8, coeff8, coeff10
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff10, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff9, coeff11
        bn.addm coeff9, coeff9, coeff11
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff11, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff12, coeff14
        bn.addm coeff12, coeff12, coeff14
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff14, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff13, coeff15
        bn.addm coeff13, coeff13, coeff15
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

        /* Layer 6, stride 4 */
        /* Load layer 6 x2 + layer 5 x1 + pad */
        bn.lid tf1_idx, 0(twp++)

        bn.subm wtmp, coeff0, coeff4
        bn.addm coeff0, coeff0, coeff4
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff4, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff1, coeff5
        bn.addm coeff1, coeff1, coeff5
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff5, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff2, coeff6
        bn.addm coeff2, coeff2, coeff6
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff6, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff3, coeff7
        bn.addm coeff3, coeff3, coeff7
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff8, coeff12
        bn.addm coeff8, coeff8, coeff12
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff12, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff9, coeff13
        bn.addm coeff9, coeff9, coeff13
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff13, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff10, coeff14
        bn.addm coeff10, coeff10, coeff14
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff14, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff11, coeff15
        bn.addm coeff11, coeff11, coeff15
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

        /* Layer 5, stride 8 */         

        bn.subm wtmp, coeff0, coeff8
        bn.addm coeff0, coeff0, coeff8
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff8, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff1, coeff9
        bn.addm coeff1, coeff1, coeff9
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff9, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff2, coeff10
        bn.addm coeff2, coeff2, coeff10
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff10, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff3, coeff11
        bn.addm coeff3, coeff3, coeff11
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff11, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff4, coeff12
        bn.addm coeff4, coeff4, coeff12
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff12, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff5, coeff13
        bn.addm coeff5, coeff5, coeff13
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff13, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff6, coeff14
        bn.addm coeff6, coeff6, coeff14
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff14, wtmp3, wtmp >> 32 /* >> l */
            
        bn.subm wtmp, coeff7, coeff15
        bn.addm coeff7, coeff7, coeff15
        /* Plantard multiplication: Twiddle * (a-b) */
        bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
        bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
        bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
        bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

        /* Reassemble WDRs and store */
        bn.rshi buf0, coeff0, buf0 >> 32
        bn.rshi buf0, coeff1, buf0 >> 32
        bn.rshi buf0, coeff2, buf0 >> 32
        bn.rshi buf0, coeff3, buf0 >> 32
        bn.rshi buf0, coeff4, buf0 >> 32
        bn.rshi buf0, coeff5, buf0 >> 32
        bn.rshi buf0, coeff6, buf0 >> 32
        bn.rshi buf0, coeff7, buf0 >> 32
        bn.sid buf0_idx, 0(inp++)
        
        bn.rshi buf0, coeff8, buf0 >> 32
        bn.rshi buf0, coeff9, buf0 >> 32
        bn.rshi buf0, coeff10, buf0 >> 32
        bn.rshi buf0, coeff11, buf0 >> 32
        bn.rshi buf0, coeff12, buf0 >> 32
        bn.rshi buf0, coeff13, buf0 >> 32
        bn.rshi buf0, coeff14, buf0 >> 32
        bn.rshi buf0, coeff15, buf0 >> 32
        bn.sid buf0_idx, 0(inp++)

    /* Restore output pointer */
    addi inp, inp, -1024

    /* Set up constants for input/twiddle factors */
    li tf1_idx, 16  

    /* We can process 16 coefficients each iteration and need to process N=256, meaning we require 16 iterations. */
    LOOPI 2, 300
        /* Load coefficients into buffer registers */
        bn.lid buf0_idx, 0(inp)
        bn.lid buf1_idx, 64(inp)
        bn.lid buf2_idx, 128(inp)
        bn.lid buf3_idx, 192(inp)
        bn.lid buf4_idx, 256(inp)
        bn.lid buf5_idx, 320(inp)
        bn.lid buf6_idx, 384(inp)
        bn.lid buf7_idx, 448(inp)
        bn.lid buf8_idx, 512(inp)
        bn.lid buf9_idx, 576(inp)
        bn.lid buf10_idx, 640(inp)
        bn.lid buf11_idx, 704(inp)
        bn.lid buf12_idx, 768(inp)
        LOOPI 8, 273
            /* Extract coefficients from buffer registers into working state */
            bn.and coeff0, buf0, wtmp3 >> 192
            bn.and coeff1, buf1, wtmp3 >> 192
            bn.and coeff2, buf2, wtmp3 >> 192
            bn.and coeff3, buf3, wtmp3 >> 192
            bn.and coeff4, buf4, wtmp3 >> 192
            bn.and coeff5, buf5, wtmp3 >> 192
            bn.and coeff6, buf6, wtmp3 >> 192
            bn.and coeff7, buf7, wtmp3 >> 192
            bn.and coeff8, buf8, wtmp3 >> 192
            bn.and coeff9, buf9, wtmp3 >> 192
            bn.and coeff10, buf10, wtmp3 >> 192
            bn.and coeff11, buf11, wtmp3 >> 192
            bn.and coeff12, buf12, wtmp3 >> 192

            /* Coeff 13 */
            lw tmp_gpr, 832(inp)
            sw tmp_gpr, STACK_WDR2GPR(fp)
            bn.lid coeff13_idx, STACK_WDR2GPR(fp)
            /* Coeff 14 */
            lw tmp_gpr, 896(inp)
            sw tmp_gpr, STACK_WDR2GPR(fp)
            bn.lid coeff14_idx, STACK_WDR2GPR(fp)
            /* Coeff 15 */
            lw tmp_gpr, 960(inp)
            sw tmp_gpr, STACK_WDR2GPR(fp)
            bn.lid coeff15_idx, STACK_WDR2GPR(fp)

            bn.lid tf1_idx, 0(twp)

            /* Layer 8, stride 1 */            
            bn.subm wtmp, coeff0, coeff1
            bn.addm coeff0, coeff0, coeff1
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff1, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff2, coeff3
            bn.addm coeff2, coeff2, coeff3
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff3, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff4, coeff5
            bn.addm coeff4, coeff4, coeff5
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff5, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff6, coeff7
            bn.addm coeff6, coeff6, coeff7
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */
                
            /* Load layer 8 twiddle 4x */
            bn.lid tf1_idx, 32(twp)

            bn.subm wtmp, coeff8, coeff9
            bn.addm coeff8, coeff8, coeff9
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff9, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff10, coeff11
            bn.addm coeff10, coeff10, coeff11
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff11, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff12, coeff13
            bn.addm coeff12, coeff12, coeff13
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff13, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff14, coeff15
            bn.addm coeff14, coeff14, coeff15
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

            /* Layer 7, stride 2 */
            /* Load layer 7 4x */
            bn.lid tf1_idx, 64(twp)

            bn.subm wtmp, coeff0, coeff2
            bn.addm coeff0, coeff0, coeff2
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff2, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff1, coeff3
            bn.addm coeff1, coeff1, coeff3
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff3, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff4, coeff6
            bn.addm coeff4, coeff4, coeff6
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff6, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff5, coeff7
            bn.addm coeff5, coeff5, coeff7
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff8, coeff10
            bn.addm coeff8, coeff8, coeff10
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff10, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff9, coeff11
            bn.addm coeff9, coeff9, coeff11
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff11, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff12, coeff14
            bn.addm coeff12, coeff12, coeff14
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff14, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff13, coeff15
            bn.addm coeff13, coeff13, coeff15
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

            /* Layer 6, stride 4 */
            /* Load layer 6 x2 + layer 5 x1 + pad */
            bn.lid tf1_idx, 96(twp)

            bn.subm wtmp, coeff0, coeff4
            bn.addm coeff0, coeff0, coeff4
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff4, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff1, coeff5
            bn.addm coeff1, coeff1, coeff5
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff5, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff2, coeff6
            bn.addm coeff2, coeff2, coeff6
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff6, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff3, coeff7
            bn.addm coeff3, coeff3, coeff7
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.0, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff8, coeff12
            bn.addm coeff8, coeff8, coeff12
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff12, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff9, coeff13
            bn.addm coeff9, coeff9, coeff13
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff13, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff10, coeff14
            bn.addm coeff10, coeff10, coeff14
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff14, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff11, coeff15
            bn.addm coeff11, coeff11, coeff15
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.1, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

            /* Layer 5, stride 8 */         

            bn.subm wtmp, coeff0, coeff8
            bn.addm coeff0, coeff0, coeff8
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff8, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff1, coeff9
            bn.addm coeff1, coeff1, coeff9
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff9, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff2, coeff10
            bn.addm coeff2, coeff2, coeff10
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff10, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff3, coeff11
            bn.addm coeff3, coeff3, coeff11
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff11, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff4, coeff12
            bn.addm coeff4, coeff4, coeff12
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff12, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff5, coeff13
            bn.addm coeff5, coeff5, coeff13
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff13, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff6, coeff14
            bn.addm coeff6, coeff6, coeff14
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff14, wtmp3, wtmp >> 32 /* >> l */
                
            bn.subm wtmp, coeff7, coeff15
            bn.addm coeff7, coeff7, coeff15
            /* Plantard multiplication: Twiddle * (a-b) */
            bn.mulqacc.wo.z wtmp, wtmp.0, tf1.2, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff15, wtmp3, wtmp >> 32 /* >> l */

            /* Mul ninv */
            bn.mulqacc.wo.z wtmp, coeff0.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff0, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff1.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff1, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff2.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff2, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff3.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff3, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff4.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff4, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff5.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff5, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff6.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff6, wtmp3, wtmp >> 32 /* >> l */

            bn.mulqacc.wo.z wtmp, coeff7.0, tf1.3, 192 /* a*bq' */
            bn.add wtmp, wtmp3, wtmp >> 160 /* + 2^alpha = 2^8 */
            bn.mulqacc.wo.z wtmp, wtmp.1, wtmp3.2, 0 /* *q */
            bn.rshi coeff7, wtmp3, wtmp >> 32 /* >> l */

            /* Shift result values into the top of buffer registers */
            /* implicitly removes the old value */
            bn.rshi buf0, coeff0, buf0 >> 32
            bn.rshi buf1, coeff1, buf1 >> 32
            bn.rshi buf2, coeff2, buf2 >> 32
            bn.rshi buf3, coeff3, buf3 >> 32
            bn.rshi buf4, coeff4, buf4 >> 32
            bn.rshi buf5, coeff5, buf5 >> 32
            bn.rshi buf6, coeff6, buf6 >> 32
            bn.rshi buf7, coeff7, buf7 >> 32
            bn.rshi buf8, coeff8, buf8 >> 32
            bn.rshi buf9, coeff9, buf9 >> 32
            bn.rshi buf10, coeff10, buf10 >> 32
            bn.rshi buf11, coeff11, buf11 >> 32
            bn.rshi buf12, coeff12, buf12 >> 32

            /* Store unbuffered values */
            /* Coeff13 */
            bn.sid coeff13_idx, STACK_WDR2GPR(fp)
            lw tmp_gpr, STACK_WDR2GPR(fp)
            sw tmp_gpr, 832(inp)
            /* Coeff14 */
            bn.sid coeff14_idx, STACK_WDR2GPR(fp)
            lw tmp_gpr, STACK_WDR2GPR(fp)
            sw tmp_gpr, 896(inp)
            /* Coeff15 */
            bn.sid coeff15_idx, STACK_WDR2GPR(fp)
            lw tmp_gpr, STACK_WDR2GPR(fp)
            sw tmp_gpr, 960(inp)
            
            /* Go to next coefficient for the unbuffered loads/stores */
            addi inp, inp, 4
            /* Inner Loop End */

        /* Subtract 32 from offset to account for the increment inside the LOOP 8 */
        bn.sid buf0_idx, -32(inp)
        bn.sid buf1_idx, 32(inp)
        bn.sid buf2_idx, 96(inp)
        bn.sid buf3_idx, 160(inp)
        bn.sid buf4_idx, 224(inp)
        bn.sid buf5_idx, 288(inp)
        bn.sid buf6_idx, 352(inp)
        bn.sid buf7_idx, 416(inp)
        bn.sid buf8_idx, 480(inp)
        bn.sid buf9_idx, 544(inp)
        bn.sid buf10_idx, 608(inp)
        bn.sid buf11_idx, 672(inp)
        bn.sid buf12_idx, 736(inp)
        /* Outer Loop End */

    .irp reg,s11,s10,s9,s8,s7,s6,s5,s4,s3,s2,s1,s0
        pop \reg
    .endr

    /* Zero w31 again */
    bn.xor w31, w31, w31

    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32

    add sp, sp, 28
    pop x6
    add sp, sp, x6

    ret