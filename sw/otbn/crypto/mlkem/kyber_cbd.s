/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text 

/*
 * cbd2
 *
 * Description: Given an array of uniformly random bytes, compute
 *              polynomial with coefficients distributed according to
 *              a centered binomial distribution with parameter eta=2
 *
 * Arguments:   - poly *r: pointer to output polynomial
 *              - const uint8_t *buf: pointer to input byte array
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x11: dptr_output, dmem pointer to output
 * @param[in]  x17: cbd2_const
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl cbd2
cbd2:
    /* Set up wide registers for input and intermediate states */
    li x4, 0
    li x5, 1
    li x6, 6
    li x7, 3
    li x8, 4
    li x9, 5

    /* Load cbd2_const */
    la x17, cbd2_const
    bn.lid x7, 0(x17++)
    bn.lid x8, 0(x17++)
    la x18, modulus_bn
    bn.lid x9, 0(x18)

    LOOPI 4, 20
        bn.lid  x4, 0(x10++)      /* Load input array of 2*256/4=128 bytes --> 4 wrs */
        bn.and  w1, w0, w3        /* Extract even bits */
        bn.rshi w0, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w0, w0, w3        /* Extract odd bits */
        bn.add  w0, w0, w1        /* Add even and odd bits */
        bn.and  w1, w0, w4        /* Extract even bit couple */
        bn.rshi w0, w31, w0 >> 2  /* w0 >> 2 */
        bn.and  w0, w0, w4        /* Extract odd bit couple */

        LOOPI 4,  10
            LOOPI 16, 6
                bn.rshi w6, w1, w6 >> 4
                bn.rshi w7, w0, w7 >> 4
                bn.rshi w6, w31, w6 >> 12
                bn.rshi w7, w31, w7 >> 12
                bn.rshi w1, w31, w1 >> 4
                bn.rshi w0, w31, w0 >> 4
            bn.add w6, w6, w5 
            bn.sub w6, w6, w7 
            bn.sid x6, 0(x11++)
        NOP

    ret    

