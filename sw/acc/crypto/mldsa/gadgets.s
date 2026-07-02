/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

/* Register aliases */
.equ x0,  zero
.equ x1,  ra
.equ x2,  sp
.equ x3,  fp
.equ x4,  tp
.equ x5,  t0
#define t1 x6
.equ x7,  t2
.equ x8,  s0
.equ x9,  s1
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

/* KMAC mode config for the SHAKE-256 XOF used by the masked samplers. */
#define SHAKE256_CFG 0xA


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

/*
 * Name: secand
 *
 * Return new Boolean shares of a value r = x & y.
 * Bitsliced.
 *
 *   s   <- urnd
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
    addi t0, x0, 2
    addi t1, x0, 3
    addi t2, x0, 4
    addi t3, x0, 5
    addi t4, x0, 6

    /* Compute tb[0] = xb[0] & yb[0]. */
    /* Whitening. */
    bn.xor w1, w1, w1
    bn.xor w3, w3, w3
    bn.xor w5, w5, w5
    bn.lid x4, 0(a0)  /* w1 = xb[0] */
    bn.lid t1, 0(a2)  /* w3 = yb[0] */
    bn.and w5, w1, w3 /* w5 = tb[0] */

    /* Compute tb[1] = xb[1] & yb[1]. */
    /* Whitening. */
    bn.xor w2, w2, w2
    bn.xor w4, w4, w4
    bn.xor w6, w6, w6
    add    t5, a0, a1
    bn.lid t0, 0(t5)  /* w2 = xb[1] */
    add    t5, a2, a3
    bn.lid t2, 0(t5)  /* w4 = yb[1] */
    bn.and w6, w2, w4 /* w6 = tb[1] */

    /* Refresh with one fresh random. */
    bn.wsrr w0, urnd /* w0 = r */

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
    bn.sid t3, 0(a6) /* rb[0] = tb[0] */
    add    t5, a6, a5
    bn.sid t4, 0(t5) /* rb[1] = tb[1] */

    ret

/*
 * Name: secfulladder
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
    addi x4, x0, 1 /* w1 = x[0] */
    addi t0, x0, 2 /* w2 = x[1] */
    addi t1, x0, 3 /* w3 = a[0] (= x[0] ^ y[0]) */
    addi t2, x0, 4 /* w4 = a[1] */
    addi t3, x0, 5 /* w5 = c[0] then t[0] */
    addi t4, x0, 6 /* w6 = c[1] then t[1] */
    addi t6, x0, 0 /* w0 = scratch (rand + write temp) */

    /* Load share 0: x[0] -> w1, a[0] -> w3, c[0] -> w5. */
    bn.xor w1, w1, w1
    bn.xor w3, w3, w3
    bn.xor w5, w5, w5
    bn.lid x4, 0(a0)  /* w1 = x[0] */
    bn.lid t1, 0(a1)  /* w3 = y[0] */
    bn.xor w3, w1, w3 /* w3 = a[0] = x[0] ^ y[0] */
    bn.lid t3, 0(a2)  /* w5 = c[0] */

    /* Load share 1: x[1] -> w2, a[1] -> w4, c[1] -> w6. */
    bn.xor w2, w2, w2
    bn.xor w4, w4, w4
    bn.xor w6, w6, w6
    add    t5, a0, a3
    bn.lid t0, 0(t5)  /* w2 = x[1] */
    add    t5, a1, a3
    bn.lid t2, 0(t5)  /* w4 = y[1] */
    bn.xor w4, w2, w4 /* w4 = a[1] = x[1] ^ y[1] */
    addi   t5, a2, 32 /* c shares are at stride 32 (caller's stack-scratch layout) */
    bn.lid t4, 0(t5)  /* w6 = c[1] */

    /* Compute r[0] = c ^ a. */
    bn.xor w0, w0, w0 /* Whitening. */
    bn.xor w0, w5, w3 /* w0 = r[0][0] = c[0] ^ a[0] */
    bn.sid t6, 0(a5)
    bn.xor w0, w0, w0 /* Whitening. */
    bn.xor w0, w6, w4 /* w0 = r[0][1] */
    add    t5, a5, a3
    bn.sid t6, 0(t5)

    /* Compute t = x ^ c (overwrites c slots w5, w6). */
    bn.xor w5, w1, w5 /* w5 = t[0] = x[0] ^ c[0] */
    bn.xor w6, w2, w6 /* w6 = t[1] = x[1] ^ c[1] */

    /* Inlined secand: tb = a & t. */
    bn.xor w7, w7, w7
    bn.and w7, w3, w5 /* tb[0] = a[0] & t[0] */
    bn.xor w8, w8, w8
    bn.and w8, w4, w6 /* tb[1] = a[1] & t[1] */

    bn.wsrr w0, urnd /* w0 = r (fresh randomness) */

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
    bn.xor w0, w0, w0 /* Whitening. */
    bn.xor w0, w1, w7 /* w0 = r[1][0] = x[0] ^ t[0] */
    bn.sid t6, 0(a6)
    bn.xor w0, w0, w0 /* Whitening. */
    bn.xor w0, w2, w8 /* w0 = r[1][1] */
    addi   t5, a6, 32 /* r[1] (= output carry) is at stride 32 */
    bn.sid t6, 0(t5)

    /* Advance per the secadd bit loop's expectations. */
    addi a0, a0, 32
    addi a1, a1, 32
    addi a5, a5, 32
    /* a2, a3, a6 preserved. */

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
    /* Reserve frame: 64 B carry c at 0(sp), saved s0 at 64(sp). */
    addi sp, sp, -96
    sw   s0, 64(sp)

    /* Initialize c = 0. */
    bn.xor w0, w0, w0
    addi   t0, sp, 0 /* ptr_c */
    loopi 2, 1
        bn.sid x0, 0(t0++)
    endloop

    /* Ripple-carry adder. */
    addi s0, a2, -1
    /* Loop over i = 0, ..., k-2. */
    loop s0, 4
        /* a0 already points to x[i] */
        /* a1 already points to y[i] */
        addi a2, sp, 0 /* ptr_c */
        /* a3 is already share stride. */
        /* a5 already points to r. */
        addi a6, sp, 0 /* ptr_c */
        jal  x1, secfulladder
        /* After secfulladder:
         *  - a0 and a1 points to x[i + 1] and y[i + 1].
         *  - a3 is still share stride.
         *  - a5 points to r[i + 1].
         *  - a6 points to c. */
        nop
    endloop

    /* Handle top bit i = k-1. */
    /* Compute r[k-1] = x[k-1] ^ y[k-1] ^ c. */
    addi t0, sp, 0 /* ptr_c */
    addi x4, x0, 1
    addi t1, x0, 2
    addi t2, x0, 3
    loopi 2, 13
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.xor w2, w2, w2
        bn.xor w3, w3, w3
        /* Computation. */
        bn.lid x0, 0(a0)
        bn.lid x4, 0(a1)
        bn.lid t1, 0(t0++)
        bn.xor w3, w0, w1
        bn.xor w3, w3, w2
        bn.sid t2, 0(a5)
        /* Adjust addresses. */
        add    a0, a0, a3
        add    a1, a1, a3
        add    a5, a5, a3
    endloop

    /* Restore registers and stack. */
    lw   s0, 64(sp)
    addi sp, sp, 96
    ret

/*
 * Name: secadd_immd_d1
 *
 * Bitsliced SecAdd for d = 1 of x and the hard-coded constant nq = 0x801FFF
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
    li   t1, 1
    li   t4, 4

    bn.not w6, w31 /* w6 = all-ones */

    /* Build nq = 0x801FFF in w7 lane 0 (= 2^23 + 2^13 - 1). */
    bn.xor w7, w7, w7
    bn.addi w7, w7, 1
    bn.shv.8s w7, w7 << 23 /* lane 0 = 0x800000 */
    bn.xor w8, w8, w8
    bn.addi w8, w8, 1
    bn.shv.8s w8, w8 << 13 /* w8 lane 0 = 0x2000 */
    bn.subi w8, w8, 1      /* w8 lane 0 = 0x1FFF */
    bn.add  w7, w7, w8     /* w7 lane 0 = 0x801FFF */

    bn.xor w8, w8, w8
    bn.addi w8, w8, 1 /* w8 = 1 (lane 0 bit 0) */

    /* Bit 0. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.lid t1, 0(a0++)
    bn.and w3, w7, w8
    bn.cmp w3, w31
    bn.sel w2, w31, w6, FG0.Z
    bn.rshi w7, w31, w7 >> 1
    bn.xor w4, w1, w2
    bn.sid t4, 0(a6++)
    bn.and w0, w1, w2

    /* Bits 1..kbits-1. */
    addi t6, a2, -1
    loop t6, 11
        bn.lid t1, 0(a0++)
        bn.and w3, w7, w8
        bn.cmp w3, w31
        bn.sel w2, w31, w6, FG0.Z
        bn.rshi w7, w31, w7 >> 1
        bn.xor w3, w1, w2
        bn.xor w4, w3, w0
        bn.sid t4, 0(a6++)
        bn.and w5, w1, w2
        bn.and w0, w0, w3
        bn.xor w0, w0, w5
    endloop

    /* Final carry bit: z[kbits] = carry ^ y[kbits]. */
    bn.and w3, w7, w8
    bn.cmp w3, w31
    bn.sel w2, w31, w6, FG0.Z
    bn.xor w4, w0, w2
    bn.sid t4, 0(a6)

    ret

