/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* KMAC mode config for the SHAKE-256 XOF used by the masked samplers. */
#define SHAKE256_CFG 0xa


/*
 * Bibliography
 *
 * [ABCH+23] Melissa Azouaoui, Olivier Bronchain, Gaetan Cassiers, Clement
 *           Hoffmann, Yulia Kuzovkova, Joost Renes, Tobias Schneider, Markus
 *           Schonauer, Francois-Xavier Standaert, Christine van Vredendaal
 *           "Protecting Dilithium against Leakage: Revisited Sensitivity
 *           Analysis and Improved Implementations"
 *           https://tches.iacr.org/index.php/TCHES/article/view/11158
 * [BC22]    Olivier Bronchain, Gaetan Cassiers
 *           "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and
 *           Profit: with Application to Lattice-Based KEMs"
 *           https://tches.iacr.org/index.php/TCHES/article/view/9831
 * [CGMZ23]  Jean-Sebastien Coron, Francois Gerard, Simon Montoya, Rina Zeitoun
 *           "High-order Polynomial Comparison and Masking Lattice-based
 *           Encryption"
 *           https://eprint.iacr.org/2021/1615
 * [CS20]    Gaetan Cassiers, Francois-Xavier Standaert
 *           "Trivially and Efficiently Composing Masked Gadgets With Probe
 *           Isolating Non-Interference"
 *           https://ieeexplore.ieee.org/document/8979162/
 */

/**
 * secand
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
 * @param[in]  x15: share stride, distance between shares of r
 * @param[out] x16: dptr_rb, dmem pointer to Boolean shares of r
 *
 * clobbered registers: x4 to x7, x28 to x30, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secand
.type secand, @function
secand:
  addi x4, x0, 1
  addi x5, x0, 2
  addi x6, x0, 3
  addi x7, x0, 4
  addi x28, x0, 5
  addi x29, x0, 6

  /* Compute tb[0] = xb[0] & yb[0]. */
  /* Whitening. */
  bn.xor w1, w1, w1
  bn.xor w3, w3, w3
  bn.xor w5, w5, w5
  bn.lid x4, 0(x10) /* w1 = xb[0] */
  bn.lid x6, 0(x12) /* w3 = yb[0] */
  bn.and w5, w1, w3 /* w5 = tb[0] */

  /* Compute tb[1] = xb[1] & yb[1]. */
  /* Whitening. */
  bn.xor w2, w2, w2
  bn.xor w4, w4, w4
  bn.xor w6, w6, w6
  add    x30, x10, x11
  bn.lid x5, 0(x30) /* w2 = xb[1] */
  add    x30, x12, x13
  bn.lid x7, 0(x30) /* w4 = yb[1] */
  bn.and w6, w2, w4 /* w6 = tb[1] */

  /* Refresh with one fresh random. */
  bn.wsrr w0, URND /* w0 = r */

  /* Handle wzij. */
  bn.xor w7, w4, w0 /* wtmp1 = yb[j] ^ r */
  bn.and w7, w7, w1 /* wtmp1 &= xb[i] */
  bn.not w8, w1     /* wtmp0 = xb[i] ^ 1 */
  bn.and w8, w8, w0 /* wtmp0 &= r */
  bn.xor w8, w8, w7 /* wtmp0 ^= wtmp1 */
  bn.xor w5, w5, w8 /* tb[0] ^= wtmp0 */

  /* Whitening. */
  bn.xor w7, w7, w7
  bn.xor w8, w8, w8

  /* Handle wzji. */
  bn.xor w7, w3, w0 /* wtmp1 = yb[i] ^ r */
  bn.and w7, w7, w2 /* wtmp1 &= xb[j] */
  bn.not w8, w2     /* wtmp0 = xb[j] ^ 1 */
  bn.and w8, w8, w0 /* wtmp0 &= r */
  bn.xor w8, w8, w7 /* wtmp0 ^= wtmp1 */
  bn.xor w6, w6, w8 /* tb[1] ^= wtmp0 */

  /* Copy tb to rb. */
  bn.sid x28, 0(x16) /* rb[0] = tb[0] */
  add    x30, x16, x15
  bn.sid x29, 0(x30) /* rb[1] = tb[1] */

  ret

/**
 * secfulladder
 *
 * Return Boolean shares of the sum bit (r0) and carry-out bit (r1) of
 * x + y + c, given Boolean shares of x, y, and the incoming carry c.
 * Bitsliced.
 *
 *   a   <- x ^ y                 (sharewise)
 *   r0  <- a ^ c                 (sharewise; sum bit)
 *   r1  <- x ^ SecAnd(a, x ^ c)  (carry bit)
 *
 * Source: Alg.5 [BC22]
 *
 * @param[inout] x10: dptr_x, dmem pointer to Boolean shares of x (advanced by 32)
 * @param[inout] x11: dptr_y, dmem pointer to Boolean shares of y (advanced by 32)
 * @param[in]    x12: dptr_c, dmem pointer to Boolean shares of c
 * @param[in]    x13: share stride for x, y, and r0; c and r1 use stride 32
 * @param[inout] x15: dptr_r0, dmem pointer to Boolean shares of r0 (advanced by 32)
 * @param[out]   x16: dptr_r1, dmem pointer to Boolean shares of r1
 *
 * clobbered registers: x4 to x7, x10 to x11, x15, x28 to x31, w0 to w10
 * clobbered flag groups: FG0
 */
.globl secfulladder
.type secfulladder, @function
secfulladder:
  /* WDR index constants. */
  addi x4, x0, 1  /* w1 = x[0] */
  addi x5, x0, 2  /* w2 = x[1] */
  addi x6, x0, 3  /* w3 = a[0] (= x[0] ^ y[0]) */
  addi x7, x0, 4  /* w4 = a[1] */
  addi x28, x0, 5 /* w5 = c[0] then t[0] */
  addi x29, x0, 6 /* w6 = c[1] then t[1] */
  addi x31, x0, 0 /* w0 = scratch (rand + write temp) */

  /* Load share 0: x[0] -> w1, a[0] -> w3, c[0] -> w5. */
  bn.xor w1, w1, w1
  bn.xor w3, w3, w3
  bn.xor w5, w5, w5
  bn.lid x4, 0(x10)  /* w1 = x[0] */
  bn.lid x6, 0(x11)  /* w3 = y[0] */
  bn.xor w3, w1, w3  /* w3 = a[0] = x[0] ^ y[0] */
  bn.lid x28, 0(x12) /* w5 = c[0] */

  /* Load share 1: x[1] -> w2, a[1] -> w4, c[1] -> w6. */
  bn.xor w2, w2, w2
  bn.xor w4, w4, w4
  bn.xor w6, w6, w6
  add    x30, x10, x13
  bn.lid x5, 0(x30)   /* w2 = x[1] */
  add    x30, x11, x13
  bn.lid x7, 0(x30)   /* w4 = y[1] */
  bn.xor w4, w2, w4   /* w4 = a[1] = x[1] ^ y[1] */
  addi   x30, x12, 32 /* c shares are at stride 32 (caller's stack-scratch layout) */
  bn.lid x29, 0(x30)  /* w6 = c[1] */

  /* Compute r[0] = c ^ a. */
  bn.xor w0, w0, w0 /* Whitening. */
  bn.xor w0, w5, w3 /* w0 = r[0][0] = c[0] ^ a[0] */
  bn.sid x31, 0(x15)
  bn.xor w0, w0, w0 /* Whitening. */
  bn.xor w0, w6, w4 /* w0 = r[0][1] */
  add    x30, x15, x13
  bn.sid x31, 0(x30)

  /* Compute t = x ^ c (overwrites c slots w5, w6). */
  bn.xor w5, w1, w5 /* w5 = t[0] = x[0] ^ c[0] */
  bn.xor w6, w2, w6 /* w6 = t[1] = x[1] ^ c[1] */

  /* Inlined secand: tb = a & t. */
  bn.xor w7, w7, w7
  bn.and w7, w3, w5 /* tb[0] = a[0] & t[0] */
  bn.xor w8, w8, w8
  bn.and w8, w4, w6 /* tb[1] = a[1] & t[1] */

  bn.wsrr w0, URND /* w0 = r (fresh randomness) */

  /* Pair (i, j) = (0, 1). */
  bn.xor w9,  w6, w0  /* wtmp1 = t[1] ^ r */
  bn.and w9,  w9, w3  /* wtmp1 &= a[0] */
  bn.not w10, w3      /* wtmp0 = ~a[0] */
  bn.and w10, w10, w0 /* wtmp0 &= r */
  bn.xor w10, w10, w9 /* wtmp0 ^= wtmp1 */
  bn.xor w7,  w7, w10 /* tb[0] ^= wtmp0 */

  /* Pair (i, j) = (1, 0). */
  bn.xor w9,  w5, w0  /* wtmp1 = t[0] ^ r */
  bn.and w9,  w9, w4  /* wtmp1 &= a[1] */
  bn.not w10, w4      /* wtmp0 = ~a[1] */
  bn.and w10, w10, w0 /* wtmp0 &= r */
  bn.xor w10, w10, w9 /* wtmp0 ^= wtmp1 */
  bn.xor w8,  w8, w10 /* tb[1] ^= wtmp0 */

  /* tb[0..1] now holds the secand output (= new t[0..1]). */

  /* Compute r[1] = x ^ t. */
  bn.xor w0, w0, w0   /* Whitening. */
  bn.xor w0, w1, w7   /* w0 = r[1][0] = x[0] ^ t[0] */
  bn.sid x31, 0(x16)
  bn.xor w0, w0, w0   /* Whitening. */
  bn.xor w0, w2, w8   /* w0 = r[1][1] */
  addi   x30, x16, 32 /* r[1] (= output carry) is at stride 32 */
  bn.sid x31, 0(x30)

  /* Advance per the secadd bit loop's expectations. */
  addi x10, x10, 32
  addi x11, x11, 32
  addi x15, x15, 32
  /* x12, x13, x16 preserved. */

  ret

/**
 * secadd
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
 * @param[in]  x11: dptr_y, dmem pointer to Boolean shares of y
 * @param[in]  x12: k, bitsize of x and y
 * @param[in]  x13: share stride, distance between shares of x, y, and r
 * @param[out] x15: dptr_r, dmem pointer to Boolean shares of r
 *
 * clobbered registers: x2, x4 to x8, x10 to x12, x15 to x16, x28 to x31, w0 to w10
 * clobbered flag groups: FG0
 */
.globl secadd
.type secadd, @function
secadd:
  /* Reserve frame: 64 B carry c at 0(x2), saved x8 at 64(x2). */
  addi x2, x2, -96
  sw   x8, 64(x2)

  /* Initialize c = 0. */
  bn.xor w0, w0, w0
  addi   x5, x2, 0 /* ptr_c */
  loopi 2, 1
    bn.sid x0, 0(x5++)
  endloop

  /* Ripple-carry adder. */
  addi x8, x12, -1
  /* Loop over i = 0, ..., k-2. */
  loop x8, 4
    /* x10 already points to x[i] */
    /* x11 already points to y[i] */
    addi x12, x2, 0 /* ptr_c */
    /* x13 is already share stride. */
    /* x15 already points to r. */
    addi x16, x2, 0 /* ptr_c */
    jal  x1, secfulladder
    /* After secfulladder:
     *  - x10 and x11 points to x[i + 1] and y[i + 1].
     *  - x13 is still share stride.
     *  - x15 points to r[i + 1].
     *  - x16 points to c. */
    nop
  endloop

  /* Handle top bit i = k-1. */
  /* Compute r[k-1] = x[k-1] ^ y[k-1] ^ c. */
  addi x5, x2, 0 /* ptr_c */
  addi x4, x0, 1
  addi x6, x0, 2
  addi x7, x0, 3
  loopi 2, 13
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    /* Computation. */
    bn.lid x0, 0(x10)
    bn.lid x4, 0(x11)
    bn.lid x6, 0(x5++)
    bn.xor w3, w0, w1
    bn.xor w3, w3, w2
    bn.sid x7, 0(x15)
    /* Adjust addresses. */
    add    x10, x10, x13
    add    x11, x11, x13
    add    x15, x15, x13
  endloop

  /* Restore registers and stack. */
  lw   x8, 64(x2)
  addi x2, x2, 96
  ret

/**
 * secadd_immd_d1
 *
 * Bitsliced SecAdd for d = 1 of x and the hard-coded constant nq = 0x801fff
 * (= 2^24 - q), producing a (kbits + 1)-bit result.
 *
 * Source: Alg.6 [BC22]
 *
 * @param[in]   x10: dptr_x, kbits * 32 B
 * @param[in]   x12: kbits
 * @param[out]  x16: dptr_z, (kbits + 1) * 32 B
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x6, x10, x16, x29, x31, w0 to w8
 * clobbered flag groups: FG0
 */
