/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

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

/**
 * Bitwise AND of two 1-bit Boolean-shared values.
 *
 * Return Boolean shares of r = x & y, given 1-bit Boolean shares of x and y.
 *
 *   s   <- urnd
 *   r_0 <- (x_0 & y_0) ^ (x_0 & (y_1 ^ s)) ^ ((x_0 ^ 1) & s)
 *   r_1 <- (x_1 & y_1) ^ (x_1 & (y_0 ^ s)) ^ ((x_1 ^ 1) & s)
 *
 * Source: Alg.2 [CS20]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride of x
 * @param[in]  x12: dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride of y
 * @param[out] x15: dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride of r
 *
 * clobbered registers: x4 to x7, x10, x12, x15, w0 to w3, w5 to w8
 * clobbered flag groups: FG0
 */

.globl secand
.type secand, @function
secand:
  /* Save addresses. */
  addi x5, x10, 0
  addi x6, x12, 0
  addi x7, x15, 0

  /* Load x. */
  bn.xor w0, w0, w0
  bn.lid x0, 0(x5) /* x[0] */
  bn.xor w1, w1, w1
  add    x5, x5, x11
  addi   x4, x0, 1
  bn.lid x4++, 0(x5) /* x[1] */

  /* Load y. */
  bn.xor w2, w2, w2
  bn.lid x4++, 0(x6) /* y[0] */
  bn.xor w3, w3, w3
  add    x6, x6, x13
  bn.lid x4, 0(x6) /* y[1] */

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
  bn.sid  x4, 0(x7) /* Save r[0]. */
  add     x7, x7, x16
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
  bn.sid  x4, 0(x7) /* Save r[1]. */

  /* Advance x10, x12, x15 to the next bit. */
  addi x10, x10, 32
  addi x12, x12, 32
  addi x15, x15, 32
  ret

/**
 * Full adder on 1-bit Boolean-shared values.
 *
 * Return Boolean shares of (cout, r) = (x + y + cin), given 1-bit Boolean
 * shares of x, y and cin.
 *
 *   a    <- x ^ y                   (sharewise)
 *   r    <- a ^ cin                 (sharewise; sum bit)
 *   cout <- x ^ secand(a, x ^ cin)  (carry bit)
 *
 * Source: Alg.5 [BC22]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride of x
 * @param[in]  x12: dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride of y
 * @param[out] x15: dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride of r
 * @param[in]  x17: dmem pointer to Boolean shares of cin
 * @param[in]  x29: share stride of cin
 * @param[out] x30: dmem pointer to Boolean shares of cout
 * @param[in]  x31: share stride of cout
 *
 * clobbered registers: x4 to x7, x10, x12, x15, x28, w0 to w9
 * clobbered flag groups: FG0
 */

.globl secfulladder
.type secfulladder, @function
secfulladder:
  /* Save addresses. */
  add x5, x10, x0
  add x6, x12, x0
  add x7, x15, x0
  add x28, x17, x0

  /* Load x. */
  bn.xor w0, w0, w0
  bn.lid x0, 0(x5) /* x[0] */
  add    x5, x5, x11
  addi   x4, x0, 1
  bn.xor w1, w1, w1
  bn.lid x4++, 0(x5) /* x[1] */
  /* Load y. */
  bn.xor w2, w2, w2
  bn.lid x4++, 0(x6) /* y[0] */
  add    x6, x6, x13
  bn.xor w3, w3, w3
  bn.lid x4, 0(x6) /* y[1] */

  /* Compute sharewise a = x ^ y. */
  bn.xor w4, w4, w4
  bn.xor w4, w0, w2
  bn.xor w5, w5, w5
  bn.xor w5, w1, w3

  /* Compute r = cin ^ a. */
  bn.xor w2, w2, w2
  addi   x4, x0, 2
  bn.lid x4++, 0(x28)
  add    x28, x28, x29
  bn.xor w3, w3, w3
  bn.lid x4++, 0(x28)

  bn.xor w6, w6, w6
  bn.xor w6, w4, w2
  addi   x4, x0, 6
  bn.sid x4, 0(x7)
  add    x7, x7, x16
  bn.xor w6, w6, w6
  bn.xor w6, w5, w3
  bn.sid x4, 0(x7)

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
  add     x7, x30, x0
  addi    x4, x0, 3
  bn.sid  x4, 0(x7)
  add     x7, x7, x31
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
  bn.sid  x4, 0(x7)

  /* Point to next bit. */
  addi x10, x10, 32
  addi x12, x12, 32
  addi x15, x15, 32
  ret

/**
 * Addition of two k-bit Boolean-shared values.
 *
 * Return Boolean shares of r = (x + y) mod 2^k, given k-bit Boolean shares of
 * x and y.
 * Bitsliced.
 *
 *   c <- 0
 *   for i = 0..k - 2:  (c, r[i]) <- secfulladder(x[i], y[i], c)
 *   r[k - 1] <- x[k - 1] ^ y[k - 1] ^ c
 *
 * Source: Alg.6 [BC22]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride of x
 * @param[in]  x12: dmem pointer to Boolean shares of y
 * @param[in]  x13: share stride of y
 * @param[out] x15: dmem pointer to Boolean shares of r
 * @param[in]  x16: share stride of r
 * @param[in]  x17: k, bitsize of x and y
 *
 * clobbered registers: x2, x4 to x8, x10, x12, x15, x17, x28 to x31, w0 to w9
 * clobbered flag groups: FG0
 */

.globl secadd
.type secadd, @function
secadd:
  /* Reserve frame: 64 B carry c at 0(x2), plus saved x8, x17. */
  addi x2, x2, -96
  sw   x8, 64(x2)
  sw   x17, 68(x2)

  /* Initialize c = 0. */
  bn.xor w0, w0, w0
  addi   x5, x2, 0 /* ptr_c */
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop

  /* Ripple-carry adder. */
  addi x8, x17, -1
  addi x17, x2, 0 /* ptr_c = cin */
  addi x29, x0, 32
  addi x30, x2, 0 /* ptr_c = cout */
  addi x31, x0, 32
  /* Loop over i=0,...,k-2. */
  loop x8, 2
    /* x10 already points to x[i] */
    /* x11 is already share stride of x. */
    /* x12 already points to y[i] */
    /* x13 is already share stride of y. */
    /* x15 already points to r. */
    /* x16 is already share stride of r. */
    /* x17 already points to ptr_c = cin. */
    /* x29 is already share stride of cin. */
    /* x30 already points to ptr_c = cout. */
    /* x31 is already share stride of cout. */
    jal  x1, secfulladder
    /* After secfulladder:
     *  - x10 and x12 points to x[i + 1] and y[i + 1].
     *  - x11 and x13 are still share stride of x and y.
     *  - x15 points to r[i + 1].
     *  - x16 is still share stride of r.
     *  - x17 points to cin.
     *  - x29 is still share stride of cin.
     *  - x30 points to cout.
     *  - x31 is still share stride of cout. */
    nop
  endloop

  /* Handle bit i = k-1. */
  /* Compute r[k-1] = x[k-1] ^ y[k-1] ^ c. */
  addi x5, x2, 0 /* ptr_c */
  addi x4, x0, 1
  addi x6, x0, 2
  addi x7, x0, 3
  loopi 2, 14
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    /* Computation. */
    bn.lid x0, 0(x10)
    bn.lid x4, 0(x12)
    bn.lid x6, 0(x5)
    bn.xor w3, w0, w1
    bn.xor w3, w3, w2
    bn.sid x7, 0(x15)
    /* Adjust addresses. */
    add    x10, x10, x11
    add    x12, x12, x13
    add    x5, x5, x29
    add    x15, x15, x16
  endloop

  /* Restore registers and frame. */
  lw   x8, 64(x2)
  lw   x17, 68(x2)
  addi x2, x2, 96
  ret

/**
 * Boolean-shared product of the modulus q = 3329 and a single bit.
 *
 * Return k-bit Boolean shares of r = q * x, given 1-bit Boolean
 * shares of x for q = 3329 and the bitsize k = 12 (since q < 2^k).
 * Bitsliced.
 *
 *   for j = 0..k - 1:  r[j] <- q[j] & x   (q = 3329 = 0b110100000001)
 *
 * Source: Alg.1 [BC22]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[in]  x11: share stride of x
 * @param[out] x13: dmem pointer to Boolean shares of r
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
    bn.lid x0, 0(x10)
    add    x10, x10, x11
    /* Copy x to bit 0. */
    bn.sid x0, 0(x13++)
    /* Clear bit 1 -- 7. */
    loopi 7, 1
      bn.sid x4, 0(x13++)
    endloop
    /* Copy x to bit 8. */
    bn.sid x0, 0(x13++)
    /* Clear bit 9. */
    bn.sid x4, 0(x13++)
    /* Copy x to bit 10 -- 11. */
    bn.sid x0, 0(x13++)
    bn.sid x0, 0(x13++)
  endloop
  ret

/**
 * Refresh of Boolean shares.
 *
 * Return new k-bit Boolean shares of x, given k-bit Boolean shares of x.
 * Bitsliced.
 *
 *   for each bit-slice:
 *     s   <- urnd
 *     r_0 <- x_0 ^ s
 *     r_1 <- x_1 ^ s
 *
 * Source: Alg.18 [BC22]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[in]  x11: k, bitsize of x
 * @param[in]  x12: share stride of x and r
 * @param[out] x14: dmem pointer to Boolean shares of r
 *
 * clobbered registers: x4 to x6, x10, x14, w0 to w2
 * clobbered flag groups: FG0
 */

.globl refreshios
.type refreshios, @function
refreshios:
  add  x5, x10, x12 /* 2nd share of x */
  add  x6, x14, x12 /* 2nd share of r */
  addi x4, x0, 1
  loop x11, 11
    bn.wsrr w2, urnd
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.xor  w1, w0, w2
    bn.sid  x4, 0(x14++)
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x5++)
    bn.xor  w1, w0, w2
    bn.sid  x4, 0(x6++)
  endloop
  ret

/**
 * Rejection sampling of a polynomial with coefficients mod q = 3329.
 *
 * Return a polynomial of random coefficients mod q, obtained by running
 * rejection sampling on uniform random bytes from urnd.
 *
 * @param[out] x10: dmem pointer to output polynomial
 * @param[in]  x11: dmem pointer to random input words
 *                  (MLKEM_REJ_SAMPLE_TEST only)
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x5 to x6, x10, w0 to w5, acch, acc
 * clobbered flag groups: FG0
 */