/*
 * Name: secadd_immd_d2
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
    add  t4, a0, a3 /* t4 = x share 1 ptr */
    add  t5, a5, a3 /* t5 = z share 1 ptr */

    bn.not w19, w31     /* w19 = all-ones */
    bn.xor w18, w18, w18
    bn.addi w18, w18, 1 /* w18 = lane-0 bit 0 */

    bn.xor w12, w12, w12 /* c_0 = 0 */
    bn.xor w13, w13, w13 /* c_1 = 0 */

    li   t0, 1  /* x_0 -> w1 */
    li   t1, 2  /* x_1 -> w2 */
    li   t2, 10 /* r_0 idx (= w10) */
    li   t3, 11 /* r_1 idx (= w11) */

    addi t6, a2, 0
    loop t6, 39
        /* Derive y_bit. */
        bn.and w0, w17, w18
        bn.cmp w0, w31
        bn.sel w3, w31, w19, FG0.Z
        bn.rshi w17, w31, w17 >> 1

        /* Share 0: a_0 = x_0 ^ y_bit, t_0 = x_0 ^ c_0, r_0 = c_0 ^ a_0. */
        bn.xor w1, w1, w1
        bn.lid t0, 0(a0)
        bn.xor w4, w1, w3
        bn.xor w6, w1, w12
        bn.xor w10, w12, w4
        bn.sid t2, 0(a5)

        bn.xor w0, w0, w0 /* Whitening. */

        /* Share 1: a_1 = x_1, t_1 = x_1 ^ c_1, r_1 = c_1 ^ a_1. */
        bn.xor w2, w2, w2
        bn.lid t1, 0(t4)
        bn.mov w5, w2
        bn.xor w7, w2, w13
        bn.xor w11, w13, w5
        bn.sid t3, 0(t5)

        /* SecAnd(a_0,a_1; t_0,t_1) -> (u_0, u_1). */
        bn.wsrr w14, urnd
        bn.xor w16, w7, w14
        bn.and w16, w16, w4
        bn.not w15, w4
        bn.and w15, w15, w14
        bn.xor w15, w15, w16
        bn.and w8, w4, w6
        bn.xor w8, w8, w15

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
        addi a0, a0, 32
        addi t4, t4, 32
        addi a5, a5, 32
        addi t5, t5, 32
    endloop

    ret

/*
 * Name: secadd_constant_bmsk
 *
 * Fused steps 5+6 of Alg.7 specialised for ML-DSA q, in place over dptr_z:
 *   z <- sp + BitCopyMask(sp[k], q)
 * Bitsliced.  q = 0x7FE001 is hard-coded, giving the per-bit run structure
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
    li   t0, 4
    li   t1, 5
    li   t2, 8
    li   t3, 9
    li   t4, 20
    li   t5, 21
    li   t6, 31

    addi a1, a0, 768 /* (k+1) * 32 */

    /* Load b = sp[k]; zero carry. */
    li   a2, 23 /* k */
    slli a2, a2, 5
    add  a3, a0, a2
    add  a4, a1, a2
    bn.lid t4, 0(a3)
    bn.lid t5, 0(a4)
    bn.xor w22, w22, w22
    bn.xor w23, w23, w23

    /* bit 0 (q=1) */
    bn.lid  t0, 0(a0)
    bn.lid  t1, 0(a1)
    bn.xor  w6, w4, w20 /* xpy = sp ^ b */
    bn.xor  w7, w5, w21
    bn.xor  w8, w22, w6 /* z = c ^ xpy */
    bn.xor  w9, w23, w7
    bn.sid  t2, 0(a0++)
    bn.sid  t3, 0(a1++)
    bn.xor  w10, w4, w22 /* xpc = sp ^ c */
    bn.xor  w11, w5, w23
    /* c' = sp ^ SecAnd(xpy, xpc). */
    bn.and  w12, w6, w10
    bn.and  w13, w7, w11
    bn.wsrr w14, urnd
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
        bn.lid  t0, 0(a0)
        bn.lid  t1, 0(a1)
        bn.xor  w8, w22, w4 /* z = c ^ sp */
        bn.xor  w9, w23, w5
        bn.sid  t2, 0(a0++)
        bn.sid  t3, 0(a1++)
        /* c' = SecAnd(c, sp). */
        bn.and  w12, w22, w4
        bn.and  w13, w23, w5
        bn.wsrr w14, urnd
        bn.and  w15, w22, w5
        bn.xor  w15, w15, w14
        bn.and  w16, w23, w4
        bn.xor  w16, w16, w14
        bn.xor  w22, w12, w15
        bn.xor  w23, w13, w16
    endloop

    /* bits 13..22 (q=1) */
    loopi 10, 21
        bn.lid  t0, 0(a0)
        bn.lid  t1, 0(a1)
        bn.xor  w6, w4, w20 /* xpy = sp ^ b */
        bn.xor  w7, w5, w21
        bn.xor  w8, w22, w6 /* z = c ^ xpy */
        bn.xor  w9, w23, w7
        bn.sid  t2, 0(a0++)
        bn.sid  t3, 0(a1++)
        bn.xor  w10, w4, w22 /* xpc = sp ^ c */
        bn.xor  w11, w5, w23
        /* c' = sp ^ SecAnd(xpy, xpc). */
        bn.and  w12, w6, w10
        bn.and  w13, w7, w11
        bn.wsrr w14, urnd
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
    bn.sid t6, 0(a3)
    bn.sid t6, 0(a4)

    ret

/*
 * Name: secaddmodq
 *
 * Return Boolean shares of z = (x + y) mod q, given k-bit Boolean shares of
 * x, y with 0 <= x, y < q.
 * Bitsliced.
 *
 *   nq <- 2^{k+1} - q                 (immediate 0x801FFF)
 *   s  <- SecAdd(x, y)
 *   sp <- SecAdd(s, nq)
 *   b  <- sp[k]
 *   a  <- BitCopyMask(b, q)
 *   z  <- SecAdd(a, sp)
 *
 * The b/a/z steps are fused inside secadd_constant_bmsk.  ML-DSA only
 * (q = 0x7FE001 hard-coded; matches the external nq).
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
    addi a7, a0, 0 /* park z_out in a7 */

    /* Step 2: s = SecAdd(x, y) -> z_out. */
    addi a0, a1, 0
    addi a1, a2, 0
    li   a2, 24 /* k+1 */
    li   a3, 768 /* (k+1) * 32 */
    addi a5, a7, 0
    jal  x1, secadd

    /* Step 3: sp = SecAdd(s, nq) -> z_out, in place. */
    bn.xor w17, w17, w17
    bn.addi w17, w17, 1
    bn.shv.8s w17, w17 << 23
    bn.xor w18, w18, w18
    bn.addi w18, w18, 1
    bn.shv.8s w18, w18 << 13
    bn.subi w18, w18, 1
    bn.add w17, w17, w18 /* w17 lane 0 = nq = 0x801FFF */
    addi a0, a7, 0
    li   a2, 24 /* k+1 */
    li   a3, 768 /* (k+1) * 32 */
    addi a5, a7, 0
    jal  x1, secadd_immd_d2

    /* Step 4+5+6: z = sp + BitCopyMask(sp[k], q) -> z_out, in-place. */
    addi a0, a7, 0
    jal  x1, secadd_constant_bmsk

    ret

/*
 * Name: seca2bmodq
 *
 * Return Boolean shares mod 2^k (k = 23) of a value x mod q (q = 0x7FE001),
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
    addi sp, sp, -32
    sw   a3, 0(sp) /* preserve scratch across secadd calls */
    addi a7, a0, 0 /* park z_out */

    /* s' <- (0, x[1]). */
    addi t3, a1, 768 /* (k+1) * 32 */
    addi t1, a3, 0
    li   t2, 31
    loopi 24, 1
        bn.sid t2, 0(t1++)
    endloop
    bn.xor w0, w0, w0 /* Whitening. */
    li   t2, 0
    loopi 24, 2
        bn.lid t2, 0(t3++)
        bn.sid t2, 0(t1++)
    endloop
    bn.xor w0, w0, w0 /* Whitening. */

    /* s share 0 <- (2^{k+1} - q) + x[0]. */
    addi a0, a1, 0
    li   a2, 23 /* k */
    addi a6, a7, 0
    jal  x1, secadd_immd_d1

    /* s share 1 <- 0. */
    addi t1, a7, 768 /* (k+1) * 32 */
    li   t2, 31
    loopi 24, 1
        bn.sid t2, 0(t1++)
    endloop

    /* u <- secadd(s, s'). */
    lw   a0, 0(sp)
    addi a1, a7, 0
    li   a2, 24 /* k+1 */
    li   a3, 768 /* (k+1) * 32 */
    addi a5, a7, 0
    jal  x1, secadd

    /* a <- bitcopymask(u[k]); z <- secadd(a, u). */
    addi a0, a7, 0
    jal  x1, secadd_constant_bmsk

    addi sp, sp, 32
    ret

/*
 * Name: secleq
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
    addi a7, a1, 0

    /* x' <- SecAdd(x, C), in place. */
    addi a0, a1, 0
    addi a5, a1, 0
    li   a2, 24 /* k+1 */
    li   a3, 768 /* (k+1) * 32 */
    jal  x1, secadd_immd_d2

    /* b <- SecUnMask(x'[k]). */
    addi t1, a7, 736 /* x'[k], share 0 */
    addi t6, t1, 768 /* x'[k], share 1 */
    li      t3, 0
    bn.lid  t3, 0(t1)
    li      t4, 1
    bn.lid  t4, 0(t6)
    bn.wsrr w2, urnd
    bn.xor  w0, w0, w2
    bn.xor  w1, w1, w2
    bn.xor  w0, w0, w1
    ret

/*
 * Name: secunmask_modq
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
    /* w11 = 0x007FFFFF * 8 (23-bit per-lane mask). */
    bn.not  w11, w31
    bn.rshi w11, w31, w11 >> 233
    bn.or   w11, w11, w11 << 32
    bn.or   w11, w11, w11 << 64
    bn.or   w11, w11, w11 << 128

    /* w13 = 0xFF000000 * 8 (top byte of each lane). */
    bn.shv.8s w13, w11 << 24

    /* w12 = q packed 8 lanes. */
    li     t0, 12
    la     t1, modulus
    bn.lid t0, 0(t1)

    addi t3, a1, 0 /* share 0 cursor */
    addi t4, a1, 1024 /* share 1 cursor */
    addi t5, a0, 0 /* output cursor */

    li   t0, 0
    li   t1, 1
    li   t2, 2
    loopi 32, 9 /* 256 / 8 WDRs */
        jal         x1, _sample_rq
        bn.lid      t0, 0(t3)
        bn.addvm.8s w0, w0, w14 /* share 0 += r */
        bn.sid      t0, 0(t3++)
        bn.lid      t1, 0(t4)
        bn.subvm.8s w1, w1, w14 /* share 1 -= r */
        bn.sid      t1, 0(t4++)
        bn.addvm.8s w2, w0, w1 /* out = share 0 + share 1 */
        bn.sid      t2, 0(t5++)
    endloop
    ret