/*
 * cbd3
 *
 * Description: Given an array of uniformly random bytes, compute
 *              polynomial with coefficients distributed according to
 *              a centered binomial distribution with parameter eta=3.
 *              This function is only needed for Kyber-512
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x11: dptr_output, dmem pointer to output
 * @param[in]  x17: cbd2_const
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl cbd3
cbd3:
    /* Set up wide registers for input and intermediate states */
    li x4, 0
    li x5, 1
    li x6, 2
    li x7, 8
    li x19, 11
    li x20, 20
    li x21, 21

    /* Load cbd3_const */
    la x17, cbd3_const
    bn.lid x20, 0(x17++)
    bn.lid x21, 0(x17)
    la x18, modulus_bn
    bn.lid x19, 0(x18)

    LOOPI 2, 125
        /* Load inpput array of 2*256/4=128 bytes --> 4 wrs */
        bn.lid x4, 0(x10++)
        bn.lid x5, 0(x10++)
        bn.lid x6, 0(x10++)

        bn.and  w3, w0, w20       /* extract mod3=0 bit of w0 */
        bn.rshi w4, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w4, w4, w20       /* extract mod3=1 bit of w0 */
        bn.rshi w5, w31, w0 >> 2  /* w0 >> 1 */
        bn.and  w5, w5, w20       /* extract mod3=2 bit of w0 */
        bn.add  w3, w3, w4        
        bn.add  w3, w3, w5        /* w3 stores 85 intermediate values */
        
        bn.rshi w0, w1, w0 >> 255 /* w0 stores last bit of old w0, and 255 bits of w1 */
        bn.and  w4, w0, w20       /* extract mod3=0 bit of w0 */
        bn.rshi w5, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w5, w5, w20       /* extract mod3=1 bit of w0 */
        bn.rshi w6, w31, w0 >> 2  /* w0 >> 2 */
        bn.and  w6, w6, w20       /* extract mod3=2 bit of w0 */
        bn.add  w4, w4, w5
        bn.add  w4, w4, w6        /* w4 stores 85 intermediate values */

        bn.rshi w0, w2, w1 >> 254 /* w0 stores 2 last bits of w1, and 254 bits of w2 */
        bn.and  w5, w0, w20       /* extract mod3=0 bit of w0 */
        bn.rshi w6, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w6, w6, w20       /* extract mod3=1 bit of w0 */
        bn.rshi w7, w31, w0 >> 2  /* w0 >> 2 */
        bn.and  w7, w7, w20       /* extract mod3=2 bit of w0 */
        bn.add  w5, w5, w6
        bn.add  w5, w5, w7        /* w5 stores 85 intermediate values */

        bn.rshi w0, w31, w2 >> 253 /* w0 stores 3 last bits of w2 */
        bn.and  w6, w0, w20       /* extract first bit of w0 */
        bn.rshi w0, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w7, w0, w20       /* extract second bit of w0 */
        bn.rshi w0, w31, w0 >> 1  /* w0 >> 1 */
        bn.and  w0, w0, w20       /* extract third bit of w0 */
        bn.add  w6, w6, w7
        bn.add  w6, w6, w0        /* w6 stores 1 intermediate value */

        bn.and  w0, w3, w21       /* and 0x000111 */
        bn.rshi w3, w31, w3 >> 3  /* w3 >> 3 */
        bn.and  w3, w3, w21       /* and 0x000111 */

        bn.and  w1, w4, w21       /* and 0x000111 */
        bn.rshi w4, w31, w4 >> 3  /* w4 >> 3 */
        bn.and  w4, w4, w21       /* and 0x000111 */

        bn.and  w2, w5, w21       /* and 0x000111 */
        bn.rshi w5, w31, w5 >> 3  /* w5 >> 3 */
        bn.and  w5, w5, w21       /* and 0x000111 */

        /* Compute 16*3=48 coeffs */
        LOOPI 2, 10
            LOOPI 16, 6
                bn.rshi w8, w0, w8 >> 6
                bn.rshi w9, w3, w9 >> 6
                bn.rshi w8, w31, w8 >> 10
                bn.rshi w9, w31, w9 >> 10
                bn.rshi w0, w31, w0 >> 6
                bn.rshi w3, w31, w3 >> 6
            bn.add w8, w8, w11
            bn.sub w8, w8, w9 
            bn.sid x7, 0(x11++)
        LOOPI 10, 6
            bn.rshi w8, w0, w8 >> 6
            bn.rshi w9, w3, w9 >> 6
            bn.rshi w8, w31, w8 >> 10
            bn.rshi w9, w31, w9 >> 10
            bn.rshi w0, w31, w0 >> 6
            bn.rshi w3, w31, w3 >> 6
        bn.rshi w8, w0, w8 >> 16
        bn.rshi w9, w1, w9 >> 6
        bn.rshi w9, w31, w9 >> 10
        bn.rshi w1, w31, w1 >> 6     /* shift out the first intermediate value */
        LOOPI 5, 6
            bn.rshi w8, w4, w8 >> 6 
            bn.rshi w9, w1, w9 >> 6
            bn.rshi w8, w31, w8 >> 10
            bn.rshi w9, w31, w9 >> 10
            bn.rshi w1, w31, w1 >> 6 
            bn.rshi w4, w31, w4 >> 6
        bn.add w8, w8, w11
        bn.sub w8, w8, w9
        bn.sid x7, 0(x11++)        

        /* Compute 16*3=48 coeffs */ 
        LOOPI 2, 10
            LOOPI 16, 6
                bn.rshi w8, w4, w8 >> 6 
                bn.rshi w9, w1, w9 >> 6
                bn.rshi w8, w31, w8 >> 10
                bn.rshi w9, w31, w9 >> 10
                bn.rshi w1, w31, w1 >> 6 
                bn.rshi w4, w31, w4 >> 6
            bn.add w8, w8, w11
            bn.sub w8, w8, w9
            bn.sid x7, 0(x11++)
        LOOPI 5, 6
            bn.rshi w8, w4, w8 >> 6 
            bn.rshi w9, w1, w9 >> 6
            bn.rshi w8, w31, w8 >> 10
            bn.rshi w9, w31, w9 >> 10
            bn.rshi w1, w31, w1 >> 6 
            bn.rshi w4, w31, w4 >> 6
        LOOPI 11, 6
            bn.rshi w8, w2, w8 >> 6 
            bn.rshi w9, w5, w9 >> 6
            bn.rshi w8, w31, w8 >> 10
            bn.rshi w9, w31, w9 >> 10
            bn.rshi w2, w31, w2 >> 6 
            bn.rshi w5, w31, w5 >> 6
        bn.add w8, w8, w11
        bn.sub w8, w8, w9
        bn.sid x7, 0(x11++)

        /* Compute 16*2=32 coeffs */
        LOOPI 16, 6
            bn.rshi w8, w2, w8 >> 6 
            bn.rshi w9, w5, w9 >> 6
            bn.rshi w8, w31, w8 >> 10
            bn.rshi w9, w31, w9 >> 10
            bn.rshi w2, w31, w2 >> 6 
            bn.rshi w5, w31, w5 >> 6
        bn.add w8, w8, w11
        bn.sub w8, w8, w9
        bn.sid x7, 0(x11++)
        LOOPI 15, 6
            bn.rshi w8, w2, w8 >> 6 
            bn.rshi w9, w5, w9 >> 6
            bn.rshi w8, w31, w8 >> 10
            bn.rshi w9, w31, w9 >> 10
            bn.rshi w2, w31, w2 >> 6 
            bn.rshi w5, w31, w5 >> 6
        bn.rshi w8, w2, w8 >> 16 
        bn.rshi w9, w6, w9 >> 16 
        bn.add  w8, w8, w11 
        bn.sub  w8, w8, w9 
        bn.sid  x7, 0(x11++)
    ret

.data
.balign 32
cbd2_const:
    /* const1 */
    .word 0x55555555
    .word 0x55555555
    .word 0x55555555
    .word 0x55555555
    .word 0x55555555
    .word 0x55555555
    .word 0x55555555
    .word 0x55555555
    /* const2 */ 
    .word 0x33333333
    .word 0x33333333
    .word 0x33333333
    .word 0x33333333
    .word 0x33333333
    .word 0x33333333
    .word 0x33333333
    .word 0x33333333

cbd3_const:
    /* const1 */
    .word 0x49249249
    .word 0x92492492
    .word 0x24924924
    .word 0x49249249
    .word 0x92492492
    .word 0x24924924
    .word 0x49249249
    .word 0x12492492
    /* const2 */
    .word 0xc71c71c7
    .word 0x71c71c71
    .word 0x1c71c71c
    .word 0xc71c71c7
    .word 0x71c71c71
    .word 0x1c71c71c
    .word 0xc71c71c7
    .word 0x71c71c71