.globl poly_rej_samp
.type poly_rej_samp, @function
poly_rej_samp:
  /* Load 19*Q - 1 into w1. */
  addi      x5, x0, 1
  la        x6, modulus_times_19_minus_1
  bn.lid    x5++, 0(x6)
  bn.shv.8s w1, w1 >> 16
  
  /* Load mont = 2**16 % Q into w2. */
  la     x6, mont
  bn.lid x5, 0(x6)
  
  /* x10 + 512 is the last valid address. */
  addi x5, x10, 512

#if defined(MLKEM_REJ_SAMPLE_TEST)
  addi x30, x0, 3
#endif
  
  /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
  /* Get 16 randoms. */
#if defined(MLKEM_REJ_SAMPLE_TEST)
  bn.lid      x30, 0(x11++)
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
  csrrs       x6, fg0, x0 /* Read flag fg0. */
  srli        x6, x6, 3 /* Extract FG0.z */
  
  /* If FG0.z == 0, there is at least one bad coeff. We throw away this
   * vector and sample again. */
  beq x6, x0, _rej_sample_loop
  
  /* Once the whole vector is accepted, reduce the accepted candidates mod Q
   * using Montgomery. */
  bn.mulv.16h.acc.z.lo w0, w3, w2
  bn.mulv.l.16h.lo     w0, w0, sw0.2
  bn.mulv.l.16h.acc.hi w0, w0, sw0.0
  bn.addvm.16h         w0, w0, w31
  bn.sid               x0, 0(x10++)
  
  /* If x10 == x5, we've filled up a polynomial. Otherwise, continue to sample. */
  beq x10, x5, _end_rej_sample_loop
  beq x0, x0, _rej_sample_loop

_end_rej_sample_loop:
  ret

/**
 * Refresh of arithmetic shares mod q = 3329.
 *
 * Return new arithmetic shares mod q = 3329 of the value x.
 * Vectorized for polynomial.
 *
 *   rand <- poly_rej_samp()      uniform polynomial mod q
 *   r_0  <- x_0 + rand   mod q
 *   r_1  <- x_1 - rand   mod q
 *
 * Source: [BBD+16]
 *
 * @param[in]  x10: dmem pointer to arithmetic shares of x
 * @param[out] x12: dmem pointer to arithmetic shares of r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x7, x10, x12, x28, w0 to w5, acch, acc
 * clobbered flag groups: FG0
 */

.globl refreshmodq
.type refreshmodq, @function
refreshmodq:
  /* Reserve frame: 512 B for rand at 0(x2), plus saved x10, x12. */
  addi x2, x2, -544
  sw x10, 512(x2)
  sw x12, 516(x2)

  /* Generate rand. */
  add x10, x2, x0
  jal x1, poly_rej_samp

  /* r[0] = x[0] + rand. */
  /* r[1] = x[1] - rand. */
  add  x5, x2, 0 /* rand */
  lw   x10, 512(x2)
  addi x6, x10, 512 /* x[1] */
  lw   x12, 516(x2)
  addi x7, x12, 512 /* r[1] */
  addi x4, x0, 1
  addi x28, x0, 2
  loopi 16, 9
    bn.lid       x0, 0(x5++)
    bn.lid       x4, 0(x10++)
    bn.addvm.16h w2, w1, w0
    bn.sid       x28, 0(x12++)
    bn.xor       w1, w1, w1
    bn.xor       w2, w2, w2
    bn.lid       x4, 0(x6++)
    bn.subvm.16h w2, w1, w0
    bn.sid       x28, 0(x7++)
  endloop

  /* Restore stack. */
  addi x2, x2, 544
  ret

/**
 * Bitsliced representation of a polynomial.
 *
 * Return the bitsliced representation r of a value x in [0, q), q = 3329.
 * Vectorized for polynomial.
 *
 *   r[j] <- bit j of x,  j = 0..11
 *
 * Only 12 bitslices are needed since q < 2^12.
 *
 * @param[in]  x10: dmem pointer to x
 * @param[out] x11: dmem pointer to bitsliced representation r
 * @param[in]  w31: all-zero register
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
    bn.lid x4, 0(x10++)
    addi   x4, x4, -1
  endloop

  jal x1, _bitslice_transpose

  /* Store the 12 bitsliced words bs[0..11] via x10 so x11 is left unchanged. */
  addi   x4, x0, 0
  addi   x10, x11, 0
  loopi 12, 2
    bn.sid x4, 0(x10++)
    addi   x4, x4, 1
  endloop
  ret

/**
 * Normal representation of a bitsliced polynomial.
 *
 * Return the normal representation r of a bitsliced value x in [0, q),
 * q = 3329.
 * Vectorized for polynomial.
 *
 *   r <- sum_{j=0..11} x[j] << j
 *
 * Only 12 bitslices are needed since q < 2^12.
 *
 * @param[in]  x10: dmem pointer to bitsliced representation x
 * @param[out] x11: dmem pointer to r
 * @param[in]  w31: all-zero register
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
    bn.lid x4, 0(x10++)
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
    bn.sid x4, 0(x11++)
    addi   x4, x4, -1
  endloop
  ret

/**
 * Per-lane 16x16 bit transpose.
 *
 * Transpose in place the 16x16 bit matrix held by each 16-bit lane of
 * w0 to w15. Shared by poly_to_bitsliced and poly_from_bitsliced.
 *
 * @param[in,out] w0 to w15: bit matrices to transpose
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: w0 to w15, w28 to w29
 * clobbered flag groups: FG0
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

/**
 * Arithmetic-to-Boolean conversion mod 2^k.
 *
 * Return k-bit Boolean shares r of x, given arithmetic shares of x mod 2^k.
 * Bitsliced.
 *
 *   s  <- (x_0, 0)
 *   s' <- (0, x_1)
 *   r  <- secadd(s, s')
 *
 * Source: Alg.8 [BC22]
 *
 * @param[in]  x10: dmem pointer to arithmetic shares of x
 * @param[in]  x11: k, bitsize of x
 * @param[in]  x12: share stride of x and r
 * @param[out] x14: dmem pointer to Boolean shares of r
 *
 * clobbered registers: x2 to x8, x10 to x13, x15 to x17, x28 to x31, w0 to w9
 * clobbered flag groups: FG0
 */

.globl seca2b
.type seca2b, @function
seca2b:
  /* Save x3 to stack */
  addi x2, x2, -32
  sw   x3, 0(x2)
  addi x3, x2, 0

  /* Adjust stack for temp variables. */
  slli x5, x12, 1
  sub  x2, x2, x5 /* ptr_s */
  add  x6, x2, x0
  sub  x2, x2, x5 /* ptr_sp */

  /* Build s = (x[0], 0). */
  add x7, x6, x0 /* Save ptr_s. */
  loop x11, 3
    bn.xor w0, w0, w0
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x6++)
  endloop
  bn.xor w0, w0, w0
  loop x11, 1
    bn.sid x0, 0(x6++)
  endloop

  /* Build s' = (0, x[1]). */
  add x5, x2, x0
  loop x11, 1
    bn.sid x0, 0(x5++)
  endloop
  loop x11, 3
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x5++)
    bn.xor w0, w0, w0
  endloop

  /* Save registers. */
  add x5, x11, x0
  add x6, x12, x0
  add x28, x14, x0

  /* Compute r = secadd(s, s', k). */
  addi x10, x7, 0 /* ptr_s */
  addi x11, x6, 0
  addi x12, x2, 0 /* ptr_sp */
  addi x13, x6, 0
  addi x15, x28, 0 /* ptr_r */
  addi x16, x6, 0
  addi x17, x5, 0 /* k */
  jal  x1, secadd

  /* Restore x2 and x3. */
  addi x2, x3, 0
  lw   x3, 0(x2)
  addi x2, x2, 32
  ret

/**
 * Arithmetic-to-Boolean conversion mod q = 3329.
 *
 * Return k-bit Boolean shares r of x, given arithmetic shares of x mod
 * q = 3329, with the bitsize k = 12 (since q < 2^k).
 * Bitsliced.
 *
 *   s  <- ((2^(k + 1) - q) + x_0, 0)    (k + 1 bits)
 *   s' <- (0, x_1)                      (k + 1 bits)
 *   u  <- secadd(s, s')                 (k + 1 bits)
 *   a  <- bitcopymask(u[k])
 *   r  <- secadd(a, u)                  (k bits)
 *
 * Source: Alg.10 [BC22]
 *
 * @param[in]  x10: dmem pointer to arithmetic shares of x
 * @param[out] x12: dmem pointer to Boolean shares of r
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x2, x4 to x7, x10 to x13, x15 to x18, x28 to x31, w0 to w9
 * clobbered flag groups: FG0
 */