/* Lane-parallel rejection sampler: returns w14 = 8 fresh uniform r in Z_q.
 * Requires w11 = 23-bit mask, w12 = q vector, w13 = top-byte mask.
 *   r  := urnd & (2^23 - 1)                 (8 lanes of 23-bit uniform)
 *   ok := (r - q signed) top byte == 0xFF   (per lane, encodes r < q)
 *   retry while not all 8 lanes accept.
 *
 *   p_wdr = (8380417 / 2**23) ** 8  # ~0.9922
 */
_sample_rq:
    bn.wsrr     w14, urnd
    bn.and      w14, w14, w11
    bn.subv.8s  w15, w14, w12
    bn.and      w15, w15, w13
    bn.cmp      w15, w13
    csrrs       t6, FG0, x0
    andi        t6, t6, 8
    beq         t6, x0, _sample_rq
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
    bn.trn1.4D w0,  w8,  w10
    bn.trn2.4D w2,  w8,  w10
    bn.trn1.4D w1,  w9,  w11
    bn.trn2.4D w3,  w9,  w11
    bn.trn1.4D w4,  w12, w14
    bn.trn2.4D w6,  w12, w14
    bn.trn1.4D w5,  w13, w15
    bn.trn2.4D w7,  w13, w15
    bn.trn1.2Q w16, w0, w4
    bn.trn2.2Q w20, w0, w4
    bn.trn1.2Q w17, w1, w5
    bn.trn2.2Q w21, w1, w5
    bn.trn1.2Q w18, w2, w6
    bn.trn2.2Q w22, w2, w6
    bn.trn1.2Q w19, w3, w7
    bn.trn2.2Q w23, w3, w7
    ret

/*
 * Bit-transpose butterfly shared by bitslice (input -> scratch) and
 * unbitslice (scratch -> output): load 8 groups of 4 WDRs via t3, apply the
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
    li   t5, 8

    loop t5, 161
        li   t0, 0
        loopi 4, 2
            bn.lid t0, 0(t3++)
            addi   t0, t0, 1
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

        li   t0, 0
        loopi 4, 2
            bn.sid t0, 0(t4++)
            addi   t0, t0, 1
        endloop
        nop
    endloop
    ret

/*
 * Name: bitslice (kbits = 23) / bitslice_k32 (kbits = 32)
 *
 * Transpose 256 canonical 32-bit coefficients into kbits bitsliced WDRs
 * (output WDR j's lane i = bit j of coefficient i); the upper 32 - kbits bits
 * of each input coefficient are dropped.  Both entry points share one core.
 *
 * @param[in]  x10: ptr_out, dmem pointer to output (kbits WDRs at stride a2)
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
    li  t0, 23
    jal x0, _bitslice_core
.globl bitslice_k32
.type bitslice_k32, @function
bitslice_k32:
    li  t0, 32
    /* fall through */
_bitslice_core:
    /* Spill nfull / remainder: kbits (t0) does not survive Phase 1. */
    addi sp, sp, -32
    addi t3, t0, -1
    srli t3, t3, 3               /* nfull = (kbits - 1) / 8 */
    slli t4, t3, 3
    sub  t4, t0, t4              /* remainder = kbits - 8 * nfull */
    sw   t3, 0(sp)
    sw   t4, 4(sp)

    la   a3, scratch

    addi t3, a1, 0               /* load from input  */
    addi t4, a3, 0               /* store to scratch */
    jal  x1, _bitslice_butterfly

    /* === Phase 2: per q-block gather (stride 128) + 8x8 transpose; store 8
     * stripes per full block, then the partial final block. === */
    addi t5, a3, 0                /* gather base, q = 0 */
    lw   t4, 0(sp)                /* nfull */

    loop t4, 13
        addi t3, t5, 0
        li   t0, 0
        loopi 8, 3
            bn.lid t0, 0(t3)
            addi   t3, t3, 128
            addi   t0, t0, 1
        endloop
        jal x1, _transpose_8x8
        li   t0, 16
        loopi 8, 3
            bn.sid t0, 0(a0)
            add    a0, a0, a2
            addi   t0, t0, 1
        endloop
        addi t5, t5, 32
    endloop

    /* Final (partial) block: kbits - 8 * nfull stripes. */
    addi t3, t5, 0
    li   t0, 0
    loopi 8, 3
        bn.lid t0, 0(t3)
        addi   t3, t3, 128
        addi   t0, t0, 1
    endloop
    jal x1, _transpose_8x8
    lw   t3, 4(sp)               /* remainder */
    li   t0, 16
    loop t3, 3
        bn.sid t0, 0(a0)
        add    a0, a0, a2
        addi   t0, t0, 1
    endloop

    addi sp, sp, 32
    ret

/*
 * Name: unbitslice
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
    la   a2, scratch

    /* === Phase 2: scatter 23 bitsliced inputs through three 8x8 lane
     * transposes into 32 scratch WDRs.  q=3 (bits 23..31) is zero-filled. === */

    /* --- q=0 --- */
    li   t0, 0
    loopi 8, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1
    endloop

    jal x1, _transpose_8x8

    /* Store w16..w23 to scratch at stride 128. */
    addi t3, a2, 0
    li   t0, 16
    loopi 8, 3
        bn.sid t0, 0(t3)
        addi   t3, t3, 128
        addi   t0, t0, 1
    endloop

    /* --- q=1 --- */
    li   t0, 0
    loopi 8, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1
    endloop

    jal x1, _transpose_8x8

    addi t3, a2, 32
    li   t0, 16
    loopi 8, 3
        bn.sid t0, 0(t3)
        addi   t3, t3, 128
        addi   t0, t0, 1
    endloop

    /* --- q=2: 7 inputs + zero pad for missing bit 23. --- */
    li   t0, 0
    loopi 7, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1
    endloop
    bn.mov w7, w31

    jal x1, _transpose_8x8

    addi t3, a2, 64
    li   t0, 16
    loopi 8, 3
        bn.sid t0, 0(t3)
        addi   t3, t3, 128
        addi   t0, t0, 1
    endloop

    /* --- q=3: zero-fill (no input bits). --- */
    addi t3, a2, 96
    li   t0, 31
    loopi 8, 2
        bn.sid t0, 0(t3)
        addi   t3, t3, 128
    endloop

    /* === Phase 1: butterfly scratch -> output. === */
    addi t3, a2, 0
    addi t4, a0, 0
    jal  x1, _bitslice_butterfly

    ret

/*
 * Name: poly_rej_samp_bitsliced
 *
 * Sample 256 coefficients uniform in [0, q) (q = 8380417) by rejection
 * sampling on uniform random words from urnd: redraw the whole batch until
 * every lane is < q (~ 1.28 draws expected).
 * Bitsliced.
 *
 * @param[in]  a0: ptr_r, dmem output (23 * 32 bytes)
 * @param[in]  a1: deterministic random stream (MLDSA_REJ_SAMPLE_TEST only)
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
    /* Read 23 WDRs from a1 in place of urnd. */
    li   t0, 0
    li   t1, 23
    loop t1, 2
        bn.lid t0, 0(a1++)
        addi   t0, t0, 1
    endloop
#else
    bn.wsrr w0,  urnd
    bn.wsrr w1,  urnd
    bn.wsrr w2,  urnd
    bn.wsrr w3,  urnd
    bn.wsrr w4,  urnd
    bn.wsrr w5,  urnd
    bn.wsrr w6,  urnd
    bn.wsrr w7,  urnd
    bn.wsrr w8,  urnd
    bn.wsrr w9,  urnd
    bn.wsrr w10, urnd
    bn.wsrr w11, urnd
    bn.wsrr w12, urnd
    bn.wsrr w13, urnd
    bn.wsrr w14, urnd
    bn.wsrr w15, urnd
    bn.wsrr w16, urnd
    bn.wsrr w17, urnd
    bn.wsrr w18, urnd
    bn.wsrr w19, urnd
    bn.wsrr w20, urnd
    bn.wsrr w21, urnd
    bn.wsrr w22, urnd
#endif

    /* Per-lane v < q check: bit k of v + (2^k - q) is 0 iff v < q.
     * With (2^k - q) = 0x1FFF (bits 0..12 = 1, bits 13..22 = 0), the
     * carry chain collapses to:
     *   bits 0..12  (const = 1):  c_{b+1} = v_b OR  c_b
     *   bits 13..22 (const = 0):  c_{b+1} = v_b AND c_b
     * Starting c_0 = 0, accept iff the folded c_23 (in w23) is all-zero.
     */
    bn.or  w23, w0,  w1
    bn.or  w23, w23, w2
    bn.or  w23, w23, w3
    bn.or  w23, w23, w4
    bn.or  w23, w23, w5
    bn.or  w23, w23, w6
    bn.or  w23, w23, w7
    bn.or  w23, w23, w8
    bn.or  w23, w23, w9
    bn.or  w23, w23, w10
    bn.or  w23, w23, w11
    bn.or  w23, w23, w12

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

    /* Redraw if any lane >= q (FG0.z clear -> w23 != 0). */
    csrrs t1, fg0, x0
    srli  t1, t1, 3              /* FG0.z */
    beq   t1, x0, _prs_bs_draw

    /* Store w0..w22 to output. */
    addi t5, a0, 0
    li   t0, 0
    li   t1, 23
    loop t1, 2
        bn.sid t0, 0(t5++)
        addi   t0, t0, 1
    endloop

    ret

