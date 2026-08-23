/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Register aliases */
.equ x0, zero
.equ x2, sp
.equ x3, fp
.equ x5, t0
#define t1 x6
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


/*
 * Bibliography
 *
 * [BBD+16]  Gilles Barthe, Sonia Belaid, Francois Dupressoir, Pierre-Alain
 *           Fouque, Benjamin Gregoire, Pierre-Yves Strub, Rebecca Zucchini
 *           "Strong Non-Interference and Type-Directed Higher-Order Masking"
 *           https://eprint.iacr.org/2015/506
 * [BC22]    Olivier Bronchain, Gaetan Cassiers
 *           "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and
 *           Profit: with Application to Lattice-Based KEMs"
 *           https://tches.iacr.org/index.php/TCHES/article/view/9831
 * [BGR+21]  Joppe W. Bos, Marc Gourjon, Joost Renes, Tobias Schneider,
 *           Christine van Vredendaal
 *           "Masking Kyber: First- and Higher-Order Implementations"
 *           https://tches.iacr.org/index.php/TCHES/article/view/9064
 * [CGMZ21b] Jean-Sebastien Coron, Francois Gerard, Simon Montoya, Rina Zeitoun
 *           "High-order Polynomial Comparison and Masking Lattice-based
 *           Encryption"
 *           https://eprint.iacr.org/2021/1615
 * [CGTZ23]  Jean-Sebastien Coron, Francois Gerard, Matthias Trannoy, Rina
 *           Zeitoun
 *           "Improved Gadgets for the High-Order Masking of Dilithium"
 *           https://tches.iacr.org/index.php/TCHES/article/view/11160
 * [CS20]    Gaetan Cassiers, Francois-Xavier Standaert
 *           "Trivially and Efficiently Composing Masked Gadgets With Probe
 *           Isolating Non-Interference"
 *           https://ieeexplore.ieee.org/document/8979162/
 * [FBR+21]  Tim Fritzmann, Michiel Van Beirendonck, Debapriya Basu Roy, Patrick
 *           Karl, Thomas Schamberger, Ingrid Verbauwhede, Georg Sigl
 *           "Masked Accelerators and Instruction Set Extensions for
 *           Post-Quantum Cryptography"
 *           https://tches.iacr.org/index.php/TCHES/article/view/9303
 * [SPOG19]  Tobias Schneider, Clara Paglialonga, Tobias Oder, Tim Guneysu
 *           "Efficiently Masking Binomial Sampling at Arbitrary Orders for
 *           Lattice-Based Crypto"
 *           https://eprint.iacr.org/2019/910
 */

/*
 * Name: secand
 *
 * Return new Boolean shares of a value r = x & y.
 * Bitsliced.
 *
 *   s   <- URND
 *   r_0 <- (x_0 & y_0) ^ (x_0 & (y_1 ^ s)) ^ ((x_0 ^ 1) & s)
 *   r_1 <- (x_1 & y_1) ^ (x_1 & (y_0 ^ s)) ^ ((x_1 ^ 1) & s)
 *
 * Source: Alg.2 [CS20]
 *
 * @param[in]  x10: dptr_xb, dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_yb, dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[out] x15: dptr_rb, dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride, distance between shares of r
 *
 * clobbered registers: x4 to x7, x10, x12, x15, w0 to w3, w5 to w8
 * clobbered flag groups: FG0
 */
.globl secand
.type secand, @function
secand:
    /* Save addresses. */
    addi t0, a0, 0
    addi t1, a2, 0
    addi t2, a5, 0

    /* Load x. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(t0) /* x[0] */
    bn.xor w1, w1, w1
    add    t0, t0, a1
    addi   x4, x0, 1
    bn.lid x4++, 0(t0) /* x[1] */

    /* Load y. */
    bn.xor w2, w2, w2
    bn.lid x4++, 0(t1) /* y[0] */
    bn.xor w3, w3, w3
    add    t1, t1, a3
    bn.lid x4, 0(t1) /* y[1] */

    addi    x4, x0, 6
    bn.wsrr w5, urnd
    /* Handle z_01. */
    bn.xor  w6, w6, w6
    bn.and  w6, w0, w2 /* x[0] & y[0] */
    bn.xor  w7, w7, w7
    bn.xor  w7, w3, w5 /* y[1] ^ r */
    bn.and  w7, w0, w7 /* &= x[0] */
    bn.xor  w8, w8, w8
    bn.not  w8, w0 /* x[0] ^ 1 */
    bn.and  w8, w8, w5 /* &= r */
    bn.xor  w7, w7, w8 /* w7 ^= w8 */
    bn.xor  w6, w6, w7
    bn.sid  x4, 0(t2) /* Save r[0]. */
    add     t2, t2, a6
    /* Handle z_10. */
    bn.xor  w6, w6, w6
    bn.and  w6, w1, w3 /* x[1] & y[1] */
    bn.xor  w7, w7, w7
    bn.xor  w7, w2, w5 /* y[0] ^ r */
    bn.and  w7, w1, w7 /* &= x[1] */
    bn.xor  w8, w8, w8
    bn.not  w8, w1 /* x[1] ^ 1 */
    bn.and  w8, w8, w5 /* &= r */
    bn.xor  w7, w7, w8 /* w7 ^= w8 */
    bn.xor  w6, w6, w7
    bn.sid  x4, 0(t2) /* Save r[1]. */

    /* Advance a0, a2, a5 to the next bit. */
    addi a0, a0, 32
    addi a2, a2, 32
    addi a5, a5, 32
    ret

/*
 * Name: secfulladder
 *
 * Return Boolean shares of a value r = (x + y + c) mod 2^2, given Boolean
 * shares of x and y mod 2.
 * Bitsliced.
 *
 *   a    <- x ^ y                   (sharewise)
 *   r    <- a ^ cin                 (sharewise; sum bit)
 *   cout <- x ^ SecAnd(a, x ^ cin)  (carry bit)
 *
 * Source: Alg.5 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[out] x15: dptr_r, dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride, distance between shares of r
 * @param[in]  x17: dptr_c, dmem pointer to the Boolean shares of cin
 * @param[in]  x29: share stride, distance between shares of cin
 * @param[out] x30: dptr_c, dmem pointer to the Boolean shares of cout
 * @param[in]  x31: share stride, distance between shares of cout
 *
 * clobbered registers: x4 to x7, x10, x12, x15, x28, w0 to w9
 * clobbered flag groups: FG0
 */
.globl secfulladder
.type secfulladder, @function
secfulladder:
    /* Save addresses. */
    add t0, a0, x0
    add t1, a2, x0
    add t2, a5, x0
    add t3, a7, x0

    /* Load x. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(t0) /* x[0] */
    add    t0, t0, a1
    addi   x4, x0, 1
    bn.xor w1, w1, w1
    bn.lid x4++, 0(t0) /* x[1] */
    /* Load y. */
    bn.xor w2, w2, w2
    bn.lid x4++, 0(t1) /* y[0] */
    add    t1, t1, a3
    bn.xor w3, w3, w3
    bn.lid x4, 0(t1) /* y[1] */

    /* Compute sharewise a = x ^ y. */
    bn.xor w4, w4, w4
    bn.xor w4, w0, w2
    bn.xor w5, w5, w5
    bn.xor w5, w1, w3

    /* Compute r = cin ^ a. */
    bn.xor w2, w2, w2
    addi   x4, x0, 2
    bn.lid x4++, 0(t3)
    add    t3, t3, t4
    bn.xor w3, w3, w3
    bn.lid x4++, 0(t3)

    bn.xor w6, w6, w6
    bn.xor w6, w4, w2
    addi   x4, x0, 6
    bn.sid x4, 0(t2)
    add    t2, t2, a6
    bn.xor w6, w6, w6
    bn.xor w6, w5, w3
    bn.sid x4, 0(t2)

    /* Compute cout = x ^ secand(a, x ^ cin). */
    /* a: w4 -- w5
     * x: w0 -- w1
     * cin: w2 -- w3 */
    bn.xor w6, w6, w6
    bn.xor w6, w0, w2
    bn.xor w7, w7, w7
    bn.xor w7, w1, w3

    /* a: w4 -- w5
     * x ^ cin: w6 -- w7
     * x: w0 -- w1.  */
    bn.wsrr w8, urnd
    /* Handle cout_01. */
    bn.xor  w2, w2, w2
    bn.and  w2, w4, w6
    bn.xor  w3, w3, w3
    bn.xor  w3, w7, w8
    bn.and  w3, w4, w3
    bn.xor  w9, w9, w9
    bn.not  w9, w4
    bn.and  w9, w9, w8
    bn.xor  w3, w3, w9
    bn.xor  w2, w2, w3
    bn.xor  w3, w3, w3
    bn.xor  w3, w2, w0
    add     t2, t5, x0
    addi    x4, x0, 3
    bn.sid  x4, 0(t2)
    add     t2, t2, t6
    /* Handle cout_10. */
    bn.xor  w2, w2, w2
    bn.and  w2, w5, w7
    bn.xor  w3, w3, w3
    bn.xor  w3, w6, w8
    bn.and  w3, w5, w3
    bn.xor  w9, w9, w9
    bn.not  w9, w5
    bn.and  w9, w9, w8
    bn.xor  w3, w3, w9
    bn.xor  w2, w2, w3
    bn.xor  w3, w3, w3
    bn.xor  w3, w2, w1
    bn.sid  x4, 0(t2)

    /* Point to next bit. */
    addi a0, a0, 32
    addi a2, a2, 32
    addi a5, a5, 32
    ret

/*
 * Name: secadd
 *
 * Return Boolean shares of a value r = (x + y) mod 2^k, given Boolean shares of
 * x and y mod 2^k.
 * Bitsliced.
 *
 *   c <- 0
 *   for i = 0, ..., k-2:  (c, r[i]) <- SecFullAdder(x[i], y[i], c)
 *   r[k-1] <- x[k-1] ^ y[k-1] ^ c
 *
 * Source: Alg.6 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[in]  x12: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride, distance between shares of y
 * @param[out] x15: dptr_r, dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride, distance between shares of r
 * @param[in]  x17: k, bitsize of x and y.
 *
 * clobbered registers: x2, x4 to x8, x10, x12, x15, x17, x28 to x31, w0 to w9
 * clobbered flag groups: FG0
 */
.globl secadd
.type secadd, @function
secadd:
    /* Reserve frame: 64 B carry c at 0(sp), plus saved s0, a7. */
    addi sp, sp, -96
    sw   s0, 64(sp)
    sw   a7, 68(sp)

    /* Initialize c = 0. */
    bn.xor w0, w0, w0
    addi   t0, sp, 0 /* ptr_c */
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop

    /* Ripple-carry adder. */
    addi s0, a7, -1
    addi a7, sp, 0 /* ptr_c = cin */
    addi t4, x0, 32
    addi t5, sp, 0 /* ptr_c = cout */
    addi t6, x0, 32
    /* Loop over i=0,...,k-2. */
    loop s0, 2
        /* a0 already points to x[i] */
        /* a1 is already share stride of x. */
        /* a2 already points to y[i] */
        /* a3 is already share stride of y. */
        /* a5 already points to r. */
        /* a6 is already share stride of r. */
        /* a7 already points to ptr_c = cin. */
        /* t4 is already share stride of cin. */
        /* t5 already points to ptr_c = cout. */
        /* t6 is already share stride of cout. */
        jal  x1, secfulladder
        /* After secfulladder:
         *  - a0 and a2 points to x[i + 1] and y[i + 1].
         *  - a1 and a3 are still share stride of x and y.
         *  - a5 points to r[i + 1].
         *  - a6 is still share stride of r.
         *  - a7 points to cin.
         *  - t4 is still share stride of cin.
         *  - t5 points to cout.
         *  - t6 is still share stride of cout. */
        nop
    endloop

    /* Handle bit i = k-1. */
    /* Compute r[k-1] = x[k-1] ^ y[k-1] ^ c. */
    addi t0, sp, 0 /* ptr_c */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loopi 2, 14
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.lid t1, 0(t0)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, a3
        add    t0, t0, t4
        add    a5, a5, a6
    endloop

    /* Restore registers and frame. */
    lw   s0, 64(sp)
    lw   a7, 68(sp)
    addi sp, sp, 96
    ret

/*
 * Name: bitcopymask
 *
 * Return k-bit Boolean shares of q * x, given 1-bit Boolean shares of x for
 * q = 3329 and the bitsize k = 12 (since q < 2**k).
 * Bitsliced.
 *
 *   for j = 0, ..., k-1:  r[j] <- q_j & x   (q = 3329 = 0b110100000001)
 *
 * Source: Alg.1 [BC22]
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input Boolean shares of x
 * @param[in]  x11: share stride, distance between shares of x
 * @param[out] x13: dptr_rb, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x4, x10, x13, w0
 * clobbered flag groups: FG0
 */
.globl bitcopymask
.type bitcopymask, @function
bitcopymask:
    /* Since q = 3329 = b110100000001, we copy x to the 1st, 9th, 11th and 12th
     * bit of r and zeroize the rest of r. */
    addi   x4, x0, 31
    loopi 2, 10
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0)
        add    a0, a0, a1
        /* Copy x to bit 0. */
        bn.sid x0, 0(a3++)
        /* Clear bit 1 -- 7. */
        loopi 7, 1
            bn.sid x4, 0(a3++)
        endloop
        /* Copy x to bit 8. */
        bn.sid x0, 0(a3++)
        /* Clear bit 9. */
        bn.sid x4, 0(a3++)
        /* Copy x to bit 10 -- 11. */
        bn.sid x0, 0(a3++)
        bn.sid x0, 0(a3++)
    endloop
    ret

/*
 * Name: refreshios
 *
 * Return new Boolean shares of x mod 2^k, given old Boolean shares of x.
 * Bitsliced.
 *
 *   for each bit-slice:
 *     s    <- URND
 *     r[0] <- x[0] ^ s
 *     r[1] <- x[1] ^ s
 *
 * Source: Alg.18 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: k, bitsize of x.
 * @param[in]  x12: share stride, distance between shares
 * @param[out] x14: dptr_r, dmem pointer to the output Boolean shares of r
 *
 * clobbered registers: x4 to x6, x10, x14, w0 to w2
 * clobbered flag groups: FG0
 */