.globl seca2bmodq
.type seca2bmodq, @function
seca2bmodq:
  /* Frame below x2:
   *   x2 +    0 : s' / a   (832 B)
   *   x2 +  832 : carry c  ( 64 B)
   *   x2 +  896 : s / u    (832 B)
   *   x2 + 1728 : saved x18 */
  addi x2, x2, -1760
  sw   x18, 1728(x2)
  addi x18, x12, 0 /* output pointer */

  /* Compute s = p + x[0], k + 1 bits (one share).
   * p = 2**(k + 1) - q = 4863 = b1001011111111. */
  addi x5, x2, 896 /* ptr_s */
  /* x10 already points to x[0]. */
  addi x4, x0, 1
  /* cin = 0 */
  bn.xor w2, w2, w2

  /* Bit 0 -- 7: 1. */
  loopi 8, 9
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    /* Compute r = x ^ p ^ cin. */
    bn.lid x0, 0(x10++)
    bn.not w3, w0 /* a = x ^ p */
    bn.xor w1, w3, w2 /* r = a ^ cin */
    bn.sid x4, 0(x5++) /* Save r. */
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
  bn.lid x0, 0(x10++)
  bn.xor w1, w0, w2 /* r = x ^ cin */
  bn.sid x4, 0(x5++) /* Save r. */
  /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
  bn.and w2, w0, w1 /* cout = x & r */
  bn.xor w2, w2, w0 /* cout ^= x */

  /* Bit 9: 1. */
  /* Whitening. */
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  /* Compute r = x ^ p ^ cin. */
  bn.lid x0, 0(x10++)
  bn.not w3, w0 /* a = x ^ p */
  bn.xor w1, w3, w2 /* r = a ^ cin */
  bn.sid x4, 0(x5++) /* Save r. */
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
    bn.lid x0, 0(x10++)
    bn.xor w1, w0, w2 /* r = x ^ cin */
    bn.sid x4, 0(x5++) /* Save r. */
    /* Compute cout = x ^ ((x ^ p) & (x ^ cin)) = x ^ (x & r). */
    bn.and w2, w0, w1 /* cout = x & r */
    bn.xor w2, w2, w0 /* cout ^= x */
  endloop

  /* Bit 12: 1. */
  /* Whitening. */
  bn.xor w1, w1, w1
  /* Compute r = x ^ p ^ cin = p ^ cin. (x only has k bits, while p has k + 1 bits). */
  bn.not w1, w2 /* r = p ^ cin */
  bn.sid x4, 0(x5++) /* Save r. */

  /* Extend s to 2 shares, i.e., clear next share of s. */
  bn.xor w0, w0, w0
  loopi 13, 1
    bn.sid x0, 0(x5++)
  endloop

  /* Clear first share of sprime and copy x[1] to second share of sprime with
   * share stride = 416. */
  addi x5, x2, 0 /* ptr_sprime */
  loopi 13, 1
    bn.sid x0, 0(x5++)
  endloop
  loopi 12, 3
    bn.lid x0, 0(x10++) /* x10 already points to x[1]. */
    bn.sid x0, 0(x5++)
    /* Whitening. */
    bn.xor w0, w0, w0
  endloop
  bn.sid x0, 0(x5++)

  /* Compute u = secadd(s, sprime, k + 1). */
  /* Initialize c = 0. */
  addi  x5, x2, 832 /* ptr_c */
  bn.xor w0, w0, w0
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop

  addi x10, x2, 896 /* ptr_s */
  addi x11, x0, 416
  addi x12, x2, 0 /* ptr_sprime */
  addi x13, x0, 416
  addi x15, x2, 896 /* ptr_u */
  addi x16, x0, 416
  addi x17, x2, 832 /* ptr_c */
  addi x29, x0, 32
  addi x30, x2, 832 /* ptr_c */
  addi x31, x0, 32
  loopi 12, 2
    jal x1, secfulladder
    nop
  endloop
  /* Handle bit 12. */
  /* Compute r[12] = x[12] ^ y[12] ^ c. */
  addi x4, x0, 1
  addi x6, x0, 2
  addi x7, x0, 3
  loopi 2, 14
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    /* Computation. */
    bn.lid x0, 0(x10)
    bn.lid x4, 0(x12)
    bn.lid x6, 0(x17)
    bn.xor w3, w0, w1
    bn.xor w3, w3, w2
    bn.sid x7, 0(x15)
    /* Adjust addresses. */
    add    x10, x10, x11
    add    x12, x12, x13
    add    x17, x17, x29
    add    x15, x15, x16
  endloop

  /* Compute a = bitcopymask(u[k], (k + 1) * 32). */
  addi x10, x2, 1280 /* ptr_u[k] */
  addi x11, x0, 416
  addi x13, x2, 0 /* ptr_a */
  jal  x1, bitcopymask

  /* Compute u = secadd(a, u, k). */
  /* Initialize c = 0. */
  addi  x5, x2, 832 /* ptr_c */
  bn.xor w0, w0, w0
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop

  addi x10, x2, 0 /* ptr_a */
  addi x11, x0, 384
  addi x12, x2, 896 /* ptr_u */
  addi x13, x0, 416
  addi x15, x18, 0 /* ptr_r */
  addi x16, x0, 384
  addi x17, x2, 832 /* ptr_c */
  addi x29, x0, 32
  addi x30, x2, 832 /* ptr_c */
  addi x31, x0, 32
  loopi 11, 2
    jal x1, secfulladder
    nop
  endloop
  /* Handle bit 11. */
  /* Compute r[11] = x[11] ^ y[11] ^ c. */
  addi x4, x0, 1
  addi x6, x0, 2
  addi x7, x0, 3
  loopi 2, 14
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    /* Computation. */
    bn.lid x0, 0(x10)
    bn.lid x4, 0(x12)
    bn.lid x6, 0(x17)
    bn.xor w3, w0, w1
    bn.xor w3, w3, w2
    bn.sid x7, 0(x15)
    /* Adjust addresses. */
    add    x10, x10, x11
    add    x12, x12, x13
    add    x17, x17, x29
    add    x15, x15, x16
  endloop

  /* Restore x18 and frame. */
  lw   x18, 1728(x2)
  addi x2, x2, 1760
  ret

/**
 * One-bit Boolean-to-Arithmetic conversion mod q = 3329.
 *
 * Return arithmetic shares mod q = 3329 r of a bit x, given its Boolean shares.
 * Vectorized for polynomial.
 *
 *   v    <- (x_0, 0)
 *   v    <- refreshmodq(v)
 *   v_0  <- (1 - 2 * x_1) * v_0 + x_1   mod q
 *   v_1  <- (1 - 2 * x_1) * v_1         mod q
 *   r    <- refreshmodq(v)
 *
 * Source: Alg.5 [SPOG19]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[out] x12: dmem pointer to arithmetic shares of r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x8, x10, x12, x18, x28, w0 to w5, w30, acch, acc
 * clobbered flag groups: FG0
 */

.globl seconebitb2amodq
.type seconebitb2amodq, @function
seconebitb2amodq:
  /* Frame: v[0..1] at x2+0 (1024 B), saved x8/x18 above. */
  addi x2, x2, -1056
  sw   x8, 1024(x2)
  sw   x18, 1028(x2)
  addi x8, x10, 0 /* ptr_x */
  addi x18, x12, 0 /* ptr_r */

  /* Copy x[0] to v[0]. */
  addi x5, x2, 0 /* ptr_v */
  add  x6, x10, x0 /* ptr_x[0] */
  loopi 16, 2
    bn.lid x0, 0(x6++)
    bn.sid x0, 0(x5++)
  endloop
  /* Zeroize v[1]. */
  bn.xor w0, w0, w0
  loopi 16, 1
    bn.sid x0, 0(x5++)
  endloop

  /* Construct the vector of 1s. */
  bn.subi    w30, w0, 1
  bn.shv.16h w30, w30 >> 15

  /* Refresh v in place. */
  addi x10, x2, 0 /* ptr_v */
  addi x12, x10, 0 /* in-place */
  jal  x1, refreshmodq

  /* To avoid use modular multiplication, we compute (1 - 2*x[1]) * v[j]
   * as follows:
   *  - x5 = x[1] - 1
   *  - We have x5 = 0xFFFF if x[1] = 0 and x5 = 0 if x[1] = 1.
   *  - x6 = v[j] & x5
   *  - x6 <<= 1
   *  - r = bn.subvm(x6, v[j]) with MOD = Q. This works because if x[1] = 0,
   *    then x6 = 2*v[j] and r = 2*v[j] - v[j] = v[j]. Otherwise,
   *    x6 = (0 - v[j]) mod Q.
   * For v[0], we continue with v[0] = (v[0] + x[1]) mod Q before
   * saving the result to memory.
   */
  addi x5, x8, 512 /* ptr_x[1] */
  addi x6, x2, 0 /* ptr_v */
  addi x4, x0, 1
  loopi 16, 16
    bn.lid         x0, 0(x5++) /* x[1] */
    bn.subv.16h    w2, w0, w30
    addi           x7, x6, 0
    /* v[0]: also add x[1] before storing. */
    bn.lid       x4, 0(x6) /* v[0] */
    bn.and       w3, w1, w2
    bn.shv.16h   w3, w3 << 1
    bn.subvm.16h w1, w3, w1
    bn.addvm.16h w1, w0, w1
    bn.sid       x4, 0(x6)
    addi         x6, x6, 512 /* Point to v[1]. */
    /* v[1]. */
    bn.lid       x4, 0(x6) /* v[1] */
    bn.and       w3, w1, w2
    bn.shv.16h   w3, w3 << 1
    bn.subvm.16h w1, w3, w1
    bn.sid       x4, 0(x6)
    addi x6, x7, 32
  endloop

  /* Final refresh: r = refreshmodq(v). */
  addi x10, x2, 0 /* ptr_v */
  addi x12, x18, 0 /* ptr_r */
  jal  x1, refreshmodq

  /* Restore registers and frame. */
  lw   x8, 1024(x2)
  lw   x18, 1028(x2)
  addi x2, x2, 1056
  ret

/**
 * Boolean-to-Arithmetic conversion mod q = 3329.
 *
 * Return arithmetic shares r of x mod q = 3329, given its Boolean
 * shares mod 2^k, with k = 12 (q < 2^k).
 * Bitsliced.
 *
 *   rand <- poly_rej_samp()      (uniform polynomial mod q)
 *   zp   <- q - rand
 *   a    <- seca2bmodq(zp)
 *   b    <- secaddmodq(a, x)
 *   c    <- refreshios(b)
 *   r    <- (rand, unmask(c))
 *
 * Source: Alg.11 [BC22]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[out] x12: dmem pointer to arithmetic shares of r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x8, x10 to x21, x28 to x31, w0 to w16, w28 to w30, acch, acc
 * clobbered flag groups: FG0
 */