/*
 * Name: secb2amodq
 *
 * Convert a Boolean sharing x^{B,k} of x in [0, q) into an arithmetic sharing
 * z^{A_q} of the same value (q = 0x7FE001).
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
    la   a4, scratch
    addi sp, sp, -32
    sw   a0, 0(sp)                 /* save z_out */
    sw   a1, 4(sp)                 /* save x_in */
    sw   a3, 8(sp)                 /* save scratch_ptr for seca2b */
    sw   a4, 12(sp)                /* save z_0 scratch ptr */

    /* z_0 <- Z_q. */
    addi a0, a4, 0
    jal  x1, poly_rej_samp_bitsliced

    /* z'_0 <- q - z_0 (bitsliced borrow chain). */
    lw   t6, 0(sp)
    lw   t5, 12(sp)
    li   t0, 0
    li   t1, 1
    li   t2, 2
    li   t3, 31

    bn.lid t0, 0(t5++)
    bn.not w2, w0
    bn.sid t2, 0(t6++)
    bn.xor w1, w31, w31

    loopi 12, 4
        bn.lid t0, 0(t5++)
        bn.xor w2, w0, w1
        bn.sid t2, 0(t6++)
        bn.or  w1, w0, w1
    endloop

    loopi 10, 5
        bn.lid t0, 0(t5++)
        bn.not w3, w0
        bn.xor w2, w3, w1
        bn.sid t2, 0(t6++)
        bn.and w1, w0, w1
    endloop

    bn.sid t3, 0(t6++)

    /* z'_1 <- 0. */
    loopi 24, 1
        bn.sid t3, 0(t6++)
    endloop

    /* a <- seca2bmodq((z'_0, 0)). */
    lw   a0, 0(sp)
    lw   a1, 0(sp)
    lw   a3, 8(sp)
    jal  x1, seca2bmodq

    /* b <- secaddmodq(a, x). */
    lw   a0, 0(sp)
    lw   a1, 4(sp)
    lw   a2, 0(sp)
    jal  x1, secaddmodq

    /* z_1 <- unmask(b) (RefreshIOS fused with the XOR-collapse). */
    lw   t6, 0(sp)
    addi a3, t6, 0                 /* b[share 0] read */
    addi a4, t6, 768               /* b[share 1] read */
    li   t1, 1
    li   t2, 2
    addi t5, t6, 768               /* z[share 1] write */
    li   t4, 23
    loop t4, 7
        bn.lid  t1, 0(a3++)
        bn.lid  t2, 0(a4++)
        bn.wsrr w3, urnd
        bn.xor  w1, w1, w3
        bn.xor  w2, w2, w3
        bn.xor  w1, w1, w2
        bn.sid  t1, 0(t5++)
    endloop
    li   t3, 31
    bn.sid t3, 0(t5)               /* z[share 1] bit k = 0 */

    /* z_0 -> z[share 0]. */
    addi t5, t6, 0                 /* z[share 0] write */
    lw   a1, 12(sp)                /* z_0 source */
    li   t0, 0
    li   t4, 23
    loop t4, 2
        bn.lid t0, 0(a1++)
        bn.sid t0, 0(t5++)
    endloop
    bn.sid t3, 0(t5)               /* z[share 0] bit k = 0 */

    addi sp, sp, 32
    ret

/*
 * Name: secb2amodq_eta
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
    addi sp, sp, -32
    sw   ra,  0(sp)
    sw   a0,  4(sp)
    sw   a4,  8(sp)
    sw   a5, 12(sp)

    /* Zero the 48-WDR buffer at a5. */
    li   t2, 31
    addi t0, a5, 0
    loopi 48, 1
        bn.sid t2, 0(t0++)
    endloop

    /* share 0 low k stripes -> buffer + 0. */
    li   t2, 0
    addi t0, a5, 0
    addi t4, a1, 0
    loop a3, 2
        bn.lid t2, 0(t4++)
        bn.sid t2, 0(t0++)
    endloop

    /* Whitening. */
    bn.xor w0, w0, w0
    /* share 1 low k stripes -> buffer + 768. */
    addi t0, a5, 768
    addi t4, a2, 0
    loop a3, 2
        bn.lid t2, 0(t4++)
        bn.sid t2, 0(t0++)
    endloop

    /* b2a: caller's a0 receives bitsliced arith shares. */
    lw   a0,  4(sp)
    addi a1, a5, 0
    lw   a3,  8(sp)
    jal  x1, secb2amodq

    /* Unbitslice each share to canonical 32-bit; share 1 first so its
     * overlapping write [1024..1535] doesn't clobber share 0's source. */
    lw   a0,  4(sp)
    addi a1, a0, 768
    addi a0, a0, 1024
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
    lw   a0,  4(sp)
    addi a1, a0, 0
    jal  x1, unbitslice

    lw   ra,  0(sp)
    addi sp, sp, 32
    ret

/*
 * Name: secboundcheck
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
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w27
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

    addi sp, sp, -64
    sw   a3, 0(sp)
    sw   a4, 4(sp)

    /* Stash C across the seca2bmodq call. */
    li   t0, 17
    bn.sid t0, 32(sp)

    /* Preserve arguments. */
    addi a7, a0, 0

    /* x_0 <- x_0 + lambda_0 mod q (written to a4; caller's x stays intact). */
    bn.lid x0, 0(a2)
    addi t0, a7, 0
    addi t1, a4, 0
    li   t2, 1
    loopi 32, 3
        bn.lid      t2, 0(t0++)
        bn.addvm.8s w1, w1, w0
        bn.sid      t2, 0(t1++)
    endloop

    /* Bitslice each share into the share-major bit-inner buffer. */
    addi a0, a4, 0
    addi a1, a4, 0
    li   a2, 32
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
    lw   a4, 4(sp)
    addi a0, a4, 768
    addi a1, a7, 1024
    li   a2, 32
    jal  x1, bitslice

    /* Zero bit-k pad of each share. */
    lw      a4, 4(sp)
    li      t0, 31
    addi    t1, a4, 736
    bn.sid  t0, 0(t1)
    addi    t1, a4, 1504
    bn.sid  t0, 0(t1)

    /* x' <- seca2bmodq(x). */
    addi a0, a4, 0
    addi a1, a4, 0
    lw   a3, 0(sp)
    jal  x1, seca2bmodq

    /* b <- secleq(x'). */
    lw   a4, 4(sp)
    li   t0, 17
    bn.lid t0, 32(sp)
    addi a1, a4, 0
    jal  x1, secleq

    addi sp, sp, 64

    bn.mov w16, w28
    bn.mov w22, w29
    bn.mov w23, w30
    ret