.globl secadd_immd_d1
.type secadd_immd_d1, @function
secadd_immd_d1:
  li x6, 1
  li x29, 4

  bn.not w6, w31 /* w6 = all-ones */

  /* Build nq = 0x801fff in w7 lane 0 (= 2^23 + 2^13 - 1). */
  bn.xor    w7, w7, w7
  bn.addi   w7, w7, 1
  bn.shv.8s w7, w7 << 23 /* lane 0 = 0x800000 */
  bn.xor    w8, w8, w8
  bn.addi   w8, w8, 1
  bn.shv.8s w8, w8 << 13 /* w8 lane 0 = 0x2000 */
  bn.subi   w8, w8, 1    /* w8 lane 0 = 0x1fff */
  bn.add    w7, w7, w8   /* w7 lane 0 = 0x801fff */

  bn.xor  w8, w8, w8
  bn.addi w8, w8, 1 /* w8 = 1 (lane 0 bit 0) */

  /* Bit 0. */
  bn.xor  w0, w0, w0
  bn.xor  w1, w1, w1
  bn.xor  w2, w2, w2
  bn.xor  w3, w3, w3
  bn.lid  x6, 0(x10++)
  bn.and  w3, w7, w8
  bn.cmp  w3, w31
  bn.sel  w2, w31, w6, FG0.Z
  bn.rshi w7, w31, w7 >> 1
  bn.xor  w4, w1, w2
  bn.sid  x29, 0(x16++)
  bn.and  w0, w1, w2

  /* Bits 1..kbits-1. */
  addi x31, x12, -1
  loop x31, 11
    bn.lid  x6, 0(x10++)
    bn.and  w3, w7, w8
    bn.cmp  w3, w31
    bn.sel  w2, w31, w6, FG0.Z
    bn.rshi w7, w31, w7 >> 1
    bn.xor  w3, w1, w2
    bn.xor  w4, w3, w0
    bn.sid  x29, 0(x16++)
    bn.and  w5, w1, w2
    bn.and  w0, w0, w3
    bn.xor  w0, w0, w5
  endloop

  /* Final carry bit: z[kbits] = carry ^ y[kbits]. */
  bn.and w3, w7, w8
  bn.cmp w3, w31
  bn.sel w2, w31, w6, FG0.Z
  bn.xor w4, w0, w2
  bn.sid x29, 0(x16)

  ret

/**
 * secadd_immd_d2
 *
 * SecAdd of x with a public k-bit constant c in w17 lane 0:
 * z = (x + c) mod 2^k.
 *
 * Source: Alg.6 [BC22]
 *
 * @param[in]  x10: dptr_x, k * 2 * 32 B
 * @param[in]  x12: k, bitsize
 * @param[in]  x13: share stride (= k * 32)
 * @param[out] x15: dptr_z, k * 2 * 32 B
 * @param[in]  w17: lane-0 holds the constant
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x5 to x7, x10, x15, x28 to x31, w0 to w19
 * clobbered flag groups: FG0
 */
.globl secadd_immd_d2
.type secadd_immd_d2, @function
secadd_immd_d2:
  add x29, x10, x13 /* x29 = x share 1 ptr */
  add x30, x15, x13 /* x30 = z share 1 ptr */

  bn.not  w19, w31    /* w19 = all-ones */
  bn.xor  w18, w18, w18
  bn.addi w18, w18, 1 /* w18 = lane-0 bit 0 */

  bn.xor w12, w12, w12 /* c_0 = 0 */
  bn.xor w13, w13, w13 /* c_1 = 0 */

  li x5, 1   /* x_0 -> w1 */
  li x6, 2   /* x_1 -> w2 */
  li x7, 10  /* r_0 idx (= w10) */
  li x28, 11 /* r_1 idx (= w11) */

  addi x31, x12, 0
  loop x31, 39
    /* Derive y_bit. */
    bn.and  w0, w17, w18
    bn.cmp  w0, w31
    bn.sel  w3, w31, w19, FG0.Z
    bn.rshi w17, w31, w17 >> 1

    /* Share 0: a_0 = x_0 ^ y_bit, t_0 = x_0 ^ c_0, r_0 = c_0 ^ a_0. */
    bn.xor w1, w1, w1
    bn.lid x5, 0(x10)
    bn.xor w4, w1, w3
    bn.xor w6, w1, w12
    bn.xor w10, w12, w4
    bn.sid x7, 0(x15)

    bn.xor w0, w0, w0 /* Whitening. */

    /* Share 1: a_1 = x_1, t_1 = x_1 ^ c_1, r_1 = c_1 ^ a_1. */
    bn.xor w2, w2, w2
    bn.lid x6, 0(x29)
    bn.mov w5, w2
    bn.xor w7, w2, w13
    bn.xor w11, w13, w5
    bn.sid x28, 0(x30)

    /* SecAnd(a_0,a_1; t_0,t_1) -> (u_0, u_1). */
    bn.wsrr w14, URND
    bn.xor  w16, w7, w14
    bn.and  w16, w16, w4
    bn.not  w15, w4
    bn.and  w15, w15, w14
    bn.xor  w15, w15, w16
    bn.and  w8, w4, w6
    bn.xor  w8, w8, w15

    bn.xor w0, w0, w0 /* Whitening. */

    bn.xor w16, w6, w14
    bn.and w16, w16, w5
    bn.not w15, w5
    bn.and w15, w15, w14
    bn.xor w15, w15, w16
    bn.and w9, w5, w7
    bn.xor w9, w9, w15

    /* New carry: c = x ^ u. */
    bn.xor w12, w1, w8
    bn.xor w13, w2, w9

    /* Advance pointers. */
    addi x10, x10, 32
    addi x29, x29, 32
    addi x15, x15, 32
    addi x30, x30, 32
  endloop

  ret

/**
 * secadd_constant_bmsk
 *
 * Fused steps 5+6 of Alg.7 specialised for ML-DSA q, in place over dptr_z:
 *   z <- sp + BitCopyMask(sp[k], q)
 * Bitsliced.  q = 0x7fe001 is hard-coded, giving the per-bit run structure
 * (bit 0 + bits 1..12 + bits 13..22).  Bit k of z is zeroed on exit.
 *
 * Source: Alg.7 [BC22]
 *
 * @param[in]   x10: dptr_z, in/out ((k+1) * 2 * 32 bytes, bit k = 0 on exit)
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x5 to x7, x10 to x14, x28 to x31, w4 to w16, w20 to w23
 * clobbered flag groups: FG0
 */

/* WDR layout: w20/w21 = b[0]/b[1]; w22/w23 = carry[0]/[1]. */

.globl secadd_constant_bmsk
.type secadd_constant_bmsk, @function
secadd_constant_bmsk:
  /* WDR id registers. */
  li x5, 4
  li x6, 5
  li x7, 8
  li x28, 9
  li x29, 20
  li x30, 21
  li x31, 31

  addi x11, x10, 768 /* (k+1) * 32 */

  /* Load b = sp[k]; zero carry. */
  li     x12, 23 /* k */
  slli   x12, x12, 5
  add    x13, x10, x12
  add    x14, x11, x12
  bn.lid x29, 0(x13)
  bn.lid x30, 0(x14)
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23

  /* bit 0 (q=1) */
  bn.lid  x5, 0(x10)
  bn.lid  x6, 0(x11)
  bn.xor  w6, w4, w20  /* xpy = sp ^ b */
  bn.xor  w7, w5, w21
  bn.xor  w8, w22, w6  /* z = c ^ xpy */
  bn.xor  w9, w23, w7
  bn.sid  x7, 0(x10++)
  bn.sid  x28, 0(x11++)
  bn.xor  w10, w4, w22 /* xpc = sp ^ c */
  bn.xor  w11, w5, w23
  /* c' = sp ^ SecAnd(xpy, xpc). */
  bn.and  w12, w6, w10
  bn.and  w13, w7, w11
  bn.wsrr w14, URND
  bn.and  w15, w6, w11
  bn.xor  w15, w15, w14
  bn.and  w16, w7, w10
  bn.xor  w16, w16, w14
  bn.xor  w12, w12, w15
  bn.xor  w13, w13, w16
  bn.xor  w22, w4, w12
  bn.xor  w23, w5, w13

  /* bits 1..12 (q=0) */
  loopi 12, 15
    bn.lid  x5, 0(x10)
    bn.lid  x6, 0(x11)
    bn.xor  w8, w22, w4 /* z = c ^ sp */
    bn.xor  w9, w23, w5
    bn.sid  x7, 0(x10++)
    bn.sid  x28, 0(x11++)
    /* c' = SecAnd(c, sp). */
    bn.and  w12, w22, w4
    bn.and  w13, w23, w5
    bn.wsrr w14, URND
    bn.and  w15, w22, w5
    bn.xor  w15, w15, w14
    bn.and  w16, w23, w4
    bn.xor  w16, w16, w14
    bn.xor  w22, w12, w15
    bn.xor  w23, w13, w16
  endloop

  /* bits 13..22 (q=1) */
  loopi 10, 21
    bn.lid  x5, 0(x10)
    bn.lid  x6, 0(x11)
    bn.xor  w6, w4, w20  /* xpy = sp ^ b */
    bn.xor  w7, w5, w21
    bn.xor  w8, w22, w6  /* z = c ^ xpy */
    bn.xor  w9, w23, w7
    bn.sid  x7, 0(x10++)
    bn.sid  x28, 0(x11++)
    bn.xor  w10, w4, w22 /* xpc = sp ^ c */
    bn.xor  w11, w5, w23
    /* c' = sp ^ SecAnd(xpy, xpc). */
    bn.and  w12, w6, w10
    bn.and  w13, w7, w11
    bn.wsrr w14, URND
    bn.and  w15, w6, w11
    bn.xor  w15, w15, w14
    bn.and  w16, w7, w10
    bn.xor  w16, w16, w14
    bn.xor  w12, w12, w15
    bn.xor  w13, w13, w16
    bn.xor  w22, w4, w12
    bn.xor  w23, w5, w13
  endloop

  /* Zero z[k]. */
  bn.sid x31, 0(x13)
  bn.sid x31, 0(x14)

  ret

/**
 * secaddmodq
 *
 * Return Boolean shares of z = (x + y) mod q, given k-bit Boolean shares of
 * x, y with 0 <= x, y < q.
 * Bitsliced.
 *
 *   nq <- 2^{k+1} - q                 (immediate 0x801fff)
 *   s  <- SecAdd(x, y)
 *   sp <- SecAdd(s, nq)
 *   b  <- sp[k]
 *   a  <- BitCopyMask(b, q)
 *   z  <- SecAdd(a, sp)
 *
 * The b/a/z steps are fused inside secadd_constant_bmsk.  ML-DSA only
 * (q = 0x7fe001 hard-coded; matches the external nq).
 *
 * Source: Alg.7 [BC22]
 *
 * @param[in]   x10: dptr_z, output ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   x11: dptr_x, input  ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   x12: dptr_y, input  ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w23
 * clobbered flag groups: FG0
 */
.globl secaddmodq
.type secaddmodq, @function
secaddmodq:
  addi x17, x10, 0 /* park z_out in x17 */

  /* Step 2: s = SecAdd(x, y) -> z_out. */
  addi x10, x11, 0
  addi x11, x12, 0
  li   x12, 24  /* k+1 */
  li   x13, 768 /* (k+1) * 32 */
  addi x15, x17, 0
  jal  x1, secadd

  /* Step 3: sp = SecAdd(s, nq) -> z_out, in place. */
  bn.xor    w17, w17, w17
  bn.addi   w17, w17, 1
  bn.shv.8s w17, w17 << 23
  bn.xor    w18, w18, w18
  bn.addi   w18, w18, 1
  bn.shv.8s w18, w18 << 13
  bn.subi   w18, w18, 1
  bn.add    w17, w17, w18 /* w17 lane 0 = nq = 0x801fff */
  addi      x10, x17, 0
  li        x12, 24       /* k+1 */
  li        x13, 768      /* (k+1) * 32 */
  addi      x15, x17, 0
  jal       x1, secadd_immd_d2

  /* Step 4+5+6: z = sp + BitCopyMask(sp[k], q) -> z_out, in-place. */
  addi x10, x17, 0
  jal  x1, secadd_constant_bmsk

  ret

/**
 * seca2bmodq
 *
 * Return Boolean shares mod 2^k (k = 23) of a value x mod q (q = 0x7fe001),
 * given its arithmetic shares (q < 2^k).
 * Bitsliced.
 *
 *   s  <- ((2^{k+1} - q) + x[0], 0)
 *   s' <- (0, x[1])
 *   u  <- secadd(s, s')
 *   a  <- bitcopymask(u[k])
 *   z  <- secadd(a, u)
 *
 * Source: Alg.10 [BC22]
 *
 * @param[in]   x10: dptr_z, output ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   x11: dptr_x, input  ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   x13: dptr_scratch, 1536 B caller-provided scratch (must not
 *                   overlap z_in/z_out or any live caller buffer)
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w16, w20 to w23
 * clobbered flag groups: FG0
 */
.globl seca2bmodq
.type seca2bmodq, @function
seca2bmodq:
  addi x2, x2, -32
  sw   x13, 0(x2)  /* preserve scratch across secadd calls */
  addi x17, x10, 0 /* park z_out */

  /* s' <- (0, x[1]). */
  addi x28, x11, 768 /* (k+1) * 32 */
  addi x6, x13, 0
  li   x7, 31
  loopi 24, 1
    bn.sid x7, 0(x6++)
  endloop
  bn.xor w0, w0, w0 /* Whitening. */
  li     x7, 0
  loopi 24, 2
    bn.lid x7, 0(x28++)
    bn.sid x7, 0(x6++)
  endloop
  bn.xor w0, w0, w0 /* Whitening. */

  /* s share 0 <- (2^{k+1} - q) + x[0]. */
  addi x10, x11, 0
  li   x12, 23 /* k */
  addi x16, x17, 0
  jal  x1, secadd_immd_d1

  /* s share 1 <- 0. */
  addi x6, x17, 768 /* (k+1) * 32 */
  li   x7, 31
  loopi 24, 1
    bn.sid x7, 0(x6++)
  endloop

  /* u <- secadd(s, s'). */
  lw   x10, 0(x2)
  addi x11, x17, 0
  li   x12, 24  /* k+1 */
  li   x13, 768 /* (k+1) * 32 */
  addi x15, x17, 0
  jal  x1, secadd

  /* a <- bitcopymask(u[k]); z <- secadd(a, u). */
  addi x10, x17, 0
  jal  x1, secadd_constant_bmsk

  addi x2, x2, 32
  ret