.globl secb2amodq
.type secb2amodq, @function
secb2amodq:
  /* Frame (2656 B, 2 shares):
   *   x2 +    0 : saved x8, x18, x19, x20, x21
   *   x2 +   32 : ptr_zp / scratch (1024 B)
   *   x2 + 1056 : ptr_s            ( 832 B)
   *   x2 + 1888 : ptr_a, ptr_b, ptr_c (bitsliced, 768 B) */
  addi x2, x2, -2048
  addi x2, x2, -608
  sw x8, 0(x2)
  sw x18, 4(x2)
  sw x19, 8(x2)
  sw x20, 12(x2)
  sw x21, 16(x2)

  /* Save input/output addresses and buffer bases. */
  addi x8, x10, 0 /* ptr_x */
  addi x18, x12, 0 /* ptr_r */
  addi x19, x2, 1888 /* ptr_a, ptr_b, ptr_c (bitsliced) */
  addi x20, x2, 1056 /* ptr_s */
  /* ptr_zp = x2 + 32 */

  /* Sample rand, then compute zp = q - rand. */
  addi    x4, x0, 30
  la      x5, modulus_bn
  bn.lid  x4, 0(x5)
  addi    x10, x12, 0 /* ptr_r */
  addi    x7, x2, 32 /* ptr_zp */
  bn.wsrr w16, mod
  jal x1, poly_rej_samp
  loopi 16, 3
    bn.lid      x0, 0(x12++)
    bn.subv.16h w0, w30, w0 /* Since inputs are < q, we need to only use bn.subv. */
    bn.sid      x0, 0(x7++)
  endloop

  /* Bitslice share 0 of zp; the last share (bitsliced) is cleared below. */
  addi x10, x2, 32 /* ptr_zp */
  addi x11, x19, 0 /* ptr_zp (bitsliced) */
  jal  x1, poly_to_bitsliced
  addi x11, x11, 384
  /* Clear the last share of zp (bitsliced). */
  bn.xor w0, w0, w0
  loopi 12, 1
    bn.sid x0, 0(x11++)
  endloop

  /* Compute a = seca2bmodq(zp). */
  addi x10, x19, 0 /* ptr_zp (bitsliced) */
  addi x12, x19, 0 /* ptr_a */
  jal  x1, seca2bmodq

  /* Compute b = secaddmodq(a, x). */
  /* Inline secaddmodq. */
  /* Compute s = secadd(a, x, k + 1). */
  /* Initialize c = 0. */
  bn.xor w0, w0, w0
  addi   x5, x20, 384 /* ptr_c */
  loopi 2, 2
    bn.sid x0, 0(x5)
    addi   x5, x5, 416
  endloop

  /* Ripple-carry adder. */
  addi x10, x19, 0 /* ptr_a */
  addi x11, x0, 384
  addi x12, x8, 0 /* ptr_x */
  addi x13, x0, 384
  addi x15, x20, 0 /* ptr_s */
  addi x16, x0, 416
  addi x17, x20, 384 /* ptr_c = cin */
  addi x29, x0, 416
  addi x30, x20, 384 /* ptr_c = cout */
  addi x31, x0, 416
  /* Loop over i=1,...,k-1. */
  loopi 12, 2
    /* x10 already points to x[i] */
    /* x11 is already share stride of x. */
    /* x12 already points to y[i] */
    /* x13 is already share stride of y. */
    /* x15 already points to r. */
    /* x16 is already share stride of r. */
    /* x17 already points to ptr_c = cin. */
    /* x29 is already share stride of cin. */
    /* x30 already points to ptr_c = cout. */
    /* x31 is already share stride of cout. */
    jal  x1, secfulladder
    /* After secfulladder:
     *  - x10 and x12 points to x[i + 1] and y[i + 1].
     *  - x11 and x13 are still share stride of x and y.
     *  - x15 points to r[i + 1].
     *  - x16 is still share stride of r.
     *  - x17 points to cin.
     *  - x29 is still share stride of cin.
     *  - x30 points to cout.
     *  - x31 is still share stride of cout. */
    nop
  endloop
  /* Bit i = k + 1 is already x[k + 1] ^ y[k + 1] ^ c = cout since x[k + 1] = y[k + 1] = 0. */

  /* Compute s = secadd(s, p, k + 1) where p = 2**(k + 1) - q = 4863 = b1001011111111. */
  /* Initialize c = 0. */
  addi   x5, x2, 32 /* ptr_c */
  bn.xor w0, w0, w0
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop
  addi x21, x5, 0 /* ptr_p */

  addi    x5, x21, 0 /* ptr_p */
  bn.subi w1, w0, 1
  addi    x4, x0, 1
  bn.sid  x4, 0(x5++)
  bn.sid  x0, 0(x5++)

  addi x10, x21, 0 /* ptr_p */
  addi x11, x0, 32
  addi x12, x20, 0 /* ptr_s */
  addi x13, x0, 416
  addi x15, x20, 0 /* ptr_s */
  addi x16, x0, 416
  addi x17, x2, 32 /* cin */
  addi x29, x0, 32
  addi x30, x2, 32 /* cout */
  addi x31, x0, 32
  /* Bit 0 -- 7: p = 1. */
  loopi 8, 2
    jal  x1, secfulladder
    addi x10, x10, -32 /* Reset x10 to ptr_p. */
  endloop

  /* Bit 8: p = 0. */
  bn.xor w0, w0, w0
  bn.sid x0, 0(x10)
  addi   x10, x21, 0
  jal    x1, secfulladder
  /* Bit 9: p = 1. */
  bn.xor  w0, w0, w0
  bn.subi w0, w0, 1
  addi    x10, x21, 0
  bn.sid  x0, 0(x10)
  jal     x1, secfulladder
  /* Bit 10 -- 11: p = 0. */
  bn.xor w0, w0, w0
  addi   x10, x21, 0
  bn.sid x0, 0(x10)
  jal    x1, secfulladder
  addi   x10, x21, 0
  jal    x1, secfulladder

  /* Bit 12: p = 1. */
  /* Compute r[12] = p[12] ^ s[12] ^ c = ~(s[12] ^ c) since p[12] = 1. */
  addi x4, x0, 1
  addi x6, x0, 2
  /* Whitening. */
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  bn.xor w2, w2, w2
  bn.xor w3, w3, w3
  /* Computation. */
  bn.lid x0, 0(x12)
  bn.lid x4, 0(x17)
  bn.xor w3, w0, w1
  bn.not w2, w3
  bn.sid x6, 0(x12)
  add    x12, x12, x13
  add    x17, x17, x29

  /* Whitening. */
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  bn.xor w2, w2, w2
  /* Computation. */
  bn.lid x0, 0(x12)
  bn.lid x4, 0(x17)
  bn.xor w2, w0, w1
  bn.sid x6, 0(x12)

  /* Compute a = bitcopymask(s[k], (k + 1) * 32). */
  addi x10, x20, 384 /* ptr_s[k] */
  addi x11, x0, 416 /* share_str = (k + 1) * 32 */
  addi x13, x19, 0 /* ptr_a */
  jal  x1, bitcopymask

  /* Compute r = secadd(a, s, k). */
  addi x10, x19, 0 /* ptr_a */
  addi x11, x0, 384
  addi x12, x20, 0 /* ptr_s */
  addi x13, x0, 416
  addi x15, x19, 0 /* ptr_b */
  addi x16, x0, 384
  addi x17, x0, 12 /* k */
  jal  x1, secadd
  /* End inlining secaddmodq. */

  /* Compute c = refreshios(b, k, k * 32). */
  addi x10, x19, 0 /* ptr_b */
  addi x11, x0, 12 /* k */
  addi x12, x0, 384 /* k * 32 */
  addi x14, x19, 0 /* ptr_c */
  jal  x1, refreshios

  /* Unmask c. */
  addi x5, x19, 0 /* ptr_c */
  addi x4, x0, 1
  loopi 12, 5
    addi   x6, x5, 384
    bn.lid x0, 0(x5)
    bn.lid x4, 0(x6)
    bn.xor w0, w0, w1
    bn.sid x0, 0(x5++)
  endloop

  /* Convert c from bitsliced to normal representation, into share 1. */
  addi x10, x19, 0 /* ptr_c */
  addi x11, x18, 0 /* ptr_r */
  addi x11, x11, 512 /* r[1] */
  jal x1, poly_from_bitsliced

  /* Restore registers. */
  lw x8, 0(x2)
  lw x18, 4(x2)
  lw x19, 8(x2)
  lw x20, 12(x2)
  lw x21, 16(x2)
  addi x2, x2, 2047
  addi x2, x2, 609
  ret

/**
 * First-order masked compression of a polynomial with dv in {4, 5}.
 *
 * Return Boolean shares of r = Compressq(x, dv) = round((2^dv / q) * x) mod
 * 2^dv for dv in {4, 5}, given arithmetic shares mod q of x. Here dv = 5 for
 * k = 4, and 4 otherwise.
 * Bitsliced.
 *
 * Each share is compressed to dv + alpha bits, recombined (seca2b), then the
 * low alpha bits dropped. The alpha extra bits absorb the per-share rounding
 * error (2^alpha > q * nshares); nshares = 2 gives dv + alpha = 18 (alpha = 13
 * for dv = 5, 14 for dv = 4).
 *
 *   z_0  <- Compressq(x_0, dv + alpha) + 2^(alpha - 1)
 *   z_1  <- Compressq(x_1, dv + alpha)
 *   c    <- seca2b(z)
 *   r    <- c >> alpha
 *
 * Source: Alg.2 [CGMZ21b]
 *
 * @param[in]  x10: dmem pointer to arithmetic shares of x
 * @param[out] x12: dmem pointer to bitsliced compressed output r
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
  addi x2, x2, -1024
  add  x7, x2, x0
  addi x2, x2, -1184
  sw   x9, 1152(x2)
  sw   x18, 1156(x2)
  sw   x19, 1160(x2)
  addi x9, x12, 0

  /* Load all constants. */
  addi      x4, x0, 17
  la        x5, const_m_dv
  bn.lid    x4++, 0(x5)
  la        x5, modulus_over_2
  bn.lid    x4++, 0(x5)
  bn.shv.8s w18, w18 >> 16

  /* Create 1-bit mask and 2**(alpha - 1). */
  bn.subi   w19, w31, 1
  bn.shv.8s w19, w19 >> 31
  bn.shv.8s w19, w19 << 12  /* alpha - 1 */

  /* Select alpha-dependent parameters: w3 = 2**(alpha - 1), x18 = the
   * extraction byte offset alpha * 32, x19 = dv. */
  addi      x4, x0, 4
  addi      x18, x0, 416  /* alpha * 32, alpha = 13 */
  addi      x19, x0, 5
  beq       x13, x4, _dv_params_done
  bn.shv.8s w19, w19 << 1
  addi      x18, x0, 448  /* alpha * 32, alpha = 14 (k != 4) */
  addi      x19, x0, 4