.globl refreshios
.type refreshios, @function
refreshios:
    add  t0, a0, a2 /* 2nd share of x */
    add  t1, a4, a2 /* 2nd share of r */
    addi x4, x0, 1
    loop a1, 11
        bn.wsrr w2, urnd
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.xor  w1, w0, w2
        bn.sid  x4, 0(a4++)
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(t0++)
        bn.xor  w1, w0, w2
        bn.sid  x4, 0(t1++)
    endloop
    ret

/*
 * Name: poly_rej_samp
 *
 * Return a polynomial of random coefficients mod q, obtained by running
 * rejection sampling on uniform random bytes from URND.
 *
 * @param[in]  w16: sw0, R | Q
 * @param[out] a0: ptr_r, dmem pointer to output polynomial
 * @param[in]  a1: dmem pointer to random input words (MLKEM_REJ_SAMPLE_TEST only)
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x5 to x6, x10, w0 to w5, acch, acc
 * clobbered flag groups: FG0
 */

.globl poly_rej_samp
.type poly_rej_samp, @function
poly_rej_samp:
	/* Load 19*Q - 1 into w1. */
	addi      t0, x0, 1
	la        t1, modulus_times_19_minus_1
	bn.lid    t0++, 0(t1)
	bn.shv.8s w1, w1 >> 16

	/* Load mont = 2**16 % Q into w2. */
	la     t1, mont
	bn.lid t0, 0(t1)

	/* a0 + 512 is the last valid address. */
	addi t0, a0, 512

#if defined(MLKEM_REJ_SAMPLE_TEST)
	addi t5, x0, 3
#endif

	/* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
	/* Get 16 randoms. */
#if defined(MLKEM_REJ_SAMPLE_TEST)
	bn.lid      t5, 0(a1++)
#else
	bn.wsrr     w3, urnd
#endif
	bn.trn1.16h w4, w3, w31
	bn.subv.8s  w4, w1, w4
	bn.shv.8s   w4, w4 >> 31
	bn.trn2.16h w5, w3, w31
	bn.subv.8s  w5, w1, w5
	bn.shv.8s   w5, w5 >> 31
	bn.trn1.16h w4, w4, w5
	bn.xor      w4, w4, w31, FG0
	csrrs       t1, fg0, x0 /* Read flag fg0. */
	srli        t1, t1, 3 /* Extract FG0.z */

	/* If FG0.z == 0, there is at least one bad coeff. We throw away this
	 * vector and sample again. */
	beq t1, x0, _rej_sample_loop

	/* Once the whole vector is accepted, reduce the accepted candidates mod Q
	 * using Montgomery. */
	bn.mulv.16h.acc.z.lo w0, w3, w2
	bn.mulv.l.16h.lo     w0, w0, sw0.2
	bn.mulv.l.16h.acc.hi w0, w0, sw0.0
	bn.addvm.16h         w0, w0, w31
	bn.sid               x0, 0(a0++)

	/* If a0 == t0, we've filled up a polynomial. Otherwise, continue to sample. */
	beq a0, t0, _end_rej_sample_loop
	beq x0, x0, _rej_sample_loop

_end_rej_sample_loop:
	ret

/*
 * Name: refreshmodq
 *
 * Return new arithmetic shares mod q = 3329 of the value x.
 * Vectorized for polynomial.
 *
 *   rand <- poly_rej_samp()      uniform polynomial mod q
 *   r[0] <- x[0] + rand   mod q
 *   r[1] <- x[1] - rand   mod q
 *
 * Source: [BBD+16]
 *
 * @param[in]  w16: R | Q
 * @param[in]  x10: dptr_xa, dmem pointer to arithmetic shares of x
 * @param[out] x12: dptr_ra, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: x2, x4 to x7, x10, x12, x28, w0 to w5, acch, acc
 * clobbered flag groups: FG0
 */
.globl refreshmodq
.type refreshmodq, @function
refreshmodq:
    /* Reserve frame: 512 B for rand at 0(sp), plus saved a0, a2. */
    addi sp, sp, -544
    sw a0, 512(sp)
    sw a2, 516(sp)

    /* Generate rand. */
    add a0, sp, x0
    jal x1, poly_rej_samp

    /* r[0] = x[0] + rand. */
    /* r[1] = x[1] - rand. */
    add  t0, sp, 0 /* rand */
    lw   a0, 512(sp)
    addi t1, a0, 512 /* x[1] */
    lw   a2, 516(sp)
    addi t2, a2, 512 /* r[1] */
    addi x4, x0, 1
    addi t3, x0, 2
    loopi 16, 9
        bn.lid       x0, 0(t0++)
        bn.lid       x4, 0(a0++)
        bn.addvm.16h w2, w1, w0
        bn.sid       t3, 0(a2++)
        bn.xor       w1, w1, w1
        bn.xor       w2, w2, w2
        bn.lid       x4, 0(t1++)
        bn.subvm.16h w2, w1, w0
        bn.sid       t3, 0(t2++)
    endloop

    /* Restore stack. */
    addi sp, sp, 544
    ret

/*
 * Name: poly_to_bitsliced
 *
 * Return bitsliced representation of a value x in [0, KYBER_Q).
 * Vectorized for polynomial.
 *
 *   bs[j] <- bit j of x,  j = 0, ..., 11
 *
 * @param[in]  x10: dptr_x, dmem pointer to the input masked value
 * @param[out] x11: dptr_r, dmem pointer to the output bitslice representation
 *
 * clobbered registers: x4, x10, w0 to w15, w28 to w29
 * clobbered flag groups: FG0
 */
.globl poly_to_bitsliced
.type poly_to_bitsliced, @function
poly_to_bitsliced:

    /* Reverse-load the 16 input WDRs: coefficient WDR i -> w[15 - i]. */
    addi x4, x0, 15
    loopi 16, 2
        bn.lid x4, 0(a0++)
        addi   x4, x4, -1
    endloop

    jal x1, _bitslice_transpose

    /* Store the 12 bitsliced words bs[0..11] via a0 so a1 is left unchanged. */
    addi   x4, x0, 0
    addi   a0, a1, 0
    loopi 12, 2
        bn.sid x4, 0(a0++)
        addi   x4, x4, 1
    endloop
    ret

/*
 * Name: poly_from_bitsliced
 *
 * Return normal representation of a bitsliced value x in [0, KYBER_Q).
 * Vectorized for polynomial.
 *
 *   x <- sum_{j=0}^{11} bs[j] << j
 *
 * @param[in]  x10: dptr_x, dmem pointer to the input bitsliced representation
 * @param[in]  w31: all-zero register
 * @param[out] x11: dptr_r, dmem pointer to the output masked value
 *
 * clobbered registers: x4, x10 to x11, w0 to w15, w28 to w29
 * clobbered flag groups: FG0
 */
.globl poly_from_bitsliced
.type poly_from_bitsliced, @function
poly_from_bitsliced:

    /* Load bs[0..11] into w0..w11; zero the upper bit positions w12..w15. */
    addi x4, x0, 0
    loopi 12, 2
        bn.lid x4, 0(a0++)
        addi   x4, x4, 1
    endloop
    bn.xor w12, w12, w12
    bn.xor w13, w13, w13
    bn.xor w14, w14, w14
    bn.xor w15, w15, w15

    jal x1, _bitslice_transpose

    /* Reverse-store: w[b] -> coefficient WDR (15 - b). */
    addi x4, x0, 15
    loopi 16, 2
        bn.sid x4, 0(a1++)
        addi   x4, x4, -1
    endloop
    ret

/*
 * 16x16 per-lane bit transpose of w0..w15, shared by poly_to_bitsliced and
 * poly_from_bitsliced.
 */
_bitslice_transpose:
    /* Stage d=8. */
    bn.not     w28, w31
    bn.shv.16h w28, w28 >> 8      /* 0x00ff */
    bn.shv.16h w29, w0 >> 8
    bn.xor     w29, w29, w8
    bn.and     w29, w29, w28
    bn.xor     w8, w8, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w0, w0, w29
    bn.shv.16h w29, w1 >> 8
    bn.xor     w29, w29, w9
    bn.and     w29, w29, w28
    bn.xor     w9, w9, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w1, w1, w29
    bn.shv.16h w29, w2 >> 8
    bn.xor     w29, w29, w10
    bn.and     w29, w29, w28
    bn.xor     w10, w10, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w2, w2, w29
    bn.shv.16h w29, w3 >> 8
    bn.xor     w29, w29, w11
    bn.and     w29, w29, w28
    bn.xor     w11, w11, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w3, w3, w29
    bn.shv.16h w29, w4 >> 8
    bn.xor     w29, w29, w12
    bn.and     w29, w29, w28
    bn.xor     w12, w12, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w4, w4, w29
    bn.shv.16h w29, w5 >> 8
    bn.xor     w29, w29, w13
    bn.and     w29, w29, w28
    bn.xor     w13, w13, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w5, w5, w29
    bn.shv.16h w29, w6 >> 8
    bn.xor     w29, w29, w14
    bn.and     w29, w29, w28
    bn.xor     w14, w14, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w6, w6, w29
    bn.shv.16h w29, w7 >> 8
    bn.xor     w29, w29, w15
    bn.and     w29, w29, w28
    bn.xor     w15, w15, w29
    bn.shv.16h w29, w29 << 8
    bn.xor     w7, w7, w29
    /* Stage d=4. */
    bn.shv.16h w29, w28 << 4
    bn.xor     w28, w28, w29      /* 0x0f0f */
    bn.shv.16h w29, w0 >> 4
    bn.xor     w29, w29, w4
    bn.and     w29, w29, w28
    bn.xor     w4, w4, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w0, w0, w29
    bn.shv.16h w29, w1 >> 4
    bn.xor     w29, w29, w5
    bn.and     w29, w29, w28
    bn.xor     w5, w5, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w1, w1, w29
    bn.shv.16h w29, w2 >> 4
    bn.xor     w29, w29, w6
    bn.and     w29, w29, w28
    bn.xor     w6, w6, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w2, w2, w29
    bn.shv.16h w29, w3 >> 4
    bn.xor     w29, w29, w7
    bn.and     w29, w29, w28
    bn.xor     w7, w7, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w3, w3, w29
    bn.shv.16h w29, w8 >> 4
    bn.xor     w29, w29, w12
    bn.and     w29, w29, w28
    bn.xor     w12, w12, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w8, w8, w29
    bn.shv.16h w29, w9 >> 4
    bn.xor     w29, w29, w13
    bn.and     w29, w29, w28
    bn.xor     w13, w13, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w9, w9, w29
    bn.shv.16h w29, w10 >> 4
    bn.xor     w29, w29, w14
    bn.and     w29, w29, w28
    bn.xor     w14, w14, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w10, w10, w29
    bn.shv.16h w29, w11 >> 4
    bn.xor     w29, w29, w15
    bn.and     w29, w29, w28
    bn.xor     w15, w15, w29
    bn.shv.16h w29, w29 << 4
    bn.xor     w11, w11, w29
    /* Stage d=2. */
    bn.shv.16h w29, w28 << 2
    bn.xor     w28, w28, w29      /* 0x3333 */
    bn.shv.16h w29, w0 >> 2
    bn.xor     w29, w29, w2
    bn.and     w29, w29, w28
    bn.xor     w2, w2, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w0, w0, w29
    bn.shv.16h w29, w1 >> 2
    bn.xor     w29, w29, w3
    bn.and     w29, w29, w28
    bn.xor     w3, w3, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w1, w1, w29
    bn.shv.16h w29, w4 >> 2
    bn.xor     w29, w29, w6
    bn.and     w29, w29, w28
    bn.xor     w6, w6, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w4, w4, w29
    bn.shv.16h w29, w5 >> 2
    bn.xor     w29, w29, w7
    bn.and     w29, w29, w28
    bn.xor     w7, w7, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w5, w5, w29
    bn.shv.16h w29, w8 >> 2
    bn.xor     w29, w29, w10
    bn.and     w29, w29, w28
    bn.xor     w10, w10, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w8, w8, w29
    bn.shv.16h w29, w9 >> 2
    bn.xor     w29, w29, w11
    bn.and     w29, w29, w28
    bn.xor     w11, w11, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w9, w9, w29
    bn.shv.16h w29, w12 >> 2
    bn.xor     w29, w29, w14
    bn.and     w29, w29, w28
    bn.xor     w14, w14, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w12, w12, w29
    bn.shv.16h w29, w13 >> 2
    bn.xor     w29, w29, w15
    bn.and     w29, w29, w28
    bn.xor     w15, w15, w29
    bn.shv.16h w29, w29 << 2
    bn.xor     w13, w13, w29
    /* Stage d=1. */
    bn.shv.16h w29, w28 << 1
    bn.xor     w28, w28, w29      /* 0x5555 */
    bn.shv.16h w29, w0 >> 1
    bn.xor     w29, w29, w1
    bn.and     w29, w29, w28
    bn.xor     w1, w1, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w0, w0, w29
    bn.shv.16h w29, w2 >> 1
    bn.xor     w29, w29, w3
    bn.and     w29, w29, w28
    bn.xor     w3, w3, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w2, w2, w29
    bn.shv.16h w29, w4 >> 1
    bn.xor     w29, w29, w5
    bn.and     w29, w29, w28
    bn.xor     w5, w5, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w4, w4, w29
    bn.shv.16h w29, w6 >> 1
    bn.xor     w29, w29, w7
    bn.and     w29, w29, w28
    bn.xor     w7, w7, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w6, w6, w29
    bn.shv.16h w29, w8 >> 1
    bn.xor     w29, w29, w9
    bn.and     w29, w29, w28
    bn.xor     w9, w9, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w8, w8, w29
    bn.shv.16h w29, w10 >> 1
    bn.xor     w29, w29, w11
    bn.and     w29, w29, w28
    bn.xor     w11, w11, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w10, w10, w29
    bn.shv.16h w29, w12 >> 1
    bn.xor     w29, w29, w13
    bn.and     w29, w29, w28
    bn.xor     w13, w13, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w12, w12, w29
    bn.shv.16h w29, w14 >> 1
    bn.xor     w29, w29, w15
    bn.and     w29, w29, w28
    bn.xor     w15, w15, w29
    bn.shv.16h w29, w29 << 1
    bn.xor     w14, w14, w29
    ret

/*
 * Name: seca2b
 *
 * Return Boolean shares mod 2**k of a value x given its arithmetic shares mod 2**k.
 * Bitsliced.
 *
 *   s  <- (x[0], 0)
 *   s' <- (0, x[1])
 *   r  <- secadd(s, s')
 *
 * Source: Alg.8 [BC22]
 *
 * @param[in]  x10: dptr_xa, dmem pointer to the input arithmetic shares mod 2**k of x
 * @param[in]  x11: k, bitsize of x.
 * @param[in]  x12: share bytes, bytes per bitsliced share
 * @param[out] x14: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x2 to x8, x10 to x13, x15 to x17, x28 to x31, w0 to w9
 * clobbered flag groups: FG0
 */