/**
 * secleq
 *
 * Return b = 1 iff x <= psi (else 0), given k-bit Boolean shares of x with
 * k = 23 and 0 <= psi < 2^k - 1.
 * Bitsliced.
 *
 *   x' <- SecAdd(x, 2^{k+1} - psi - 1)
 *   b  <- SecUnMask(x'[k])
 *
 * Source: Alg.4 [ABCH+23]
 *
 * @param[in]  x11: dptr_x, (k+1) * 2 * 32 bytes (top WDR = 0; clobbered)
 * @param[in]  w17: lane-0 holds C = 2^{k+1} - psi - 1
 * @param[in]  w31: all-zero register
 * @param[out] w0:  per-lane b (lane i = 1 iff x_i <= psi)
 *
 * clobbered registers: x5 to x7, x10, x12 to x13, x15, x17, x28 to x31, w0 to w19
 * clobbered flag groups: FG0
 */
.globl secleq
.type secleq, @function
secleq:
  /* Stash x ptr in a7. */
  addi x17, x11, 0

  /* x' <- SecAdd(x, C), in place. */
  addi x10, x11, 0
  addi x15, x11, 0
  li   x12, 24  /* k+1 */
  li   x13, 768 /* (k+1) * 32 */
  jal  x1, secadd_immd_d2

  /* b <- SecUnMask(x'[k]). */
  addi    x6, x17, 736 /* x'[k], share 0 */
  addi    x31, x6, 768 /* x'[k], share 1 */
  li      x28, 0
  bn.lid  x28, 0(x6)
  li      x29, 1
  bn.lid  x29, 0(x31)
  bn.wsrr w2, URND
  bn.xor  w0, w0, w2
  bn.xor  w1, w1, w2
  bn.xor  w0, w0, w1
  ret

/**
 * secunmask_modq
 *
 * Refresh and unmask an arithmetic sharing of one polynomial mod q.  Runs
 * per-WDR (8 coefficients at a time); the caller must pre-load MOD with q in
 * the lower half for the .8s reductions.
 *
 *   x   <- RefreshIOS(x)       (per-coef +/- with fresh r)
 *   out <- x_0 + x_1 mod q     (sum-collapse)
 *
 * Source: Alg.18 [BC22]
 *
 * @param[out]    x10: dptr_out, 1024 B plaintext polynomial
 * @param[in,out] x11: dptr_x, 2 * 1024 B input (stride 1024; refreshed in place)
 * @param[in]     w31: all-zero register
 *
 * clobbered registers: x5 to x7, x28 to x31, w0 to w2, w11 to w15
 * clobbered flag groups: FG0
 */
.globl secunmask_modq
.type secunmask_modq, @function
secunmask_modq:
  /* w11 = 0x007fffff * 8 (23-bit per-lane mask). */
  bn.not  w11, w31
  bn.rshi w11, w31, w11 >> 233
  bn.or   w11, w11, w11 << 32
  bn.or   w11, w11, w11 << 64
  bn.or   w11, w11, w11 << 128

  /* w13 = 0xff000000 * 8 (top byte of each lane). */
  bn.shv.8s w13, w11 << 24

  /* w12 = q packed 8 lanes. */
  li     x5, 12
  la     x6, modulus
  bn.lid x5, 0(x6)

  addi x28, x11, 0    /* share 0 cursor */
  addi x29, x11, 1024 /* share 1 cursor */
  addi x30, x10, 0    /* output cursor */

  li x5, 0
  li x6, 1
  li x7, 2
  loopi 32, 9 /* 256 / 8 WDRs */
    jal         x1, _sample_rq
    bn.lid      x5, 0(x28)
    bn.addvm.8s w0, w0, w14 /* share 0 += r */
    bn.sid      x5, 0(x28++)
    bn.lid      x6, 0(x29)
    bn.subvm.8s w1, w1, w14 /* share 1 -= r */
    bn.sid      x6, 0(x29++)
    bn.addvm.8s w2, w0, w1  /* out = share 0 + share 1 */
    bn.sid      x7, 0(x30++)
  endloop
  ret

/* Lane-parallel rejection sampler: returns w14 = 8 fresh uniform r in Z_q.
 * Requires w11 = 23-bit mask, w12 = q vector, w13 = top-byte mask.
 *   r  := URND & (2^23 - 1)                 (8 lanes of 23-bit uniform)
 *   ok := (r - q signed) top byte == 0xff   (per lane, encodes r < q)
 *   retry while not all 8 lanes accept.
 *
 *   p_wdr = (8380417 / 2**23) ** 8  # ~0.9922
 */
_sample_rq:
  bn.wsrr    w14, URND
  bn.and     w14, w14, w11
  bn.subv.8s w15, w14, w12
  bn.and     w15, w15, w13
  bn.cmp     w15, w13
  csrrs      x31, FG0, x0
  andi       x31, x31, 8
  beq        x31, x0, _sample_rq
  ret

/*
 * 8x8 lane transpose: w0..w7 -> w16..w23 (clobbers w0..w15).  Shared by the
 * bitslice / unbitslice Phase-2 gather steps.
 */
_transpose_8x8:
  bn.trn1.8s w8,  w0, w1
  bn.trn2.8s w9,  w0, w1
  bn.trn1.8s w10, w2, w3
  bn.trn2.8s w11, w2, w3
  bn.trn1.8s w12, w4, w5
  bn.trn2.8s w13, w4, w5
  bn.trn1.8s w14, w6, w7
  bn.trn2.8s w15, w6, w7
  bn.trn1.4d w0,  w8,  w10
  bn.trn2.4d w2,  w8,  w10
  bn.trn1.4d w1,  w9,  w11
  bn.trn2.4d w3,  w9,  w11
  bn.trn1.4d w4,  w12, w14
  bn.trn2.4d w6,  w12, w14
  bn.trn1.4d w5,  w13, w15
  bn.trn2.4d w7,  w13, w15
  bn.trn1.2q w16, w0, w4
  bn.trn2.2q w20, w0, w4
  bn.trn1.2q w17, w1, w5
  bn.trn2.2q w21, w1, w5
  bn.trn1.2q w18, w2, w6
  bn.trn2.2q w22, w2, w6
  bn.trn1.2q w19, w3, w7
  bn.trn2.2q w23, w3, w7
  ret

/*
 * Bit-transpose butterfly shared by bitslice (input -> scratch) and
 * unbitslice (scratch -> output): load 8 groups of 4 WDRs via x28, apply the
 * self-inverse stride 16/8/4/2/1 network, and store the transposed groups
 * via t4.  Builds mask registers:
 *   w20..w24 = butterfly masks for j = 16/8/4/2/1
 *   w25 = j=4 stripe (lanes 0-3)
 *   w26 = j=2 stripe (lanes {0,1,4,5})
 *   w27 = j=1 stripe (lanes {0,2,4,6})
 */
_bitslice_butterfly:
  bn.not    w6,  w31
  bn.shv.8s w20, w6  >> 16
  bn.shv.8s w4,  w20 << 8
  bn.xor    w21, w20, w4
  bn.shv.8s w4,  w21 << 4
  bn.xor    w22, w21, w4
  bn.shv.8s w4,  w22 << 2
  bn.xor    w23, w22, w4
  bn.shv.8s w4,  w23 << 1
  bn.xor    w24, w23, w4
  bn.rshi   w25, w31, w6  >> 128
  bn.rshi   w4,  w31, w6  >> 192
  bn.rshi   w5,  w4,  w31 >> 128
  bn.or     w26, w4,  w5
  bn.rshi   w4,  w31, w6  >> 224
  bn.rshi   w5,  w4,  w31 >> 192
  bn.or     w4,  w4,  w5
  bn.rshi   w5,  w4,  w31 >> 128
  bn.or     w27, w4,  w5
  li        x30, 8

  loop x30, 161
    li x5, 0
    loopi 4, 2
      bn.lid x5, 0(x28++)
      addi   x5, x5, 1
    endloop

    /* Stage j=16 (cross-WDR). */
    bn.shv.8s w4, w0 >> 16
    bn.xor    w4, w2, w4
    bn.and    w4, w4, w20
    bn.xor    w2, w2, w4
    bn.shv.8s w4, w4 << 16
    bn.xor    w0, w0, w4

    bn.shv.8s w4, w1 >> 16
    bn.xor    w4, w3, w4
    bn.and    w4, w4, w20
    bn.xor    w3, w3, w4
    bn.shv.8s w4, w4 << 16
    bn.xor    w1, w1, w4

    /* Stage j=8 (cross-WDR). */
    bn.shv.8s w4, w0 >> 8
    bn.xor    w4, w1, w4
    bn.and    w4, w4, w21
    bn.xor    w1, w1, w4
    bn.shv.8s w4, w4 << 8
    bn.xor    w0, w0, w4

    bn.shv.8s w4, w2 >> 8
    bn.xor    w4, w3, w4
    bn.and    w4, w4, w21
    bn.xor    w3, w3, w4
    bn.shv.8s w4, w4 << 8
    bn.xor    w2, w2, w4

    /* Stage j=4 (intra-WDR). */
    bn.rshi   w6, w31, w0 >> 128
    bn.shv.8s w4, w0 >> 4
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w22
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 4
    bn.xor    w0, w0, w4
    bn.rshi   w6, w6, w31 >> 128
    bn.and    w0, w0, w25
    bn.or     w0, w0, w6

    bn.rshi   w6, w31, w1 >> 128
    bn.shv.8s w4, w1 >> 4
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w22
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 4
    bn.xor    w1, w1, w4
    bn.rshi   w6, w6, w31 >> 128
    bn.and    w1, w1, w25
    bn.or     w1, w1, w6

    bn.rshi   w6, w31, w2 >> 128
    bn.shv.8s w4, w2 >> 4
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w22
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 4
    bn.xor    w2, w2, w4
    bn.rshi   w6, w6, w31 >> 128
    bn.and    w2, w2, w25
    bn.or     w2, w2, w6

    bn.rshi   w6, w31, w3 >> 128
    bn.shv.8s w4, w3 >> 4
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w22
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 4
    bn.xor    w3, w3, w4
    bn.rshi   w6, w6, w31 >> 128
    bn.and    w3, w3, w25
    bn.or     w3, w3, w6

    /* Stage j=2 (intra-WDR). */
    bn.and    w5, w0, w26
    bn.rshi   w6, w31, w0 >> 64
    bn.and    w6, w6, w26
    bn.shv.8s w4, w5 >> 2
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w23
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 2
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 192
    bn.or     w0, w5, w6

    bn.and    w5, w1, w26
    bn.rshi   w6, w31, w1 >> 64
    bn.and    w6, w6, w26
    bn.shv.8s w4, w5 >> 2
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w23
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 2
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 192
    bn.or     w1, w5, w6

    bn.and    w5, w2, w26
    bn.rshi   w6, w31, w2 >> 64
    bn.and    w6, w6, w26
    bn.shv.8s w4, w5 >> 2
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w23
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 2
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 192
    bn.or     w2, w5, w6

    bn.and    w5, w3, w26
    bn.rshi   w6, w31, w3 >> 64
    bn.and    w6, w6, w26
    bn.shv.8s w4, w5 >> 2
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w23
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 2
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 192
    bn.or     w3, w5, w6

    /* Stage j=1 (intra-WDR). */
    bn.and    w5, w0, w27
    bn.rshi   w6, w31, w0 >> 32
    bn.and    w6, w6, w27
    bn.shv.8s w4, w5 >> 1
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w24
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 1
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 224
    bn.or     w0, w5, w6

    bn.and    w5, w1, w27
    bn.rshi   w6, w31, w1 >> 32
    bn.and    w6, w6, w27
    bn.shv.8s w4, w5 >> 1
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w24
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 1
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 224
    bn.or     w1, w5, w6

    bn.and    w5, w2, w27
    bn.rshi   w6, w31, w2 >> 32
    bn.and    w6, w6, w27
    bn.shv.8s w4, w5 >> 1
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w24
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 1
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 224
    bn.or     w2, w5, w6

    bn.and    w5, w3, w27
    bn.rshi   w6, w31, w3 >> 32
    bn.and    w6, w6, w27
    bn.shv.8s w4, w5 >> 1
    bn.xor    w4, w6, w4
    bn.and    w4, w4, w24
    bn.xor    w6, w6, w4
    bn.shv.8s w4, w4 << 1
    bn.xor    w5, w5, w4
    bn.rshi   w6, w6, w31 >> 224
    bn.or     w3, w5, w6

    li x5, 0
    loopi 4, 2
      bn.sid x5, 0(x29++)
      addi   x5, x5, 1
    endloop
    nop
  endloop
  ret

/**
 * bitslice / bitslice_k32
 *
 * Transpose 256 canonical 32-bit coefficients into kbits bitsliced WDRs
 * (output WDR j's lane i = bit j of coefficient i); the upper 32 - kbits bits
 * of each input coefficient are dropped.  Both entry points share one core;
 * bitslice uses kbits = 23 and bitslice_k32 uses kbits = 32.
 *
 * @param[in]  x10: ptr_out, dmem pointer to output (kbits WDRs at stride x12)
 * @param[in]  x11: ptr_in,  dmem pointer to input (32 * 32 = 1024 B)
 * @param[in]  x12: stride,  output WDR stride in bytes (32 for contiguous)
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x2, x5, x10, x13, x28 to x30, w0 to w27
 * clobbered flag groups: FG0
 */
.globl bitslice
.type bitslice, @function
bitslice:
  li  x5, 23
  jal x0, _bitslice_core
.globl bitslice_k32
.type bitslice_k32, @function
bitslice_k32:
  li x5, 32
  /* fall through */