_dv_params_done:

  addi x6, x2, 0 /* ptr_z */
  addi x28, x6, 512 /* Skip the first 16 bits. */

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
      bn.lid             x0, 0(x10++)
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
      bn.sid             x0, 0(x7++)
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
      bn.sid x4, 0(x6++)
      addi   x4, x4, 1
    endloop
    addi x6, x6, 64 /* Skip the last 2 bits. */

    /* Bitslice the last 2 bits. */
    addi x4, x0, 15
    addi x7, x7, -512
    loopi 16, 2
      bn.lid x4, 0(x7++)
      addi   x4, x4, -1
    endloop

    jal x1, _bitslice_transpose

    add x4, x0, x0
    loopi 2, 2
      bn.sid x4, 0(x28++)
      addi   x4, x4, 1
    endloop
    addi x28, x28, 512 /* Skip the first 16 bits. */
  endloop

  /* Compute c = seca2b(z), k = dv + alpha, share bytes = 576. */
  addi x10, x2, 0 /* ptr_z */
  addi x11, x0, 18 /* dv + alpha */
  addi x12, x0, 576
  addi x14, x2, 0 /* ptr_c */
  jal  x1, seca2b

  /* Compute r = c >> alpha: keep the bits c[alpha]...c[alpha + dv]. */
  addi x5, x2, 0 /* ptr_c */
  add  x5, x5, x18
  addi x6, x9, 0 /* ptr_r */
  loopi 2, 5
    loop x19, 3
      /* Whitening. */
      bn.xor w0, w0, w0
      bn.lid x0, 0(x5++)
      bn.sid x0, 0(x6++)
    endloop
    /* After copy DV bits of z to r, we need to adjust address of z again. */
    add x5, x5, x18
  endloop

  /* Restore registers. */
  lw   x9, 1152(x2)
  lw   x18, 1156(x2)
  lw   x19, 1160(x2)
  addi x2, x2, 1184
  addi x2, x2, 1024
  ret

/**
 * First-order masked compression of a polynomial with du in {10, 11}.
 *
 * Return Boolean shares of r = Compressq(x, du) = round((2^du / q) * x) mod
 * 2^du for du in {10, 11}, given arithmetic shares mod q of x. Here du = 11
 * for k = 4, and 10 otherwise.
 * Bitsliced.
 *
 * Each share is compressed to du + alpha bits, recombined (seca2b), then the
 * low alpha bits dropped. The alpha extra bits absorb the per-share rounding
 * error (2^alpha > q * nshares); nshares = 2 gives du + alpha = 24 (alpha = 13
 * for du = 11, 14 for du = 10).
 *
 *   z_0  <- Compressq(x_0, du + alpha) + 2^(alpha - 1)
 *   z_1  <- Compressq(x_1, du + alpha)
 *   c    <- seca2b(z)
 *   r    <- c >> alpha
 *
 * Source: Alg.2 [CGMZ21b]
 *
 * @param[in]  x10: dmem pointer to arithmetic shares of x
 * @param[out] x12: dmem pointer to bitsliced compressed output r
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
  addi x2, x2, -1024
  add  x7, x2, x0
  addi x2, x2, -1568
  sw   x9, 1536(x2)
  sw   x18, 1540(x2)
  sw   x19, 1544(x2)
  addi x9, x12, 0

  /* Create 2**(alpha - 1). */
  bn.subi   w30, w31, 1
  bn.shv.8s w30, w30 >> 31
  bn.shv.8s w30, w30 << 12  /* alpha - 1 */

  /* Select alpha-dependent parameters: x18 = the extraction byte offset
   * alpha * 32, x19 = du. The in-loop computation of 2**(alpha - 1)
   * branches on x13 (k) directly. */
  addi      x4, x0, 4
  addi      x18, x0, 416  /* alpha * 32, alpha = 13 */
  addi      x19, x0, 11
  beq       x13, x4, _du_params_done
  bn.shv.8s w30, w30 << 1
  addi      x18, x0, 448  /* alpha * 32, alpha = 14 (k != 4) */
  addi      x19, x0, 10
_du_params_done:

  /* Load all constants. */
  addi       x4, x0, 17
  la         x5, const_m_du
  bn.lid     x4++, 0(x5)

  la         x5, const_1664
  bn.lid     x4, 0(x5)

  /* Adjust space for temporary variable y. */
  addi x5, x0, 21
  addi x6, x2, 0 /* ptr_z */
  addi x28, x6, 512 /* Skip the first 16 bits. */

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
      bn.lid           x0, 0(x10++)
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
      bn.movr         x4, x5
      addi            x4, x4, -1
      bn.trn2.16h     w21, w19, w20
      bn.sid          x5, 0(x7++)
    endloop

    /* Clear w30. */
    bn.xor w30, w30, w30

    /* Bitslice the first 16 bits. */
    jal x1, _bitslice_transpose

    add x4, x0, x0
    loopi 16, 2
      bn.sid x4, 0(x6++)
      addi   x4, x4, 1
    endloop
    addi x6, x6, 256 /* Skip the last 8 bits. */

    /* Bitslice the last 8 bits. */
    addi x4, x0, 15
    addi x7, x7, -512
    loopi 16, 2
      bn.lid x4, 0(x7++)
      addi   x4, x4, -1
    endloop

    jal x1, _bitslice_transpose

    add x4, x0, x0
    loopi 8, 2
      bn.sid x4, 0(x28++)
      addi   x4, x4, 1
    endloop
    addi x28, x28, 512 /* Skip the first 16 bits. */
  endloop

  /* Compute c = seca2b(z), k = du + alpha, share bytes = 768. */
  addi x10, x2, 0 /* ptr_z */
  addi x11, x0, 24 /* du + alpha */
  addi x12, x0, 768
  addi x14, x2, 0 /* ptr_c */
  jal  x1, seca2b

  /* Compute r = c >> alpha: keep the bits c[alpha]...c[alpha + du]. */
  addi x5, x2, 0 /* ptr_c */
  add  x5, x5, x18
  addi x6, x9, 0 /* ptr_r */
  loopi 2, 5
    loop x19, 3
      /* Whitening. */
      bn.xor w0, w0, w0
      bn.lid x0, 0(x5++)
      bn.sid x0, 0(x6++)
    endloop
    /* After copy DV bits of z to r, we need to adjust address of z again. */
    add x5, x5, x18
  endloop

  /* Restore registers. */
  lw   x9, 1536(x2)
  lw   x18, 1540(x2)
  lw   x19, 1544(x2)
  addi x2, x2, 1568
  addi x2, x2, 1024
  ret

/**
 * Masked decompression of a 1-bit message.
 *
 * Return arithmetic shares mod q = 3329 of mp = Decompressq(m, 1), given
 * Boolean shares of a 32-byte message m: coefficient i is (q + 1) / 2 if
 * bit i of m is set, else 0.
 * Vectorized for polynomial.
 *
 *   m  <- unpack(m)                 (one message bit per coefficient)
 *   mp <- seconebitb2amodq(m)       (Boolean to arithmetic shares mod q)
 *   mp <- mp * (q + 1) / 2   mod q
 *
 * Source: Section 3.3 [BGR+21]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of m (bitsliced)
 * @param[out] x12: dmem pointer to arithmetic shares of mp
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x8, x10, x12, x18, x28, w0 to w5, w30, acch, acc
 * clobbered flag groups: FG0
 */

.globl onebitdecompress
.type onebitdecompress, @function
onebitdecompress:
  /* Save the output base pointer; reused as scratch across the call. */
  addi x2, x2, -32
  sw   x8, 0(x2)
  addi x8, x12, 0

  /* Unpack m, matching the bitslice layout from masked_poly_tomsg. */
  addi x4, x0, 1
  loopi 2, 7
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(x10++)
    loopi 16, 3
      bn.shv.16h w1, w0 >> 15
      bn.shv.16h w0, w0 << 1
      bn.sid     x4, 0(x12++)
    endloop
    nop
  endloop

  /* mp = seconebitb2amodq(m), with w16 = R | Q. */
  addi x10, x8, 0 /* ptr_m */
  addi x12, x8, 0 /* ptr_r */
  jal  x1, seconebitb2amodq

  /* mp *= (q + 1) / 2 mod q, coefficient-wise (Montgomery). */
  la      x5, modulus_over_2_m2_16 /* ((Q + 1) / 2) * (2^16) % Q. */
  addi    x4, x0, 1
  bn.lid  x4, 0(x5)
  loopi 2, 9
    /* Whitening. */
    bn.xor w0, w0, w0
    loopi 16, 6
      bn.lid               x0, 0(x8)
      bn.mulv.16h.acc.z.lo w0, w0, w1
      bn.mulv.l.16h.lo     w0, w0, sw0.2
      bn.mulv.l.16h.acc.hi w0, w0, sw0.0
      bn.addvm.16h         w0, w0, w31
      bn.sid               x0, 0(x8++)
    endloop
    nop
  endloop

  /* Restore the output base pointer and stack. */
  lw   x8, 0(x2)
  addi x2, x2, 32
  ret

/**
 * First-order masked binomial sampler for q = 3329.
 *
 * Return arithmetic shares mod q = 3329 of the centered binomial sample
 * r = HW(x) - HW(y), given Boolean shares of the eta-bit values x and y.
 * Since HW(y) = eta - HW(~y), this sums the 2 * eta bit-planes of x and ~y.
 * k = 12 (q < 2^k).
 * Bitsliced.
 *
 *   a <- Hamming weight of (x, ~y) via a secfulladder tree
 *   r <- secb2amodq(a) - eta   mod q
 *
 * Source: Alg.17 [BC22]
 *
 * @param[in]  x10: dmem pointer to Boolean shares of x
 * @param[in]  x11: dmem pointer to Boolean shares of y
 * @param[in]  x12: eta in {2, 3}
 * @param[out] x14: dmem pointer to arithmetic shares of r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x22, x28 to x31, w0 to w16, w28 to w30, acch, acc
 * clobbered flag groups: FG0
 */