/*
 * Name: seccompress
 *
 * Masked SecCompress for the ML-DSA-44 SecDecompose: from arithmetic shares of
 * x mod q (q = 8380417) produce a Boolean sharing of
 * w1 = round(x * delta / q) mod delta, delta = 44 (ell = 24, c = 8,
 * k = ell + c = 32).
 * Bitsliced.
 *
 *   z_0 <- round(x_0 * delta * 2^ell / q) + 2^(ell-1)  mod 2^(ell+c)
 *   z_1 <- round(x_1 * delta * 2^ell / q)              mod 2^(ell+c)
 *   Z   <- seca2b((z_0, z_1))
 *   V'  <- Z >> ell                                    (top c = 8 stripes)
 *   V'  <- (V' >= delta) ? V' - delta : V'             (twice; V' in [0, 88])
 *
 * The rounded division by q is a truncating Barrett multiply (ACC has no
 * divide): z_i = (x_i * K) >> 25, K = round(delta * 2^(ell+25) / q) =
 * 0xB02C09A2.
 *
 * Source: Alg.2 [CGMZ23]
 *
 * @param[out]  x10: dptr_z, 2048 B share-major a2b output (share_str = 1024)
 * @param[in]   x11: dptr_x, 2 * 1024 B arith shares mod q (contiguous)
 * @param[in]   x12: dptr_scratch, 4096 B (T_dense + T_bsl), caller-provided
 * @param[in]   x13: dptr_b, 2048 B scratch for the a2b's B, caller-provided
 * @param[in]   w31: all-zero register
 *
 * clobbered registers: x2, x4 to x7, x10 to x17, x28 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl seccompress
.type seccompress, @function
seccompress:
    li   t0, 64
    sub  sp, sp, t0
    sw   a0, 4(sp)
    sw   a1, 8(sp)
    sw   s0, 16(sp)
    sw   s1, 20(sp)
    sw   s2, 24(sp)
    sw   s3, 28(sp)
    sw   a2, 32(sp)
    sw   a3, 36(sp)

    /* K = 0xB02C09A2 -> w16 (broadcast to all 8 lanes). */
    bn.addi  w16, w31, 0xB0
    bn.rshi  w16, w16, w31 >> 248
    bn.addi  w16, w16, 0x2C
    bn.rshi  w16, w16, w31 >> 248
    bn.addi  w16, w16, 0x09
    bn.rshi  w16, w16, w31 >> 248
    bn.addi  w16, w16, 0xA2
    bn.rshi  w18, w16, w31 >> 224
    bn.or    w16, w16, w18
    bn.rshi  w18, w16, w31 >> 192
    bn.or    w16, w16, w18
    bn.rshi  w18, w16, w31 >> 128
    bn.or    w16, w16, w18

    /* BIAS = 2^23 -> w17 (broadcast to all 8 lanes). */
    bn.addi   w17, w31, 1
    bn.rshi   w18, w17, w31 >> 224
    bn.or     w17, w17, w18
    bn.rshi   w18, w17, w31 >> 192
    bn.or     w17, w17, w18
    bn.rshi   w18, w17, w31 >> 128
    bn.or     w17, w17, w18
    bn.shv.8s w17, w17 << 23

    /* Steps 1-2: z_i = round(x_i*delta*2^ell / q) mod 2^(ell+c) for i in {0,1}. */
    addi     s0, a1, 0
    lw       s1, 32(sp)
    loopi    2, 10
        li       t0, 0
        li       t2, 3
        loopi    32, 5
            bn.lid               t0, 0(s0++)
            bn.shv.8s            w0, w0 << 7
            bn.mulv.8s.even.hi   w3, w0, w16
            bn.mulv.8s.odd.hi    w3, w3, w16
            bn.sid               t2, 0(s1++)
        endloop
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w3, w3, w3
    endloop

    /* Add the rounding bias 2^(ell-1) = 2^23 to share 0. */
    lw       s0, 32(sp)
    li       t0, 0
    loopi    32, 3
        bn.lid       t0, 0(s0)
        bn.addv.8s   w0, w0, w17
        bn.sid       t0, 0(s0++)
    endloop

    /* Step 3: Z = A2B(z_0, z_1) */

    /* Bitslice each share */
    lw       s0, 32(sp)
    lw       s1, 32(sp)
    li       t0, 2048
    add      s1, s1, t0
    loopi    2, 34
        addi a0, s1, 0
        addi a1, s0, 0
        li   a2, 32
        jal  x1, bitslice_k32
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
        addi s0, s0, 1024
        addi s1, s1, 1024
    endloop


    /* SecA2B (BCC22, Alg 8) */
    /* A = (z_0, 0), B = (0, z_1). */
    lw   a1, 32(sp)
    li   t0, 2048
    add  a1, a1, t0                     /* z_0 bitsliced */
    addi a2, a1, 1024                   /* z_1 bitsliced */
    lw   a4, 32(sp)
    lw   a5, 36(sp)
    addi t3, a4, 0
    addi t4, a5, 0
    li   t0, 0
    li   t1, 1
    li   t2, 31
    loopi 32, 6
        bn.lid t0, 0(a1++)            /* z_0[i] */
        bn.lid t1, 0(a2++)            /* z_1[i] */
        bn.sid t0, 0(t3)              /* A.share0 = z_0[i] */
        bn.sid t2, 1024(t3++)         /* A.share1 = 0 */
        bn.sid t2, 0(t4)              /* B.share0 = 0 */
        bn.sid t1, 1024(t4++)         /* B.share1 = z_1[i] */
    endloop

    /* Z = A + B mod 2^32 (secadd, k=32, share_str=1024, d=2). */
    addi a0, a4, 0
    addi a1, a5, 0
    li   a2, 32
    li   a3, 1024
    lw   a5, 4(sp)
    jal  x1, secadd

    /* Step 4 implicit by using higher bits. */

    /* Step 5: V' = V' mod delta, two passes of the conditional subtract-delta.
     * V' from step 4 lies in [0, 2*delta] = [0, 88]:
     *  pass 1 maps it to [0, 44],
     *  pass 2 folds the residual 44 -> 0.*/
    lw   a0, 4(sp)
    addi a0, a0, 768                /* V' = top 8 stripes of Z (share 0) */
    lw   a1, 32(sp)
    li   t0, 32
    sub  sp, sp, t0
    sw   a0, 4(sp)
    sw   a1, 16(sp)
    jal  x1, _seccompress_csub
    jal  x1, _seccompress_csub
    li   t0, 32
    add  sp, sp, t0

    lw   s0, 16(sp)
    lw   s1, 20(sp)
    lw   s2, 24(sp)
    lw   s3, 28(sp)
    li   t0, 64
    add  sp, sp, t0
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
    lw   a0, 4(sp)
    li   a2, 8
    li   a3, 1024
    lw   a5, 16(sp)
    addi a5, a5, 192
    jal  x1, secadd_immd_d2

    /* Masked select over the 8 V'/diff stripes:
     *   V'[i] = (mask & (V'[i] ^ diff[i])) ^ diff[i],  mask = MSB(diff).
     */
    lw   s0, 4(sp)
    lw   t6, 16(sp)
    addi s1, t6, 192
    loopi 8, 36
        /* tmp = V'[i] ^ diff[i] sharewise */
        li   t1, 0
        li   t2, 1
        bn.lid t1, 0(s0)
        bn.lid t2, 0(s1)
        bn.xor w0, w0, w1
        addi t5, t6, 32
        bn.sid t1, 0(t5)
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.lid t1, 1024(s0)
        bn.lid t2, 1024(s1)
        bn.xor w0, w0, w1
        bn.sid t1, 32(t5)
        /* and = secand(mask = diff[bit 7], tmp) */
        addi a0, t6, 192
        addi a0, a0, 224
        li   a1, 1024
        addi a2, t6, 32
        li   a3, 32
        li   a5, 32
        addi a6, t6, 96
        jal  x1, secand
        /* V'[i] = and ^ diff[i] sharewise */
        li   t1, 0
        li   t2, 1
        addi t5, t6, 96
        bn.lid t1, 0(t5)
        bn.lid t2, 0(s1)
        bn.xor w0, w0, w1
        bn.sid t1, 0(s0)
        /* Whitening. */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
        bn.lid t1, 32(t5)
        bn.lid t2, 1024(s1)
        bn.xor w0, w0, w1
        bn.sid t1, 1024(s0)
        addi s0, s0, 32
        addi s1, s1, 32
    endloop

    ret

/*
 * Name: secdecompose
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
 *   L35:  Boolean shares of (gamma2 - w0) dumped to a5/a6 (consumers b2a them)
 *
 * Source: Alg.7 [ABCH+23]
 *
 * @param[out]  x10: dptr_w1, 1024 B unmasked w1
 * @param[in]   x11: dptr_w, base of arith shares (mod q) at stride a4
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
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w15, w17 to w21, w24 to w30
 * clobbered flag groups: FG0
 */
.globl secdecompose
.type secdecompose, @function
secdecompose:
    bn.mov w28, w16
    bn.mov w29, w22
    bn.mov w30, w23

    li   t0, 64
    sub  sp, sp, t0
    sw   a0, 4(sp)               /* w1_out */
    sw   a1, 8(sp)               /* w_io */
    sw   s5, 16(sp)
    sw   s6, 20(sp)
    sw   s7, 24(sp)
    sw   s8, 28(sp)
    sw   s9, 32(sp)

    /* Select the variant from the level in a2 (2 = ML-DSA-44); spill it and
     * the per-variant constants (M_BITS / SHARE_STR / ZERO_STRIPES) so they
     * survive the core subcalls. */
    sw   a2, 60(sp)
    li   t0, 2
    bne  a2, t0, _secdecompose_l35

    /* ===== ML-DSA-44 (L2): w1 <- SecCompress(w), delta = 44. ===== */
    li   t0, 6
    sw   t0, 48(sp)              /* M_BITS */
    li   t0, 1024
    sw   t0, 52(sp)             /* SHARE_STR */
    li   t0, 17
    sw   t0, 56(sp)             /* ZERO_STRIPES */

    sw   a6, 12(sp)             /* T_packed base */
    /* Copy the 2 strided shares of w into contiguous T_packed (a6). */
    addi t3, a1, 0
    addi t4, a6, 0
    li   t6, 0
    loopi 2, 6
        addi t1, t3, 0
        loopi 32, 2
            bn.lid t6, 0(t1++)
            bn.sid t6, 0(t4++)
        endloop
        /* Whitening. */
        bn.xor w0, w0, w0
        add  t3, t3, a4
    endloop
    /* seccompress in place. */
    addi a0, a6, 0
    addi a1, a6, 0
    addi a2, a3, 0
    addi a3, a5, 0
    jal  x1, seccompress
    lw   s9, 12(sp)
    addi s8, s9, 768
    beq  x0, x0, _secdecompose_unmask

_secdecompose_l35:
    /* ===== ML-DSA-65/87 (L35): b' = -16*(w + gamma2) - 1 = -16*w + (q-1)/2. ===== */
    li   t0, 4
    sw   t0, 48(sp)             /* M_BITS */
    li   t0, 768
    sw   t0, 52(sp)            /* SHARE_STR */
    li   t0, 19
    sw   t0, 56(sp)            /* ZERO_STRIPES */

    sw   a5, 36(sp)            /* w0_packed_share0 */
    sw   a6, 40(sp)            /* w0_packed_share1 */
    sw   a7, 44(sp)            /* seca2bmodq scratch */

    addi s5, a3, 0
    addi s8, s5, 1024
    /* Share 0: -16*w_s0 + (q-1)/2. */
    la   t0, qm1half_const
    li   t1, 1
    bn.lid t1, 0(t0)
    lw   t3, 8(sp)
    addi t4, s5, 0
    li   t6, 0
    loopi 32, 8
        bn.lid      t6, 0(t3++)
        bn.subvm.8s w0, w31, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w1
        bn.sid      t6, 0(t4++)
    endloop
    /* Bitslice share 0; zero bit k. */
    addi a0, s8, 0
    addi a1, s5, 0
    li   a2, 32
    jal  x1, bitslice
    li   t0, 31
    addi t1, s8, 736
    bn.sid t0, 0(t1)

    /* Whitening. */
    bn.xor w0, w0, w0
    /* Share 1: -16*w_s1. */
    lw   t3, 8(sp)
    add  t3, t3, a4
    addi t4, s5, 0
    li   t6, 0
    loopi 32, 7
        bn.lid      t6, 0(t3++)
        bn.subvm.8s w0, w31, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w0
        bn.addvm.8s w0, w0, w0
        bn.sid      t6, 0(t4++)
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
    addi a0, s8, 768
    addi a1, s5, 0
    li   a2, 32
    jal  x1, bitslice
    li   t0, 31
    addi t1, s8, 1504            /* 768 + 736 */
    bn.sid t0, 0(t1)

    /* b' <- seca2bmodq(b'). */
    addi a0, s8, 0
    addi a1, s8, 0
    li   a2, 2
    lw   a3, 44(sp)
    jal  x1, seca2bmodq

    /* Stripes 4..22 (19) hold Boolean shares of (gamma2 - w0); dump per share
     * to a5/a6 (608 B each). */
    lw   t0, 36(sp)
    addi t3, s8, 128             /* share 0, stripe 4 */
    li   t1, 0
    loopi 19, 2
        bn.lid t1, 0(t3++)
        bn.sid t1, 0(t0++)
    endloop
    lw   t0, 40(sp)
    addi t3, s8, 896             /* share 1, stripe 4 (768 + 128) */
    loopi 19, 2
        bn.lid t1, 0(t3++)
        bn.sid t1, 0(t0++)
    endloop
    addi s9, s8, 1536