.globl seca2b
.type seca2b, @function
seca2b:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Adjust stack for temp variables. */
    slli t0, a2, 1
    sub  sp, sp, t0 /* ptr_s */
    add  t1, sp, x0
    sub  sp, sp, t0 /* ptr_sp */

    /* Build s = (x[0], 0). */
    add t2, t1, x0 /* Save ptr_s. */
    loop a1, 3
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t1++)
    endloop
    bn.xor w0, w0, w0
    loop a1, 1
        bn.sid x0, 0(t1++)
    endloop

    /* Build s' = (0, x[1]). */
    add t0, sp, x0
    loop a1, 1
        bn.sid x0, 0(t0++)
    endloop
    loop a1, 3
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t0++)
        bn.xor w0, w0, w0
    endloop

    /* Save registers. */
    add t0, a1, x0
    add t1, a2, x0
    add t3, a4, x0

    /* Compute r = secadd(s, s', k). */
    addi a0, t2, 0 /* ptr_s */
    addi a1, t1, 0
    addi a2, sp, 0 /* ptr_sp */
    addi a3, t1, 0
    addi a5, t3, 0 /* ptr_r */
    addi a6, t1, 0
    addi a7, t0, 0 /* k */
    jal  x1, secadd

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret

/*
 * Name: seca2bmodq
 *
 * Return Boolean shares mod 2**k (k = 12) of a value x mod q = 3329 given its
 * arithmetic shares. (It is required that q < 2**k).
 * Bitsliced.
 *
 *   s  <- ((2^(k+1) - q) + x[0], 0)
 *   s' <- (0, x[1])
 *   u  <- secadd(s, s')
 *   a  <- bitcopymask(u[k])
 *   r  <- secadd(a, u)
 *
 * Source: Alg.10 [BC22]
 *
 * @param[in]  x10: dptr_xa, dmem pointer to the input arithmetic shares mod q of x
 * @param[out] x12: dptr_rb, dmem pointer to the output Boolean shares
 *
 * clobbered registers: x2, x4 to x7, x10 to x13, x15 to x18, x28 to x31, w0 to w9
 * clobbered flag groups: FG0
 */
.globl seca2bmodq
.type seca2bmodq, @function
seca2bmodq:
    /* Frame below sp:
     *   sp +    0 : s' / a   (832 B)
     *   sp +  832 : carry c  ( 64 B)
     *   sp +  896 : s / u    (832 B)
     *   sp + 1728 : saved s2 */
    addi sp, sp, -1760
    sw   s2, 1728(sp)
    addi s2, a2, 0 /* output pointer */

    /* Compute s = p + x[0], k + 1 bits (one share).
     * p = 2**(k + 1) - q = 4863 = b1001011111111. */
    addi t0, sp, 896 /* ptr_s */
    /* a0 already points to x[0]. */
    addi x4, x0, 1
    /* cin = 0 */
    bn.xor w2, w2, w2

    /* Bit 0 -- 7: 1. */
    loopi 8, 9
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        /* Compute r = x ^ p ^ cin. */
        bn.lid x0, 0(a0++)
        bn.not w3, w0 /* a = x ^ p */
        bn.xor w1, w3, w2 /* r = a ^ cin */
        bn.sid x4, 0(t0++) /* Save r. */
        /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (a & (x ^ cin)). */
        bn.xor w2, w0, w2 /* cout = x ^ cin */
        bn.and w2, w3, w2 /* cout &= a */
        bn.xor w2, w2, w0 /* cout ^= x */
    endloop

    /* Bit 8: 0. */
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    /* Compute r = x ^ 0 ^ cin = x ^ cin. */
    bn.lid x0, 0(a0++)
    bn.xor w1, w0, w2 /* r = x ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
    bn.and w2, w0, w1 /* cout = x & r */
    bn.xor w2, w2, w0 /* cout ^= x */

    /* Bit 9: 1. */
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    /* Compute r = x ^ p ^ cin. */
    bn.lid x0, 0(a0++)
    bn.not w3, w0 /* a = x ^ p */
    bn.xor w1, w3, w2 /* r = a ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (a & (x ^ cin)). */
    bn.xor w2, w0, w2 /* cout = x ^ cin */
    bn.and w2, w3, w2 /* cout &= a */
    bn.xor w2, w2, w0 /* cout ^= x */

    /* Bit 10 -- 11: 0. */
    loopi 2, 7
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        /* Compute r = x ^ 0 ^ cin = x ^ cin. */
        bn.lid x0, 0(a0++)
        bn.xor w1, w0, w2 /* r = x ^ cin */
        bn.sid x4, 0(t0++) /* Save r. */
        /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
        bn.and w2, w0, w1 /* cout = x & r */
        bn.xor w2, w2, w0 /* cout ^= x */
    endloop

    /* Bit 12: 1. */
    /* Whitening. */
    bn.xor w1, w1, w1
    /* Compute r = x ^ p ^ cin = p ^ cin. (x only has k bits, while p has k + 1 bits). */
    bn.not w1, w2 /* r = p ^ cin */
    bn.sid x4, 0(t0++) /* Save r. */

    /* Extend s to 2 shares, i.e., clear next share of s. */
    bn.xor w0, w0, w0
    loopi 13, 1
        bn.sid x0, 0(t0++)
    endloop

    /* Clear first share of sprime and copy x[1] to second share of sprime with
     * share stride = 416. */
    addi t0, sp, 0 /* ptr_sprime */
    loopi 13, 1
        bn.sid x0, 0(t0++)
    endloop
    loopi 12, 3
        bn.lid x0, 0(a0++) /* a0 already points to x[1]. */
        bn.sid x0, 0(t0++)
        /* Whitening. */
        bn.xor w0, w0, w0
    endloop
    bn.sid x0, 0(t0++)

    /* Compute u = secadd(s, sprime, k + 1). */
    /* Initialize c = 0. */
    addi  t0, sp, 832 /* ptr_c */
    bn.xor w0, w0, w0
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop

    addi a0, sp, 896 /* ptr_s */
    addi a1, x0, 416
    addi a2, sp, 0 /* ptr_sprime */
    addi a3, x0, 416
    addi a5, sp, 896 /* ptr_u */
    addi a6, x0, 416
    addi a7, sp, 832 /* ptr_c */
    addi t4, x0, 32
    addi t5, sp, 832 /* ptr_c */
    addi t6, x0, 32
    loopi 12, 2
        jal x1, secfulladder
        nop
    endloop
    /* Handle bit 12. */
    /* Compute r[12] = x[12] ^ y[12] ^ c. */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loopi 2, 14
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.lid t1, 0(a7)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, a3
        add    a7, a7, t4
        add    a5, a5, a6
    endloop

    /* Compute a = bitcopymask(u[k], (k + 1) * 32). */
    addi a0, sp, 1280 /* ptr_u[k] */
    addi a1, x0, 416
    addi a3, sp, 0 /* ptr_a */
    jal  x1, bitcopymask

    /* Compute u = secadd(a, u, k). */
    /* Initialize c = 0. */
    addi  t0, sp, 832 /* ptr_c */
    bn.xor w0, w0, w0
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop

    addi a0, sp, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, sp, 896 /* ptr_u */
    addi a3, x0, 416
    addi a5, s2, 0 /* ptr_r */
    addi a6, x0, 384
    addi a7, sp, 832 /* ptr_c */
    addi t4, x0, 32
    addi t5, sp, 832 /* ptr_c */
    addi t6, x0, 32
    loopi 11, 2
        jal x1, secfulladder
        nop
    endloop
    /* Handle bit 11. */
    /* Compute r[11] = x[11] ^ y[11] ^ c. */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loopi 2, 14
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a2)
        bn.lid t1, 0(a7)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a1
        add    a2, a2, a3
        add    a7, a7, t4
        add    a5, a5, a6
    endloop

    /* Restore s2 and frame. */
    lw   s2, 1728(sp)
    addi sp, sp, 1760
    ret

/*
 * Name: seconebitb2amodq
 *
 * Return arithmetic shares mod q = 3329 of a bit x, given its Boolean shares.
 * Vectorized for polynomial.
 *
 *   v    <- (x[0], 0)
 *   v    <- refreshmodq(v)
 *   v[0] <- (1 - 2*x[1])*v[0] + x[1]   mod q
 *   v[1] <- (1 - 2*x[1])*v[1]          mod q
 *   r    <- refreshmodq(v[0], v[1])
 *
 * Source: Alg.5 [SPOG19]
 *
 * @param[in]  w16: R | Q
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[out] x12: dptr_r, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: x2, x4 to x8, x10, x12, x18, x28, w0 to w5, w30, acch, acc
 * clobbered flag groups: FG0
 */
.globl seconebitb2amodq
.type seconebitb2amodq, @function
seconebitb2amodq:
    /* Frame: v[0..1] at sp+0 (1024 B), saved s0/s2 above. */
    addi sp, sp, -1056
    sw   s0, 1024(sp)
    sw   s2, 1028(sp)
    addi s0, a0, 0 /* ptr_x */
    addi s2, a2, 0 /* ptr_r */

    /* Copy x[0] to v[0]. */
    addi t0, sp, 0 /* ptr_v */
    add  t1, a0, x0 /* ptr_x[0] */
    loopi 16, 2
        bn.lid x0, 0(t1++)
        bn.sid x0, 0(t0++)
    endloop
    /* Zeroize v[1]. */
    bn.xor w0, w0, w0
    loopi 16, 1
        bn.sid x0, 0(t0++)
    endloop

    /* Construct the vector of 1s. */
    bn.subi    w30, w0, 1
    bn.shv.16h w30, w30 >> 15

    /* Refresh v in place. */
    addi a0, sp, 0 /* ptr_v */
    addi a2, a0, 0 /* in-place */
    jal  x1, refreshmodq

    /* To avoid use modular multiplication, we compute (1 - 2*x[1]) * v[j]
     * as follows:
     *  - t0 = x[1] - 1
     *  - We have t0 = 0xFFFF if x[1] = 0 and t0 = 0 if x[1] = 1.
     *  - t1 = v[j] & t0
     *  - t1 <<= 1
     *  - r = bn.subvm(t1, v[j]) with MOD = Q. This works because if x[1] = 0,
     *    then t1 = 2*v[j] and r = 2*v[j] - v[j] = v[j]. Otherwise,
     *    t1 = (0 - v[j]) mod Q.
     * For v[0], we continue with v[0] = (v[0] + x[1]) mod Q before
     * saving the result to memory.
     */
    addi t0, s0, 512 /* ptr_x[1] */
    addi t1, sp, 0 /* ptr_v */
    addi x4, x0, 1
    loopi 16, 16
        bn.lid         x0, 0(t0++) /* x[1] */
        bn.subv.16h    w2, w0, w30
        addi           t2, t1, 0
        /* v[0]: also add x[1] before storing. */
        bn.lid       x4, 0(t1) /* v[0] */
        bn.and       w3, w1, w2
        bn.shv.16h   w3, w3 << 1
        bn.subvm.16h w1, w3, w1
        bn.addvm.16h w1, w0, w1
        bn.sid       x4, 0(t1)
        addi         t1, t1, 512 /* Point to v[1]. */
        /* v[1]. */
        bn.lid       x4, 0(t1) /* v[1] */
        bn.and       w3, w1, w2
        bn.shv.16h   w3, w3 << 1
        bn.subvm.16h w1, w3, w1
        bn.sid       x4, 0(t1)
        addi t1, t2, 32
    endloop

    /* Final refresh: r = refreshmodq(v). */
    addi a0, sp, 0 /* ptr_v */
    addi a2, s2, 0 /* ptr_r */
    jal  x1, refreshmodq

    /* Restore registers and frame. */
    lw   s0, 1024(sp)
    lw   s2, 1028(sp)
    addi sp, sp, 1056
    ret

/*
 * Name: secb2amodq
 *
 * Return arithmetic shares mod q = 3329 of x, given its Boolean shares mod 2^k,
 * with k = 12 (q < 2**k).
 * Bitsliced.
 *
 *   rand <- poly_rej_samp()      uniform polynomial mod q
 *   zp   <- q - rand
 *   a    <- seca2bmodq(zp)
 *   b    <- secaddmodq(a, x)
 *   c    <- refreshios(b)
 *   r    <- (rand, unmask(c))
 *
 * Source: Alg.11 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[out] x12: dptr_r, dmem pointer to the output arithmetic shares of r
 *
 * clobbered registers: x2, x4 to x8, x10 to x21, x28 to x31, w0 to w16, w28 to w30, acch, acc
 * clobbered flag groups: FG0
 */