_bitslice_core:
  /* Spill nfull / remainder: kbits (x5) does not survive Phase 1. */
  addi x2, x2, -32
  addi x28, x5, -1
  srli x28, x28, 3  /* nfull = (kbits - 1) / 8 */
  slli x29, x28, 3
  sub  x29, x5, x29 /* remainder = kbits - 8 * nfull */
  sw   x28, 0(x2)
  sw   x29, 4(x2)

  la x13, scratch

  addi x28, x11, 0 /* load from input  */
  addi x29, x13, 0 /* store to scratch */
  jal  x1, _bitslice_butterfly

  /* === Phase 2: per q-block gather (stride 128) + 8x8 transpose; store 8
   * stripes per full block, then the partial final block. === */
  addi x30, x13, 0 /* gather base, q = 0 */
  lw   x29, 0(x2)  /* nfull */

  loop x29, 13
    addi x28, x30, 0
    li   x5, 0
    loopi 8, 3
      bn.lid x5, 0(x28)
      addi   x28, x28, 128
      addi   x5, x5, 1
    endloop
    jal x1, _transpose_8x8
    li  x5, 16
    loopi 8, 3
      bn.sid x5, 0(x10)
      add    x10, x10, x12
      addi   x5, x5, 1
    endloop
    addi x30, x30, 32
  endloop

  /* Final (partial) block: kbits - 8 * nfull stripes. */
  addi x28, x30, 0
  li   x5, 0
  loopi 8, 3
    bn.lid x5, 0(x28)
    addi   x28, x28, 128
    addi   x5, x5, 1
  endloop
  jal x1, _transpose_8x8
  lw  x28, 4(x2) /* remainder */
  li  x5, 16
  loop x28, 3
    bn.sid x5, 0(x10)
    add    x10, x10, x12
    addi   x5, x5, 1
  endloop

  addi x2, x2, 32
  ret

/**
 * unbitslice
 *
 * Inverse of bitslice: take 23 bitsliced WDRs (lane i of WDR j = bit j of
 * coefficient i) and produce 32 canonical WDRs of 8 x 32-bit packed
 * coefficients with the upper 9 bits zero.
 *
 * @param[in]  x10: ptr_out, dmem pointer to output (32 * 32 = 1024 B)
 * @param[in]  x11: ptr_in,  dmem pointer to input (23 * 32 = 736 B)
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x5, x11 to x12, x28 to x30, w0 to w27
 * clobbered flag groups: FG0
 */
.globl unbitslice
.type unbitslice, @function
unbitslice:
  la x12, scratch

  /* === Phase 2: scatter 23 bitsliced inputs through three 8x8 lane
   * transposes into 32 scratch WDRs.  q=3 (bits 23..31) is zero-filled. === */

  /* --- q=0 --- */
  li x5, 0
  loopi 8, 2
    bn.lid x5, 0(x11++)
    addi   x5, x5, 1
  endloop

  jal x1, _transpose_8x8

  /* Store w16..w23 to scratch at stride 128. */
  addi x28, x12, 0
  li   x5, 16
  loopi 8, 3
    bn.sid x5, 0(x28)
    addi   x28, x28, 128
    addi   x5, x5, 1
  endloop

  /* --- q=1 --- */
  li x5, 0
  loopi 8, 2
    bn.lid x5, 0(x11++)
    addi   x5, x5, 1
  endloop

  jal x1, _transpose_8x8

  addi x28, x12, 32
  li   x5, 16
  loopi 8, 3
    bn.sid x5, 0(x28)
    addi   x28, x28, 128
    addi   x5, x5, 1
  endloop

  /* --- q=2: 7 inputs + zero pad for missing bit 23. --- */
  li x5, 0
  loopi 7, 2
    bn.lid x5, 0(x11++)
    addi   x5, x5, 1
  endloop
  bn.mov w7, w31

  jal x1, _transpose_8x8

  addi x28, x12, 64
  li   x5, 16
  loopi 8, 3
    bn.sid x5, 0(x28)
    addi   x28, x28, 128
    addi   x5, x5, 1
  endloop

  /* --- q=3: zero-fill (no input bits). --- */
  addi x28, x12, 96
  li   x5, 31
  loopi 8, 2
    bn.sid x5, 0(x28)
    addi   x28, x28, 128
  endloop

  /* === Phase 1: butterfly scratch -> output. === */
  addi x28, x12, 0
  addi x29, x10, 0
  jal  x1, _bitslice_butterfly

  ret

/**
 * poly_rej_samp_bitsliced
 *
 * Sample 256 coefficients uniform in [0, q) (q = 8380417) by rejection
 * sampling on uniform random words from URND: redraw the whole batch until
 * every lane is < q (~ 1.28 draws expected).
 * Bitsliced.
 *
 * @param[in]  x10: ptr_r, dmem output (23 * 32 bytes)
 * @param[in]  x11: deterministic random stream (MLDSA_REJ_SAMPLE_TEST only)
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x5 to x6, x30, w0 to w23
 * clobbered flag groups: FG0
 */
.globl poly_rej_samp_bitsliced
.type poly_rej_samp_bitsliced, @function
poly_rej_samp_bitsliced:
_prs_bs_draw:
#if defined(MLDSA_REJ_SAMPLE_TEST)
  /* Read 23 WDRs from x11 in place of URND. */
  li x5, 0
  li x6, 23
  loop x6, 2
    bn.lid x5, 0(x11++)
    addi   x5, x5, 1
  endloop
#else
  bn.wsrr w0,  URND
  bn.wsrr w1,  URND
  bn.wsrr w2,  URND
  bn.wsrr w3,  URND
  bn.wsrr w4,  URND
  bn.wsrr w5,  URND
  bn.wsrr w6,  URND
  bn.wsrr w7,  URND
  bn.wsrr w8,  URND
  bn.wsrr w9,  URND
  bn.wsrr w10, URND
  bn.wsrr w11, URND
  bn.wsrr w12, URND
  bn.wsrr w13, URND
  bn.wsrr w14, URND
  bn.wsrr w15, URND
  bn.wsrr w16, URND
  bn.wsrr w17, URND
  bn.wsrr w18, URND
  bn.wsrr w19, URND
  bn.wsrr w20, URND
  bn.wsrr w21, URND
  bn.wsrr w22, URND
#endif

  /* Per-lane v < q check: bit k of v + (2^k - q) is 0 iff v < q.
   * With (2^k - q) = 0x1fff (bits 0..12 = 1, bits 13..22 = 0), the
   * carry chain collapses to:
   *   bits 0..12  (const = 1):  c_{b+1} = v_b OR  c_b
   *   bits 13..22 (const = 0):  c_{b+1} = v_b AND c_b
   * Starting c_0 = 0, accept iff the folded c_23 (in w23) is all-zero.
   */
  bn.or w23, w0,  w1
  bn.or w23, w23, w2
  bn.or w23, w23, w3
  bn.or w23, w23, w4
  bn.or w23, w23, w5
  bn.or w23, w23, w6
  bn.or w23, w23, w7
  bn.or w23, w23, w8
  bn.or w23, w23, w9
  bn.or w23, w23, w10
  bn.or w23, w23, w11
  bn.or w23, w23, w12

  bn.and w23, w23, w13
  bn.and w23, w23, w14
  bn.and w23, w23, w15
  bn.and w23, w23, w16
  bn.and w23, w23, w17
  bn.and w23, w23, w18
  bn.and w23, w23, w19
  bn.and w23, w23, w20
  bn.and w23, w23, w21
  bn.and w23, w23, w22

  /* Redraw if any lane >= q (FG0.Z clear -> w23 != 0). */
  csrrs x6, FG0, x0
  srli  x6, x6, 3 /* FG0.Z */
  beq   x6, x0, _prs_bs_draw

  /* Store w0..w22 to output. */
  addi x30, x10, 0
  li   x5, 0
  li   x6, 23
  loop x6, 2
    bn.sid x5, 0(x30++)
    addi   x5, x5, 1
  endloop

  ret

/**
 * secb2amodq
 *
 * Convert a Boolean sharing x^{B,k} of x in [0, q) into an arithmetic sharing
 * z^{A_q} of the same value (q = 0x7fe001).
 * Bitsliced.
 *
 *   z_0  <- Z_q                              (poly_rej_samp_bitsliced)
 *   z'_0 <- q - z_0                          (bitsliced borrow chain)
 *   a    <- seca2bmodq((z'_0, 0))
 *   b    <- secaddmodq(a, x)
 *   z_1  <- unmask(b)                        (RefreshIOS fused with XOR-collapse)
 *
 * Source: Alg.11 [BC22]
 *
 * @param[in]   x10: dptr_z, output ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   x11: dptr_x, input  ((k+1) * 2 * 32 bytes, bit k = 0)
 * @param[in]   x13: dptr_scratch, 1536 B for seca2bmodq (forwarded)
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w23
 * clobbered flag groups: FG0
 */
.globl secb2amodq
.type secb2amodq, @function
secb2amodq:
  /* z_0 staged in the shared scratchpad; standard 32 B prologue. */
  la   x14, scratch
  addi x2, x2, -32
  sw   x10, 0(x2)  /* save z_out */
  sw   x11, 4(x2)  /* save x_in */
  sw   x13, 8(x2)  /* save scratch_ptr for seca2b */
  sw   x14, 12(x2) /* save z_0 scratch ptr */

  /* z_0 <- Z_q. */
  addi x10, x14, 0
  jal  x1, poly_rej_samp_bitsliced

  /* z'_0 <- q - z_0 (bitsliced borrow chain). */
  lw x31, 0(x2)
  lw x30, 12(x2)
  li x5, 0
  li x6, 1
  li x7, 2
  li x28, 31

  bn.lid x5, 0(x30++)
  bn.not w2, w0
  bn.sid x7, 0(x31++)
  bn.xor w1, w31, w31

  loopi 12, 4
    bn.lid x5, 0(x30++)
    bn.xor w2, w0, w1
    bn.sid x7, 0(x31++)
    bn.or  w1, w0, w1
  endloop

  loopi 10, 5
    bn.lid x5, 0(x30++)
    bn.not w3, w0
    bn.xor w2, w3, w1
    bn.sid x7, 0(x31++)
    bn.and w1, w0, w1
  endloop

  bn.sid x28, 0(x31++)

  /* z'_1 <- 0. */
  loopi 24, 1
    bn.sid x28, 0(x31++)
  endloop

  /* a <- seca2bmodq((z'_0, 0)). */
  lw  x10, 0(x2)
  lw  x11, 0(x2)
  lw  x13, 8(x2)
  jal x1, seca2bmodq

  /* b <- secaddmodq(a, x). */
  lw  x10, 0(x2)
  lw  x11, 4(x2)
  lw  x12, 0(x2)
  jal x1, secaddmodq

  /* z_1 <- unmask(b) (RefreshIOS fused with the XOR-collapse). */
  lw   x31, 0(x2)
  addi x13, x31, 0   /* b[share 0] read */
  addi x14, x31, 768 /* b[share 1] read */
  li   x6, 1
  li   x7, 2
  addi x30, x31, 768 /* z[share 1] write */
  li   x29, 23
  loop x29, 7
    bn.lid  x6, 0(x13++)
    bn.lid  x7, 0(x14++)
    bn.wsrr w3, URND
    bn.xor  w1, w1, w3
    bn.xor  w2, w2, w3
    bn.xor  w1, w1, w2
    bn.sid  x6, 0(x30++)
  endloop
  li     x28, 31
  bn.sid x28, 0(x30) /* z[share 1] bit k = 0 */

  /* z_0 -> z[share 0]. */
  addi x30, x31, 0 /* z[share 0] write */
  lw   x11, 12(x2) /* z_0 source */
  li   x5, 0
  li   x29, 23
  loop x29, 2
    bn.lid x5, 0(x11++)
    bn.sid x5, 0(x30++)
  endloop
  bn.sid x28, 0(x30) /* z[share 0] bit k = 0 */

  addi x2, x2, 32
  ret

/**
 * secb2amodq_eta
 *
 * B2A for polyeta-shaped Boolean inputs (k = 3 for eta = 2, k = 4 for
 * eta = 4): zero-pad the k-stripe shares to the full 24-stripe Z_q layout,
 * run secb2amodq, then unbitslice each output share to canonical 32-bit
 * arithmetic at a0.
 *
 * @param[in]   x10: dptr_out, 2 * 1024 B canonical arithmetic shares (mod q)
 * @param[in]   x11: dptr_x_share0, k * 32 B Boolean bitsliced
 * @param[in]   x12: dptr_x_share1, k * 32 B Boolean bitsliced
 * @param[in]   x13: bit-width k (3 or 4)
 * @param[in]   x14: dptr_scratch, 1536 B for seca2bmodq (forwarded)
 * @param[in]   x15: dptr_buf, 1536 B share-major Boolean buffer (must not
 *                   overlap dptr_scratch)
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl secb2amodq_eta
.type secb2amodq_eta, @function
secb2amodq_eta:
  addi x2, x2, -32
  sw   x1,  0(x2)
  sw   x10,  4(x2)
  sw   x14,  8(x2)
  sw   x15, 12(x2)

  /* Zero the 48-WDR buffer at a5. */
  li   x7, 31
  addi x5, x15, 0
  loopi 48, 1
    bn.sid x7, 0(x5++)
  endloop

  /* share 0 low k stripes -> buffer + 0. */
  li   x7, 0
  addi x5, x15, 0
  addi x29, x11, 0
  loop x13, 2
    bn.lid x7, 0(x29++)
    bn.sid x7, 0(x5++)
  endloop

  /* Whitening. */
  bn.xor w0, w0, w0
  /* share 1 low k stripes -> buffer + 768. */
  addi   x5, x15, 768
  addi   x29, x12, 0
  loop x13, 2
    bn.lid x7, 0(x29++)
    bn.sid x7, 0(x5++)
  endloop

  /* b2a: caller's x10 receives bitsliced arith shares. */
  lw   x10,  4(x2)
  addi x11, x15, 0
  lw   x13,  8(x2)
  jal  x1, secb2amodq

  /* Unbitslice each share to canonical 32-bit; share 1 first so its
   * overlapping write [1024..1535] doesn't clobber share 0's source. */
  lw   x10,  4(x2)
  addi x11, x10, 768
  addi x10, x10, 1024
  jal  x1, unbitslice

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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  lw     x10,  4(x2)
  addi   x11, x10, 0
  jal    x1, unbitslice

  lw   x1,  0(x2)
  addi x2, x2, 32
  ret