_secdecompose_unmask:
    /* w1 <- SecUnMask(w1): refresh + XOR-collapse over M_BITS stripes. */
    addi t3, s8, 0               /* share 0 stripe 0 */
    lw   t0, 52(sp)             /* SHARE_STR */
    add  t4, s8, t0              /* share 1 stripe 0 */
    addi t5, s9, 0
    lw   t2, 48(sp)             /* M_BITS */
    li   t0, 0
    li   t1, 1
    loop t2, 7
        bn.lid  t0, 0(t3++)
        bn.lid  t1, 0(t4++)
        bn.wsrr w2, urnd
        bn.xor  w0, w0, w2
        bn.xor  w1, w1, w2
        bn.xor  w0, w0, w1
        bn.sid  t0, 0(t5++)
    endloop

    /* Zero stripes M_BITS..KBITS-1. */
    lw   t0, 56(sp)            /* ZERO_STRIPES */
    li   t1, 31
    loop t0, 1
        bn.sid t1, 0(t5++)
    endloop

    /* unbitslice w1. */
    lw   a0, 4(sp)
    addi a1, s9, 0
    jal  x1, unbitslice

    /* Line 9 (L2 only): w0 <- w - alpha*w1 mod q. */
    lw   t0, 60(sp)
    li   t1, 2
    bne  t0, t1, _secdecompose_epilogue

    bn.wsrw 0x0, w28            /* MOD = R|Q (stashed) for subvm */
    la   t0, gamma2_vec_const
    li   t1, 24
    bn.lid t1, 0(t0)
    lw   a0, 4(sp)
    lw   a1, 8(sp)
    li   t0, 0
    li   t1, 1
    loopi 32, 7
        bn.lid t0, 0(a0++)
        bn.mulv.8s.even.lo w0, w0, w24
        bn.mulv.8s.odd.lo  w0, w0, w24
        bn.addv.8s w0, w0, w0
        bn.lid t1, 0(a1)
        bn.subvm.8s w0, w1, w0
        bn.sid t0, 0(a1++)
    endloop

_secdecompose_epilogue:
    lw   s5, 16(sp)
    lw   s6, 20(sp)
    lw   s7, 24(sp)
    lw   s8, 28(sp)
    lw   s9, 32(sp)
    li   t0, 64
    add  sp, sp, t0

    bn.mov w16, w28
    bn.mov w22, w29
    bn.mov w23, w30
    ret

/*
 * Name: masked_poly_uniform_eta
 *
 * Produce an arithmetic sharing (mod q) of one s1/s2 polynomial,
 * ExpandS(rho', nonce): draw 4-bit nibbles from SHAKE-256(rho' || nonce) and
 * map each accepted nibble n to eta - reduce(n) per FIPS 204 CoeffFromHalfByte:
 *   eta = 2: reject n == 15, coefficient = 2 - (n mod 5)
 *   eta = 4: reject n >= 9,  coefficient = 4 - n
 * The variant is selected at runtime from the eta argument (a5).
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
 * clobbered registers: x2, x4 to x7, x10 to x17, x28 to x31, w0 to w27, w30
 * clobbered flag groups: FG0
 */

.globl masked_poly_uniform_eta
.type masked_poly_uniform_eta, @function
masked_poly_uniform_eta:
    addi a6, x0, 0                 /* no export */
.globl masked_poly_uniform_eta_export
.type masked_poly_uniform_eta_export, @function
masked_poly_uniform_eta_export:
    addi sp, sp, -64
    sw   a0, 0(sp)                 /* out ptr (also bitsliced m, then output) */
    sw   a3, 4(sp)                 /* scratch base (= b2a seca2b scratch) */
    sw   a4, 8(sp)                 /* b2a Boolean buffer */
    sw   a5, 12(sp)                /* eta (variant: 2 or 4) */
    sw   s0, 16(sp)                /* callee-save: caller parks pointers here */
    sw   s1, 20(sp)
    sw   s2, 24(sp)
    sw   s11, 28(sp)
    sw   a6, 32(sp)                /* export dest */

    /* ---- Init masked SHAKE-256, absorb rho' shares + nonce. ---- */
    addi  a4, x0, 64
    addi  a4, a4, 2
    slli  t0, a4, 5
    addi  t0, t0, SHAKE256_CFG
    addi  a4, x0, 1
    slli  a4, a4, 20              /* masking-enable bit */
    add   t0, t0, a4
    csrrw x0, kmac_cfg, t0

    bn.lid  x0, 0(a1)             /* share0[0..32] */
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.lid  x0, 64(a1)            /* share1[0..32] */
    bn.wsrw kmac_msg1, w0
    bn.lid  x0, 32(a1)            /* share0[32..64] */
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.lid  x0, 96(a1)            /* share1[32..64] */
    bn.wsrw kmac_msg1, w0

    /* Nonce, using out[0..32] as scratch (overwritten later). */
    bn.sid  x0, 0(a0)
    sw      a2, 0(a0)
    bn.lid  x0, 0(a0)
    li      t0, 2
    csrrw   x0, kmac_partial_write, t0
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

    lw   a3, 4(sp)
    addi s0, a3, 0                /* G0 write cursor */
    addi s1, a3, 1024             /* G1 write cursor */
    addi s2, a3, 1024             /* G0 end (256 nibbles done) */

_mpue_squeeze:
    /* s0_w/s1_w = next 64 masked nibbles (share 0 / share 1). */
    bn.wsrr w0, kmac_digest
    bn.wsrr w1, kmac_digest1

    lw   t0, 12(sp)               /* eta (2 or 4) */
    li   t1, 2
    bne  t0, t1, _mpue_reject_e4
    /* reject (n == 15) = AND of the nibble's 4 bits, at bit 4i. */
    /* SecAnd: z = n & (n>>1) on the masked nibble n = (w0,w1). */
    bn.rshi w2, w31, w0 >> 1
    bn.rshi w3, w31, w1 >> 1
    bn.wsrr w6, urnd
    bn.and  w4, w0, w2
    bn.xor  w4, w4, w6
    bn.and  w7, w0, w3
    bn.xor  w7, w7, w6
    bn.and  w8, w1, w2
    bn.xor  w7, w7, w8
    bn.and  w5, w1, w3
    bn.xor  w5, w5, w7           /* (w4,w5) = shares of z */

    /* SecAnd: u = z & (z>>2)  -> bit 4i = AND of nibble's 4 bits. */
    bn.rshi w2, w31, w4 >> 2
    bn.rshi w3, w31, w5 >> 2
    bn.wsrr w6, urnd
    bn.and  w7, w4, w2
    bn.xor  w7, w7, w6
    bn.and  w8, w4, w3
    bn.xor  w8, w8, w6
    bn.and  w2, w5, w2
    bn.xor  w8, w8, w2
    bn.and  w3, w5, w3
    bn.xor  w3, w3, w8           /* (w7,w3) = shares of u */
    beq  x0, x0, _mpue_reject_done
_mpue_reject_e4:
    /* reject (n >= 9) = b3 & (b0|b1|b2), at bit 4i.  Via De Morgan on m = ~n:
     * three SecAnds give b3 & ~(~b0 & ~b1 & ~b2). */
    /* SecAnd: za = m & (m>>1),  m = ~n = (~w0, w1). */
    bn.not  w2, w0
    bn.rshi w3, w31, w2 >> 1
    bn.rshi w4, w31, w1 >> 1
    bn.wsrr w6, urnd
    bn.and  w7, w2, w3
    bn.xor  w7, w7, w6
    bn.and  w8, w2, w4
    bn.xor  w8, w8, w6
    bn.and  w9, w1, w3
    bn.xor  w8, w8, w9
    bn.and  w5, w1, w4
    bn.xor  w5, w5, w8           /* za = (w7,w5) */

    /* SecAnd: zb = za & (m>>2)  -> bit 4i = ~b0 & ~b1 & ~b2. */
    bn.rshi w3, w31, w2 >> 2
    bn.rshi w4, w31, w1 >> 2
    bn.wsrr w6, urnd
    bn.and  w8, w7, w3
    bn.xor  w8, w8, w6
    bn.and  w9, w7, w4
    bn.xor  w9, w9, w6
    bn.and  w10, w5, w3
    bn.xor  w9, w9, w10
    bn.and  w11, w5, w4
    bn.xor  w11, w11, w9        /* zb = (w8,w11) */
    bn.not  w8, w8             /* ~zb -> bit 4i = b0|b1|b2 */

    /* SecAnd: reject = (n>>3) & ~zb  -> bit 4i = b3 & (b0|b1|b2). */
    bn.rshi w3, w31, w0 >> 3
    bn.rshi w4, w31, w1 >> 3
    bn.wsrr w6, urnd
    bn.and  w7, w3, w8
    bn.xor  w7, w7, w6
    bn.and  w9, w3, w11
    bn.xor  w9, w9, w6
    bn.and  w10, w4, w8
    bn.xor  w9, w9, w10
    bn.and  w3, w4, w11
    bn.xor  w3, w3, w9          /* (w7,w3) = shares of reject */
_mpue_reject_done:

    /* Reveal only the per-nibble reject bits (mask off the garbage). */
    bn.and  w7, w7, w30
    bn.and  w3, w3, w30
    bn.xor  w7, w7, w3           /* public reject mask, bit 4i set => reject */

    /* Stash share words + reject mask for the scalar gather. */
    li   s11, 2048               /* SQ0 */
    add  t2, a3, s11
    bn.sid x0, 0(t2)             /* x0 indexes w0 */
    li   s11, 2080               /* SQ1 */
    add  t2, a3, s11
    li   t3, 1
    bn.sid t3, 0(t2)             /* w1 */
    li   s11, 2112               /* REJ */
    add  t2, a3, s11
    li   t3, 7
    bn.sid t3, 0(t2)             /* w7 */

    /* Gather: 8 words x 8 nibbles, compacting accepted nibbles. */
    li   s11, 2048               /* SQ0 */
    add  t0, a3, s11
    li   s11, 2080               /* SQ1 */
    add  t2, a3, s11
    li   s11, 2112               /* REJ */
    add  t3, a3, s11
    li   t4, 8                   /* word counter */