.globl secb2amodq
.type secb2amodq, @function
secb2amodq:
    /* Frame (2656 B, 2 shares):
     *   sp +    0 : saved s0, s2, s3, s4, s5
     *   sp +   32 : ptr_zp / scratch (1024 B)
     *   sp + 1056 : ptr_s            ( 832 B)
     *   sp + 1888 : ptr_a, ptr_b, ptr_c (bitsliced, 768 B) */
    addi sp, sp, -2048
    addi sp, sp, -608
    sw s0, 0(sp)
    sw s2, 4(sp)
    sw s3, 8(sp)
    sw s4, 12(sp)
    sw s5, 16(sp)

    /* Save input/output addresses and buffer bases. */
    addi s0, a0, 0 /* ptr_x */
    addi s2, a2, 0 /* ptr_r */
    addi s3, sp, 1888 /* ptr_a, ptr_b, ptr_c (bitsliced) */
    addi s4, sp, 1056 /* ptr_s */
    /* ptr_zp = sp + 32 */

    /* Sample rand, then compute zp = q - rand. */
    addi    x4, x0, 30
    la      t0, modulus_bn
    bn.lid  x4, 0(t0)
    addi    a0, a2, 0 /* ptr_r */
    addi    t2, sp, 32 /* ptr_zp */
    bn.wsrr w16, mod
    jal x1, poly_rej_samp
    loopi 16, 3
        bn.lid      x0, 0(a2++)
        bn.subv.16h w0, w30, w0 /* Since inputs are < q, we need to only use bn.subv. */
        bn.sid      x0, 0(t2++)
    endloop

    /* Bitslice share 0 of zp; the last share (bitsliced) is cleared below. */
    addi a0, sp, 32 /* ptr_zp */
    addi a1, s3, 0 /* ptr_zp (bitsliced) */
    jal  x1, poly_to_bitsliced
    addi a1, a1, 384
    /* Clear the last share of zp (bitsliced). */
    bn.xor w0, w0, w0
    loopi 12, 1
        bn.sid x0, 0(a1++)
    endloop

    /* Compute a = seca2bmodq(zp). */
    addi a0, s3, 0 /* ptr_zp (bitsliced) */
    addi a2, s3, 0 /* ptr_a */
    jal  x1, seca2bmodq

    /* Compute b = secaddmodq(a, x). */
    /* Inline secaddmodq. */
    /* Compute s = secadd(a, x, k + 1). */
    /* Initialize c = 0. */
    bn.xor w0, w0, w0
    addi   t0, s4, 384 /* ptr_c */
    loopi 2, 2
        bn.sid x0, 0(t0)
        addi   t0, t0, 416
    endloop

    /* Ripple-carry adder. */
    addi a0, s3, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, s0, 0 /* ptr_x */
    addi a3, x0, 384
    addi a5, s4, 0 /* ptr_s */
    addi a6, x0, 416
    addi a7, s4, 384 /* ptr_c = cin */
    addi t4, x0, 416
    addi t5, s4, 384 /* ptr_c = cout */
    addi t6, x0, 416
    /* Loop over i=1,...,k-1. */
    loopi 12, 2
        /* a0 already points to x[i] */
        /* a1 is already share stride of x. */
        /* a2 already points to y[i] */
        /* a3 is already share stride of y. */
        /* a5 already points to r. */
        /* a6 is already share stride of r. */
        /* a7 already points to ptr_c = cin. */
        /* t4 is already share stride of cin. */
        /* t5 already points to ptr_c = cout. */
        /* t6 is already share stride of cout. */
        jal  x1, secfulladder
        /* After secfulladder:
         *  - a0 and a2 points to x[i + 1] and y[i + 1].
         *  - a1 and a3 are still share stride of x and y.
         *  - a5 points to r[i + 1].
         *  - a6 is still share stride of r.
         *  - a7 points to cin.
         *  - t4 is still share stride of cin.
         *  - t5 points to cout.
         *  - t6 is still share stride of cout. */
        nop
    endloop
    /* Bit i = k + 1 is already x[k + 1] ^ y[k + 1] ^ c = cout since x[k + 1] = y[k + 1] = 0. */

    /* Compute s = secadd(s, p, k + 1) where p = 2**(k + 1) - q = 4863 = b1001011111111. */
    /* Initialize c = 0. */
    addi   t0, sp, 32 /* ptr_c */
    bn.xor w0, w0, w0
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop
    addi s5, t0, 0 /* ptr_p */

    addi    t0, s5, 0 /* ptr_p */
    bn.subi w1, w0, 1
    addi    x4, x0, 1
    bn.sid  x4, 0(t0++)
    bn.sid  x0, 0(t0++)

    addi a0, s5, 0 /* ptr_p */
    addi a1, x0, 32
    addi a2, s4, 0 /* ptr_s */
    addi a3, x0, 416
    addi a5, s4, 0 /* ptr_s */
    addi a6, x0, 416
    addi a7, sp, 32 /* cin */
    addi t4, x0, 32
    addi t5, sp, 32 /* cout */
    addi t6, x0, 32
    /* Bit 0 -- 7: p = 1. */
    loopi 8, 2
        jal  x1, secfulladder
        addi a0, a0, -32 /* Reset a0 to ptr_p. */
    endloop

    /* Bit 8: p = 0. */
    bn.xor w0, w0, w0
    bn.sid x0, 0(a0)
    addi   a0, s5, 0
    jal    x1, secfulladder
    /* Bit 9: p = 1. */
    bn.xor  w0, w0, w0
    bn.subi w0, w0, 1
    addi    a0, s5, 0
    bn.sid  x0, 0(a0)
    jal     x1, secfulladder
    /* Bit 10 -- 11: p = 0. */
    bn.xor w0, w0, w0
    addi   a0, s5, 0
    bn.sid x0, 0(a0)
    jal    x1, secfulladder
    addi   a0, s5, 0
    jal    x1, secfulladder

    /* Bit 12: p = 1. */
    /* Compute r[12] = p[12] ^ s[12] ^ c = ~(s[12] ^ c) since p[12] = 1. */
    addi x4, x0, 1
    addi t1, x0, 2
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    /* Computation. */
    bn.lid x0, 0(a2)
    bn.lid x4, 0(a7)
    bn.xor w3, w0, w1
    bn.not w2, w3
    bn.sid t1, 0(a2)
    add    a2, a2, a3
    add    a7, a7, t4

    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    /* Computation. */
    bn.lid x0, 0(a2)
    bn.lid x4, 0(a7)
    bn.xor w2, w0, w1
    bn.sid t1, 0(a2)

    /* Compute a = bitcopymask(s[k], (k + 1) * 32). */
    addi a0, s4, 384 /* ptr_s[k] */
    addi a1, x0, 416 /* share_str = (k + 1) * 32 */
    addi a3, s3, 0 /* ptr_a */
    jal  x1, bitcopymask

    /* Compute r = secadd(a, s, k). */
    addi a0, s3, 0 /* ptr_a */
    addi a1, x0, 384
    addi a2, s4, 0 /* ptr_s */
    addi a3, x0, 416
    addi a5, s3, 0 /* ptr_b */
    addi a6, x0, 384
    addi a7, x0, 12 /* k */
    jal  x1, secadd
    /* End inlining secaddmodq. */

    /* Compute c = refreshios(b, k, k * 32). */
    addi a0, s3, 0 /* ptr_b */
    addi a1, x0, 12 /* k */
    addi a2, x0, 384 /* k * 32 */
    addi a4, s3, 0 /* ptr_c */
    jal  x1, refreshios

    /* Unmask c. */
    addi t0, s3, 0 /* ptr_c */
    addi x4, x0, 1
    loopi 12, 5
        addi   t1, t0, 384
        bn.lid x0, 0(t0)
        bn.lid x4, 0(t1)
        bn.xor w0, w0, w1
        bn.sid x0, 0(t0++)
    endloop

    /* Convert c from bitsliced to normal representation, into share 1. */
    addi a0, s3, 0 /* ptr_c */
    addi a1, s2, 0 /* ptr_r */
    addi a1, a1, 512 /* r[1] */
    jal x1, poly_from_bitsliced

    /* Restore registers. */
    lw s0, 0(sp)
    lw s2, 4(sp)
    lw s3, 8(sp)
    lw s4, 12(sp)
    lw s5, 16(sp)
    addi sp, sp, 2047
    addi sp, sp, 609
    ret

/*
 * Name: poly_hocompress
 *
 * Return Boolean shares of Compressq(x, d) = round((2^d / q) * x) mod 2^d for
 * d in {4, 5}, given arithmetic shares mod q of x. Bitsliced.
 *
 * Each share is compressed to d + alpha bits, recombined (seca2b), then the low
 * alpha bits dropped. The alpha extra bits absorb the per-share rounding error
 * (2^alpha > q * nshares); nshares = 2 gives d + alpha = 18 (alpha = 13 for
 * d = 5, 14 for d = 4).
 *
 *   z[0] <- Compressq(x[0], d + alpha) + 2^(alpha - 1)
 *   z[1] <- Compressq(x[1], d + alpha)
 *   c    <- seca2b(z[0], z[1])
 *   r    <- c >> alpha
 *
 * Source: Alg.2 [CGMZ21b]
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input arithmetic shares of x
 * @param[in]  x11: indicates du or dv (0: dv, 1: du)
 * @param[out] x12: dptr_rb, dmem pointer to the bitsliced compressed output
 * @param[in]  x13: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x2 to x19, x28 to x31, w0 to w15, w17 to w21, w28 to w29
 * clobbered flag groups: FG0
 */

.globl poly_hocompress
.type poly_hocompress, @function
poly_hocompress:
    /* Allocate y[0], y[1] scratch and save callee-saved registers. */
    addi sp, sp, -1024
    add  t2, sp, x0
    addi sp, sp, -1184
    sw   s1, 1152(sp)
    sw   s2, 1156(sp)
    sw   s3, 1160(sp)
    addi s1, a2, 0

    /* Load all constants. */
    addi      x4, x0, 17
    la        t0, const_m_dv
    bn.lid    x4++, 0(t0)
    la        t0, modulus_over_2
    bn.lid    x4++, 0(t0)
    bn.shv.8s w18, w18 >> 16

    /* Create 1-bit mask and 2**(alpha - 1). */
    bn.subi   w19, w31, 1
    bn.shv.8s w19, w19 >> 31
    bn.shv.8s w19, w19 << 12  /* alpha - 1 */

    /* Select alpha-dependent parameters: w3 = 2**(alpha - 1), s2 = the
     * extraction byte offset alpha * 32, s3 = dv. */
    addi      x4, x0, 4
    addi      s2, x0, 416  /* alpha * 32, alpha = 13 */
    addi      s3, x0, 5
    beq       a3, x4, _dv_params_done
    bn.shv.8s w19, w19 << 1
    addi      s2, x0, 448  /* alpha * 32, alpha = 14 (k != 4) */
    addi      s3, x0, 4
_dv_params_done:

    addi t1, sp, 0 /* ptr_z */
    addi t3, t1, 512 /* Skip the first 16 bits. */

    /* For DV in {4,5}, in order to avoid division by Q, we need to compute:
     *  - x << (DV + ALPHA) --> x is maximum 20 bits.
     *  - x += 1665
     *  - x *=m where m = ((1 << 37) + Q // 2) // Q = 41285357 (m is 26 bits).
     *  - x >>= k where k = 37.
     *  - x &= ((1 << (DV + ALPHA)) - 1).
     * where 37 is the smallest integer that makes this algorithm equivalent to
     * the division by Q.
     *
     * Now for the first share, for performance reason after the step above, we
     * want to also compute + 2**(ALPHA - 1) before saving the results to
     * memory. This would result in two more bn.addv.8s instructions compared
     * to the other shares. In order to reduce code size, we want the
     * computation of the first share to be identical to subsequent shares. We
     * realize that if k = 40, after the taking the high parts of the 64-bit
     * products of x * m, we need to shift 8 bits more, instead of 5 bits.
     * This shift of a multiple of 8 bits helps us to merge the final shift by
     * 5 bits with the addition of 2**(alpha - 1) by using bn.add instead of
     * bn.shv.8s and bn.addv.8s. Since alpha = 13 or 14, and (x * m) >> 40 is
     * of size 19 bits, their sum is maximum 20 bits, which doesn't overflow
     * 32-bit slot, ensuring that the addition with bn.add is equivalent to the
     * vector addition with bn.addv.8s. This is for the first share.
     *
     * For subsequent shares, we only need to add (x * m) >> k with 0 with
     * bn.add to make it a shift, thus reusing the same code for all the shares.
     */

    /* Compute z[0] = Compressq(x[0], dv + alpha) + 2**(alpha - 1). */
    loopi 2, 58
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        bn.xor w4, w4, w4
        bn.xor w5, w5, w5
        bn.xor w6, w6, w6
        bn.xor w7, w7, w7
        bn.xor w8, w8, w8
        bn.xor w9, w9, w9
        bn.xor w10, w10, w10
        bn.xor w11, w11, w11
        bn.xor w12, w12, w12
        bn.xor w13, w13, w13
        bn.xor w14, w14, w14
        bn.xor w15, w15, w15
        bn.xor w20, w20, w20
        bn.xor w21, w21, w21
        bn.xor w28, w28, w28
        bn.xor w29, w29, w29

        addi x4, x0, 15
        loopi 16, 18  /* 16 WDRs hold the 256 coeffs */
            bn.lid             x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h        w20, w0, w31
            bn.shv.8s          w20, w20 << 18
            bn.addv.8s         w20, w20, w18
            bn.mulv.8s.even.hi w20, w20, w17
            bn.mulv.8s.odd.hi  w20, w20, w17
            bn.add             w21, w19, w20 >> 8
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h        w20, w0, w31
            bn.shv.8s          w20, w20 << 18
            bn.addv.8s         w20, w20, w18
            bn.mulv.8s.even.hi w20, w20, w17
            bn.mulv.8s.odd.hi  w20, w20, w17
            bn.add             w20, w19, w20 >> 8
            /* Combine the results before bitslicing. */
            bn.trn2.16h        w0, w21, w20
            bn.sid             x0, 0(t2++)
            bn.trn1.16h        w0, w21, w20
            bn.movr            x4, x0
            addi               x4, x4, -1
        endloop

        /* For the first share, w19 is 2**(alpha - 1). After that, we need to
         * clear w19 so that bn.add acts as a shift. */
        bn.xor w19, w19, w19

        /* Bitslice the first 16 bits. */
        jal x1, _bitslice_transpose

        add x4, x0, x0
        loopi 16, 2
            bn.sid x4, 0(t1++)
            addi   x4, x4, 1
        endloop
        addi t1, t1, 64 /* Skip the last 2 bits. */

        /* Bitslice the last 2 bits. */
        addi x4, x0, 15
        addi t2, t2, -512
        loopi 16, 2
            bn.lid x4, 0(t2++)
            addi   x4, x4, -1
        endloop

        jal x1, _bitslice_transpose

        add x4, x0, x0
        loopi 2, 2
            bn.sid x4, 0(t3++)
            addi   x4, x4, 1
        endloop
        addi t3, t3, 512 /* Skip the first 16 bits. */
    endloop

    /* Compute c = seca2b(z), k = dv + alpha, share bytes = 576. */
    addi a0, sp, 0 /* ptr_z */
    addi a1, x0, 18 /* dv + alpha */
    addi a2, x0, 576
    addi a4, sp, 0 /* ptr_c */
    jal  x1, seca2b

    /* Compute r = c >> alpha: keep the bits c[alpha]...c[alpha + dv]. */
    addi t0, sp, 0 /* ptr_c */
    add  t0, t0, s2
    addi t1, s1, 0 /* ptr_r */
    loopi 2, 5
        loop s3, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        endloop
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, s2
    endloop

    /* Restore registers. */
    lw   s1, 1152(sp)
    lw   s2, 1156(sp)
    lw   s3, 1160(sp)
    addi sp, sp, 1184
    addi sp, sp, 1024
    ret