/**
 * secboundcheck
 *
 * Bound-check masked arithmetic input x^{A_q}: return the per-lane mask b in
 * w0 (b_i = 1 iff -lambda_0 <= x_i <= lambda_1 mod q).
 * Bitsliced.
 *
 *   x_0 <- x_0 + lambda_0 mod q
 *   x'  <- seca2bmodq(x)
 *   b   <- secleq(x')
 *
 * Source: Alg.5 [ABCH+23]
 *
 * @param[in]   x10: dptr_x_arith, 2 * 1024 B arith shares (stride 1024)
 * @param[in]   x12: dptr_lambda0_vec, 32 B broadcast of lambda_0
 * @param[in]   x13: dptr_scratch, 1536 B for seca2bmodq
 * @param[in]   x14: dptr_buf, 1536 B bit-major share-inner buffer (must not
 *                   overlap dptr_scratch or dptr_x_arith)
 * @param[in]   w17: lane 0 holds C = 2^{k+1} - (lambda_0 + lambda_1) - 1
 * @param[in]   w31: all-zero register
 * @param[out]  w0: per-lane b
 *
 * w16/w22/w23 are stashed in w28/w29/w30 across the chain.
 *
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w30
 * clobbered flag groups: FG0
 */

/* Stack frame (64 B): 0 = seca2b scratch ptr, 4 = buf ptr,
 * 32 = WDR stash for the secleq constant C. */
.globl secboundcheck
.type secboundcheck, @function
secboundcheck:
  bn.mov w28, w16
  bn.mov w29, w22
  bn.mov w30, w23

  addi x2, x2, -64
  sw   x13, 0(x2)
  sw   x14, 4(x2)

  /* Stash C across the seca2bmodq call. */
  li     x5, 17
  bn.sid x5, 32(x2)

  /* Preserve arguments. */
  addi x17, x10, 0

  /* x_0 <- x_0 + lambda_0 mod q (written to x14; caller's x stays intact). */
  bn.lid x0, 0(x12)
  addi   x5, x17, 0
  addi   x6, x14, 0
  li     x7, 1
  loopi 32, 3
    bn.lid      x7, 0(x5++)
    bn.addvm.8s w1, w1, w0
    bn.sid      x7, 0(x6++)
  endloop

  /* Bitslice each share into the share-major bit-inner buffer. */
  addi x10, x14, 0
  addi x11, x14, 0
  li   x12, 32
  jal  x1, bitslice

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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  lw     x14, 4(x2)
  addi   x10, x14, 768
  addi   x11, x17, 1024
  li     x12, 32
  jal    x1, bitslice

  /* Zero bit-k pad of each share. */
  lw     x14, 4(x2)
  li     x5, 31
  addi   x6, x14, 736
  bn.sid x5, 0(x6)
  addi   x6, x14, 1504
  bn.sid x5, 0(x6)

  /* x' <- seca2bmodq(x). */
  addi x10, x14, 0
  addi x11, x14, 0
  lw   x13, 0(x2)
  jal  x1, seca2bmodq

  /* b <- secleq(x'). */
  lw     x14, 4(x2)
  li     x5, 17
  bn.lid x5, 32(x2)
  addi   x11, x14, 0
  jal    x1, secleq

  addi x2, x2, 64

  bn.mov w16, w28
  bn.mov w22, w29
  bn.mov w23, w30
  ret

/**
 * seccompress
 *
 * Masked SecCompress for the ML-DSA-44 SecDecompose: from arithmetic shares of
 * x mod q (q = 8380417) produce a Boolean sharing of
 * w1 = round(x * delta / q) mod delta, delta = 44 (ell = 24, c = 8,
 * k = ell + c = 32).
 * Bitsliced.
 *
 *   z_0 <- round(x_0 * delta * 2^ell / q) + 2^(ell-1) + 1  mod 2^(ell+c)
 *   z_1 <- round(x_1 * delta * 2^ell / q)                  mod 2^(ell+c)
 *   Z   <- seca2b((z_0, z_1))
 *   V'  <- Z >> ell                                    (top c = 8 stripes)
 *   V'  <- (V' >= delta) ? V' - delta : V'             (twice; V' in [0, 88])
 *
 * The rounded division by q is a truncating Barrett multiply (ACC has no
 * divide): z_i = (x_i * K) >> 25, K = round(delta * 2^(ell+25) / q) =
 * 0xb02c09a2.
 *
 * Source: Alg.2 [CGMZ23]
 *
 * @param[out]  x10: dptr_z, 2048 B share-major a2b output (share_str = 1024)
 * @param[in]   x11: dptr_x, 2 * 1024 B arith shares mod q (contiguous)
 * @param[in]   x12: dptr_scratch, 4096 B (T_dense + T_bsl), caller-provided
 * @param[in]   x13: dptr_b, 2048 B scratch for the a2b's B, caller-provided
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x16, x18 to x19, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl seccompress
.type seccompress, @function
seccompress:
  li  x5, 64
  sub x2, x2, x5
  sw  x10, 4(x2)
  sw  x11, 8(x2)
  sw  x8, 16(x2)
  sw  x9, 20(x2)
  sw  x18, 24(x2)
  sw  x19, 28(x2)
  sw  x12, 32(x2)
  sw  x13, 36(x2)

  /* K = 0xb02c09a2 -> w16 (broadcast to all 8 lanes). */
  bn.addi w16, w31, 0xb0
  bn.rshi w16, w16, w31 >> 248
  bn.addi w16, w16, 0x2c
  bn.rshi w16, w16, w31 >> 248
  bn.addi w16, w16, 0x09
  bn.rshi w16, w16, w31 >> 248
  bn.addi w16, w16, 0xa2
  bn.rshi w18, w16, w31 >> 224
  bn.or   w16, w16, w18
  bn.rshi w18, w16, w31 >> 192
  bn.or   w16, w16, w18
  bn.rshi w18, w16, w31 >> 128
  bn.or   w16, w16, w18

  /* BIAS = 2^23 + 1 -> w17 (broadcast to all 8 lanes). */
  bn.addi   w17, w31, 1
  bn.shv.8s w17, w17 << 23
  bn.addi   w17, w17, 1
  bn.rshi   w18, w17, w31 >> 224
  bn.or     w17, w17, w18
  bn.rshi   w18, w17, w31 >> 192
  bn.or     w17, w17, w18
  bn.rshi   w18, w17, w31 >> 128
  bn.or     w17, w17, w18

  /* Steps 1-2: z_i = round(x_i*delta*2^ell / q) mod 2^(ell+c) for i in {0,1}. */
  addi x8, x11, 0
  lw   x9, 32(x2)
  loopi    2, 10
    li x5, 0
    li x7, 3
    loopi    32, 5
      bn.lid             x5, 0(x8++)
      bn.shv.8s          w0, w0 << 7
      bn.mulv.8s.even.hi w3, w0, w16
      bn.mulv.8s.odd.hi  w3, w3, w16
      bn.sid             x7, 0(x9++)
    endloop
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w3, w3, w3
  endloop

  /* Add the rounding bias 2^(ell-1) + 1 to share 0. */
  lw x8, 32(x2)
  li x5, 0
  loopi    32, 3
    bn.lid     x5, 0(x8)
    bn.addv.8s w0, w0, w17
    bn.sid     x5, 0(x8++)
  endloop

  /* Step 3: Z = A2B(z_0, z_1) */

  /* Bitslice each share */
  lw  x8, 32(x2)
  lw  x9, 32(x2)
  li  x5, 2048
  add x9, x9, x5
  loopi    2, 34
    addi   x10, x9, 0
    addi   x11, x8, 0
    li     x12, 32
    jal    x1, bitslice_k32
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
    bn.xor w16, w16, w16
    bn.xor w17, w17, w17
    bn.xor w18, w18, w18
    bn.xor w19, w19, w19
    bn.xor w20, w20, w20
    bn.xor w21, w21, w21
    bn.xor w22, w22, w22
    bn.xor w23, w23, w23
    bn.xor w24, w24, w24
    bn.xor w25, w25, w25
    bn.xor w26, w26, w26
    bn.xor w27, w27, w27
    addi   x8, x8, 1024
    addi   x9, x9, 1024
  endloop


  /* SecA2B (BCC22, Alg 8) */
  /* A = (z_0, 0), B = (0, z_1). */
  lw   x11, 32(x2)
  li   x5, 2048
  add  x11, x11, x5   /* z_0 bitsliced */
  addi x12, x11, 1024 /* z_1 bitsliced */
  lw   x14, 32(x2)
  lw   x15, 36(x2)
  addi x28, x14, 0
  addi x29, x15, 0
  li   x5, 0
  li   x6, 1
  li   x7, 31
  loopi 32, 6
    bn.lid x5, 0(x11++)    /* z_0[i] */
    bn.lid x6, 0(x12++)    /* z_1[i] */
    bn.sid x5, 0(x28)      /* A.share0 = z_0[i] */
    bn.sid x7, 1024(x28++) /* A.share1 = 0 */
    bn.sid x7, 0(x29)      /* B.share0 = 0 */
    bn.sid x6, 1024(x29++) /* B.share1 = z_1[i] */
  endloop

  /* Z = A + B mod 2^32 (secadd, k=32, share_str=1024, d=2). */
  addi x10, x14, 0
  addi x11, x15, 0
  li   x12, 32
  li   x13, 1024
  lw   x15, 4(x2)
  jal  x1, secadd

  /* Step 4 implicit by using higher bits. */

  /* Step 5: V' = V' mod delta, two passes of the conditional subtract-delta.
   * V' from step 4 lies in [0, 2*delta] = [0, 88]:
   *  pass 1 maps it to [0, 44],
   *  pass 2 folds the residual 44 -> 0.*/
  lw   x10, 4(x2)
  addi x10, x10, 768 /* V' = top 8 stripes of Z (share 0) */
  lw   x11, 32(x2)
  li   x5, 32
  sub  x2, x2, x5
  sw   x10, 4(x2)
  sw   x11, 16(x2)
  jal  x1, _seccompress_csub
  jal  x1, _seccompress_csub
  li   x5, 32
  add  x2, x2, x5

  lw  x8, 16(x2)
  lw  x9, 20(x2)
  lw  x18, 24(x2)
  lw  x19, 28(x2)
  li  x5, 64
  add x2, x2, x5
  ret


/*
 * _seccompress_csub (internal, d=2): one conditional subtract of delta=44,
 * V' = (V' >= delta) ? V' - delta : V', as a masked select:
 *   diff = V' + (256 - delta)             (secadd_immd_d2, 8 stripes)
 *   mask = MSB(diff)                      (1 iff V' < delta)
 *   tmp  = V' XOR diff                    (sharewise)
 *   V'   = SecAnd(mask, tmp) XOR diff     (mask=1 keeps V', mask=0 takes diff)
 */
_seccompress_csub:
  /* diff = V' + (256 - delta) mod 256 via inline-constant SecAdd. */
  bn.addi w17, w31, 212
  lw      x10, 4(x2)
  li      x12, 8
  li      x13, 1024
  lw      x15, 16(x2)
  addi    x15, x15, 192
  jal     x1, secadd_immd_d2

  /* Masked select over the 8 V'/diff stripes:
   *   V'[i] = (mask & (V'[i] ^ diff[i])) ^ diff[i],  mask = MSB(diff).
   */
  lw   x8, 4(x2)
  lw   x31, 16(x2)
  addi x9, x31, 192
  loopi 8, 36
    /* tmp = V'[i] ^ diff[i] sharewise */
    li     x6, 0
    li     x7, 1
    bn.lid x6, 0(x8)
    bn.lid x7, 0(x9)
    bn.xor w0, w0, w1
    addi   x30, x31, 32
    bn.sid x6, 0(x30)
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.lid x6, 1024(x8)
    bn.lid x7, 1024(x9)
    bn.xor w0, w0, w1
    bn.sid x6, 32(x30)
    /* and = secand(mask = diff[bit 7], tmp) */
    addi   x10, x31, 192
    addi   x10, x10, 224
    li     x11, 1024
    addi   x12, x31, 32
    li     x13, 32
    li     x15, 32
    addi   x16, x31, 96
    jal    x1, secand
    /* V'[i] = and ^ diff[i] sharewise */
    li     x6, 0
    li     x7, 1
    addi   x30, x31, 96
    bn.lid x6, 0(x30)
    bn.lid x7, 0(x9)
    bn.xor w0, w0, w1
    bn.sid x6, 0(x8)
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.lid x6, 32(x30)
    bn.lid x7, 1024(x9)
    bn.xor w0, w0, w1
    bn.sid x6, 1024(x8)
    addi   x8, x8, 32
    addi   x9, x9, 32
  endloop

  ret