.globl masked_cbd
.type masked_cbd, @function
masked_cbd:
  /* Frame: tmp at 0 (768 B), sum at 768 (64 B), s at 832 (384 B, sized for
   * the worst case eta = 3), saved registers at 1216. */
  addi x2, x2, -1248
  sw x8, 1216(x2)
  sw x9, 1220(x2)
  sw x18, 1224(x2)
  sw x20, 1228(x2)
  sw x21, 1232(x2)
  sw x22, 1236(x2)

  /* Save input/output addresses and set the scratch pointers. */
  addi x8, x10, 0
  addi x9, x11, 0
  addi x18, x12, 0
  addi x20, x14, 0
  addi x21, x2, 832 /* ptr_s */
  addi x22, x2, 768 /* ptr_sum */

  /* Copy x to s[1,..,eta] and ~y to s[eta + 1,..,2 * eta]. */
  addi x5, x21, 0 /* ptr_s */
  slli x4, x12, 5 /* eta * 32 */
  add  x6, x21, x4 /* ptr_s[eta + 1] */
  /* Share 0: copy x[0] and ~y[0]. */
  loop x12, 7
    /* Whitening. */
    bn.xor w0, w0, w0
    /* Copy x[0]. */
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x5++)
    /* Whitening. */
    bn.xor w0, w0, w0
    /* Copy ~y[0]. */
    bn.lid x0, 0(x11++)
    bn.not w0, w0
    bn.sid x0, 0(x6++)
  endloop
  add x5, x5, x4
  add x6, x6, x4
  /* Share 1: copy x[1] and y[1]. */
  loop x12, 6
    /* Whitening. */
    bn.xor w0, w0, w0
    /* Copy x[1]. */
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x5++)
    /* Whitening. */
    bn.xor w0, w0, w0
    /* Copy y[1]. */
    bn.lid x0, 0(x11++)
    bn.sid x0, 0(x6++)
  endloop

  /* We need to loop over i = 1,...,k where k = ceil(log2(l + 1)) = 3 for both
   * eta = 2 and eta = 3. Then the inner loop is over j = 1,...,l where
   * l >>= i, so j is in {eta, eta/2, eta/4}, i.e., {2, 1, 0} for eta = 2 and
   * {3, 1, 0} for eta = 3. Thus, in the third iteration i = k, the inner loop
   * is not executed at all. */
  /*----------------------- Iteration i = 1, l = 2 * eta -----------------------*/
  /* Since l mod 2 = 0, we clear the carry sum. */
  addi   x5, x22, 0 /* ptr_sum */
  bn.xor w0, w0, w0
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop

  /* l >>= 1: loop j = 1,..., l = 1,...,eta. */
  /* Inputs to secfulladder. */
  slli x5, x12, 6 /* (2 * eta) * 32 */
  addi x10, x21, 0 /* s[0] */
  addi x11, x5, 0
  addi x12, x21, 32 /* s[1] */
  addi x13, x5, 0
  addi x15, x22, 0 /* ptr_sum = r */
  addi x16, x0, 32
  addi x17, x22, 0 /* ptr_sum = cin */
  addi x29, x0, 32
  addi x30, x21, 0 /* s[0] = cout */
  addi x31, x5, 0
  loop x18, 5
    /* Compute c, s[j] = secfulladder(s[2j], s[2j + 1], c). */
    /* x10 already points to s[2j] */
    /* x11 is already share stride of s. */
    /* x12 already points to s[2j + 1] */
    /* x13 is already share stride of s. */
    /* x15 already points to sum = r. */
    /* x16 is already share stride of sum = r. */
    /* x17 already points to sum = cin. */
    /* x29 is already share stride of sum = cin. */
    /* x30 already points to s[j] = cout. */
    /* x31 is already share stride of s = cout. */
    jal  x1, secfulladder
    /* After secfulladder:
    *  - x10 and x12 points to s[2j + 1] and s[2j + 2] --> need to be adjusted.
    *  - x11 and x13 are still share stride of s.
    *  - x15 points to sum + 32 (output) --> need to be adjusted to sum.
    *  - x16 is still share stride of sum.
    *  - x17 points to sum (cin).
    *  - x29 is still share stride of sum.
    *  - x30 points to s[j] (cout) --> need to be adjusted to s[j + 1].
    *  - x31 is still share stride of s. */
    /* Adjust addresses. */
    addi x10, x10, 32 /* s[2 * (j + 1)] */
    addi x12, x12, 32 /* s[2 * (j + 1) + 1] */
    addi x15, x15, -32 /* sum */
    addi x30, x30, 32 /* s[j + 1] */
  endloop

  /* Copy sum to ptr_tmp[1]. */
  addi x5, x2, 0 /* ptr_tmp[1] */
  loopi 2, 4
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(x15++) /* x15 still points to sum. */
    bn.sid x0, 0(x5)
    addi   x5, x5, 384
  endloop

  /*----------------------- Iteration i = 2, l = eta -----------------------*/
  addi x5, x0, 2
  beq  x18, x5, _cbd_eta_2
  /* Since l mod 2 = 1 if eta = 3, we compute sum = s[l] = s[3]. */
  addi x5, x22, 0 /* ptr_sum */
  addi x6, x21, 0 /* ptr_s */
  addi x6, x6, 64 /* 2 * 32 */
  slli x4, x18, 6 /* (2 * eta) * 32 */
  loopi 2, 4
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(x6)
    bn.sid x0, 0(x5++)
    add    x6, x6, x4
  endloop
  beq x0, x0, _continue_1

_cbd_eta_2:
  /* Since l mod 2 = 0 if eta = 2, we clear the carry sum. */
  addi   x5, x22, 0 /* ptr_sum */
  bn.xor w0, w0, w0
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop

_continue_1:
  /* l >> 1: loop j = 1,...,l // 2 --> 1 iteration. */
  /* Inputs to secfulladder. */
  slli x5, x18, 6
  addi x10, x21, 0 /* s[0] */
  addi x11, x5, 0
  addi x12, x21, 32 /* s[1] */
  addi x13, x5, 0
  addi x15, x22, 0 /* ptr_sum = r */
  addi x16, x0, 32
  addi x17, x22, 0 /* ptr_sum = cin */
  addi x29, x0, 32
  addi x30, x21, 0 /* s[0] = cout */
  addi x31, x5, 0
  /* Compute c, s[j] = secfulladder(s[2j], s[2j + 1], c). */
  /* x10 already points to s[2j] */
  /* x11 is already share stride of s. */
  /* x12 already points to s[2j + 1] */
  /* x13 is already share stride of s. */
  /* x15 already points to sum = r. */
  /* x16 is already share stride of sum = r. */
  /* x17 already points to sum = cin. */
  /* x29 is already share stride of sum = cin. */
  /* x30 already points to s[j] = cout. */
  /* x31 is already share stride of s = cout. */
  jal  x1, secfulladder
  /* After secfulladder:
  *  - x10 and x12 points to s[2j + 1] and s[2j + 2] --> need to be adjusted.
  *  - x11 and x13 are still share stride of s.
  *  - x15 points to sum + 32 (output) --> need to be adjusted to sum.
  *  - x16 is still share stride of sum.
  *  - x17 points to sum (cin).
  *  - x29 is still share stride of sum.
  *  - x30 points to s[j] (cout) --> need to be adjusted to s[j + 1].
  *  - x31 is still share stride of s. */

  /* Copy sum to ptr_tmp[2]. */
  addi x5, x2, 32 /* ptr_tmp[2] */
  loopi 2, 4
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(x17++) /* x17 still points to sum. */
    bn.sid x0, 0(x5)
    addi   x5, x5, 384
  endloop

  /*----------------------- Iteration i = 3, l = eta / 2 -----------------------*/
  /* Since l mod 2 = 1, we compute tmp[3] = s[l] = s[1]. */
  addi x5, x2, 0 /* ptr_tmp */
  addi x5, x5, 64
  addi x6, x21, 0 /* ptr_s */
  slli x7, x18, 6

  loopi 2, 5
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(x6)
    bn.sid x0, 0(x5)
    add    x6, x6, x7
    addi   x5, x5, 384
  endloop

  /* Clear bit k --> 12 of tmp. */
  addi   x5, x2, 0 /* ptr_tmp */
  addi   x5, x5, 96
  bn.xor w0, w0, w0
  loopi 2, 3
    loopi 9, 1
      bn.sid x0, 0(x5++)
    endloop
    addi x5, x5, 96 /* point to next share. */
  endloop

  /* Compute r = secb2amodq(tmp). */
  addi x10, x2, 0 /* ptr_tmp */
  addi x12, x20, 0 /* ptr_r */
  jal  x1, secb2amodq

  /* Compute r[0] = r[0] - eta mod q. */
  addi   x5, x20, 0 /* ptr_r */
  addi   x6, x21, 0 /* ptr_s */
  sw     x18, 0(x6)
  bn.lid x0, 0(x6)
  loopi 16, 1
    bn.rshi w1, w0, w1 >> 16
  endloop
  loopi 16, 3
    bn.lid       x0, 0(x5)
    bn.subvm.16h w0, w0, w1
    bn.sid       x0, 0(x5++)
  endloop

  /* Restore registers and stack. */
  lw x8, 1216(x2)
  lw x9, 1220(x2)
  lw x18, 1224(x2)
  lw x20, 1228(x2)
  lw x21, 1232(x2)
  lw x22, 1236(x2)
  addi x2, x2, 1248
  ret


/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA

/**
 * Initialization of the SHAKE-256 operation for masked_poly_getnoise_eta_{1,2}.
 *
 * Configure a SHAKE-256 operation for a 33-byte message and absorb
 * seed || nonce, so that a subsequent call to `masked_poly_getnoise_eta_1`
 * or `masked_poly_getnoise_eta_2` can squeeze the bytes it samples from.
 * The seed is Boolean-shared across two 32-byte shares; the nonce is
 * public, so its second share is zero.
 *
 * @param[in]  x10: dmem pointer to the seed
 * @param[in]  x11: dmem pointer to the nonce
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x5 to x6, x10, w0
 * clobbered flag groups: FG0
 */

.globl masked_poly_getnoise_eta_init
.type masked_poly_getnoise_eta_init, @function
masked_poly_getnoise_eta_init:
  /* Initialize a SHAKE256 operation. */
  addi  x5, x0, 33
  slli  x5, x5, 5
  addi  x5, x5, SHAKE256_CFG
  addi  x6, x0, 1
  slli  x6, x6, 20
  add   x5, x5, x6
  csrrw x0, kmac_cfg, x5

  /* Send the message to the Keccak core. */
  bn.xor  w0, w0, w0 /* Whitening. */
  bn.lid  x0, 0(x10++)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0 /* Whitening. */
  bn.lid  x0, 0(x10++)
  bn.wsrw kmac_msg1, w0
  li      x5, 1
  csrrw   x0, kmac_partial_write, x5
  bn.lid  x0, 0(x11)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.wsrw kmac_msg1, w0

  ret