/*
 * Name: polyvec_hocompress
 *
 * Return Boolean shares of Compressq(x, d) = round((2^d / q) * x) mod 2^d for
 * d in {10, 11}, given arithmetic shares mod q of x. Bitsliced.
 *
 * Each share is compressed to d + alpha bits, recombined (seca2b), then the low
 * alpha bits dropped. The alpha extra bits absorb the per-share rounding error
 * (2^alpha > q * nshares); nshares = 2 gives d + alpha = 24 (alpha = 13 for
 * d = 11, 14 for d = 10).
 *
 *   z[0] <- Compressq(x[0], d + alpha) + 2^(alpha - 1)
 *   z[1] <- Compressq(x[1], d + alpha)
 *   c    <- seca2b(z[0], z[1])
 *   r    <- c >> alpha
 *
 * Source: Alg.2 [CGMZ21b]
 *
 * @param[in]  x10: dptr_xb, dmem pointer to the input arithmetic shares of x
 * @param[out] x12: dptr_rb, dmem pointer to the bitsliced compressed output
 * @param[in]  x13: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x2 to x19, x28 to x31, w0 to w15, w17 to w21, w28 to w30, acc
 * clobbered flag groups: FG0
 */
.globl polyvec_hocompress
.type polyvec_hocompress, @function
polyvec_hocompress:
    /* Allocate y[0], y[1] scratch and save callee-saved registers. */
    addi sp, sp, -1024
    add  t2, sp, x0
    addi sp, sp, -1568
    sw   s1, 1536(sp)
    sw   s2, 1540(sp)
    sw   s3, 1544(sp)
    addi s1, a2, 0

    /* Create 2**(alpha - 1). */
    bn.subi   w30, w31, 1
    bn.shv.8s w30, w30 >> 31
    bn.shv.8s w30, w30 << 12  /* alpha - 1 */

    /* Select alpha-dependent parameters: s2 = the extraction byte offset
     * alpha * 32, s3 = du. The in-loop computation of 2**(alpha - 1)
     * branches on a3 (k) directly. */
    addi      x4, x0, 4
    addi      s2, x0, 416  /* alpha * 32, alpha = 13 */
    addi      s3, x0, 11
    beq       a3, x4, _du_params_done
    bn.shv.8s w30, w30 << 1
    addi      s2, x0, 448  /* alpha * 32, alpha = 14 (k != 4) */
    addi      s3, x0, 10
_du_params_done:

    /* Load all constants. */
    addi       x4, x0, 17
    la         t0, const_m_du
    bn.lid     x4++, 0(t0)

    la         t0, const_1664
    bn.lid     x4, 0(t0)

    /* Adjust space for temporary variable y. */
    addi t0, x0, 21
    addi t1, sp, 0 /* ptr_z */
    addi t3, t1, 512 /* Skip the first 16 bits. */

    loopi 2, 85
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        bn.xor w4, w4, w4
        bn.xor w5, w5, w5
        bn.xor w6, w6, w6
        bn.xor w7, w7, w7
        bn.xor w8, w8, w8
        bn.xor w9, w9, w9
        bn.xor w10, w10, w10
        bn.xor w11, w11, w11
        bn.xor w12, w12, w12
        bn.xor w13, w13, w13
        bn.xor w14, w14, w14
        bn.xor w15, w15, w15
        bn.xor w19, w19, w19
        bn.xor w20, w20, w20
        bn.xor w21, w21, w21
        bn.xor w28, w28, w28
        bn.xor w29, w29, w29

        addi x4, x0, 15
        loopi 16, 44  /* 16 WDRs hold the 256 coeffs */
            bn.lid           x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h      w19, w0, w31
            /* Handle coeff[0] - coeff[4] - coeff[8] - coeff[12]. */
            bn.trn1.8s      w20, w19, w31
            bn.rshi         w20, w20, w31 >> 232
            bn.add          w20, w20, w18
            bn.mulqacc.so.z w21.l, w20.0, w17.0, 0
            bn.mulqacc.so.z w21.u, w20.2, w17.0, 0
            bn.mulqacc.so.z w20.l, w20.1, w17.0, 0
            bn.mulqacc.so.z w20.u, w20.3, w17.0, 0
            bn.trn2.4d      w20, w21, w20
            /* Handle coeff[2] - coeff[6] - coeff[10] - coeff[14]. */
            bn.trn2.8s      w19, w19, w31
            bn.rshi         w19, w19, w31 >> 232
            bn.add          w19, w19, w18
            bn.mulqacc.so.z w21.l, w19.0, w17.0, 0
            bn.mulqacc.so.z w21.u, w19.2, w17.0, 0
            bn.mulqacc.so.z w19.l, w19.1, w17.0, 0
            bn.mulqacc.so.z w19.u, w19.3, w17.0, 0
            bn.trn2.4d      w19, w21, w19
            /* Combine the result. */
            bn.trn1.8s      w19, w20, w19

            /* Handle odd-positioned coeffs. */
            bn.trn2.16h     w0, w0, w31
            /* Handle coeff[1] - coeff[5] - coeff[9] - coeff[13]. */
            bn.trn1.8s      w20, w0, w31
            bn.rshi         w20, w20, w31 >> 232
            bn.add          w20, w20, w18
            bn.mulqacc.so.z w21.l, w20.0, w17.0, 0
            bn.mulqacc.so.z w21.u, w20.2, w17.0, 0
            bn.mulqacc.so.z w20.l, w20.1, w17.0, 0
            bn.mulqacc.so.z w20.u, w20.3, w17.0, 0
            bn.trn2.4d      w20, w21, w20
            /* Handle coeff[3] - coeff[7] - coeff[11] - coeff[15]. */
            bn.trn2.8s      w0, w0, w31
            bn.rshi         w0, w0, w31 >> 232
            bn.add          w0, w0, w18
            bn.mulqacc.so.z w21.l, w0.0, w17.0, 0
            bn.mulqacc.so.z w21.u, w0.2, w17.0, 0
            bn.mulqacc.so.z w0.l, w0.1, w17.0, 0
            bn.mulqacc.so.z w0.u, w0.3, w17.0, 0
            bn.trn2.4d      w0, w21, w0
            /* Combine the result. */
            bn.trn1.8s      w20, w20, w0
            /* Compute + 2**(alpha - 1) mod 2**(du + alpha); w30 holds
            * 2**(alpha - 1) for the alpha selected per K. Then turn w31 into
            * the per-lane bit mask for the bitslice helper below; it is zeroed
            * again at the end of the loop body. */
            bn.addv.8s      w19, w19, w30
            bn.addv.8s      w20, w20, w30
            /* Combine the results before bitslicing. */
            bn.trn1.16h     w21, w19, w20
            bn.movr         x4, t0
            addi            x4, x4, -1
            bn.trn2.16h     w21, w19, w20
            bn.sid          t0, 0(t2++)
        endloop

        /* Clear w30. */
        bn.xor w30, w30, w30

        /* Bitslice the first 16 bits. */
        jal x1, _bitslice_transpose

        add x4, x0, x0
        loopi 16, 2
            bn.sid x4, 0(t1++)
            addi   x4, x4, 1
        endloop
        addi t1, t1, 256 /* Skip the last 8 bits. */

        /* Bitslice the last 8 bits. */
        addi x4, x0, 15
        addi t2, t2, -512
        loopi 16, 2
            bn.lid x4, 0(t2++)
            addi   x4, x4, -1
        endloop

        jal x1, _bitslice_transpose

        add x4, x0, x0
        loopi 8, 2
            bn.sid x4, 0(t3++)
            addi   x4, x4, 1
        endloop
        addi t3, t3, 512 /* Skip the first 16 bits. */
    endloop

    /* Compute c = seca2b(z), k = du + alpha, share bytes = 768. */
    addi a0, sp, 0 /* ptr_z */
    addi a1, x0, 24 /* du + alpha */
    addi a2, x0, 768
    addi a4, sp, 0 /* ptr_c */
    jal  x1, seca2b

    /* Compute r = c >> alpha: keep the bits c[alpha]...c[alpha + du]. */
    addi t0, sp, 0 /* ptr_c */
    add  t0, t0, s2
    addi t1, s1, 0 /* ptr_r */
    loopi 2, 5
        loop s3, 3
            /* Whitening. */
            bn.xor w0, w0, w0
            bn.lid x0, 0(t0++)
            bn.sid x0, 0(t1++)
        endloop
        /* After copy DV bits of z to r, we need to adjust address of z again. */
        add t0, t0, s2
    endloop

    /* Restore registers. */
    lw   s1, 1536(sp)
    lw   s2, 1540(sp)
    lw   s3, 1544(sp)
    addi sp, sp, 1568
    addi sp, sp, 1024
    ret

/*
 * Name: onebitdecompress
 *
 * Given Boolean shares of a 32-byte message m, return arithmetic shares
 * mod q = 3329 of mp = Decompress_q(m, 1): coefficient i is (q + 1) / 2
 * if bit i of m is set, else 0. Vectorized for a polynomial.
 *
 *   m  <- unpack(m)                ; one message bit per coefficient
 *   mp <- seconebitb2amodq(m)      ; Boolean to arithmetic shares mod q
 *   mp <- mp * (q + 1) / 2   mod q
 *
 * Source: Section 3.3 [BGR+21]
 *
 * @param[in]  w16: R | Q
 * @param[in]  x10: dptr_m, dmem pointer to Boolean shares of m (bitsliced)
 * @param[in]  w31: all-zero register
 * @param[out] x12: dptr_mp, dmem pointer to arithmetic shares of mp
 *
 * clobbered registers: x2, x4 to x8, x10, x12, x18, x28, w0 to w5, w30, acch, acc
 * clobbered flag groups: FG0
 */
.globl onebitdecompress
.type onebitdecompress, @function
onebitdecompress:
    /* Save the output base pointer; reused as scratch across the call. */
    addi sp, sp, -32
    sw   s0, 0(sp)
    addi s0, a2, 0

    /* Unpack m, matching the bitslice layout from masked_poly_tomsg. */
    addi x4, x0, 1
    loopi 2, 7
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a0++)
        loopi 16, 3
            bn.shv.16h w1, w0 >> 15
            bn.shv.16h w0, w0 << 1
            bn.sid     x4, 0(a2++)
        endloop
        nop
    endloop

    /* mp = seconebitb2amodq(m), with w16 = R | Q. */
    addi a0, s0, 0 /* ptr_m */
    addi a2, s0, 0 /* ptr_r */
    jal  x1, seconebitb2amodq

    /* mp *= (q + 1) / 2 mod q, coefficient-wise (Montgomery). */
    la      t0, modulus_over_2_m2_16 /* ((Q + 1) / 2) * (2^16) % Q. */
    addi    x4, x0, 1
    bn.lid  x4, 0(t0)
    loopi 2, 9
        /* Whitening. */
        bn.xor w0, w0, w0
        loopi 16, 6
            bn.lid               x0, 0(s0)
            bn.mulv.16h.acc.z.lo w0, w0, w1
            bn.mulv.l.16h.lo     w0, w0, sw0.2
            bn.mulv.l.16h.acc.hi w0, w0, sw0.0
            bn.addvm.16h         w0, w0, w31
            bn.sid               x0, 0(s0++)
        endloop
        nop
    endloop

    /* Restore the output base pointer and stack. */
    lw   s0, 0(sp)
    addi sp, sp, 32
    ret

/*
 * Name: masked_cbd
 *
 * Return arithmetic shares mod q = 3329 of the centered binomial sample
 * r = HW(x) - HW(y), given Boolean shares of the eta-bit values x and y.
 * Since HW(y) = eta - HW(~y), this sums the 2 * eta bit-planes of x and ~y.
 * k = 12 (q < 2**k). Bitsliced.
 *
 *   sum <- Hamming weight of (x, ~y) via a secfulladder tree
 *   r   <- secb2amodq(sum) - eta   mod q
 *
 * Source: Alg.17 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to Boolean shares of x
 * @param[in]  x11: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x12: eta
 * @param[out] x14: dptr_r, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: x2, x4 to x22, x28 to x31, w0 to w16, w28 to w30, acch, acc
 * clobbered flag groups: FG0
 */