/**
 * secdecompose
 *
 * Masked SecDecompose for ML-DSA: from arithmetic shares of w mod q
 * (q = 8380417) produce the unmasked w1 = HighBits(w, alpha) and a sharing of
 * the low part w0, where w = alpha * w1 + w0 mod q and alpha = 2 * gamma2.  The
 * ML-DSA-44 (L2) and ML-DSA-65/87 (L35) variants are selected at runtime from
 * gamma2.
 * Bitsliced.
 *
 *   L2:   w1 <- seccompress(w)
 *   L35:  b' <- -16 * (w + gamma2) - 1 mod q;  b' <- seca2bmodq(b')
 *         w1 <- b'[0, k')
 *   w1 <- unmask(w1)
 *   L2:   w0 <- w - alpha * w1 mod q         (in place over the input shares)
 *   L35:  Boolean shares of (gamma2 - w0) dumped to x15/x16 (consumers b2a them)
 *
 * Source: Alg.7 [ABCH+23]
 *
 * @param[out]  x10: dptr_w1, 1024 B unmasked w1
 * @param[in]   x11: dptr_w, base of arith shares (mod q) at stride x14
 * @param[in]   x12: level (2 = ML-DSA-44 / SecCompress path; 3 or 5 = L35)
 * @param[in]   x13: dptr_scratch (L2: seccompress scratch 4096 B; L35: >= 3296 B)
 * @param[in]   x14: stride between shares in bytes (>= 1024)
 * @param[in]   x15: L2: seccompress B scratch 2048 B; L35: dptr_w0_packed_share0 768 B
 * @param[in]   x16: L2: T_packed 2048 B; L35: dptr_w0_packed_share1 768 B
 * @param[in]   x17: dptr_scratch, 1536 B for seca2bmodq (L35 only)
 * @param[in]   w31: all-zero register
 *
 * w16/w22/w23 are stashed in w28/w29/w30 across the chain.
 *
 * clobbered registers: x2, x4 to x19, x21 to x25, x28 to x31, w0 to w30, mod
 * clobbered flag groups: FG0
 */
.globl secdecompose
.type secdecompose, @function
secdecompose:
  bn.mov w28, w16
  bn.mov w29, w22
  bn.mov w30, w23

  li  x5, 64
  sub x2, x2, x5
  sw  x10, 4(x2) /* w1_out */
  sw  x11, 8(x2) /* w_io */
  sw  x21, 16(x2)
  sw  x22, 20(x2)
  sw  x23, 24(x2)
  sw  x24, 28(x2)
  sw  x25, 32(x2)

  /* Select the variant from the level in x12 (2 = ML-DSA-44); spill it and
   * the per-variant constants (M_BITS / SHARE_STR / ZERO_STRIPES) so they
   * survive the core subcalls. */
  sw  x12, 60(x2)
  li  x5, 2
  bne x12, x5, _secdecompose_l35

  /* ===== ML-DSA-44 (L2): w1 <- SecCompress(w), delta = 44. ===== */
  li x5, 6
  sw x5, 48(x2) /* M_BITS */
  li x5, 1024
  sw x5, 52(x2) /* SHARE_STR */
  li x5, 17
  sw x5, 56(x2) /* ZERO_STRIPES */

  sw   x16, 12(x2) /* T_packed base */
  /* Copy the 2 strided shares of w into contiguous T_packed (x16). */
  addi x28, x11, 0
  addi x29, x16, 0
  li   x31, 0
  loopi 2, 6
    addi x6, x28, 0
    loopi 32, 2
      bn.lid x31, 0(x6++)
      bn.sid x31, 0(x29++)
    endloop
    /* Whitening. */
    bn.xor w0, w0, w0
    add    x28, x28, x14
  endloop
  /* seccompress in place. */
  addi x10, x16, 0
  addi x11, x16, 0
  addi x12, x13, 0
  addi x13, x15, 0
  jal  x1, seccompress
  lw   x25, 12(x2)
  addi x24, x25, 768
  beq  x0, x0, _secdecompose_unmask

_secdecompose_l35:
  /* ===== ML-DSA-65/87 (L35): b' = -16*(w + gamma2) - 1 = -16*w + (q-1)/2. ===== */
  li x5, 4
  sw x5, 48(x2) /* M_BITS */
  li x5, 768
  sw x5, 52(x2) /* SHARE_STR */
  li x5, 19
  sw x5, 56(x2) /* ZERO_STRIPES */

  sw x15, 36(x2) /* w0_packed_share0 */
  sw x16, 40(x2) /* w0_packed_share1 */
  sw x17, 44(x2) /* seca2bmodq scratch */

  addi   x21, x13, 0
  addi   x24, x21, 1024
  /* Share 0: -16*w_s0 + (q-1)/2. */
  la     x5, qm1half_const
  li     x6, 1
  bn.lid x6, 0(x5)
  lw     x28, 8(x2)
  addi   x29, x21, 0
  li     x31, 0
  loopi 32, 8
    bn.lid      x31, 0(x28++)
    bn.subvm.8s w0, w31, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w1
    bn.sid      x31, 0(x29++)
  endloop
  /* Bitslice share 0; zero bit k. */
  addi   x10, x24, 0
  addi   x11, x21, 0
  li     x12, 32
  jal    x1, bitslice
  li     x5, 31
  addi   x6, x24, 736
  bn.sid x5, 0(x6)

  /* Whitening. */
  bn.xor w0, w0, w0
  /* Share 1: -16*w_s1. */
  lw     x28, 8(x2)
  add    x28, x28, x14
  addi   x29, x21, 0
  li     x31, 0
  loopi 32, 7
    bn.lid      x31, 0(x28++)
    bn.subvm.8s w0, w31, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w0
    bn.addvm.8s w0, w0, w0
    bn.sid      x31, 0(x29++)
  endloop

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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  /* Bitslice share 1; zero bit k. */
  addi   x10, x24, 768
  addi   x11, x21, 0
  li     x12, 32
  jal    x1, bitslice
  li     x5, 31
  addi   x6, x24, 1504 /* 768 + 736 */
  bn.sid x5, 0(x6)

  /* b' <- seca2bmodq(b'). */
  addi x10, x24, 0
  addi x11, x24, 0
  li   x12, 2
  lw   x13, 44(x2)
  jal  x1, seca2bmodq

  /* Stripes 4..22 (19) hold Boolean shares of (gamma2 - w0); dump per share
   * to x15/x16 (608 B each). */
  lw   x5, 36(x2)
  addi x28, x24, 128 /* share 0, stripe 4 */
  li   x6, 0
  loopi 19, 2
    bn.lid x6, 0(x28++)
    bn.sid x6, 0(x5++)
  endloop
  lw   x5, 40(x2)
  addi x28, x24, 896 /* share 1, stripe 4 (768 + 128) */
  loopi 19, 2
    bn.lid x6, 0(x28++)
    bn.sid x6, 0(x5++)
  endloop
  addi x25, x24, 1536

_secdecompose_unmask:
  /* w1 <- SecUnMask(w1): refresh + XOR-collapse over M_BITS stripes. */
  addi x28, x24, 0  /* share 0 stripe 0 */
  lw   x5, 52(x2)   /* SHARE_STR */
  add  x29, x24, x5 /* share 1 stripe 0 */
  addi x30, x25, 0
  lw   x7, 48(x2)   /* M_BITS */
  li   x5, 0
  li   x6, 1
  loop x7, 7
    bn.lid  x5, 0(x28++)
    bn.lid  x6, 0(x29++)
    bn.wsrr w2, URND
    bn.xor  w0, w0, w2
    bn.xor  w1, w1, w2
    bn.xor  w0, w0, w1
    bn.sid  x5, 0(x30++)
  endloop

  /* Zero stripes M_BITS..KBITS-1. */
  lw x5, 56(x2) /* ZERO_STRIPES */
  li x6, 31
  loop x5, 1
    bn.sid x6, 0(x30++)
  endloop

  /* unbitslice w1. */
  lw   x10, 4(x2)
  addi x11, x25, 0
  jal  x1, unbitslice

  /* Line 9 (L2 only): w0 <- w - alpha*w1 mod q. */
  lw  x5, 60(x2)
  li  x6, 2
  bne x5, x6, _secdecompose_epilogue

  bn.wsrw 0x0, w28 /* MOD = R|Q (stashed) for subvm */
  la      x5, gamma2_vec_const
  li      x6, 24
  bn.lid  x6, 0(x5)
  lw      x10, 4(x2)
  lw      x11, 8(x2)
  li      x5, 0
  li      x6, 1
  loopi 32, 7
    bn.lid             x5, 0(x10++)
    bn.mulv.8s.even.lo w0, w0, w24
    bn.mulv.8s.odd.lo  w0, w0, w24
    bn.addv.8s         w0, w0, w0
    bn.lid             x6, 0(x11)
    bn.subvm.8s        w0, w1, w0
    bn.sid             x5, 0(x11++)
  endloop

_secdecompose_epilogue:
  lw  x21, 16(x2)
  lw  x22, 20(x2)
  lw  x23, 24(x2)
  lw  x24, 28(x2)
  lw  x25, 32(x2)
  li  x5, 64
  add x2, x2, x5

  bn.mov w16, w28
  bn.mov w22, w29
  bn.mov w23, w30
  ret

/**
 * masked_poly_uniform_eta / masked_poly_uniform_eta_export
 *
 * Produce an arithmetic sharing (mod q) of one s1/s2 polynomial,
 * ExpandS(rho', nonce): draw 4-bit nibbles from SHAKE-256(rho' || nonce) and
 * map each accepted nibble n to eta - reduce(n) per FIPS 204 CoeffFromHalfByte:
 *   eta = 2: reject n == 15, coefficient = 2 - (n mod 5)
 *   eta = 4: reject n >= 9,  coefficient = 4 - n
 * The variant is selected at runtime from the eta argument (x15).
 * Bitsliced.
 *
 *   draw + reject-gather 256 accepted nibbles (two shares each) into G0/G1
 *   n^B <- bitslice(G0, G1)
 *   m   <- n mod 5                       (eta = 2 only; eta = 4 uses n as-is)
 *   r   <- secb2amodq_eta(m)             (reduce(n) -> arithmetic shares mod q)
 *   out <- eta - r                       (eta folded into one share)
 *
 * This is FIPS 204 CoeffFromHalfByte, NOT [ABCH+23] Alg.6 SecSampleModp: Alg.6
 * also samples [-eta, eta] but encodes the XOF differently (3-bit, accept 5/8
 * vs FIPS's 15/16), deriving a different key; we must match the FIPS key
 * bit-for-bit.  Primitives: SecAnd / SecAdd / SecB2AModp [BC22]; (n>=5)/(n>=10)
 * use the [ABCH+23] SecLeq carry bit.
 *
 * @param[out]  x10: dptr_out, 2 * 1024 B arithmetic shares (mod q); also holds
 *                   bitsliced m transiently before the b2a consumes it
 * @param[in]   x11: dptr_seed, 2 * 64 B masked rho' (share-major)
 * @param[in]   x12: nonce (uint16_t)
 * @param[in]   x13: dptr_scratch, >= 3104 B (also the b2a seca2b scratch)
 * @param[in]   x14: dptr_b2a_buf, 1536 B (secb2amodq_eta Boolean buffer)
 * @param[in]   x15: eta (variant selector: 2 or 4)
 * @param[in]   w31: all-zero register
 *
 * The _export entry additionally takes x16 = dptr_export (2 * POLYETA B) and
 * copies the bitsliced reduce(n) shares there for the expanded secret key.
 *
 * clobbered registers: x2, x4 to x18, x27 to x31, w0 to w27, w30
 * clobbered flag groups: FG0
 */

.globl masked_poly_uniform_eta
.type masked_poly_uniform_eta, @function
masked_poly_uniform_eta:
  addi x16, x0, 0 /* no export */
.globl masked_poly_uniform_eta_export
.type masked_poly_uniform_eta_export, @function
masked_poly_uniform_eta_export:
  addi x2, x2, -64
  sw   x10, 0(x2)  /* out ptr (also bitsliced m, then output) */
  sw   x13, 4(x2)  /* scratch base (= b2a seca2b scratch) */
  sw   x14, 8(x2)  /* b2a Boolean buffer */
  sw   x15, 12(x2) /* eta (variant: 2 or 4) */
  sw   x8, 16(x2)  /* callee-save: caller parks pointers here */
  sw   x9, 20(x2)
  sw   x18, 24(x2)
  sw   x27, 28(x2)
  sw   x16, 32(x2) /* export dest */

  /* ---- Init masked SHAKE-256, absorb rho' shares + nonce. ---- */
  addi  x14, x0, 64
  addi  x14, x14, 2
  slli  x5, x14, 5
  addi  x5, x5, SHAKE256_CFG
  addi  x14, x0, 1
  slli  x14, x14, 20 /* masking-enable bit */
  add   x5, x5, x14
  csrrw x0, kmac_cfg, x5

  bn.lid  x0, 0(x11)  /* share0[0..32] */
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.lid  x0, 64(x11) /* share1[0..32] */
  bn.wsrw kmac_msg1, w0
  bn.lid  x0, 32(x11) /* share0[32..64] */
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.lid  x0, 96(x11) /* share1[32..64] */
  bn.wsrw kmac_msg1, w0

  /* Nonce, using out[0..32] as scratch (overwritten later). */
  bn.sid  x0, 0(x10)
  sw      x12, 0(x10)
  bn.lid  x0, 0(x10)
  li      x5, 2
  csrrw   x0, kmac_partial_write, x5
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.wsrw kmac_msg1, w0

  /* ---- Reject-and-gather 256 accepted nibbles into G0/G1. ---- */
  /* w30 = per-nibble bit-0 mask (bits 0,4,8,...,252).  Built from the byte
   * pattern 0x11 (= bits 0,4) with byte-aligned shifts only, since the
   * shifted-operand form encodes the shift as uimm5<<3 (multiples of 8). */
  bn.addi w30, w31, 0x11
  bn.or   w30, w30, w30 << 8
  bn.or   w30, w30, w30 << 16
  bn.or   w30, w30, w30 << 32
  bn.or   w30, w30, w30 << 64
  bn.or   w30, w30, w30 << 128

  lw   x13, 4(x2)
  addi x8, x13, 0     /* G0 write cursor */
  addi x9, x13, 1024  /* G1 write cursor */
  addi x18, x13, 1024 /* G0 end (256 nibbles done) */