/**
 * Sampling of a masked polynomial from the centered binomial distribution
 * with parameter KYBER_ETA2.
 *
 * Deterministically sample a polynomial whose coefficients follow a centered
 * binomial distribution with parameter eta = KYBER_ETA2, and assume that
 * `masked_poly_getnoise_eta_init` has been called beforehand with the
 * appropriate seed and nonce. Since KYBER_ETA2 = 2 for every parameter set,
 * callers pass eta = 2, and this entry point falls through into
 * masked_poly_getnoise_eta_1.
 *
 * On return, x10 holds the eta it was called with and x11 has been advanced
 * by one polynomial (512 bytes).
 *
 * @param[in]  x10: eta, always 2
 * @param[out] x11: dmem pointer to arithmetic shares of r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x22, x28 to x31, w0 to w30, acch, acc
 * clobbered flag groups: FG0
 */

.globl masked_poly_getnoise_eta_2
.type masked_poly_getnoise_eta_2, @function
masked_poly_getnoise_eta_2:

/**
 * Sampling of a masked polynomial from the centered binomial distribution
 * with parameter KYBER_ETA1.
 *
 * Deterministically sample a polynomial whose coefficients follow a centered
 * binomial distribution with parameter eta = KYBER_ETA1, which is 3 for
 * KYBER_K = 2 and 2 for KYBER_K = 3 and KYBER_K = 4. Assumes that
 * `masked_poly_getnoise_eta_init` has been called beforehand with the
 * appropriate seed and nonce.
 *
 * On return, x10 holds the eta it was called with and x11 has been advanced
 * by one polynomial (512 bytes).
 *
 * @param[in]  x10: eta in {2, 3}
 * @param[out] x11: dmem pointer to arithmetic shares of r
 * @param[in]  w16 (sw0): sw0.0 = q = 3329 (1st 16-bit lane),
 *                        sw0.2 = -q^-1 mod 2^16 = 3327 (3rd 16-bit lane)
 * @param[in]  w31: all-zero register
 * @param[in]  mod: q = 3329
 *
 * clobbered registers: x2, x4 to x22, x28 to x31, w0 to w30, acch, acc
 * clobbered flag groups: FG0
 */

.globl masked_poly_getnoise_eta_1
.type masked_poly_getnoise_eta_1, @function
masked_poly_getnoise_eta_1:
  /* Frame: ptr_y at 0, ptr_x at 192 (each 2 * eta * 32, sized for the worst
   * case eta = 3), saved registers at 384. */
  addi x2, x2, -416
  sw   x8, 384(x2)
  sw   x9, 388(x2)
  sw   x18, 392(x2)
  sw   x19, 396(x2)
  addi x8, x10, 0
  addi x9, x11, 0
  addi x18, x2, 192 /* ptr_x */

  addi x4, x0, 3
  bne  x10, x4, _getnoise_eta_2

  addi x5, x2, 0 /* ptr_y */

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
    bn.sid x4, 0(x18++)
    addi   x4, x4, 1
  endloop
  loopi 3, 2
    bn.sid x4, 0(x5++)
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
    bn.sid x4, 0(x18++)
    addi   x4, x4, 1
  endloop
  loopi 3, 2
    bn.sid x4, 0(x5++)
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

  addi x5, x0, 25
  addi x6, x0, 17
  addi x7, x0, 26
  addi x28, x2, 0 /* ptr_y */
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
      bn.movr x5, x6
      loopi 4, 5
        loopi 16, 2
          bn.rshi w26, w25, w26 >> 16
          bn.rshi w25, w31, w25 >> 4
        endloop
        bn.movr x4, x7
        addi    x4, x4, -1
      endloop
      addi x6, x6, 1
    endloop

    jal x1, _bitslice_transpose

    bn.sid x0, 0(x18++)
    addi   x4, x0, 1
    bn.sid x4, 0(x18++)
    addi   x4, x4, 1
    bn.sid x4, 0(x28++)
    addi   x4, x4, 1
    bn.sid x4, 0(x28++)
  endloop

_getnoise_common:
  /* Compute r = masked_cbd(x, y, eta). */
  addi x10, x2, 192 /* ptr_x */
  addi x11, x2, 0 /* ptr_y */
  addi x12, x8, 0 /* eta */
  addi x14, x9, 0 /* ptr_r */
  jal  x1, masked_cbd

  /* Restore inputs. */
  addi x10, x8, 0
  /* We want to point r to the next polynomial for next cbd. */
  addi x11, x9, 512

  /* Restore registers and stack. */
  lw   x8, 384(x2)
  lw   x9, 388(x2)
  lw   x18, 392(x2)
  lw   x19, 396(x2)
  addi x2, x2, 416
  ret

/**
 * Bitslicing of the SHAKE-256 digests for eta = 3.
 *
 * Split the six digest words in w17 to w22 into the 3 x and 3 y bit-planes
 * that masked_cbd consumes, one share per call. Called by
 * masked_poly_getnoise_eta_1 on the KYBER_K = 2 path.
 *
 * @param[in]     x7: dmem pointer to const_zero
 * @param[in,out] x10: dmem pointer to the x bit-planes
 * @param[in,out] x11: dmem pointer to the y bit-planes
 * @param[in]     w17 to w22: the six digest words to bitslice
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x4, x10 to x11, w0 to w15, w17 to w22, w28 to w29
 * clobbered flag groups: FG0
 */

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

/**
 * First-order masked compression of a polynomial to a message.
 *
 * Return Boolean shares of r = Compressq(x, 1) = round((2 / q) * x) mod 2, the
 * one-bit message compression, given arithmetic shares mod q of x.
 * Bitsliced.
 *
 * Each share is compressed to 1 + alpha bits, recombined (seca2b), then the low
 * alpha bits dropped. The alpha extra bits absorb the per-share rounding error
 * (2^alpha > q * nshares); nshares = 2 gives 1 + alpha = 16 (alpha = 15).
 *
 *   z_0  <- Compressq(x_0, 1 + alpha) + 2^(alpha - 1)
 *   z_1  <- Compressq(x_1, 1 + alpha)
 *   c    <- seca2b(z)
 *   r    <- c >> alpha
 *
 * Source: Alg.2 [CGMZ21b]
 *
 * @param[in]  x10: dmem pointer to arithmetic shares of x
 * @param[out] x12: dmem pointer to bitsliced compressed output r
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x2 to x8, x10 to x17, x28 to x31, w0 to w15, w17 to w21, w28 to w29
 * clobbered flag groups: FG0
 */

.globl masked_poly_tomsg
.type masked_poly_tomsg, @function
masked_poly_tomsg:
  /* Allocate y[0], y[1] scratch and save callee-saved registers. */
  addi x2, x2, -1056
  sw   x8, 1024(x2)
  addi x8, x12, 0

  /* Load all constants. */
  addi      x4, x0, 17
  la        x5, const_m_dv
  bn.lid    x4++, 0(x5)
  la        x5, modulus_over_2
  bn.lid    x4++, 0(x5)
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
  addi x5, x0, 21
  addi x6, x2, 0 /* ptr_y */

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
      bn.lid             x0, 0(x10++)
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
      bn.movr            x4, x5
      addi               x4, x4, -1
    endloop

    jal x1, _bitslice_transpose

    add x4, x0, x0
    loopi 16, 2
      bn.sid x4, 0(x6++)
      addi   x4, x4, 1
    endloop

    /* Clear the offset; only share 0 carries 2**(alpha - 1). */
    bn.xor w19, w19, w19
  endloop

  /* Compute z = seca2b(y, k = 1 + alpha, share bytes = k * 32). */
  addi x10, x2, 0 /* ptr_y */
  addi x11, x0, 16 /* 1 + alpha */
  addi x12, x0, 512
  addi x14, x2, 0 /* ptr_z */
  jal  x1, seca2b

  /* Compute z >>= alpha, i.e. keep only bit z[alpha], the message bit. */
  addi x5, x2, 0 /* ptr_z */
  addi x5, x5, 480 /* skip to bit-plane alpha = 15 */
  addi x6, x8, 0 /* ptr_r */
  loopi 2, 4
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.lid x0, 0(x5++)
    bn.sid x0, 0(x6++)
    /* Advance to bit-plane alpha of the next share. */
    addi x5, x5, 480
  endloop

  /* Restore registers. */
  lw   x8, 1024(x2)
  addi x2, x2, 1056
  ret

#define N_COEFFS 16

/**
 * First-order masked comparison of a polynomial compressed with dv in {4, 5}.
 *
 * For every coefficient of the polynomial, AND into r a 1 if
 * Compressq(c', dv) == c, else a 0. Here dv = 5 for k = 4, and 4 otherwise.
 * Bitsliced.
 *
 * Source: Section 6.2 [BC22]
 *
 * @param[in]     x10: dmem pointer to arithmetic shares of c'
 * @param[in]     x11: dmem pointer to reference compressed polynomial c
 * @param[in]     x12: share stride of compressed c', i.e. dv * 32
 * @param[in,out] x14: dmem pointer to Boolean shares of r, which must
 *                     hold all-ones on entry
 * @param[in]     x15: k, the security level
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x2 to x20, x28 to x31, w0 to w15, w17 to w21, w28 to w29
 * clobbered flag groups: FG0
 */

.globl poly_masked_compare_dv
.type poly_masked_compare_dv, @function
poly_masked_compare_dv:
  /* Allocate t scratch (2 shares * 160 B, dv = 5 worst case) + saves. */
  addi x2, x2, -352
  sw   x8, 324(x2)
  sw   x9, 328(x2)
  sw   x18, 332(x2)
  sw   x20, 340(x2)
  sw   x15, 344(x2)

  /* Save input/output addresses. */
  addi x8, x10, 0
  addi x9, x11, 0
  addi x18, x12, 0
  addi x20, x14, 0

  /* Compute t = poly_hocompress(cprime). */
  addi x10, x8, 0 /* ptr_cprime */
  addi x12, x2, 0 /* ptr_t */
  addi x13, x15, 0 /* k */
  jal  x1, poly_hocompress

  /* Decode + bitslice c. */
  addi x11, x9, 0 /* ptr_c */

  addi x4, x0, 4
  lw   x15, 344(x2)
  bne  x15, x4, _handle_kn4_dv

_handle_k4_dv:
  addi   x4, x0, 17
  bn.lid x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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

  addi    x9, x0, 5
  beq     x0, x0, _handle_common_dv

