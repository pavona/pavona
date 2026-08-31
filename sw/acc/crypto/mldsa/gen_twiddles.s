/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Runtime regeneration of the ML-DSA forward NTT twiddle table (and its
 * inverse) into the `scratch` buffer.
 *
 * Hardened builds omit the 1 KiB static forward table from the loaded DMEM
 * image (mldsa_consts.s) to make room, and rebuild it here instead; the output
 * is identical to twiddles_fwd.
 *
 * The length-256 NTT twiddles are powers of zeta = 1753, the primitive 512th
 * root of unity mod q (q = 8380417), held in Montgomery form
 * (x_bar = x * R mod q, R = 2^32 mod q). Since zeta^a * zeta^b = zeta^(a+b), a
 * Montgomery multiply of two powers adds their exponents, so the table is
 * rebuilt entirely by multiplying stored powers together.
 *
 * The 256 twiddles are emitted 8 at a time. Each group is one 8-lane base
 * vector multiplied lane-wise by a single scalar power, which adds a constant
 * to all eight exponents:
 *
 *     out[8*k + j] = base_j * scalar_k = zeta^(e_j) * zeta^(s_k) = zeta^(e_j + s_k)
 *
 * gen_seed_scalars holds the scalar powers zeta^(s_k); most groups reuse the
 * previous group as their base, so the table is one running chain of products.
 * The base "level" vectors are related by squaring (zeta^e -> zeta^(2e)), so
 * only gen_seed_lv0 and gen_seed_lv3 are stored: lv2 = lv3^2 and
 * lv1 = lv3^4 = lv2^2 are recomputed on entry.
 *
 * _inv_transform then builds the inverse table from the forward one by
 * reverse-order modular negation, inv[i] = q - fwd[255-i] (i.e. zeta^(-e) from
 * zeta^e), plus two ninv-scaled tail entries (inv[254] = ninv * fwd[1],
 * inv[255] = ninv).
 *
 * Entry points:
 *   gen_twiddles_fwd - build the forward table in `scratch`.
 *   _inv_transform   - convert the forward table in `scratch` to the inverse.
 */

.text

/**
 * gen_twiddles_fwd
 *
 * Regenerate the forward NTT twiddle table (256 words).
 *
 * @param[in]  w16: ... | -Q^-1 mod 2^32 | Q
 * @param[in]  w31: all-zero register
 * @param[out] dmem[scratch]: forward twiddle table, 1 KiB.
 *
 * Preserves x10, x11, x12.
 *
 * clobbered registers: x5 to x7, w0, w17, w24 to w27, w30, acch, acc
 * clobbered flag groups: none
 */