_mpue_squeeze:
  /* s0_w/s1_w = next 64 masked nibbles (share 0 / share 1). */
  bn.wsrr w0, kmac_digest
  bn.wsrr w1, kmac_digest1

  lw      x5, 12(x2) /* eta (2 or 4) */
  li      x6, 2
  bne     x5, x6, _mpue_reject_e4
  /* reject (n == 15) = AND of the nibble's 4 bits, at bit 4i. */
  /* SecAnd: z = n & (n>>1) on the masked nibble n = (w0,w1). */
  bn.rshi w2, w31, w0 >> 1
  bn.rshi w3, w31, w1 >> 1
  bn.wsrr w6, URND
  bn.and  w4, w0, w2
  bn.xor  w4, w4, w6
  bn.and  w7, w0, w3
  bn.xor  w7, w7, w6
  bn.and  w8, w1, w2
  bn.xor  w7, w7, w8
  bn.and  w5, w1, w3
  bn.xor  w5, w5, w7 /* (w4,w5) = shares of z */

  /* SecAnd: u = z & (z>>2)  -> bit 4i = AND of nibble's 4 bits. */
  bn.rshi w2, w31, w4 >> 2
  bn.rshi w3, w31, w5 >> 2
  bn.wsrr w6, URND
  bn.and  w7, w4, w2
  bn.xor  w7, w7, w6
  bn.and  w8, w4, w3
  bn.xor  w8, w8, w6
  bn.and  w2, w5, w2
  bn.xor  w8, w8, w2
  bn.and  w3, w5, w3
  bn.xor  w3, w3, w8 /* (w7,w3) = shares of u */
  beq     x0, x0, _mpue_reject_done
_mpue_reject_e4:
  /* reject (n >= 9) = b3 & (b0|b1|b2), at bit 4i.  Via De Morgan on m = ~n:
   * three SecAnds give b3 & ~(~b0 & ~b1 & ~b2). */
  /* SecAnd: za = m & (m>>1),  m = ~n = (~w0, w1). */
  bn.not  w2, w0
  bn.rshi w3, w31, w2 >> 1
  bn.rshi w4, w31, w1 >> 1
  bn.wsrr w6, URND
  bn.and  w7, w2, w3
  bn.xor  w7, w7, w6
  bn.and  w8, w2, w4
  bn.xor  w8, w8, w6
  bn.and  w9, w1, w3
  bn.xor  w8, w8, w9
  bn.and  w5, w1, w4
  bn.xor  w5, w5, w8 /* za = (w7,w5) */

  /* SecAnd: zb = za & (m>>2)  -> bit 4i = ~b0 & ~b1 & ~b2. */
  bn.rshi w3, w31, w2 >> 2
  bn.rshi w4, w31, w1 >> 2
  bn.wsrr w6, URND
  bn.and  w8, w7, w3
  bn.xor  w8, w8, w6
  bn.and  w9, w7, w4
  bn.xor  w9, w9, w6
  bn.and  w10, w5, w3
  bn.xor  w9, w9, w10
  bn.and  w11, w5, w4
  bn.xor  w11, w11, w9 /* zb = (w8,w11) */
  bn.not  w8, w8       /* ~zb -> bit 4i = b0|b1|b2 */

  /* SecAnd: reject = (n>>3) & ~zb  -> bit 4i = b3 & (b0|b1|b2). */
  bn.rshi w3, w31, w0 >> 3
  bn.rshi w4, w31, w1 >> 3
  bn.wsrr w6, URND
  bn.and  w7, w3, w8
  bn.xor  w7, w7, w6
  bn.and  w9, w3, w11
  bn.xor  w9, w9, w6
  bn.and  w10, w4, w8
  bn.xor  w9, w9, w10
  bn.and  w3, w4, w11
  bn.xor  w3, w3, w9 /* (w7,w3) = shares of reject */
_mpue_reject_done:

  /* Reveal only the per-nibble reject bits (mask off the garbage). */
  bn.and w7, w7, w30
  bn.and w3, w3, w30
  bn.xor w7, w7, w3 /* public reject mask, bit 4i set => reject */

  /* Stash share words + reject mask for the scalar gather. */
  li     x27, 2048  /* SQ0 */
  add    x7, x13, x27
  bn.sid x0, 0(x7)  /* x0 indexes w0 */
  li     x27, 2080  /* SQ1 */
  add    x7, x13, x27
  li     x28, 1
  bn.sid x28, 0(x7) /* w1 */
  li     x27, 2112  /* REJ */
  add    x7, x13, x27
  li     x28, 7
  bn.sid x28, 0(x7) /* w7 */

  /* Gather: 8 words x 8 nibbles, compacting accepted nibbles. */
  li  x27, 2048 /* SQ0 */
  add x5, x13, x27
  li  x27, 2080 /* SQ1 */
  add x7, x13, x27
  li  x27, 2112 /* REJ */
  add x28, x13, x27
  li  x29, 8    /* word counter */
_mpue_word:
  lw   x14, 0(x5)  /* share0 word */
  lw   x15, 0(x7)  /* share1 word */
  lw   x16, 0(x28) /* reject word */
  addi x5, x5, 4
  addi x7, x7, 4
  addi x28, x28, 4
  li   x30, 8      /* nibble counter */
_mpue_nib:
  andi x17, x16, 1  /* reject bit */
  andi x31, x14, 15 /* nibble share0 */
  andi x11, x15, 15 /* nibble share1 */
  srli x16, x16, 4
  srli x14, x14, 4
  srli x15, x15, 4
  bne  x17, x0, _mpue_skip
  sw   x31, 0(x8)
  sw   x11, 0(x9)
  addi x8, x8, 4
  addi x9, x9, 4
  beq  x8, x18, _mpue_gathered
_mpue_skip:
  addi x30, x30, -1
  bne  x30, x0, _mpue_nib
  addi x29, x29, -1
  bne  x29, x0, _mpue_word
  beq  x0, x0, _mpue_squeeze

_mpue_gathered:
  lw  x5, 12(x2) /* eta (2 or 4) */
  li  x6, 2
  bne x5, x6, _mpue_core_e4
  /* ---- mod-5 in the Boolean domain. ---- */
  lw  x13, 4(x2)

  /* Bitslice share 0 -> BS, copy low 5 stripes to N5 share 0; then reuse
   * BS for share 1.  (Single bitslice buffer overlaid by lifetime.) */
  li   x27, 2048   /* BS */
  add  x10, x13, x27
  addi x11, x13, 0 /* G0 */
  li   x12, 32
  jal  x1, bitslice

  lw  x13, 4(x2)
  li  x27, 2048 /* BS */
  add x5, x13, x27
  li  x27, 2784 /* N5 */
  add x6, x13, x27
  li  x7, 0
  loopi 5, 2
    bn.lid x7, 0(x5++)
    bn.sid x7, 0(x6++)
  endloop

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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  li     x27, 2048      /* BS */
  add    x10, x13, x27
  addi   x11, x13, 1024 /* G1 */
  li     x12, 32
  jal    x1, bitslice

  lw   x13, 4(x2)
  li   x27, 2048 /* BS */
  add  x5, x13, x27
  li   x27, 2784 /* N5 */
  add  x6, x13, x27
  addi x6, x6, 160
  loopi 5, 2
    bn.lid x7, 0(x5++)
    bn.sid x7, 0(x6++)
  endloop

  /* c1 = [n>=5] = !SecLeq_4(n): SecAdd_5(n, 2^5-4-1=27), bit 4 = [n<=4]. */
  li      x27, 2784 /* N5 */
  add     x10, x13, x27
  li      x12, 5
  li      x13, 160
  lw      x15, 4(x2)
  li      x27, 0    /* Z */
  add     x15, x15, x27
  bn.xor  w17, w17, w17
  bn.addi w17, w17, 27
  jal     x1, secadd_immd_d2

  /* Build T = c1 gated into the 27 bit-pattern {0,1,3,4}, c1 = !Z[4]. */
  lw  x13, 4(x2)
  jal x1, _mpue_build_subtrahend

  /* m1 = SecAdd_5(n, T) = n - 5*c1. */
  lw  x13, 4(x2)
  li  x27, 2784 /* N5 */
  add x10, x13, x27
  li  x27, 320  /* T */
  add x11, x13, x27
  li  x12, 5
  li  x13, 160
  lw  x15, 4(x2)
  li  x27, 640  /* M1 */
  add x15, x15, x27
  jal x1, secadd

  /* c2 = [n>=10] = !SecLeq_9(n): SecAdd_5(n, 2^5-9-1=22), bit 4 = [n<=9]. */
  lw      x13, 4(x2)
  li      x27, 2784 /* N5 */
  add     x10, x13, x27
  li      x12, 5
  li      x13, 160
  lw      x15, 4(x2)
  li      x27, 0    /* Z */
  add     x15, x15, x27
  bn.xor  w17, w17, w17
  bn.addi w17, w17, 22
  jal     x1, secadd_immd_d2

  lw  x13, 4(x2)
  jal x1, _mpue_build_subtrahend

  /* m = SecAdd_5(m1, T) = n - 5*c1 - 5*c2 = n mod 5, written to the OUTPUT
   * buffer (share0 at out+0, share1 at out+160). */
  lw  x13, 4(x2)
  li  x27, 640   /* M1 */
  add x10, x13, x27
  li  x27, 320   /* T */
  add x11, x13, x27
  li  x12, 5
  li  x13, 160
  lw  x15, 0(x2) /* out */
  jal x1, secadd

  /* Export bitsliced m shares (k=3) to x16 (skipped by the base entry). */
  lw  x16, 32(x2)
  beq x16, x0, _mpue_skip_export_m
  lw  x5, 0(x2) /* m share0 @ out+0 */
  li  x6, 0
  loopi 3, 2
    bn.lid x6, 0(x5++)
    bn.sid x6, 0(x16++)
  endloop
  lw   x5, 0(x2)
  addi x5, x5, 160 /* m share1 @ out+160 */
  loopi 3, 2
    bn.lid x6, 0(x5++)
    bn.sid x6, 0(x16++)
  endloop
  bn.xor w0, w0, w0 /* whitening */
_mpue_skip_export_m:

  /* ---- B2A(m, k=3): out holds m; x13 (dead) is the seca2b scratch. ---- */
  lw   x10, 0(x2)
  addi x11, x10, 0   /* m share0 in out */
  addi x12, x10, 160 /* m share1 in out */
  li   x13, 3
  lw   x14, 4(x2)    /* seca2b scratch (= x13) */
  lw   x15, 8(x2)    /* Boolean buffer */
  jal  x1, secb2amodq_eta
  beq  x0, x0, _mpue_core_done
_mpue_core_e4:
  /* ---- eta=4: no mod 5; coeff = 4 - n.  Bitslice n, B2A(k=4). ---- */
  lw x13, 4(x2)

  /* Bitslice share 0 -> BS; copy low 4 stripes to out+0 (b2a share 0). */
  li   x27, 2048   /* BS */
  add  x10, x13, x27
  addi x11, x13, 0 /* G0 */
  li   x12, 32
  jal  x1, bitslice

  lw  x13, 4(x2)
  li  x27, 2048 /* BS */
  add x5, x13, x27
  lw  x6, 0(x2)
  li  x7, 0
  loopi 4, 2
    bn.lid x7, 0(x5++)
    bn.sid x7, 0(x6++)
  endloop

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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  /* Bitslice share 1 -> BS; copy low 4 stripes to out+128 (b2a share 1). */
  li     x27, 2048      /* BS */
  add    x10, x13, x27
  addi   x11, x13, 1024 /* G1 */
  li     x12, 32
  jal    x1, bitslice

  lw   x13, 4(x2)
  li   x27, 2048 /* BS */
  add  x5, x13, x27
  lw   x6, 0(x2)
  addi x6, x6, 128
  li   x7, 0
  loopi 4, 2
    bn.lid x7, 0(x5++)
    bn.sid x7, 0(x6++)
  endloop

  /* Export bitsliced n shares (k=4, both shares contiguous) to x16
   * (skipped by the base entry). */
  lw  x16, 32(x2)
  beq x16, x0, _mpue_skip_export_n
  lw  x5, 0(x2) /* n share0 @ out+0, share1 @ out+128 */
  li  x6, 0
  loopi 8, 2
    bn.lid x6, 0(x5++)
    bn.sid x6, 0(x16++)
  endloop
  bn.xor w0, w0, w0 /* whitening */
_mpue_skip_export_n:

  /* B2A(n, k=4): out+0 / out+128 hold n; out receives arith shares. */
  lw   x10, 0(x2)
  addi x11, x10, 0
  addi x12, x10, 128
  li   x13, 4
  lw   x14, 4(x2) /* seca2b scratch */
  lw   x15, 8(x2) /* Boolean buffer */
  jal  x1, secb2amodq_eta
_mpue_core_done:

  /* coeff = eta - reduce(n): share 0 = eta - m0, share 1 = -m1  (mod q).
   * Broadcast the eta argument to all 8 lanes of w4. */
  lw      x5, 12(x2) /* eta (2 or 4) */
  li      x6, 2
  bn.addi w4, w31, 4
  bne     x5, x6, _mpue_coeff_bcast
  bn.addi w4, w31, 2
_mpue_coeff_bcast:
  bn.or w4, w4, w4 << 32
  bn.or w4, w4, w4 << 64
  bn.or w4, w4, w4 << 128

  lw   x10, 0(x2)
  li   x5, 0
  addi x6, x10, 0
  loopi 32, 3
    bn.lid      x5, 0(x6)
    bn.subvm.8s w0, w4, w0
    bn.sid      x5, 0(x6++)
  endloop

  /* Whitening. */
  bn.xor w0, w0, w0
  lw     x10, 0(x2)
  addi   x6, x10, 1024
  loopi 32, 3
    bn.lid      x5, 0(x6)
    bn.subvm.8s w0, w31, w0
    bn.sid      x5, 0(x6++)
  endloop

  lw   x8, 16(x2)
  lw   x9, 20(x2)
  lw   x18, 24(x2)
  lw   x27, 28(x2)
  addi x2, x2, 64
  ret