_handle_kn4_dv:
  addi x4, x0, 17
  bn.lid x4, 0(x11++)
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
  bn.lid x4, 0(x11++)
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
  bn.lid x4, 0(x11++)
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
  bn.lid x4, 0(x11++)
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

  addi    x9, x0, 4

_handle_common_dv:
  /* t[0] ^= c ^ ((1 << N) - 1):  c-planes are now w0..w3 if x9 != 4 else w0..w4. */
  bn.subi w15, w31, 1
  addi    x5, x2, 0 /* ptr_t */

  bn.lid  x4, 0(x5)
  bn.xor  w0, w0, w15
  bn.xor  w17, w17, w0
  bn.sid  x4, 0(x5++)

  bn.lid  x4, 0(x5)
  bn.xor  w1, w1, w15
  bn.xor  w17, w17, w1
  bn.sid  x4, 0(x5++)

  bn.lid  x4, 0(x5)
  bn.xor  w2, w2, w15
  bn.xor  w17, w17, w2
  bn.sid  x4, 0(x5++)

  bn.lid  x4, 0(x5)
  bn.xor  w3, w3, w15
  bn.xor  w17, w17, w3
  bn.sid  x4, 0(x5++)

  addi    x6, x0, 4
  beq     x9, x6, _skip_bit_4

  bn.lid  x4, 0(x5)
  bn.xor  w4, w4, w15
  bn.xor  w17, w17, w4
  bn.sid  x4, 0(x5++)

_skip_bit_4:
  /* Compute r = secand(r, t). */
  addi x11, x0, 32
  addi x12, x2, 0 /* ptr_t */
  addi x13, x18, 0 /* share_str */
  addi x16, x0, 32 /* output share_str */
  /* After the secand, the input and output pointers will point to
   * next bit so we don't have to pass all the arguments above to secand again. */
  loop x9, 4
    addi x10, x20, 0 /* ptr_r */
    addi x15, x20, 0 /* ptr_r */
    jal  x1, secand
    nop
  endloop

  /* Restore registers. */
  lw   x8, 324(x2)
  lw   x9, 328(x2)
  lw   x18, 332(x2)
  lw   x20, 340(x2)
  lw   x15, 344(x2)
  addi x2, x2, 352
  ret

/**
 * First-order masked comparison of a polynomial compressed with du in {10, 11}.
 *
 * For every coefficient of the polynomial, AND into r a 1 if
 * Compressq(c', du) == c, else a 0. Here du = 11 for k = 4, and 10 otherwise.
 * Bitsliced.
 *
 * Source: Section 6.2 [BC22]
 *
 * @param[in]     x10: dmem pointer to arithmetic shares of c'
 * @param[in]     x11: dmem pointer to reference compressed polynomial c
 * @param[in]     x12: share stride of compressed c', i.e. du * 32
 * @param[in,out] x14: dmem pointer to Boolean shares of r, which must
 *                     hold all-ones on entry
 * @param[in]     x15: k, the security level
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x2 to x20, x28 to x31, w0 to w15, w17 to w21, w28 to w30, acc
 * clobbered flag groups: FG0
 */

.globl poly_masked_compare_du
.type poly_masked_compare_du, @function
poly_masked_compare_du:
  /* Allocate t scratch (2 shares * 352 B, du = 11 worst case) + saves. */
  addi x2, x2, -736
  sw   x8, 708(x2)
  sw   x9, 712(x2)
  sw   x18, 716(x2)
  sw   x20, 724(x2)
  sw   x15, 728(x2)

  /* Save input/output addresses. */
  addi x8, x10, 0
  addi x9, x11, 0
  addi x18, x12, 0
  addi x20, x14, 0

  /* Compute t = poly_hocompress(cprime). */
  addi x10, x8, 0 /* ptr_cprime */
  addi x12, x2, 0 /* ptr_t */
  addi x13, x15, 0 /* k */
  jal  x1, polyvec_hocompress

  /* Decode + bitslice c. */
  addi x11, x9, 0 /* ptr_c */

  addi x4, x0, 4
  lw   x15, 728(x2)
  bne  x15, x4, _handle_kn4_du

_handle_k4_du:
  /* group 0 -> w15 */
  addi   x4, x0, 17
  bn.lid x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  bn.lid  x4, 0(x11++)
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
  
  addi x9, x0, 11 /* du */
  beq  x0, x0, _handle_common_du

_handle_kn4_du:
  addi x4, x0, 17
  addi x5, x0, 15
  addi x6, x0, 18
  loopi 2, 69
    /* group i + 0 */
    bn.lid x4, 0(x11++)
    loopi 16, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 1 */
    loopi 9, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.rshi w18, w17, w18 >> 6
    bn.lid  x4, 0(x11++)
    bn.rshi w18, w17, w18 >> 10
    bn.rshi w17, w31, w17 >> 4
    loopi 6, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 2 */
    loopi 16, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 3 */
    loopi 3, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.rshi w18, w17, w18 >> 2
    bn.lid  x4, 0(x11++)
    bn.rshi w18, w17, w18 >> 14
    bn.rshi w17, w31, w17 >> 8
    loopi 12, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 4 */
    loopi 12, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.rshi w18, w17, w18 >> 8
    bn.lid  x4, 0(x11++)
    bn.rshi w18, w17, w18 >> 8
    bn.rshi w17, w31, w17 >> 2
    loopi 3, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 5 */
    loopi 16, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 6 */
    loopi 6, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.rshi w18, w17, w18 >> 4
    bn.lid  x4, 0(x11++)
    bn.rshi w18, w17, w18 >> 12
    bn.rshi w17, w31, w17 >> 6
    loopi 9, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
    
    /* group i + 7 */
    loopi 16, 2
      bn.rshi w18, w17, w18 >> 16
      bn.rshi w17, w31, w17 >> 10
    endloop
    bn.movr x5, x6
    addi    x5, x5, -1
  endloop
  jal x1, _bitslice_transpose
    
  addi x9, x0, 10 /* du */

_handle_common_du:
  /* t[0] ^= c ^ ((1 << N) - 1):  c-planes are now w0..w9. */
  bn.subi w15, w31, 1
  addi    x5, x2, 0 /* ptr_t */

  bn.lid x4, 0(x5)
  bn.xor w0, w0, w15
  bn.xor w17, w17, w0
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w1, w1, w15
  bn.xor w17, w17, w1
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w2, w2, w15
  bn.xor w17, w17, w2
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w3, w3, w15
  bn.xor w17, w17, w3
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w4, w4, w15
  bn.xor w17, w17, w4
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w5, w5, w15
  bn.xor w17, w17, w5
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w6, w6, w15
  bn.xor w17, w17, w6
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w7, w7, w15
  bn.xor w17, w17, w7
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w8, w8, w15
  bn.xor w17, w17, w8
  bn.sid x4, 0(x5++)

  bn.lid x4, 0(x5)
  bn.xor w9, w9, w15
  bn.xor w17, w17, w9
  bn.sid x4, 0(x5++)

  addi   x6, x0, 10
  beq    x9, x6, _skip_bit_10

  bn.lid x4, 0(x5)
  bn.xor w10, w10, w15
  bn.xor w17, w17, w10
  bn.sid x4, 0(x5++)

_skip_bit_10:
  /* Compute r = secand(r, t). */
  addi x11, x0, 32
  addi x12, x2, 0 /* ptr_t */
  addi x13, x18, 0 /* share_str */
  addi x16, x0, 32 /* output share_str */
  /* After the secand, the input and output pointers will point to
   * next bit so we don't have to pass all the arguments above to secand again. */
  loop x9, 4
    addi x10, x20, 0 /* ptr_r */
    addi x15, x20, 0 /* ptr_r */
    jal  x1, secand
    nop
  endloop

  /* Restore registers. */
  lw   x8, 708(x2)
  lw   x9, 712(x2)
  lw   x18, 716(x2)
  lw   x20, 724(x2)
  lw   x15, 728(x2)
  addi x2, x2, 736
  ret

/**
 * First-order reduction of the masked comparison result to a single bit.
 *
 * Reduce the masked_poly_compare_{du, dv} output in place to Boolean shares of
 * the single comparison bit.
 * Bitsliced.
 *
 * Source: Section 6.2 [BC22]
 *
 * @param[in,out] x10: dmem pointer to Boolean shares of r, the output
 *                     of masked_poly_compare_{du, dv}
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x13, x15 to x16, w0 to w3, w5 to w8
 * clobbered flag groups: FG0
 */

.globl finalize_cmp
.type finalize_cmp, @function
finalize_cmp:
  /* Allocate t scratch (2 shares * 32 B) and save x8. */
  addi x2, x2, -96
  sw x8, 68(x2)

  /* Save the in/out address. */
  addi x8, x10, 0

  /* Compute x &= (x >> 128). */
  /* Compute t = x >> 128. */
  addi x4, x0, 1
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 128
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  addi x11, x0, 32
  addi x12, x2, 0
  addi x13, x0, 32
  addi x15, x8, 0
  addi x16, x0, 32
  jal  x1, secand

  /* Compute x &= (x >> 64). */
  /* Compute t = x >> 64. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 64
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Compute x &= (x >> 32). */
  /* Compute t = x >> 32. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 32
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Compute x &= (x >> 16). */
  /* Compute t = x >> 16. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 16
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Compute x &= (x >> 8). */
  /* Compute t = x >> 8. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 8
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Compute x &= (x >> 4). */
  /* Compute t = x >> 4. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 4
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Compute x &= (x >> 2). */
  /* Compute t = x >> 2. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 2
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Compute x &= (x >> 1). */
  /* Compute t = x >> 1. */
  addi x4, x0, 1
  addi x10, x8, 0
  addi x5, x2, 0 /* ptr_t */
  loopi 2, 5
    /* Whitening. */
    bn.xor  w0, w0, w0
    bn.xor  w1, w1, w1
    bn.lid  x0, 0(x10++)
    bn.rshi w1, w31, w0 >> 1
    bn.sid  x4, 0(x5++)
  endloop
  /* Compute x &= t. */
  addi x10, x8, 0
  /* x11 is still 32. */
  addi x12, x2, 0
  /* x13 is still 32. */
  addi x15, x8, 0
  /* x16 is still 32. */
  jal  x1, secand

  /* Restore x8. */
  lw x8, 68(x2)

  addi x2, x2, 96
  ret