.globl masked_cbd
.type masked_cbd, @function
masked_cbd:
    /* Frame: tmp at 0 (768 B), sum at 768 (64 B), s at 832 (384 B, sized for
     * the worst case eta = 3), saved registers at 1216. */
    addi sp, sp, -1248
    sw s0, 1216(sp)
    sw s1, 1220(sp)
    sw s2, 1224(sp)
    sw s4, 1228(sp)
    sw s5, 1232(sp)
    sw s6, 1236(sp)

    /* Save input/output addresses and set the scratch pointers. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s4, a4, 0
    addi s5, sp, 832 /* ptr_s */
    addi s6, sp, 768 /* ptr_sum */

    /* Copy x to s[1,..,eta] and ~y to s[eta + 1,..,2 * eta]. */
    addi t0, s5, 0 /* ptr_s */
    slli x4, a2, 5 /* eta * 32 */
    add  t1, s5, x4 /* ptr_s[eta + 1] */
    /* Share 0: copy x[0] and ~y[0]. */
    loop a2, 7
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Copy x[0]. */
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t0++)
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Copy ~y[0]. */
        bn.lid x0, 0(a1++)
        bn.not w0, w0
        bn.sid x0, 0(t1++)
    endloop
    add t0, t0, x4
    add t1, t1, x4
    /* Share 1: copy x[1] and y[1]. */
    loop a2, 6
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Copy x[1]. */
        bn.lid x0, 0(a0++)
        bn.sid x0, 0(t0++)
        /* Whitening. */
        bn.xor w0, w0, w0
        /* Copy y[1]. */
        bn.lid x0, 0(a1++)
        bn.sid x0, 0(t1++)
    endloop

    /* We need to loop over i = 1,...,k where k = ceil(log2(l + 1)) = 3 for both
     * eta = 2 and eta = 3. Then the inner loop is over j = 1,...,l where
     * l >>= i, so j is in {eta, eta/2, eta/4}, i.e., {2, 1, 0} for eta = 2 and
     * {3, 1, 0} for eta = 3. Thus, in the third iteration i = k, the inner loop
     * is not executed at all. */
    /*----------------------- Iteration i = 1, l = 2 * eta -----------------------*/
    /* Since l mod 2 = 0, we clear the carry sum. */
    addi   t0, s6, 0 /* ptr_sum */
    bn.xor w0, w0, w0
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop

    /* l >>= 1: loop j = 1,..., l = 1,...,eta. */
    /* Inputs to secfulladder. */
    slli t0, a2, 6 /* (2 * eta) * 32 */
    addi a0, s5, 0 /* s[0] */
    addi a1, t0, 0
    addi a2, s5, 32 /* s[1] */
    addi a3, t0, 0
    addi a5, s6, 0 /* ptr_sum = r */
    addi a6, x0, 32
    addi a7, s6, 0 /* ptr_sum = cin */
    addi t4, x0, 32
    addi t5, s5, 0 /* s[0] = cout */
    addi t6, t0, 0
    loop s2, 5
        /* Compute c, s[j] = secfulladder(s[2j], s[2j + 1], c). */
        /* a0 already points to s[2j] */
        /* a1 is already share stride of s. */
        /* a2 already points to s[2j + 1] */
        /* a3 is already share stride of s. */
        /* a5 already points to sum = r. */
        /* a6 is already share stride of sum = r. */
        /* a7 already points to sum = cin. */
        /* t4 is already share stride of sum = cin. */
        /* t5 already points to s[j] = cout. */
        /* t6 is already share stride of s = cout. */
        jal  x1, secfulladder
        /* After secfulladder:
        *  - a0 and a2 points to s[2j + 1] and s[2j + 2] --> need to be adjusted.
        *  - a1 and a3 are still share stride of s.
        *  - a5 points to sum + 32 (output) --> need to be adjusted to sum.
        *  - a6 is still share stride of sum.
        *  - a7 points to sum (cin).
        *  - t4 is still share stride of sum.
        *  - t5 points to s[j] (cout) --> need to be adjusted to s[j + 1].
        *  - t6 is still share stride of s. */
        /* Adjust addresses. */
        addi a0, a0, 32 /* s[2 * (j + 1)] */
        addi a2, a2, 32 /* s[2 * (j + 1) + 1] */
        addi a5, a5, -32 /* sum */
        addi t5, t5, 32 /* s[j + 1] */
    endloop

    /* Copy sum to ptr_tmp[1]. */
    addi t0, sp, 0 /* ptr_tmp[1] */
    loopi 2, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a5++) /* a5 still points to sum. */
        bn.sid x0, 0(t0)
        addi   t0, t0, 384
    endloop

    /*----------------------- Iteration i = 2, l = eta -----------------------*/
    addi t0, x0, 2
    beq  s2, t0, _cbd_eta_2
    /* Since l mod 2 = 1 if eta = 3, we compute sum = s[l] = s[3]. */
    addi t0, s6, 0 /* ptr_sum */
    addi t1, s5, 0 /* ptr_s */
    addi t1, t1, 64 /* 2 * 32 */
    slli x4, s2, 6 /* (2 * eta) * 32 */
    loopi 2, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t1)
        bn.sid x0, 0(t0++)
        add    t1, t1, x4
    endloop
    beq x0, x0, _continue_1

_cbd_eta_2:
    /* Since l mod 2 = 0 if eta = 2, we clear the carry sum. */
    addi   t0, s6, 0 /* ptr_sum */
    bn.xor w0, w0, w0
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop

_continue_1:
    /* l >> 1: loop j = 1,...,l // 2 --> 1 iteration. */
    /* Inputs to secfulladder. */
    slli t0, s2, 6
    addi a0, s5, 0 /* s[0] */
    addi a1, t0, 0
    addi a2, s5, 32 /* s[1] */
    addi a3, t0, 0
    addi a5, s6, 0 /* ptr_sum = r */
    addi a6, x0, 32
    addi a7, s6, 0 /* ptr_sum = cin */
    addi t4, x0, 32
    addi t5, s5, 0 /* s[0] = cout */
    addi t6, t0, 0
    /* Compute c, s[j] = secfulladder(s[2j], s[2j + 1], c). */
    /* a0 already points to s[2j] */
    /* a1 is already share stride of s. */
    /* a2 already points to s[2j + 1] */
    /* a3 is already share stride of s. */
    /* a5 already points to sum = r. */
    /* a6 is already share stride of sum = r. */
    /* a7 already points to sum = cin. */
    /* t4 is already share stride of sum = cin. */
    /* t5 already points to s[j] = cout. */
    /* t6 is already share stride of s = cout. */
    jal  x1, secfulladder
    /* After secfulladder:
    *  - a0 and a2 points to s[2j + 1] and s[2j + 2] --> need to be adjusted.
    *  - a1 and a3 are still share stride of s.
    *  - a5 points to sum + 32 (output) --> need to be adjusted to sum.
    *  - a6 is still share stride of sum.
    *  - a7 points to sum (cin).
    *  - t4 is still share stride of sum.
    *  - t5 points to s[j] (cout) --> need to be adjusted to s[j + 1].
    *  - t6 is still share stride of s. */

    /* Copy sum to ptr_tmp[2]. */
    addi t0, sp, 32 /* ptr_tmp[2] */
    loopi 2, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(a7++) /* a7 still points to sum. */
        bn.sid x0, 0(t0)
        addi   t0, t0, 384
    endloop

    /*----------------------- Iteration i = 3, l = eta / 2 -----------------------*/
    /* Since l mod 2 = 1, we compute tmp[3] = s[l] = s[1]. */
    addi t0, sp, 0 /* ptr_tmp */
    addi t0, t0, 64
    addi t1, s5, 0 /* ptr_s */
    slli t2, s2, 6

    loopi 2, 5
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t1)
        bn.sid x0, 0(t0)
        add    t1, t1, t2
        addi   t0, t0, 384
    endloop

    /* Clear bit k --> 12 of tmp. */
    addi   t0, sp, 0 /* ptr_tmp */
    addi   t0, t0, 96
    bn.xor w0, w0, w0
    loopi 2, 3
        loopi 9, 1
            bn.sid x0, 0(t0++)
        endloop
        addi t0, t0, 96 /* point to next share. */
    endloop

    /* Compute r = secb2amodq(tmp). */
    addi a0, sp, 0 /* ptr_tmp */
    addi a2, s4, 0 /* ptr_r */
    jal  x1, secb2amodq

    /* Compute r[0] = r[0] - eta mod q. */
    addi   t0, s4, 0 /* ptr_r */
    addi   t1, s5, 0 /* ptr_s */
    sw     s2, 0(t1)
    bn.lid x0, 0(t1)
    loopi 16, 1
        bn.rshi w1, w0, w1 >> 16
    endloop
    loopi 16, 3
        bn.lid       x0, 0(t0)
        bn.subvm.16h w0, w0, w1
        bn.sid       x0, 0(t0++)
    endloop

    /* Restore registers and stack. */
    lw s0, 1216(sp)
    lw s1, 1220(sp)
    lw s2, 1224(sp)
    lw s4, 1228(sp)
    lw s5, 1232(sp)
    lw s6, 1236(sp)
    addi sp, sp, 1248
    ret


/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA

/*
 * Name: masked_poly_getnoise_eta_init
 *
 * Initialize a SHAKE-256 operation for CBD noise sampling, absorbing the seed
 * and nonce. Call before masked_poly_getnoise_eta_1 or eta_2.
 *
 * @param[in]  x10: dptr_seed, dmem pointer to the seed
 * @param[in]  x11: dptr_nonce, dmem pointer to the nonce
 *
 * clobbered registers: x5 to x6, x10, w0
 * clobbered flag groups: FG0
 */
.globl masked_poly_getnoise_eta_init
.type masked_poly_getnoise_eta_init, @function
masked_poly_getnoise_eta_init:
    /* Initialize a SHAKE256 operation. */
    addi  t0, x0, 33
    slli  t0, t0, 5
    addi  t0, t0, SHAKE256_CFG
    addi  t1, x0, 1
    slli  t1, t1, 20
    add   t0, t0, t1
    csrrw x0, kmac_cfg, t0

    /* Send the message to the Keccak core. */
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.lid  x0, 0(a0++)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.lid  x0, 0(a0++)
    bn.wsrw kmac_msg1, w0
    li      t0, 1
    csrrw   x0, kmac_partial_write, t0
    bn.lid  x0, 0(a1)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.wsrw kmac_msg1, w0

    ret

/*
 * Name: masked_poly_getnoise_eta_2
 *
 * Sample a polynomial deterministically from a seed and a nonce, with output
 * polynomial close to centered binomial distribution with parameter KYBER_ETA2;
 * this function assumes `masked_poly_getnoise_eta_init` has been called first with the
 * appropriate seed and nonce.
 *
 * @param[in]  x10: eta
 * @param[in]  w31: all-zero register
 * @param[out] x11: ptr_ra, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: x2, x4 to x22, x28 to x31, w0 to w30, acch, acc
 * clobbered flag groups: FG0
 */
.globl masked_poly_getnoise_eta_2
.type masked_poly_getnoise_eta_2, @function
masked_poly_getnoise_eta_2:

/*
 * Name: masked_poly_getnoise_eta_1
 *
 * Sample a polynomial deterministically from a seed and a nonce, with output
 * polynomial close to centered binomial distribution with parameter KYBER_ETA1;
 * this function assumes `masked_poly_getnoise_eta_init` has been called first with the
 * appropriate seed and nonce.
 *
 * @param[in]  x10: eta
 * @param[in]  w31: all-zero register
 * @param[out] x11: ptr_ra, dmem pointer to arithmetic shares of r
 *
 * clobbered registers: x2, x4 to x22, x28 to x31, w0 to w30, acch, acc
 * clobbered flag groups: FG0
 */
.globl masked_poly_getnoise_eta_1
.type masked_poly_getnoise_eta_1, @function
masked_poly_getnoise_eta_1:
    /* Frame: ptr_y at 0, ptr_x at 192 (each 2 * eta * 32, sized for the worst
     * case eta = 3), saved registers at 384. */
    addi sp, sp, -416
    sw   s0, 384(sp)
    sw   s1, 388(sp)
    sw   s2, 392(sp)
    sw   s3, 396(sp)
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, sp, 192 /* ptr_x */

    addi x4, x0, 3
    bne  a0, x4, _getnoise_eta_2

    addi t0, sp, 0 /* ptr_y */

    bn.wsrr w17, kmac_digest
    bn.wsrr w23, kmac_digest1
    bn.wsrr w18, kmac_digest
    bn.wsrr w24, kmac_digest1
    bn.wsrr w19, kmac_digest
    bn.wsrr w25, kmac_digest1

    bn.wsrr w20, kmac_digest
    bn.wsrr w26, kmac_digest1
    bn.wsrr w21, kmac_digest
    bn.wsrr w27, kmac_digest1
    bn.wsrr w22, kmac_digest
    bn.wsrr w30, kmac_digest1

    jal x1, _bitslice_eta_3

    add x4, x0, x0
    loopi 3, 2
        bn.sid x4, 0(s2++)
        addi   x4, x4, 1
    endloop
    loopi 3, 2
        bn.sid x4, 0(t0++)
        addi   x4, x4, 1
    endloop

    bn.xor w17, w17, w17
    bn.mov w17, w23
    bn.xor w18, w18, w18
    bn.mov w18, w24
    bn.xor w19, w19, w19
    bn.mov w19, w25
    bn.xor w20, w20, w20
    bn.mov w20, w26
    bn.xor w21, w21, w21
    bn.mov w21, w27
    bn.xor w22, w22, w22
    bn.mov w22, w30

    jal x1, _bitslice_eta_3

    add x4, x0, x0
    loopi 3, 2
        bn.sid x4, 0(s2++)
        addi   x4, x4, 1
    endloop
    loopi 3, 2
        bn.sid x4, 0(t0++)
        addi   x4, x4, 1
    endloop

    beq  x0, x0, _getnoise_common

_getnoise_eta_2:

    bn.wsrr w17, kmac_digest
    bn.wsrr w21, kmac_digest1
    bn.wsrr w18, kmac_digest
    bn.wsrr w22, kmac_digest1
    bn.wsrr w19, kmac_digest
    bn.wsrr w23, kmac_digest1
    bn.wsrr w20, kmac_digest
    bn.wsrr w24, kmac_digest1

    addi t0, x0, 25
    addi t1, x0, 17
    addi t2, x0, 26
    addi t3, sp, 0 /* ptr_y */
    loopi 2, 38
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        bn.xor w4, w4, w4
        bn.xor w5, w5, w5
        bn.xor w6, w6, w6
        bn.xor w7, w7, w7
        bn.xor w8, w8, w8
        bn.xor w9, w9, w9
        bn.xor w10, w10, w10
        bn.xor w11, w11, w11
        bn.xor w12, w12, w12
        bn.xor w13, w13, w13
        bn.xor w14, w14, w14
        bn.xor w15, w15, w15
        bn.xor w25, w25, w25
        bn.xor w26, w26, w26
        bn.xor w28, w28, w28
        bn.xor w29, w29, w29

        addi x4, x0, 15
        loopi 4, 8
            bn.movr t0, t1
            loopi 4, 5
                loopi 16, 2
                    bn.rshi w26, w25, w26 >> 16
                    bn.rshi w25, w31, w25 >> 4
                endloop
                bn.movr x4, t2
                addi    x4, x4, -1
            endloop
            addi t1, t1, 1
        endloop

        jal x1, _bitslice_transpose

        bn.sid x0, 0(s2++)
        addi   x4, x0, 1
        bn.sid x4, 0(s2++)
        addi   x4, x4, 1
        bn.sid x4, 0(t3++)
        addi   x4, x4, 1
        bn.sid x4, 0(t3++)
    endloop

_getnoise_common:
    /* Compute r = masked_cbd(x, y, eta). */
    addi a0, sp, 192 /* ptr_x */
    addi a1, sp, 0 /* ptr_y */
    addi a2, s0, 0 /* eta */
    addi a4, s1, 0 /* ptr_r */
    jal  x1, masked_cbd

    /* Restore inputs. */
    addi a0, s0, 0
    /* We want to point r to the next polynomial for next cbd. */
    addi a1, s1, 512

    /* Restore registers and stack. */
    lw   s0, 384(sp)
    lw   s1, 388(sp)
    lw   s2, 392(sp)
    lw   s3, 396(sp)
    addi sp, sp, 416
    ret

/* Bitslice the SHAKE-256 digests in w17-w22 into the eta = 3 x and y
 * bit-planes for masked_cbd. Called by masked_poly_getnoise_eta_1 on the
 * KYBER_K == 2 path. */