.globl gen_twiddles_fwd
.type gen_twiddles_fwd, @function
gen_twiddles_fwd:
  la   x7, scratch              /* output base */
  la   x6, gen_seed_lv0
  li   x5, 24
  bn.lid x5, 0(x6)
  la   x6, gen_seed_lv3
  li   x5, 27
  bn.lid x5, 0(x6)
  li   x5, 17
  /* LV2=LV3^2 ; LV1=LV2^2 */
  bn.mulv.8s.even.acc.z.lo   w26, w27, w27
  bn.mulv.l.8s.even.lo       w26, w26, sw0.1
  bn.mulv.l.8s.even.acc.hi   w26, w26, sw0.0
  bn.mulv.8s.odd.acc.z.lo    w26, w26, w27
  bn.mulv.l.8s.odd.lo        w26, w26, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w26, w26, sw0.0
  bn.mulv.8s.even.acc.z.lo   w25, w26, w26
  bn.mulv.l.8s.even.lo       w25, w25, sw0.1
  bn.mulv.l.8s.even.acc.hi   w25, w25, sw0.0
  bn.mulv.8s.odd.acc.z.lo    w25, w25, w26
  bn.mulv.l.8s.odd.lo        w25, w25, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w25, w25, sw0.0
  la   x6, gen_seed_scalars+0
  bn.lid x5, 0(x6)              /* w17 = scalars[0..7] */
  bn.mulv.l.8s.even.acc.z.lo w30, w24, sw1.0
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.0
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.1
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.1
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w25, sw1.2
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.2
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.3
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.3
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.4
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.4
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w26, sw1.5
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.5
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.6
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.6
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.7
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.7
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  la   x6, gen_seed_scalars+32
  bn.lid x5, 0(x6)              /* w17 = scalars[8..15] */
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.0
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.0
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w27, sw1.1
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.1
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.2
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.2
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.3
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.3
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.4
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.4
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.5
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.5
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.6
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.6
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.7
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.7
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  la   x6, gen_seed_scalars+64
  bn.lid x5, 0(x6)              /* w17 = scalars[16..23] */
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.0
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.0
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w25, sw1.1
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.1
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.2
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.2
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.3
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.3
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w26, sw1.4
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.4
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.5
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.5
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.6
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.6
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.7
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.7
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  la   x6, gen_seed_scalars+96
  bn.lid x5, 0(x6)              /* w17 = scalars[24..31] */
  bn.mulv.l.8s.even.acc.z.lo w30, w27, sw1.0
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.0
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.1
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.1
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.2
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.2
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.3
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.3
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.4
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.4
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.5
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.5
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.6
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.6
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  bn.mulv.l.8s.even.acc.z.lo w30, w0, sw1.7
  bn.mulv.l.8s.even.lo       w30, w30, sw0.1
  bn.mulv.l.8s.even.acc.hi   w30, w30, sw0.0
  bn.mulv.l.8s.odd.acc.z.lo  w30, w30, sw1.7
  bn.mulv.l.8s.odd.lo        w30, w30, sw0.1
  bn.mulv.l.8s.odd.acc.hi    w30, w30, sw0.0
  bn.mov w0, w30
  bn.sid x0, 0(x7++)
  la   x6, scratch
  sw   x0, 60(x6)
  ret

/**
 * _inv_transform
 *
 * In place, fwd twiddle table in `scratch` -> inverse table
 *
 * @param[in]    w16: ... | -Q^-1 mod 2^32 | Q
 * @param[in]    w31: all-zero register
 * @param[inout] dmem[scratch]: forward twiddle table in, inverse table out.
 *
 * Preserves x10, x12, w22, w23 (saved and restored).  Leaves MOD = 2R|2Q.
 *
 * clobbered registers: x5 to x7, x11, w1 to w2, w19 to w23, w28 to w29, mod
 * clobbered flag groups: FG0
 */