_mpue_word:
    lw   a4, 0(t0)               /* share0 word */
    lw   a5, 0(t2)               /* share1 word */
    lw   a6, 0(t3)               /* reject word */
    addi t0, t0, 4
    addi t2, t2, 4
    addi t3, t3, 4
    li   t5, 8                   /* nibble counter */
_mpue_nib:
    andi a7, a6, 1               /* reject bit */
    andi t6, a4, 15              /* nibble share0 */
    andi a1, a5, 15              /* nibble share1 */
    srli a6, a6, 4
    srli a4, a4, 4
    srli a5, a5, 4
    bne  a7, x0, _mpue_skip
    sw   t6, 0(s0)
    sw   a1, 0(s1)
    addi s0, s0, 4
    addi s1, s1, 4
    beq  s0, s2, _mpue_gathered
_mpue_skip:
    addi t5, t5, -1
    bne  t5, x0, _mpue_nib
    addi t4, t4, -1
    bne  t4, x0, _mpue_word
    beq  x0, x0, _mpue_squeeze

_mpue_gathered:
    lw   t0, 12(sp)               /* eta (2 or 4) */
    li   t1, 2
    bne  t0, t1, _mpue_core_e4
    /* ---- mod-5 in the Boolean domain. ---- */
    lw   a3, 4(sp)

    /* Bitslice share 0 -> BS, copy low 5 stripes to N5 share 0; then reuse
     * BS for share 1.  (Single bitslice buffer overlaid by lifetime.) */
    li   s11, 2048               /* BS */
    add  a0, a3, s11
    addi a1, a3, 0                /* G0 */
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, 2048               /* BS */
    add  t0, a3, s11
    li   s11, 2784               /* N5 */
    add  t1, a3, s11
    li   t2, 0
    loopi 5, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)
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
    li   s11, 2048               /* BS */
    add  a0, a3, s11
    addi a1, a3, 1024             /* G1 */
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, 2048               /* BS */
    add  t0, a3, s11
    li   s11, 2784               /* N5 */
    add  t1, a3, s11
    addi t1, t1, 160
    loopi 5, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)
    endloop

    /* c1 = [n>=5] = !SecLeq_4(n): SecAdd_5(n, 2^5-4-1=27), bit 4 = [n<=4]. */
    li   s11, 2784               /* N5 */
    add  a0, a3, s11
    li   a2, 5
    li   a3, 160
    lw   a5, 4(sp)
    li   s11, 0                  /* Z */
    add  a5, a5, s11
    bn.xor w17, w17, w17
    bn.addi w17, w17, 27
    jal  x1, secadd_immd_d2

    /* Build T = c1 gated into the 27 bit-pattern {0,1,3,4}, c1 = !Z[4]. */
    lw   a3, 4(sp)
    jal  x1, _mpue_build_subtrahend

    /* m1 = SecAdd_5(n, T) = n - 5*c1. */
    lw   a3, 4(sp)
    li   s11, 2784               /* N5 */
    add  a0, a3, s11
    li   s11, 320                /* T */
    add  a1, a3, s11
    li   a2, 5
    li   a3, 160
    lw   a5, 4(sp)
    li   s11, 640                /* M1 */
    add  a5, a5, s11
    jal  x1, secadd

    /* c2 = [n>=10] = !SecLeq_9(n): SecAdd_5(n, 2^5-9-1=22), bit 4 = [n<=9]. */
    lw   a3, 4(sp)
    li   s11, 2784               /* N5 */
    add  a0, a3, s11
    li   a2, 5
    li   a3, 160
    lw   a5, 4(sp)
    li   s11, 0                  /* Z */
    add  a5, a5, s11
    bn.xor w17, w17, w17
    bn.addi w17, w17, 22
    jal  x1, secadd_immd_d2

    lw   a3, 4(sp)
    jal  x1, _mpue_build_subtrahend

    /* m = SecAdd_5(m1, T) = n - 5*c1 - 5*c2 = n mod 5, written to the OUTPUT
     * buffer (share0 at out+0, share1 at out+160). */
    lw   a3, 4(sp)
    li   s11, 640                /* M1 */
    add  a0, a3, s11
    li   s11, 320                /* T */
    add  a1, a3, s11
    li   a2, 5
    li   a3, 160
    lw   a5, 0(sp)               /* out */
    jal  x1, secadd

    /* Export bitsliced m shares (k=3) to a6 (skipped by the base entry). */
    lw   a6, 32(sp)
    beq  a6, x0, _mpue_skip_export_m
    lw   t0, 0(sp)               /* m share0 @ out+0 */
    li   t1, 0
    loopi 3, 2
        bn.lid t1, 0(t0++)
        bn.sid t1, 0(a6++)
    endloop
    lw   t0, 0(sp)
    addi t0, t0, 160             /* m share1 @ out+160 */
    loopi 3, 2
        bn.lid t1, 0(t0++)
        bn.sid t1, 0(a6++)
    endloop
    bn.xor w0, w0, w0            /* whitening */
_mpue_skip_export_m:

    /* ---- B2A(m, k=3): out holds m; a3 (dead) is the seca2b scratch. ---- */
    lw   a0, 0(sp)
    addi a1, a0, 0               /* m share0 in out */
    addi a2, a0, 160             /* m share1 in out */
    li   a3, 3
    lw   a4, 4(sp)               /* seca2b scratch (= a3) */
    lw   a5, 8(sp)               /* Boolean buffer */
    jal  x1, secb2amodq_eta
    beq  x0, x0, _mpue_core_done
_mpue_core_e4:
    /* ---- eta=4: no mod 5; coeff = 4 - n.  Bitslice n, B2A(k=4). ---- */
    lw   a3, 4(sp)

    /* Bitslice share 0 -> BS; copy low 4 stripes to out+0 (b2a share 0). */
    li   s11, 2048               /* BS */
    add  a0, a3, s11
    addi a1, a3, 0                /* G0 */
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, 2048               /* BS */
    add  t0, a3, s11
    lw   t1, 0(sp)
    li   t2, 0
    loopi 4, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)
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
    li   s11, 2048               /* BS */
    add  a0, a3, s11
    addi a1, a3, 1024             /* G1 */
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, 2048               /* BS */
    add  t0, a3, s11
    lw   t1, 0(sp)
    addi t1, t1, 128
    li   t2, 0
    loopi 4, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)
    endloop

    /* Export bitsliced n shares (k=4, both shares contiguous) to a6
     * (skipped by the base entry). */
    lw   a6, 32(sp)
    beq  a6, x0, _mpue_skip_export_n
    lw   t0, 0(sp)               /* n share0 @ out+0, share1 @ out+128 */
    li   t1, 0
    loopi 8, 2
        bn.lid t1, 0(t0++)
        bn.sid t1, 0(a6++)
    endloop
    bn.xor w0, w0, w0            /* whitening */
_mpue_skip_export_n:

    /* B2A(n, k=4): out+0 / out+128 hold n; out receives arith shares. */
    lw   a0, 0(sp)
    addi a1, a0, 0
    addi a2, a0, 128
    li   a3, 4
    lw   a4, 4(sp)               /* seca2b scratch */
    lw   a5, 8(sp)               /* Boolean buffer */
    jal  x1, secb2amodq_eta
_mpue_core_done:

    /* coeff = eta - reduce(n): share 0 = eta - m0, share 1 = -m1  (mod q).
     * Broadcast the eta argument to all 8 lanes of w4. */
    lw      t0, 12(sp)            /* eta (2 or 4) */
    li      t1, 2
    bn.addi w4, w31, 4
    bne     t0, t1, _mpue_coeff_bcast
    bn.addi w4, w31, 2
_mpue_coeff_bcast:
    bn.or   w4, w4, w4 << 32
    bn.or   w4, w4, w4 << 64
    bn.or   w4, w4, w4 << 128

    lw   a0, 0(sp)
    li   t0, 0
    addi t1, a0, 0
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w4, w0
        bn.sid t0, 0(t1++)
    endloop

    /* Whitening. */
    bn.xor w0, w0, w0
    lw   a0, 0(sp)
    addi t1, a0, 1024
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w31, w0
        bn.sid t0, 0(t1++)
    endloop

    lw   s0, 16(sp)
    lw   s1, 20(sp)
    lw   s2, 24(sp)
    lw   s11, 28(sp)
    addi sp, sp, 64
    ret

/*
 * Helper: build T from the comparison bit at stripe 4 of Z.
 * c = !Z[4] (flip share 0); gate c into the bit pattern of 27 (= -5 mod 2^5),
 * i.e. stripes {0,1,3,4} = c, stripe 2 = 0.  a3 = scratch base.
 */
_mpue_build_subtrahend:
    /* Load c shares: w0 = !Z[4]_s0, w1 = Z[4]_s1. */
    li   s11, 0                  /* Z */
    add  t0, a3, s11
    addi t0, t0, 128             /* stripe 4 (4 * 32), share 0 */
    li   t2, 0
    bn.lid t2, 0(t0)
    bn.not w0, w0                /* c_s0 = NOT Z[4]_s0 */
    li   s11, 0                  /* Z */
    add  t0, a3, s11
    addi t0, t0, 160
    addi t0, t0, 128             /* stripe 4, share 1 */
    li   t2, 1
    bn.lid t2, 0(t0)

    /* Write share 0 stripes {0,1,3,4}=c, {2}=0. */
    li   s11, 320                /* T */
    add  t1, a3, s11
    li   t2, 0
    li   t3, 31                  /* w31 = 0 */
    bn.sid t2, 0(t1)             /* stripe 0 = c */
    bn.sid t2, 32(t1)            /* stripe 1 = c */
    bn.sid t3, 64(t1)            /* stripe 2 = 0 */
    bn.sid t2, 96(t1)            /* stripe 3 = c */
    bn.sid t2, 128(t1)           /* stripe 4 = c */

    /* Write share 1 stripes {0,1,3,4}=c, {2}=0. */
    li   s11, 320                /* T */
    add  t1, a3, s11
    addi t1, t1, 160
    li   t2, 1                   /* w1 = c_s1 */
    bn.sid t2, 0(t1)
    bn.sid t2, 32(t1)
    bn.sid t3, 64(t1)
    bn.sid t2, 96(t1)
    bn.sid t2, 128(t1)
    ret