/*
 * Helper: build T from the comparison bit at stripe 4 of Z.
 * c = !Z[4] (flip share 0); gate c into the bit pattern of 27 (= -5 mod 2^5),
 * i.e. stripes {0,1,3,4} = c, stripe 2 = 0.  x13 = scratch base.
 */
_mpue_build_subtrahend:
  /* Load c shares: w0 = !Z[4]_s0, w1 = Z[4]_s1. */
  li     x27, 0      /* Z */
  add    x5, x13, x27
  addi   x5, x5, 128 /* stripe 4 (4 * 32), share 0 */
  li     x7, 0
  bn.lid x7, 0(x5)
  bn.not w0, w0      /* c_s0 = NOT Z[4]_s0 */
  li     x27, 0      /* Z */
  add    x5, x13, x27
  addi   x5, x5, 160
  addi   x5, x5, 128 /* stripe 4, share 1 */
  li     x7, 1
  bn.lid x7, 0(x5)

  /* Write share 0 stripes {0,1,3,4}=c, {2}=0. */
  li     x27, 320    /* T */
  add    x6, x13, x27
  li     x7, 0
  li     x28, 31     /* w31 = 0 */
  bn.sid x7, 0(x6)   /* stripe 0 = c */
  bn.sid x7, 32(x6)  /* stripe 1 = c */
  bn.sid x28, 64(x6) /* stripe 2 = 0 */
  bn.sid x7, 96(x6)  /* stripe 3 = c */
  bn.sid x7, 128(x6) /* stripe 4 = c */

  /* Write share 1 stripes {0,1,3,4}=c, {2}=0. */
  li     x27, 320 /* T */
  add    x6, x13, x27
  addi   x6, x6, 160
  li     x7, 1    /* w1 = c_s1 */
  bn.sid x7, 0(x6)
  bn.sid x7, 32(x6)
  bn.sid x28, 64(x6)
  bn.sid x7, 96(x6)
  bn.sid x7, 128(x6)
  ret


/**
 * masked_poly_uniform_gamma_1
 *
 * Sample a 2-share arithmetic sharing (mod q) of y = gamma1 - u, u uniform in
 * [0, 2^POLYZ_BITS), from masked SHAKE-256(rho' || nonce).  The squeezed u
 * stays masked through bitslice -> secb2amodq -> unbitslice before the
 * gamma1 - u step.  The variant is selected at runtime from x15:
 *   x15 == 2: POLYZ_BITS = 18, gamma1 = 2^17 (ML-DSA-44)
 *   else:     POLYZ_BITS = 20, gamma1 = 2^19
 * Bitsliced.
 *
 * @param[out]  x10: dptr_out, 2 * 1024 B arithmetic shares (mod q)
 * @param[in]   x11: dptr_seed, 2 * 64 B masked rho' (share-major)
 * @param[in]   x12: nonce (uint16_t)
 * @param[in]   x13: dptr_scratch, 1536 B (secb2amodq seca2b scratch)
 * @param[in]   x14: dptr_buf, 1536 B bitsliced-u staging buffer
 * @param[in]   x15: gamma1 variant selector (2 => POLYZ_BITS 18, else 20)
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w30
 * clobbered flag groups: FG0
 */
.globl masked_poly_uniform_gamma_1
.type masked_poly_uniform_gamma_1, @function
masked_poly_uniform_gamma_1:
  addi x2, x2, -32
  sw   x10, 0(x2)  /* out pointer */
  sw   x13, 8(x2)  /* seca2b scratch */
  sw   x14, 12(x2) /* bitslice buffer */

  /* Map x15 to POLYZ_BITS (2 -> 18, else -> 20); spill it. */
  li  x5, 2
  li  x6, 18
  beq x15, x5, _mpug_pb_set
  li  x6, 20
_mpug_pb_set:
  sw x6, 4(x2) /* POLYZ_BITS (18 or 20) */

  bn.mov w28, w16
  bn.mov w29, w22
  bn.mov w30, w23

  /* Init masked SHAKE256, send rho'. */
  addi  x13, x0, 64
  addi  x13, x13, 2
  slli  x5, x13, 5
  addi  x5, x5, SHAKE256_CFG
  addi  x13, x0, 1
  slli  x13, x13, 20
  add   x5, x5, x13
  csrrw x0, kmac_cfg, x5

  bn.lid  x0, 0(x11)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.lid  x0, 64(x11)
  bn.wsrw kmac_msg1, w0
  bn.lid  x0, 32(x11)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.lid  x0, 96(x11)
  bn.wsrw kmac_msg1, w0

  /* Send nonce (out[0..31] as scratch, overwritten later). */
  bn.sid  x0, 0(x10)
  sw      x12, 0(x10)
  bn.lid  x0, 0(x10)
  li      x5, 2
  csrrw   x0, kmac_partial_write, x5
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.wsrw kmac_msg1, w0

  /* Squeeze POLYZ_BITS raw words into the tail of each share's output slot
   * (RAW0 = 1024 - 32*POLYZ_BITS, RAW1 = RAW0 + 1024) so the forward in-place
   * unpack keeps writes below reads. */
  lw   x15, 4(x2)    /* POLYZ_BITS */
  slli x30, x15, 5
  li   x31, 1024
  sub  x31, x31, x30 /* RAW0 */
  add  x6, x10, x31
  addi x7, x6, 1024
  li   x28, 0
  li   x29, 1
  loop x15, 4
    bn.wsrr w0, kmac_digest
    bn.wsrr w1, kmac_digest1
    bn.sid  x28, 0(x6++)
    bn.sid  x29, 0(x7++)
  endloop

  /* Unpack each share in place (out[RAW..1023] -> out[0..1023]).  w5 = the
   * per-coef mask 2^POLYZ_BITS - 1, built inline (avoids a per-mode const). */
  lw      x5, 4(x2)          /* POLYZ_BITS */
  li      x6, 18
  bn.addi w5, w31, 1
  bne     x5, x6, _mpug_mask_20
  bn.rshi w5, w5, w31 >> 238 /* 2^18 */
  beq     x0, x0, _mpug_mask_sub
_mpug_mask_20:
  bn.rshi w5, w5, w31 >> 236 /* 2^20 */
_mpug_mask_sub:
  bn.subi w5, w5, 1 /* 2^POLYZ_BITS - 1 */
  bn.or   w5, w5, w5 << 32
  bn.or   w5, w5, w5 << 64
  bn.or   w5, w5, w5 << 128

  lw     x15, 4(x2)    /* POLYZ_BITS */
  slli   x30, x15, 5
  li     x31, 1024
  sub    x31, x31, x30 /* RAW0 */
  add    x11, x10, x31
  /* Whitening. */
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  jal    x1, _unpack_share

  lw     x10, 0(x2)
  lw     x15, 4(x2)     /* POLYZ_BITS */
  slli   x30, x15, 5
  li     x31, 1024
  sub    x31, x31, x30
  addi   x31, x31, 1024 /* RAW1 = RAW0 + 1024 */
  add    x11, x10, x31
  addi   x10, x10, 1024
  /* Whitening. */
  bn.xor w1, w1, w1
  bn.xor w2, w2, w2
  bn.xor w3, w3, w3
  bn.xor w6, w6, w6
  jal    x1, _unpack_share

  /* Bitslice each share to caller's buffer (top bit zeroed for k+1). */
  lw     x11, 0(x2)
  lw     x10, 12(x2)
  li     x12, 32
  jal    x1, bitslice
  lw     x6, 12(x2)
  addi   x6, x6, 736
  li     x5, 31
  bn.sid x5, 0(x6)

  lw     x11, 0(x2)
  addi   x11, x11, 1024
  lw     x10, 12(x2)
  addi   x10, x10, 768
  li     x12, 32
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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  jal    x1, bitslice
  lw     x6, 12(x2)
  addi   x6, x6, 1504
  li     x5, 31
  bn.sid x5, 0(x6)

  /* B2A: u^{B,k} (buffer) -> u^{A_p} at caller out. */
  lw  x11, 12(x2)
  lw  x10, 0(x2)
  lw  x13, 8(x2)
  jal x1, secb2amodq

  /* Unbitslice each share in place; share 1 first so its overlapping
   * write [1024..1503] doesn't clobber share 0's source. */
  lw   x10, 0(x2)
  addi x11, x10, 768
  addi x10, x10, 1024
  jal  x1, unbitslice

  lw     x10, 0(x2)
  addi   x11, x10, 0
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
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  jal    x1, unbitslice

  /* y = gamma1 - u on share 0, -u on share 1.  gamma1 = 2^(POLYZ_BITS-1),
   * built into all 8 lanes of w4 (avoids a per-mode constant load). */
  lw      x5, 4(x2)          /* POLYZ_BITS */
  li      x6, 18
  bn.addi w4, w31, 1
  bne     x5, x6, _mpug_g1_20
  bn.rshi w4, w4, w31 >> 239 /* 2^17 */
  beq     x0, x0, _mpug_g1_bcast
_mpug_g1_20:
  bn.rshi w4, w4, w31 >> 237 /* 2^19 */
_mpug_g1_bcast:
  bn.or w4, w4, w4 << 32
  bn.or w4, w4, w4 << 64
  bn.or w4, w4, w4 << 128

  lw   x10, 0(x2)
  li   x5, 0
  addi x6, x10, 0
  loopi 32, 3
    bn.lid      x5, 0(x6)
    bn.subvm.8s w0, w4, w0
    bn.sid      x5, 0(x6++)
  endloop

  /* Whitening. */
  bn.xor w0, w0, w0
  lw     x10, 0(x2)
  addi   x6, x10, 1024
  loopi 32, 3
    bn.lid      x5, 0(x6)
    bn.subvm.8s w0, w31, w0
    bn.sid      x5, 0(x6++)
  endloop

  bn.mov w16, w28
  bn.mov w22, w29
  bn.mov w23, w30

  addi x2, x2, 32
  ret


/* Per-share unpack (caller pre-loads w5 = the per-coef mask 2^POLYZ_BITS-1). */
_unpack_share:
  addi x6, x10, 0
  addi x31, x11, 0
  li   x7, 2
  li   x5, 6
  li   x28, 3
  lw   x29, 4(x2) /* POLYZ_BITS */
  li   x30, 18
  bne  x29, x30, _unpack_share_20

  /* L2: 2 outer x 16 inner unpacks (144 raw bits each). */
  loopi 2, 42
    bn.lid x5, 0(x31++)
    bn.mov w1, w6
    jal    x1, _unpack_inner_18

    bn.lid  x28, 0(x31++)
    bn.rshi w1, w3, w6 >> 144
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w3 >> 32
    jal     x1, _unpack_inner_18

    bn.lid  x5, 0(x31++)
    bn.rshi w1, w6, w3 >> 176
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w6 >> 64
    jal     x1, _unpack_inner_18

    bn.lid  x28, 0(x31++)
    bn.rshi w1, w3, w6 >> 208
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w3 >> 96
    jal     x1, _unpack_inner_18

    bn.lid  x5, 0(x31++)
    bn.rshi w1, w6, w3 >> 240
    jal     x1, _unpack_inner_18

    bn.lid  x28, 0(x31++)
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w3 >> 16
    jal     x1, _unpack_inner_18

    bn.lid  x5, 0(x31++)
    bn.rshi w1, w6, w3 >> 160
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w6 >> 48
    jal     x1, _unpack_inner_18

    bn.lid  x28, 0(x31++)
    bn.rshi w1, w3, w6 >> 192
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w3 >> 80
    jal     x1, _unpack_inner_18

    bn.lid  x5, 0(x31++)
    bn.rshi w1, w6, w3 >> 224
    jal     x1, _unpack_inner_18

    bn.rshi w1, w31, w6 >> 112
    jal     x1, _unpack_inner_18
    nop
  endloop

  ret

_unpack_share_20:
  /* L3/L5: 4 outer x 8 inner unpacks (160 raw bits each). */
  loopi 4, 22
    bn.lid x5, 0(x31++)
    bn.mov w1, w6
    jal    x1, _unpack_inner_20

    bn.lid  x28, 0(x31++)
    bn.rshi w1, w3, w6 >> 160
    jal     x1, _unpack_inner_20

    bn.rshi w1, w31, w3 >> 64
    jal     x1, _unpack_inner_20

    bn.lid  x5, 0(x31++)
    bn.rshi w1, w6, w3 >> 224
    jal     x1, _unpack_inner_20

    bn.lid  x28, 0(x31++)
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _unpack_inner_20

    bn.rshi w1, w31, w3 >> 32
    jal     x1, _unpack_inner_20

    bn.lid  x5, 0(x31++)
    bn.rshi w1, w6, w3 >> 192
    jal     x1, _unpack_inner_20

    bn.rshi w1, w31, w6 >> 96
    jal     x1, _unpack_inner_20
    nop
  endloop

  ret

/* Inner: extract 8 coefs from w1, mask, store at x6++. */
_unpack_inner_18:
  loopi 8, 2
    bn.rshi w2, w1, w2 >> 32
    bn.rshi w1, w31, w1 >> 18
  endloop
  bn.and w2, w2, w5
  bn.sid x7, 0(x6++)
  ret

_unpack_inner_20:
  loopi 8, 2
    bn.rshi w2, w1, w2 >> 32
    bn.rshi w1, w31, w1 >> 20
  endloop
  bn.and w2, w2, w5
  bn.sid x7, 0(x6++)
  ret