.globl _inv_transform
_inv_transform:
  bn.mov  w1, w22                /* preserve caller w22/w23 (e.g. mod_x2) */
  bn.mov  w2, w23
  bn.wsrw 0x0, w16               /* MOD = R|Q (low32 = q) for modular negate */
  bn.xor  w23, w23, w23          /* minuend 0 */
  la      x11, scratch
  /* save fwd[240..255] (overwritten by the tail / inv[0..15] steps) */
  li     x5, 28
  addi   x6, x11, 960
  bn.lid x5, 0(x6)
  li     x5, 29
  addi   x6, x11, 992
  bn.lid x5, 0(x6)
  /* pair-swap reverse-negate WDR2..WDR29: inv[i]=q-fwd[255-i], i=16..239 */
  addi   x6, x11, 64
  addi   x7, x11, 928
  loopi 14, 22
    li     x5, 20
    bn.lid x5, 0(x6)
    li     x5, 19
    bn.lid x5, 0(x7)
    bn.rshi     w21, w20, w20 >> 32
    bn.trn1.8s  w21, w21, w20
    bn.rshi     w22, w21, w21 >> 64
    bn.trn1.4d  w22, w22, w21
    bn.rshi     w20, w22, w22 >> 128
    bn.subvm.8s w20, w23, w20
    li     x5, 20
    bn.sid x5, 0(x7)
    bn.rshi     w21, w19, w19 >> 32
    bn.trn1.8s  w21, w21, w19
    bn.rshi     w22, w21, w21 >> 64
    bn.trn1.4d  w22, w22, w21
    bn.rshi     w19, w22, w22 >> 128
    bn.subvm.8s w19, w23, w19
    li     x5, 19
    bn.sid x5, 0(x6)
    addi   x6, x6, 32
    addi   x7, x7, -32
  endloop
  /* tail: inv[240..253] = q - fwd[14..1] (fwd[1..14] still in scratch[1..14]) */
  addi x6, x11, 56              /* &fwd[14] */
  addi x7, x11, 960            /* &inv[240] */
  li   x5, 0x7fe001
  loopi 14, 5
    lw   x11, 0(x6)
    sub  x11, x5, x11
    sw   x11, 0(x7)
    addi x6, x6, -4
    addi x7, x7, 4
  endloop
  la   x11, scratch
  li   x5, 0x003caa21          /* inv[254] = ninv * fwd[1] (Mont) */
  sw   x5, 1016(x11)
  li   x5, 0x0000a3fa          /* inv[255] = ninv (Mont) */
  sw   x5, 1020(x11)
  /* inv[0..7]=revneg(fwd[248..255]) ; inv[8..15]=revneg(fwd[240..247]) */
  bn.rshi     w21, w29, w29 >> 32
  bn.trn1.8s  w21, w21, w29
  bn.rshi     w22, w21, w21 >> 64
  bn.trn1.4d  w22, w22, w21
  bn.rshi     w29, w22, w22 >> 128
  bn.subvm.8s w29, w23, w29
  li     x5, 29
  bn.sid x5, 0(x11)
  bn.rshi     w21, w28, w28 >> 32
  bn.trn1.8s  w21, w21, w28
  bn.rshi     w22, w21, w21 >> 64
  bn.trn1.4d  w22, w22, w21
  bn.rshi     w28, w22, w22 >> 128
  bn.subvm.8s w28, w23, w28
  li     x5, 28
  bn.sid x5, 32(x11)
  /* restore MOD = 2R|2Q for the intt butterflies */
  bn.shv.8s w19, w16 << 1
  bn.wsrw 0x0, w19
  bn.mov w22, w1                 /* restore caller w22/w23 */
  bn.mov w23, w2
  ret

.data
gen_seed_lv0:
  .word 0x003ffe00
  .word 0x0007eafd
  .word 0x00581103
  .word 0x000bdee8
  .word 0x00039e44
  .word 0x0078c1dd
  .word 0x00728129
  .word 0x005bf6d6
gen_seed_lv3:
  .word 0x003ffe00
  .word 0x00039e44
  .word 0x001bde2b
  .word 0x002f9a75
  .word 0x00299658
  .word 0x00777d91
  .word 0x005f8dd7
  .word 0x001ad035
gen_seed_scalars:
  .word 0x000064f7
  .word 0x001bde2b
  .word 0x00299658
  .word 0x002ab0d3
  .word 0x001bde2b
  .word 0x0043e6e6
  .word 0x000064f7
  .word 0x00703f91
  .word 0x000064f7
  .word 0x001fea93
  .word 0x000064f7
  .word 0x0007eafd
  .word 0x000064f7
  .word 0x0050eb34
  .word 0x000064f7
  .word 0x0007eafd
  .word 0x000064f7
  .word 0x005f8dd7
  .word 0x00083aa3
  .word 0x001bde2b
  .word 0x004cdbea
  .word 0x000064f7
  .word 0x00703f91
  .word 0x000064f7
  .word 0x006c5954
  .word 0x000064f7
  .word 0x0007eafd
  .word 0x000064f7
  .word 0x0050eb34
  .word 0x000064f7
  .word 0x0007eafd
  .word 0x000064f7
