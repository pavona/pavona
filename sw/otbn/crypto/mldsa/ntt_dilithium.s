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

/**
 * Constant Time Dilithium NTT
 *
 * Returns: NTT(input)
 *
 * This implements the in-place NTT for Dilithium, where n=256, q=8380417.
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_tw, dmem pointer to array of twiddle factors
 * @param[in]  w31: all-zero
 * @param[out] x12: dmem pointer to result
 *
 * clobbered registers: x4-x30, w2-w25, w30
 */
.globl ntt_dilithium
ntt_dilithium:

    /* Save callee-saved registers */
    .irp reg,s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11
        push \reg
    .endr

    /* Set up constants for input/state */
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

    /* Set up constants for input/twiddle factors */
    li x23, 16
    li x24, 17
    li x25, 18
    li x26, 19
    li x31, 20
    li x28, 21
    li x29, 22
    li x30, 23

    /* Load twiddle factors for layers 1--4 */
    bn.lid x23, 0(x11)
    bn.lid x24, 32(x11)
    
    LOOPI 2, 130
        /* Load input data */
        bn.lid x4, 0(x10)
        bn.lid x5, 64(x10)
        bn.lid x6, 128(x10)
        bn.lid x7, 192(x10)
        bn.lid x8, 256(x10)
        bn.lid x9, 320(x10)
        bn.lid x13, 384(x10)
        bn.lid x14, 448(x10)
        bn.lid x15, 512(x10)
        bn.lid x16, 576(x10)
        bn.lid x17, 640(x10)
        bn.lid x18, 704(x10)
        bn.lid x19, 768(x10)
        bn.lid x20, 832(x10)
        bn.lid x21, 896(x10)
        bn.lid x22, 960(x10)

        /* Layer 1, stride 128 */

        bn.mulvm.l.8S w30, w8, w16, 0
        bn.subvm.8S   w8, w0, w30
        bn.addvm.8S   w0, w0, w30
        bn.mulvm.l.8S w30, w9, w16, 0
        bn.subvm.8S   w9, w1, w30
        bn.addvm.8S   w1, w1, w30
        bn.mulvm.l.8S w30, w10, w16, 0
        bn.subvm.8S   w10, w2, w30
        bn.addvm.8S   w2, w2, w30
        bn.mulvm.l.8S w30, w11, w16, 0
        bn.subvm.8S   w11, w3, w30
        bn.addvm.8S   w3, w3, w30
        bn.mulvm.l.8S w30, w12, w16, 0
        bn.subvm.8S   w12, w4, w30
        bn.addvm.8S   w4, w4, w30
        bn.mulvm.l.8S w30, w13, w16, 0
        bn.subvm.8S   w13, w5, w30
        bn.addvm.8S   w5, w5, w30
        bn.mulvm.l.8S w30, w14, w16, 0
        bn.subvm.8S   w14, w6, w30
        bn.addvm.8S   w6, w6, w30
        bn.mulvm.l.8S w30, w15, w16, 0
        bn.subvm.8S   w15, w7, w30
        bn.addvm.8S   w7, w7, w30
        
        /* Layer 2, stride 64 */

        bn.mulvm.l.8S w30, w4, w16, 1
        bn.subvm.8S   w4, w0, w30
        bn.addvm.8S   w0, w0, w30
        bn.mulvm.l.8S w30, w5, w16, 1
        bn.subvm.8S   w5, w1, w30
        bn.addvm.8S   w1, w1, w30
        bn.mulvm.l.8S w30, w6, w16, 1
        bn.subvm.8S   w6, w2, w30
        bn.addvm.8S   w2, w2, w30
        bn.mulvm.l.8S w30, w7, w16, 1
        bn.subvm.8S   w7, w3, w30
        bn.addvm.8S   w3, w3, w30
        bn.mulvm.l.8S w30, w12, w16, 2
        bn.subvm.8S   w12, w8, w30
        bn.addvm.8S   w8, w8, w30
        bn.mulvm.l.8S w30, w13, w16, 2
        bn.subvm.8S   w13, w9, w30
        bn.addvm.8S   w9, w9, w30
        bn.mulvm.l.8S w30, w14, w16, 2
        bn.subvm.8S   w14, w10, w30
        bn.addvm.8S   w10, w10, w30
        bn.mulvm.l.8S w30, w15, w16, 2
        bn.subvm.8S   w15, w11, w30
        bn.addvm.8S   w11, w11, w30

        /* Layer 3, stride 32 */

        bn.mulvm.l.8S w30, w2, w16, 3
        bn.subvm.8S   w2, w0, w30
        bn.addvm.8S   w0, w0, w30
        bn.mulvm.l.8S w30, w3, w16, 3
        bn.subvm.8S   w3, w1, w30
        bn.addvm.8S   w1, w1, w30
        bn.mulvm.l.8S w30, w6, w16, 4
        bn.subvm.8S   w6, w4, w30
        bn.addvm.8S   w4, w4, w30
        bn.mulvm.l.8S w30, w7, w16, 4
        bn.subvm.8S   w7, w5, w30
        bn.addvm.8S   w5, w5, w30
        bn.mulvm.l.8S w30, w10, w16, 5
        bn.subvm.8S   w10, w8, w30
        bn.addvm.8S   w8, w8, w30
        bn.mulvm.l.8S w30, w11, w16, 5
        bn.subvm.8S   w11, w9, w30
        bn.addvm.8S   w9, w9, w30
        bn.mulvm.l.8S w30, w14, w16, 6
        bn.subvm.8S   w14, w12, w30
        bn.addvm.8S   w12, w12, w30
        bn.mulvm.l.8S w30, w15, w16, 6
        bn.subvm.8S   w15, w13, w30
        bn.addvm.8S   w13, w13, w30

        /* Layer 4, stride 16 */

        bn.mulvm.l.8S w30, w1, w16, 7
        bn.subvm.8S   w1, w0, w30
        bn.addvm.8S   w0, w0, w30
        bn.mulvm.l.8S w30, w3, w17, 0
        bn.subvm.8S   w3, w2, w30
        bn.addvm.8S   w2, w2, w30
        bn.mulvm.l.8S w30, w5, w17, 1
        bn.subvm.8S   w5, w4, w30
        bn.addvm.8S   w4, w4, w30
        bn.mulvm.l.8S w30, w7, w17, 2
        bn.subvm.8S   w7, w6, w30
        bn.addvm.8S   w6, w6, w30
        bn.mulvm.l.8S w30, w9, w17, 3
        bn.subvm.8S   w9, w8, w30
        bn.addvm.8S   w8, w8, w30
        bn.mulvm.l.8S w30, w11, w17, 4
        bn.subvm.8S   w11, w10, w30
        bn.addvm.8S   w10, w10, w30
        bn.mulvm.l.8S w30, w13, w17, 5
        bn.subvm.8S   w13, w12, w30
        bn.addvm.8S   w12, w12, w30
        bn.mulvm.l.8S w30, w15, w17, 6
        bn.subvm.8S   w15, w14, w30
        bn.addvm.8S   w14, w14, w30

        /* Store output data */
        bn.sid x4,  0(x12)
        bn.sid x5, 64(x12)
        bn.sid x6, 128(x12)
        bn.sid x7, 192(x12)
        bn.sid x8, 256(x12)
        bn.sid x9, 320(x12)
        bn.sid x13, 384(x12)
        bn.sid x14, 448(x12)
        bn.sid x15, 512(x12)
        bn.sid x16, 576(x12)
        bn.sid x17, 640(x12)
        bn.sid x18, 704(x12)
        bn.sid x19, 768(x12)
        bn.sid x20, 832(x12)
        bn.sid x21, 896(x12)
        bn.sid x22, 960(x12)
        
        addi x10, x10, 32
        addi x12, x12, 32
    
    /* Restore input pointer */
    addi x10, x10, -64
    /* Restore output pointer */
    addi x12, x12, -64

    /* Set the twiddle pointer for layer 5 */
    addi x11, x11, 64

    /* w16--w23 are used for the twiddle factors on layers 5--8 */
    LOOPI 2, 241
        /* Load input data */
        bn.lid x4, 0(x12)
        bn.lid x5, 32(x12)
        bn.lid x6, 64(x12)
        bn.lid x7, 96(x12)
        bn.lid x8, 128(x12)
        bn.lid x9, 160(x12)
        bn.lid x13, 192(x12)
        bn.lid x14, 224(x12)
        bn.lid x15, 256(x12)
        bn.lid x16, 288(x12)
        bn.lid x17, 320(x12)
        bn.lid x18, 352(x12)
        bn.lid x19, 384(x12)
        bn.lid x20, 416(x12)
        bn.lid x21, 448(x12)
        bn.lid x22, 480(x12)

        /* Layer 5, stride 8 */

        /* Load twiddle factors */
        bn.lid x23, 0(x11++)

        /* Butterflies */
        bn.mulvm.l.8S w30, w1, w16, 0
        bn.subvm.8S   w1, w0, w30
        bn.addvm.8S   w0, w0, w30
        bn.mulvm.l.8S w30, w3, w16, 1
        bn.subvm.8S   w3, w2, w30
        bn.addvm.8S   w2, w2, w30
        bn.mulvm.l.8S w30, w5, w16, 2
        bn.subvm.8S   w5, w4, w30
        bn.addvm.8S   w4, w4, w30
        bn.mulvm.l.8S w30, w7, w16, 3
        bn.subvm.8S   w7, w6, w30
        bn.addvm.8S   w6, w6, w30
        bn.mulvm.l.8S w30, w9, w16, 4
        bn.subvm.8S   w9, w8, w30
        bn.addvm.8S   w8, w8, w30
        bn.mulvm.l.8S w30, w11, w16, 5
        bn.subvm.8S   w11, w10, w30
        bn.addvm.8S   w10, w10, w30
        bn.mulvm.l.8S w30, w13, w16, 6
        bn.subvm.8S   w13, w12, w30
        bn.addvm.8S   w12, w12, w30
        bn.mulvm.l.8S w30, w15, w16, 7
        bn.subvm.8S   w15, w14, w30
        bn.addvm.8S   w14, w14, w30

        /* Transpose */
        /* At this point, w0-w15 are in use */
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
        
        /* bn.trans8 w8, w8 */

        /* bn.trans8 w8, w8 */
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

        /* Layer 6, stride 4 */

        /* Load twiddle factors */
        bn.lid x23, 0(x11++)
        bn.lid x24, 0(x11++)
        #define wtmp w8
        /* Butterflies */
        bn.mulvm.8S wtmp, w28, w16, 0
        bn.subvm.8S w28, w24, wtmp
        bn.addvm.8S w24, w24, wtmp
        bn.mulvm.8S wtmp, w29, w16, 0
        bn.subvm.8S w29, w25, wtmp
        bn.addvm.8S w25, w25, wtmp
        bn.mulvm.8S wtmp, w30, w16, 0
        bn.subvm.8S w30, w26, wtmp
        bn.addvm.8S w26, w26, wtmp
        bn.mulvm.8S wtmp, w31, w16, 0
        bn.subvm.8S w31, w27, wtmp
        bn.addvm.8S w27, w27, wtmp
        bn.mulvm.8S wtmp, w4, w17, 0
        bn.subvm.8S w4, w0, wtmp
        bn.addvm.8S w0, w0, wtmp
        bn.mulvm.8S wtmp, w5, w17, 0
        bn.subvm.8S w5, w1, wtmp
        bn.addvm.8S w1, w1, wtmp
        bn.mulvm.8S wtmp, w6, w17, 0
        bn.subvm.8S w6, w2, wtmp
        bn.addvm.8S w2, w2, wtmp
        bn.mulvm.8S wtmp, w7, w17, 0
        bn.subvm.8S w7, w3, wtmp
        bn.addvm.8S w3, w3, wtmp

        /* Layer 7, stride 2 */

        /* Load twiddle factors */
        bn.lid x23, 0(x11++)
        bn.lid x24, 0(x11++)
        bn.lid x25, 0(x11++)
        bn.lid x26, 0(x11++)

        /* Butterflies */
        bn.mulvm.8S wtmp, w26, w16, 0
        bn.subvm.8S w26, w24, wtmp
        bn.addvm.8S w24, w24, wtmp
        bn.mulvm.8S wtmp, w27, w16, 0
        bn.subvm.8S w27, w25, wtmp
        bn.addvm.8S w25, w25, wtmp
        bn.mulvm.8S wtmp, w30, w17, 0
        bn.subvm.8S w30, w28, wtmp
        bn.addvm.8S w28, w28, wtmp
        bn.mulvm.8S wtmp, w31, w17, 0
        bn.subvm.8S w31, w29, wtmp
        bn.addvm.8S w29, w29, wtmp
        bn.mulvm.8S wtmp, w2, w18, 0
        bn.subvm.8S w2, w0, wtmp
        bn.addvm.8S w0, w0, wtmp
        bn.mulvm.8S wtmp, w3, w18, 0
        bn.subvm.8S w3, w1, wtmp
        bn.addvm.8S w1, w1, wtmp
        bn.mulvm.8S wtmp, w6, w19, 0
        bn.subvm.8S w6, w4, wtmp
        bn.addvm.8S w4, w4, wtmp
        bn.mulvm.8S wtmp, w7, w19, 0
        bn.subvm.8S w7, w5, wtmp
        bn.addvm.8S w5, w5, wtmp

        /* Layer 8, stride 1 */

        /* Load twiddle factors */
        bn.lid x23, 0(x11++)
        bn.lid x24, 0(x11++)
        bn.lid x25, 0(x11++)
        bn.lid x26, 0(x11++)
        bn.lid x31, 0(x11++)
        bn.lid x28, 0(x11++)
        bn.lid x29, 0(x11++)
        bn.lid x30, 0(x11++)

        /* Butterflies */
        bn.mulvm.8S wtmp, w25, w16, 0
        bn.subvm.8S w25, w24, wtmp
        bn.addvm.8S w24, w24, wtmp
        bn.mulvm.8S wtmp, w27, w17, 0
        bn.subvm.8S w27, w26, wtmp
        bn.addvm.8S w26, w26, wtmp
        bn.mulvm.8S wtmp, w29, w18, 0
        bn.subvm.8S w29, w28, wtmp
        bn.addvm.8S w28, w28, wtmp
        bn.mulvm.8S wtmp, w31, w19, 0
        bn.subvm.8S w31, w30, wtmp
        bn.addvm.8S w30, w30, wtmp
        bn.mulvm.8S wtmp, w1, w20, 0
        bn.subvm.8S w1, w0, wtmp
        bn.addvm.8S w0, w0, wtmp
        bn.mulvm.8S wtmp, w3, w21, 0
        bn.subvm.8S w3, w2, wtmp
        bn.addvm.8S w2, w2, wtmp
        bn.mulvm.8S wtmp, w5, w22, 0
        bn.subvm.8S w5, w4, wtmp
        bn.addvm.8S w4, w4, wtmp
        bn.mulvm.8S wtmp, w7, w23, 0
        bn.subvm.8S w7, w6, wtmp
        bn.addvm.8S w6, w6, wtmp

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
        

        bn.sid x4, 0(x12)
        bn.sid x5, 32(x12)
        bn.sid x6, 64(x12)
        bn.sid x7, 96(x12)
        bn.sid x8, 128(x12)
        bn.sid x9, 160(x12)
        bn.sid x13, 192(x12)
        bn.sid x14, 224(x12)

        bn.sid x15, 256(x12)
        bn.sid x16, 288(x12)
        bn.sid x17, 320(x12)
        bn.sid x18, 352(x12)
        bn.sid x19, 384(x12)
        bn.sid x20, 416(x12)
        bn.sid x21, 448(x12)
        bn.sid x22, 480(x12)

        addi x10, x10, 512
        addi x12, x12, 512

    .irp reg,s11,s10,s9,s8,s7,s6,s5,s4,s3,s2,s1,s0
        pop \reg
    .endr

    /* Zero w31 again */
    bn.xor w31, w31, w31

    ret