_bitslice_eta_3:
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w4, w4, w4
    bn.xor w5, w5, w5
    bn.xor w6, w6, w6
    bn.xor w7, w7, w7
    bn.xor w8, w8, w8
    bn.xor w9, w9, w9
    bn.xor w10, w10, w10
    bn.xor w11, w11, w11
    bn.xor w12, w12, w12
    bn.xor w13, w13, w13
    bn.xor w14, w14, w14
    bn.xor w15, w15, w15
    bn.xor w28, w28, w28
    bn.xor w29, w29, w29

    loopi 16, 2
        bn.rshi w15, w17, w15 >> 16
        bn.rshi w17, w31, w17 >> 6
    endloop

    loopi 16, 2
        bn.rshi w14, w17, w14 >> 16
        bn.rshi w17, w31, w17 >> 6
    endloop

    loopi 10, 2
        bn.rshi w13, w17, w13 >> 16
        bn.rshi w17, w31, w17 >> 6
    endloop
    bn.rshi w13, w17, w13 >> 4
    bn.rshi w13, w18, w13 >> 12
    bn.rshi w18, w31, w18 >> 2
    loopi 5, 2
        bn.rshi w13, w18, w13 >> 16
        bn.rshi w18, w31, w18 >> 6
    endloop

    loopi 16, 2
        bn.rshi w12, w18, w12 >> 16
        bn.rshi w18, w31, w18 >> 6
    endloop

    loopi 16, 2
        bn.rshi w11, w18, w11 >> 16
        bn.rshi w18, w31, w18 >> 6
    endloop

    loopi 5, 2
        bn.rshi w10, w18, w10 >> 16
        bn.rshi w18, w31, w18 >> 6
    endloop
    bn.rshi w10, w18, w10 >> 2
    bn.rshi w10, w19, w10 >> 14
    bn.rshi w19, w31, w19 >> 4
    loopi 10, 2
        bn.rshi w10, w19, w10 >> 16
        bn.rshi w19, w31, w19 >> 6
    endloop

    loopi 16, 2
        bn.rshi w9, w19, w9 >> 16
        bn.rshi w19, w31, w19 >> 6
    endloop

    loopi 16, 2
        bn.rshi w8, w19, w8 >> 16
        bn.rshi w19, w31, w19 >> 6
    endloop

    loopi 16, 2
        bn.rshi w7, w20, w7 >> 16
        bn.rshi w20, w31, w20 >> 6
    endloop

    loopi 16, 2
        bn.rshi w6, w20, w6 >> 16
        bn.rshi w20, w31, w20 >> 6
    endloop

    loopi 10, 2
        bn.rshi w5, w20, w5 >> 16
        bn.rshi w20, w31, w20 >> 6
    endloop
    bn.rshi w5, w20, w5 >> 4
    bn.rshi w5, w21, w5 >> 12
    bn.rshi w21, w31, w21 >> 2
    loopi 5, 2
        bn.rshi w5, w21, w5 >> 16
        bn.rshi w21, w31, w21 >> 6
    endloop

    loopi 16, 2
        bn.rshi w4, w21, w4 >> 16
        bn.rshi w21, w31, w21 >> 6
    endloop

    loopi 16, 2
        bn.rshi w3, w21, w3 >> 16
        bn.rshi w21, w31, w21 >> 6
    endloop

    loopi 5, 2
        bn.rshi w2, w21, w2 >> 16
        bn.rshi w21, w31, w21 >> 6
    endloop
    bn.rshi w2, w21, w2 >> 2
    bn.rshi w2, w22, w2 >> 14
    bn.rshi w22, w31, w22 >> 4
    loopi 10, 2
        bn.rshi w2, w22, w2 >> 16
        bn.rshi w22, w31, w22 >> 6
    endloop

    loopi 16, 2
        bn.rshi w1, w22, w1 >> 16
        bn.rshi w22, w31, w22 >> 6
    endloop

    loopi 16, 2
        bn.rshi w0, w22, w0 >> 16
        bn.rshi w22, w31, w22 >> 6
    endloop

    jal x1, _bitslice_transpose
    ret

/* Undefine gadget-local macros. */
#undef SHAKE256_CFG

/*
 * Name: masked_poly_tomsg
 *
 * Return Boolean shares of Compressq(x, 1) = round((2 / q) * x) mod 2, the
 * one-bit message compression, given arithmetic shares mod q of x. Bitsliced.
 *
 * Each share is compressed to 1 + alpha bits, recombined (seca2b), then the low
 * alpha bits dropped. The alpha extra bits absorb the per-share rounding error
 * (2^alpha > q * nshares); nshares = 2 gives 1 + alpha = 16 (alpha = 15).
 *
 *   y[0] <- Compressq(x[0], 1 + alpha) + 2^(alpha - 1)
 *   y[1] <- Compressq(x[1], 1 + alpha)
 *   z    <- seca2b(y[0], y[1])
 *   r    <- z >> alpha
 *
 * Source: Alg.2 [CGMZ21b]
 *
 * @param[in]  x10: dptr_xb, dmem pointer to arithmetic shares of x
 * @param[in]  w31: all-zero register
 * @param[out] x12: dptr_rb, dmem pointer to the bitsliced compressed output
 *
 * clobbered registers: x2 to x8, x10 to x17, x28 to x31, w0 to w15, w17 to w21, w28 to w29
 * clobbered flag groups: FG0
 */

.globl masked_poly_tomsg
.type masked_poly_tomsg, @function
masked_poly_tomsg:
    /* Allocate y[0], y[1] scratch and save callee-saved registers. */
    addi sp, sp, -1056
    sw   s0, 1024(sp)
    addi s0, a2, 0

    /* Load all constants. */
    addi      x4, x0, 17
    la        t0, const_m_dv
    bn.lid    x4++, 0(t0)
    la        t0, modulus_over_2
    bn.lid    x4++, 0(t0)
    bn.shv.8s w18, w18 >> 16

    /* Create 2**(alpha - 1), alpha = 15. */
    bn.subi    w19, w31, 1
    bn.shv.8s  w19, w19 >> 31
    bn.shv.8s  w19, w19 << 14


    /* In order to avoid division by Q, we need to compute:
     *  - x << (1 + alpha) --> x is 28 bits.
     *  - x += 1665
     *  - x *=m where m = ((1 << 37) + Q // 2) // Q = 41285357 (m is 26 bits).
     *  - x >>= k where k = 37. */
    /* Compute y[i] = Compressq(x[i], 1 + alpha); share 0 also adds
     * 2**(alpha - 1). */
    addi t0, x0, 21
    addi t1, sp, 0 /* ptr_y */

    loopi 2, 44
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        bn.xor w4, w4, w4
        bn.xor w5, w5, w5
        bn.xor w6, w6, w6
        bn.xor w7, w7, w7
        bn.xor w8, w8, w8
        bn.xor w9, w9, w9
        bn.xor w10, w10, w10
        bn.xor w11, w11, w11
        bn.xor w12, w12, w12
        bn.xor w13, w13, w13
        bn.xor w14, w14, w14
        bn.xor w15, w15, w15
        bn.xor w20, w20, w20
        bn.xor w21, w21, w21
        bn.xor w28, w28, w28
        bn.xor w29, w29, w29

        addi x4, x0, 15
        loopi 16, 16
            bn.lid             x0, 0(a0++)
            /* Handle even-positioned coeffs. */
            bn.trn1.16h        w20, w0, w31
            bn.shv.8s          w20, w20 << 16
            bn.addv.8s         w20, w20, w18
            bn.mulv.8s.even.hi w20, w20, w17
            bn.mulv.8s.odd.hi  w20, w20, w17
            bn.add             w21, w19, w20 >> 8
            /* Handle odd-positioned coeffs. */
            bn.trn2.16h        w20, w0, w31
            bn.shv.8s          w20, w20 << 16
            bn.addv.8s         w20, w20, w18
            bn.mulv.8s.even.hi w20, w20, w17
            bn.mulv.8s.odd.hi  w20, w20, w17
            bn.add             w20, w19, w20 >> 8
            /* Combine results. */
            bn.trn1.16h        w21, w21, w20
            bn.movr            x4, t0
            addi               x4, x4, -1
        endloop

        jal x1, _bitslice_transpose

        add x4, x0, x0
        loopi 16, 2
            bn.sid x4, 0(t1++)
            addi   x4, x4, 1
        endloop

        /* Clear the offset; only share 0 carries 2**(alpha - 1). */
        bn.xor w19, w19, w19
    endloop

    /* Compute z = seca2b(y, k = 1 + alpha, share bytes = k * 32). */
    addi a0, sp, 0 /* ptr_y */
    addi a1, x0, 16 /* 1 + alpha */
    addi a2, x0, 512
    addi a4, sp, 0 /* ptr_z */
    jal  x1, seca2b

    /* Compute z >>= alpha, i.e. keep only bit z[alpha], the message bit. */
    addi t0, sp, 0 /* ptr_z */
    addi t0, t0, 480 /* skip to bit-plane alpha = 15 */
    addi t1, s0, 0 /* ptr_r */
    loopi 2, 4
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.lid x0, 0(t0++)
        bn.sid x0, 0(t1++)
        /* Advance to bit-plane alpha of the next share. */
        addi t0, t0, 480
    endloop

    /* Restore registers. */
    lw   s0, 1024(sp)
    addi sp, sp, 1056
    ret

#define N_COEFFS 16

/*
 * Name: poly_masked_compare_dv
 *
 * For every coefficient of the polynomial, return 1 if Compressq(cprime, dv)
 * == c, else 0. Bitsliced.
 *
 * Source: Section 6.2 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to arithmetic shares of cprime
 * @param[in]  x11: dptr_y, dmem pointer to the reference compressed polynomial c
 * @param[in]  x12: share stride, distance between shares
 * @param[in]  w31: all-zero register
 * @param[out] x14: dptr_r, dmem pointer to the output Boolean shares of r
 * @param[in]  x15: k, the security level
 *
 * clobbered registers: x2 to x20, x28 to x31, w0 to w15, w17 to w21, w28 to w29
 * clobbered flag groups: FG0
 */
.globl poly_masked_compare_dv
.type poly_masked_compare_dv, @function
poly_masked_compare_dv:
    /* Allocate t scratch (2 shares * 160 B, dv = 5 worst case) + saves. */
    addi sp, sp, -352
    sw   s0, 324(sp)
    sw   s1, 328(sp)
    sw   s2, 332(sp)
    sw   s4, 340(sp)
    sw   a5, 344(sp)

    /* Save input/output addresses. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s4, a4, 0

    /* Compute t = poly_hocompress(cprime). */
    addi a0, s0, 0 /* ptr_cprime */
    addi a2, sp, 0 /* ptr_t */
    addi a3, a5, 0 /* k */
    jal  x1, poly_hocompress

    /* Decode + bitslice c. */
    addi a1, s1, 0 /* ptr_c */

    addi x4, x0, 4
    lw   a5, 344(sp)
    bne  a5, x4, _handle_kn4_dv

_handle_k4_dv:
    addi   x4, x0, 17
    bn.lid x4, 0(a1++)
    /* group 0 -> w15 */
    loopi 16, 2
        bn.rshi w15, w17, w15 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 1 -> w14 */
    loopi 16, 2
        bn.rshi w14, w17, w14 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 2 -> w13 */
    loopi 16, 2
        bn.rshi w13, w17, w13 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 3 -> w12 */
    loopi 3, 2
        bn.rshi w12, w17, w12 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    bn.rshi w12, w17, w12 >> 1
    bn.lid  x4, 0(a1++)
    bn.rshi w12, w17, w12 >> 15
    bn.rshi w17, w31, w17 >> 4
    loopi 12, 2
        bn.rshi w12, w17, w12 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 4 -> w11 */
    loopi 16, 2
        bn.rshi w11, w17, w11 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 5 -> w10 */
    loopi 16, 2
        bn.rshi w10, w17, w10 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 6 -> w9 */
    loopi 6, 2
        bn.rshi w9, w17, w9 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    bn.rshi w9, w17, w9 >> 2
    bn.lid  x4, 0(a1++)
    bn.rshi w9, w17, w9 >> 14
    bn.rshi w17, w31, w17 >> 3
    loopi 9, 2
        bn.rshi w9, w17, w9 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 7 -> w8 */
    loopi 16, 2
        bn.rshi w8, w17, w8 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 8 -> w7 */
    loopi 16, 2
        bn.rshi w7, w17, w7 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 9 -> w6 */
    loopi 9, 2
        bn.rshi w6, w17, w6 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    bn.rshi w6, w17, w6 >> 3
    bn.lid  x4, 0(a1++)
    bn.rshi w6, w17, w6 >> 13
    bn.rshi w17, w31, w17 >> 2
    loopi 6, 2
        bn.rshi w6, w17, w6 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 10 -> w5 */
    loopi 16, 2
        bn.rshi w5, w17, w5 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 11 -> w4 */
    loopi 16, 2
        bn.rshi w4, w17, w4 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 12 -> w3 */
    loopi 12, 2
        bn.rshi w3, w17, w3 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    bn.rshi w3, w17, w3 >> 4
    bn.lid  x4, 0(a1++)
    bn.rshi w3, w17, w3 >> 12
    bn.rshi w17, w31, w17 >> 1
    loopi 3, 2
        bn.rshi w3, w17, w3 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 13 -> w2 */
    loopi 16, 2
        bn.rshi w2, w17, w2 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 14 -> w1 */
    loopi 16, 2
        bn.rshi w1, w17, w1 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    /* group 15 -> w0 */
    loopi 16, 2
        bn.rshi w0, w17, w0 >> 16
        bn.rshi w17, w31, w17 >> 5
    endloop
    jal x1, _bitslice_transpose

    addi    s1, x0, 5
    beq     x0, x0, _handle_common_dv