/*
 * Name: masked_poly_uniform_gamma_1
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
 * clobbered registers: x2, x4 to x8, x10 to x17, x28 to x31, w0 to w15, w17 to w21, w24 to w30
 * clobbered flag groups: FG0
 */
.globl masked_poly_uniform_gamma_1
.type masked_poly_uniform_gamma_1, @function
masked_poly_uniform_gamma_1:
    addi sp, sp, -32
    sw   a0, 0(sp)                 /* out pointer */
    sw   a3, 8(sp)                 /* seca2b scratch */
    sw   a4, 12(sp)                /* bitslice buffer */

    /* Map a5 to POLYZ_BITS (2 -> 18, else -> 20); spill it. */
    li   t0, 2
    li   t1, 18
    beq  a5, t0, _mpug_pb_set
    li   t1, 20
_mpug_pb_set:
    sw   t1, 4(sp)                 /* POLYZ_BITS (18 or 20) */

    bn.mov w28, w16
    bn.mov w29, w22
    bn.mov w30, w23

    /* Init masked SHAKE256, send rho'. */
    addi  a3, x0, 64
    addi  a3, a3, 2
    slli  t0, a3, 5
    addi  t0, t0, SHAKE256_CFG
    addi  a3, x0, 1
    slli  a3, a3, 20
    add   t0, t0, a3
    csrrw x0, kmac_cfg, t0

    bn.lid  x0, 0(a1)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.lid  x0, 64(a1)
    bn.wsrw kmac_msg1, w0
    bn.lid  x0, 32(a1)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.lid  x0, 96(a1)
    bn.wsrw kmac_msg1, w0

    /* Send nonce (out[0..31] as scratch, overwritten later). */
    bn.sid  x0, 0(a0)
    sw      a2, 0(a0)
    bn.lid  x0, 0(a0)
    li      t0, 2
    csrrw   x0, kmac_partial_write, t0
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.wsrw kmac_msg1, w0

    /* Squeeze POLYZ_BITS raw words into the tail of each share's output slot
     * (RAW0 = 1024 - 32*POLYZ_BITS, RAW1 = RAW0 + 1024) so the forward in-place
     * unpack keeps writes below reads. */
    lw   a5, 4(sp)                 /* POLYZ_BITS */
    slli t5, a5, 5
    li   t6, 1024
    sub  t6, t6, t5                /* RAW0 */
    add  t1, a0, t6
    addi t2, t1, 1024
    li   t3, 0
    li   t4, 1
    loop a5, 4
        bn.wsrr w0, kmac_digest
        bn.wsrr w1, kmac_digest1
        bn.sid  t3, 0(t1++)
        bn.sid  t4, 0(t2++)
    endloop

    /* Unpack each share in place (out[RAW..1023] -> out[0..1023]).  w5 = the
     * per-coef mask 2^POLYZ_BITS - 1, built inline (avoids a per-mode const). */
    lw   t0, 4(sp)                 /* POLYZ_BITS */
    li   t1, 18
    bn.addi w5, w31, 1
    bne  t0, t1, _mpug_mask_20
    bn.rshi w5, w5, w31 >> 238     /* 2^18 */
    beq  x0, x0, _mpug_mask_sub
_mpug_mask_20:
    bn.rshi w5, w5, w31 >> 236     /* 2^20 */
_mpug_mask_sub:
    bn.subi w5, w5, 1              /* 2^POLYZ_BITS - 1 */
    bn.or  w5, w5, w5 << 32
    bn.or  w5, w5, w5 << 64
    bn.or  w5, w5, w5 << 128

    lw   a5, 4(sp)                 /* POLYZ_BITS */
    slli t5, a5, 5
    li   t6, 1024
    sub  t6, t6, t5                /* RAW0 */
    add  a1, a0, t6
    /* Whitening. */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    jal  ra, _unpack_share

    lw   a0, 0(sp)
    lw   a5, 4(sp)                 /* POLYZ_BITS */
    slli t5, a5, 5
    li   t6, 1024
    sub  t6, t6, t5
    addi t6, t6, 1024              /* RAW1 = RAW0 + 1024 */
    add  a1, a0, t6
    addi a0, a0, 1024
    /* Whitening. */
    bn.xor w1, w1, w1
    bn.xor w2, w2, w2
    bn.xor w3, w3, w3
    bn.xor w6, w6, w6
    jal  ra, _unpack_share

    /* Bitslice each share to caller's buffer (top bit zeroed for k+1). */
    lw   a1, 0(sp)
    lw   a0, 12(sp)
    li   a2, 32
    jal  ra, bitslice
    lw   t1, 12(sp)
    addi t1, t1, 736
    li   t0, 31
    bn.sid t0, 0(t1)

    lw   a1, 0(sp)
    addi a1, a1, 1024
    lw   a0, 12(sp)
    addi a0, a0, 768
    li   a2, 32
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
    jal  ra, bitslice
    lw   t1, 12(sp)
    addi t1, t1, 1504
    li   t0, 31
    bn.sid t0, 0(t1)

    /* B2A: u^{B,k} (buffer) -> u^{A_p} at caller out. */
    lw   a1, 12(sp)
    lw   a0, 0(sp)
    lw   a3, 8(sp)
    jal  ra, secb2amodq

    /* Unbitslice each share in place; share 1 first so its overlapping
     * write [1024..1503] doesn't clobber share 0's source. */
    lw   a0, 0(sp)
    addi a1, a0, 768
    addi a0, a0, 1024
    jal  ra, unbitslice

    lw   a0, 0(sp)
    addi a1, a0, 0
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
    jal  ra, unbitslice

    /* y = gamma1 - u on share 0, -u on share 1.  gamma1 = 2^(POLYZ_BITS-1),
     * built into all 8 lanes of w4 (avoids a per-mode constant load). */
    lw      t0, 4(sp)              /* POLYZ_BITS */
    li      t1, 18
    bn.addi w4, w31, 1
    bne     t0, t1, _mpug_g1_20
    bn.rshi w4, w4, w31 >> 239     /* 2^17 */
    beq     x0, x0, _mpug_g1_bcast
_mpug_g1_20:
    bn.rshi w4, w4, w31 >> 237     /* 2^19 */
_mpug_g1_bcast:
    bn.or   w4, w4, w4 << 32
    bn.or   w4, w4, w4 << 64
    bn.or   w4, w4, w4 << 128

    lw   a0, 0(sp)
    li   t0, 0
    addi t1, a0, 0
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w4, w0
        bn.sid t0, 0(t1++)
    endloop

    /* Whitening. */
    bn.xor w0, w0, w0
    lw   a0, 0(sp)
    addi t1, a0, 1024
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w31, w0
        bn.sid t0, 0(t1++)
    endloop

    bn.mov w16, w28
    bn.mov w22, w29
    bn.mov w23, w30

    addi sp, sp, 32
    ret


/* Per-share unpack (caller pre-loads w5 = the per-coef mask 2^POLYZ_BITS-1). */
_unpack_share:
    addi t1, a0, 0
    addi t6, a1, 0
    li   t2, 2
    li   t0, 6
    li   t3, 3
    lw   t4, 4(sp)                 /* POLYZ_BITS */
    li   t5, 18
    bne  t4, t5, _unpack_share_20

    /* L2: 2 outer x 16 inner unpacks (144 raw bits each). */
    loopi 2, 42
        bn.lid  t0, 0(t6++)
        bn.mov  w1, w6
        jal     x1, _unpack_inner_18

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 144
        jal     x1, _unpack_inner_18

        bn.rshi w1, w31, w3 >> 32
        jal     x1, _unpack_inner_18

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 176
        jal     x1, _unpack_inner_18

        bn.rshi w1, w31, w6 >> 64
        jal     x1, _unpack_inner_18

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 208
        jal     x1, _unpack_inner_18

        bn.rshi w1, w31, w3 >> 96
        jal     x1, _unpack_inner_18

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 240
        jal     x1, _unpack_inner_18

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _unpack_inner_18

        bn.rshi w1, w31, w3 >> 16
        jal     x1, _unpack_inner_18

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 160
        jal     x1, _unpack_inner_18

        bn.rshi w1, w31, w6 >> 48
        jal     x1, _unpack_inner_18

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 192
        jal     x1, _unpack_inner_18

        bn.rshi w1, w31, w3 >> 80
        jal     x1, _unpack_inner_18

        bn.lid  t0, 0(t6++)
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
        bn.lid  t0, 0(t6++)
        bn.mov  w1, w6
        jal     x1, _unpack_inner_20

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 160
        jal     x1, _unpack_inner_20

        bn.rshi w1, w31, w3 >> 64
        jal     x1, _unpack_inner_20

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _unpack_inner_20

        bn.lid  t3, 0(t6++)
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _unpack_inner_20

        bn.rshi w1, w31, w3 >> 32
        jal     x1, _unpack_inner_20

        bn.lid  t0, 0(t6++)
        bn.rshi w1, w6, w3 >> 192
        jal     x1, _unpack_inner_20

        bn.rshi w1, w31, w6 >> 96
        jal     x1, _unpack_inner_20
        nop
    endloop

    ret

/* Inner: extract 8 coefs from w1, mask, store at t1++. */
_unpack_inner_18:
    loopi 8, 2
        bn.rshi w2, w1, w2 >> 32
        bn.rshi w1, w31, w1 >> 18
    endloop
    bn.and w2, w2, w5
    bn.sid t2, 0(t1++)
    ret

_unpack_inner_20:
    loopi 8, 2
        bn.rshi w2, w1, w2 >> 32
        bn.rshi w1, w31, w1 >> 20
    endloop
    bn.and w2, w2, w5
    bn.sid t2, 0(t1++)
    ret