_handle_kn4_dv:
    addi x4, x0, 17
    bn.lid x4, 0(a1++)
    /* group 0 -> w15 */
    loopi 16, 2
        bn.rshi w15, w17, w15 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 1 -> w14 */
    loopi 16, 2
        bn.rshi w14, w17, w14 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 2 -> w13 */
    loopi 16, 2
        bn.rshi w13, w17, w13 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 3 -> w12 */
    loopi 16, 2
        bn.rshi w12, w17, w12 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    bn.lid x4, 0(a1++)
    /* group 4 -> w11 */
    loopi 16, 2
        bn.rshi w11, w17, w11 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 5 -> w10 */
    loopi 16, 2
        bn.rshi w10, w17, w10 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 6 -> w9 */
    loopi 16, 2
        bn.rshi w9, w17, w9 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 7 -> w8 */
    loopi 16, 2
        bn.rshi w8, w17, w8 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    bn.lid x4, 0(a1++)
    /* group 8 -> w7 */
    loopi 16, 2
        bn.rshi w7, w17, w7 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 9 -> w6 */
    loopi 16, 2
        bn.rshi w6, w17, w6 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 10 -> w5 */
    loopi 16, 2
        bn.rshi w5, w17, w5 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 11 -> w4 */
    loopi 16, 2
        bn.rshi w4, w17, w4 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    bn.lid x4, 0(a1++)
    /* group 12 -> w3 */
    loopi 16, 2
        bn.rshi w3, w17, w3 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 13 -> w2 */
    loopi 16, 2
        bn.rshi w2, w17, w2 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 14 -> w1 */
    loopi 16, 2
        bn.rshi w1, w17, w1 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    /* group 15 -> w0 */
    loopi 16, 2
        bn.rshi w0, w17, w0 >> 16
        bn.rshi w17, w31, w17 >> 4
    endloop
    jal x1, _bitslice_transpose

    addi    s1, x0, 4

_handle_common_dv:
    /* t[0] ^= c ^ ((1 << N) - 1):  c-planes are now w0..w3 if s1 != 4 else w0..w4. */
    bn.subi w15, w31, 1
    addi    t0, sp, 0 /* ptr_t */

    bn.lid  x4, 0(t0)
    bn.xor  w0, w0, w15
    bn.xor  w17, w17, w0
    bn.sid  x4, 0(t0++)

    bn.lid  x4, 0(t0)
    bn.xor  w1, w1, w15
    bn.xor  w17, w17, w1
    bn.sid  x4, 0(t0++)

    bn.lid  x4, 0(t0)
    bn.xor  w2, w2, w15
    bn.xor  w17, w17, w2
    bn.sid  x4, 0(t0++)

    bn.lid  x4, 0(t0)
    bn.xor  w3, w3, w15
    bn.xor  w17, w17, w3
    bn.sid  x4, 0(t0++)

    addi    t1, x0, 4
    beq     s1, t1, _skip_bit_4

    bn.lid  x4, 0(t0)
    bn.xor  w4, w4, w15
    bn.xor  w17, w17, w4
    bn.sid  x4, 0(t0++)

_skip_bit_4:
    /* Compute r = secand(r, t). */
    addi a1, x0, 32
    addi a2, sp, 0 /* ptr_t */
    addi a3, s2, 0 /* share_str */
    addi a6, x0, 32 /* output share_str */
    /* After the secand, the input and output pointers will point to
     * next bit so we don't have to pass all the arguments above to secand again. */
    loop s1, 4
        addi a0, s4, 0 /* ptr_r */
        addi a5, s4, 0 /* ptr_r */
        jal  x1, secand
        nop
    endloop

    /* Restore registers. */
    lw   s0, 324(sp)
    lw   s1, 328(sp)
    lw   s2, 332(sp)
    lw   s4, 340(sp)
    lw   a5, 344(sp)
    addi sp, sp, 352
    ret


/*
 * Name: poly_masked_compare_du
 *
 * For every coefficient of the polynomial, return 1 if Compressq(cprime, du)
 * == c, else 0. Bitsliced.
 *
 * Source: Section 6.2 [BC22]
 *
 * @param[in]  x10: dptr_x, dmem pointer to arithmetic shares of cprime
 * @param[in]  x11: dptr_y, dmem pointer to the reference compressed polynomial c
 * @param[in]  x12: share stride, distance between shares
 * @param[in]  w31: all-zero register
 * @param[out] x14: dptr_r, dmem pointer to the output Boolean shares of r
 * @param[in]  x15: k, the security level
 *
 * clobbered registers: x2 to x20, x28 to x31, w0 to w15, w17 to w21, w28 to w30, acc
 * clobbered flag groups: FG0
 */
.globl poly_masked_compare_du
.type poly_masked_compare_du, @function
poly_masked_compare_du:
    /* Allocate t scratch (2 shares * 352 B, du = 11 worst case) + saves. */
    addi sp, sp, -736
    sw   s0, 708(sp)
    sw   s1, 712(sp)
    sw   s2, 716(sp)
    sw   s4, 724(sp)
    sw   a5, 728(sp)

    /* Save input/output addresses. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s4, a4, 0

    /* Compute t = poly_hocompress(cprime). */
    addi a0, s0, 0 /* ptr_cprime */
    addi a2, sp, 0 /* ptr_t */
    addi a3, a5, 0 /* k */
    jal  x1, polyvec_hocompress

    /* Decode + bitslice c. */
    addi a1, s1, 0 /* ptr_c */

    addi x4, x0, 4
    lw   a5, 728(sp)
    bne  a5, x4, _handle_kn4_du

_handle_k4_du:
    /* group 0 -> w15 */
    addi   x4, x0, 17
	bn.lid x4, 0(a1++)
	loopi 16, 2
		bn.rshi w15, w17, w15 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 1 -> w14 */
	loopi 7, 2
		bn.rshi w14, w17, w14 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w14, w17, w14 >> 3
	bn.lid  x4, 0(a1++)
	bn.rshi w14, w17, w14 >> 13
	bn.rshi w17, w31, w17 >> 8
	loopi 8, 2
		bn.rshi w14, w17, w14 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 2 -> w13 */
	loopi 14, 2
		bn.rshi w13, w17, w13 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w13, w17, w13 >> 6
	bn.lid  x4, 0(a1++)
	bn.rshi w13, w17, w13 >> 10
	bn.rshi w17, w31, w17 >> 5
	bn.rshi w13, w17, w13 >> 16
	bn.rshi w17, w31, w17 >> 11

    /* group 3 -> w12 */
	loopi 16, 2
		bn.rshi w12, w17, w12 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 4 -> w11 */
	loopi 5, 2
		bn.rshi w11, w17, w11 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w11, w17, w11 >> 9
	bn.lid  x4, 0(a1++)
	bn.rshi w11, w17, w11 >> 7
	bn.rshi w17, w31, w17 >> 2
	loopi 10, 2
		bn.rshi w11, w17, w11 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 5 -> w10 */
	loopi 13, 2
		bn.rshi w10, w17, w10 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w10, w17, w10 >> 1
	bn.lid  x4, 0(a1++)
	bn.rshi w10, w17, w10 >> 15
	bn.rshi w17, w31, w17 >> 10
	loopi 2, 2
		bn.rshi w10, w17, w10 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 6 -> w9 */
	loopi 16, 2
		bn.rshi w9, w17, w9 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 7 -> w8 */
	loopi 4, 2
		bn.rshi w8, w17, w8 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w8, w17, w8 >> 4
	bn.lid  x4, 0(a1++)
	bn.rshi w8, w17, w8 >> 12
	bn.rshi w17, w31, w17 >> 7
	loopi 11, 2
		bn.rshi w8, w17, w8 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 8 -> w7 */
	loopi 11, 2
		bn.rshi w7, w17, w7 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w7, w17, w7 >> 7
	bn.lid  x4, 0(a1++)
	bn.rshi w7, w17, w7 >> 9
	bn.rshi w17, w31, w17 >> 4
	loopi 4, 2
		bn.rshi w7, w17, w7 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 9 -> w6 */
	loopi 16, 2
		bn.rshi w6, w17, w6 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 10 -> w5 */
	loopi 2, 2
		bn.rshi w5, w17, w5 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w5, w17, w5 >> 10
	bn.lid  x4, 0(a1++)
	bn.rshi w5, w17, w5 >> 6
	bn.rshi w17, w31, w17 >> 1
	loopi 13, 2
		bn.rshi w5, w17, w5 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 11 -> w4 */
	loopi 10, 2
		bn.rshi w4, w17, w4 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w4, w17, w4 >> 2
	bn.lid  x4, 0(a1++)
	bn.rshi w4, w17, w4 >> 14
	bn.rshi w17, w31, w17 >> 9
	loopi 5, 2
		bn.rshi w4, w17, w4 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 12 -> w3 */
	loopi 16, 2
		bn.rshi w3, w17, w3 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 13 -> w2 */
	bn.rshi w2, w17, w2 >> 16
	bn.rshi w17, w31, w17 >> 11
	bn.rshi w2, w17, w2 >> 5
	bn.lid  x4, 0(a1++)
	bn.rshi w2, w17, w2 >> 11
	bn.rshi w17, w31, w17 >> 6
	loopi 14, 2
		bn.rshi w2, w17, w2 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 14 -> w1 */
	loopi 8, 2
		bn.rshi w1, w17, w1 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
	bn.rshi w1, w17, w1 >> 8
	bn.lid  x4, 0(a1++)
	bn.rshi w1, w17, w1 >> 8
	bn.rshi w17, w31, w17 >> 3
	loopi 7, 2
		bn.rshi w1, w17, w1 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop

    /* group 15 -> w0 */
	loopi 16, 2
		bn.rshi w0, w17, w0 >> 16
		bn.rshi w17, w31, w17 >> 11
	endloop
    jal x1, _bitslice_transpose

    addi s1, x0, 11 /* du */
    beq  x0, x0, _handle_common_du

_handle_kn4_du:
    addi x4, x0, 17
    addi t0, x0, 15
    addi t1, x0, 18
    loopi 2, 69
        /* group i + 0 */
		bn.lid x4, 0(a1++)
		loopi 16, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 1 */
		loopi 9, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
		bn.rshi w18, w17, w18 >> 6
		bn.lid  x4, 0(a1++)
		bn.rshi w18, w17, w18 >> 10
		bn.rshi w17, w31, w17 >> 4
		loopi 6, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 2 */
		loopi 16, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 3 */
		loopi 3, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
		bn.rshi w18, w17, w18 >> 2
		bn.lid  x4, 0(a1++)
		bn.rshi w18, w17, w18 >> 14
		bn.rshi w17, w31, w17 >> 8
		loopi 12, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 4 */
		loopi 12, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
		bn.rshi w18, w17, w18 >> 8
		bn.lid  x4, 0(a1++)
		bn.rshi w18, w17, w18 >> 8
		bn.rshi w17, w31, w17 >> 2
		loopi 3, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 5 */
		loopi 16, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 6 */
		loopi 6, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
		bn.rshi w18, w17, w18 >> 4
		bn.lid  x4, 0(a1++)
		bn.rshi w18, w17, w18 >> 12
		bn.rshi w17, w31, w17 >> 6
		loopi 9, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1

        /* group i + 7 */
		loopi 16, 2
			bn.rshi w18, w17, w18 >> 16
			bn.rshi w17, w31, w17 >> 10
		endloop
        bn.movr t0, t1
        addi    t0, t0, -1
    endloop
    jal x1, _bitslice_transpose

    addi s1, x0, 10 /* du */

_handle_common_du:
    /* t[0] ^= c ^ ((1 << N) - 1):  c-planes are now w0..w9. */
    bn.subi w15, w31, 1
    addi    t0, sp, 0 /* ptr_t */

    bn.lid x4, 0(t0)
    bn.xor w0, w0, w15
    bn.xor w17, w17, w0
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w1, w1, w15
    bn.xor w17, w17, w1
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w2, w2, w15
    bn.xor w17, w17, w2
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w3, w3, w15
    bn.xor w17, w17, w3
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w4, w4, w15
    bn.xor w17, w17, w4
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w5, w5, w15
    bn.xor w17, w17, w5
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w6, w6, w15
    bn.xor w17, w17, w6
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w7, w7, w15
    bn.xor w17, w17, w7
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w8, w8, w15
    bn.xor w17, w17, w8
    bn.sid x4, 0(t0++)

    bn.lid x4, 0(t0)
    bn.xor w9, w9, w15
    bn.xor w17, w17, w9
    bn.sid x4, 0(t0++)

    addi   t1, x0, 10
    beq    s1, t1, _skip_bit_10

    bn.lid x4, 0(t0)
    bn.xor w10, w10, w15
    bn.xor w17, w17, w10
    bn.sid x4, 0(t0++)

_skip_bit_10:
    /* Compute r = secand(r, t). */
    addi a1, x0, 32
    addi a2, sp, 0 /* ptr_t */
    addi a3, s2, 0 /* share_str */
    addi a6, x0, 32 /* output share_str */
    /* After the secand, the input and output pointers will point to
     * next bit so we don't have to pass all the arguments above to secand again. */
    loop s1, 4
        addi a0, s4, 0 /* ptr_r */
        addi a5, s4, 0 /* ptr_r */
        jal  x1, secand
        nop
    endloop

    /* Restore registers. */
    lw   s0, 708(sp)
    lw   s1, 712(sp)
    lw   s2, 716(sp)
    lw   s4, 724(sp)
    lw   a5, 728(sp)
    addi sp, sp, 736
    ret

/*
 * Name: finalize_cmp
 *
 * Reduce the masked_compare output in place to Boolean shares of the single
 * comparison bit. Bitsliced.
 *
 * Source: Section 6.2 [BC22]
 *
 * @param[in/out] x10: dptr_x, dmem pointer to Boolean shares of output of masked_compare
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x13, x15 to x16, w0 to w3, w5 to w8
 * clobbered flag groups: FG0
 */
.globl finalize_cmp
.type finalize_cmp, @function
finalize_cmp:
    /* Allocate t scratch (2 shares * 32 B) and save s0. */
    addi sp, sp, -96
    sw s0, 68(sp)

    /* Save the in/out address. */
    addi s0, a0, 0

    /* Compute x &= (x >> 128). */
    /* Compute t = x >> 128. */
    addi x4, x0, 1
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 128
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, x0, 32
    addi a2, sp, 0
    addi a3, x0, 32
    addi a5, s0, 0
    addi a6, x0, 32
    jal  x1, secand

    /* Compute x &= (x >> 64). */
    /* Compute t = x >> 64. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 64
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Compute x &= (x >> 32). */
    /* Compute t = x >> 32. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 32
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Compute x &= (x >> 16). */
    /* Compute t = x >> 16. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 16
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Compute x &= (x >> 8). */
    /* Compute t = x >> 8. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 8
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Compute x &= (x >> 4). */
    /* Compute t = x >> 4. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 4
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Compute x &= (x >> 2). */
    /* Compute t = x >> 2. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 2
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Compute x &= (x >> 1). */
    /* Compute t = x >> 1. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loopi 2, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, w31, w0 >> 1
        bn.sid  x4, 0(t0++)
    endloop
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand

    /* Restore s0. */
    lw s0, 68(sp)

    addi sp, sp, 96
    ret
