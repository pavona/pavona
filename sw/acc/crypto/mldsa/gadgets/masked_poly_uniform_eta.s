/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x0,  zero
.equ x1,  ra
.equ x2,  sp
.equ x3,  fp
.equ x5,  t0
/* acc_as mangles identifiers ending in `t1` (kmac_digest1 -> kmac_digesx6)
 * when t1 is set via `.equ`; use a token-based #define instead. */
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

.equ w31, bn0

#ifndef NSHARES
  #define NSHARES 2
#endif
#if NSHARES != 2
  #error "masked_poly_uniform_eta only supports NSHARES=2"
#endif

#ifndef ETA
  #define ETA 2
#endif

#define CRHBYTES     64
#define SHAKE256_CFG 0xA

/* Scratch (a3, >= 3104 B).  Four live buffers; the gather stash (SQ*) and the
 * mod-5 temps (Z,T,M1) reuse dead bytes since the phases run in sequence.  a3
 * is also the b2a seca2b scratch.  Offsets > 2047 take an `li s11; add` pair. */
#define OFF_G0     0      /* gathered nibbles, share 0 (canonical, 1024 B) */
#define OFF_G1     1024   /* gathered nibbles, share 1 */
#define OFF_BS     2048   /* bitslice output, reused per share (736 B) */
#define OFF_N5     2784   /* n^{B,5}, share stride 160 (320 B) */
#define OFF_SQ0    2048   /* squeeze stash, reuses BS (gather phase) */
#define OFF_SQ1    2080
#define OFF_REJ    2112
#define OFF_Z      0      /* mod-5 temps, reuse G0 (after bitslice) */
#define OFF_T      320
#define OFF_M1     640

#define STRIPE_K   5
#define STRIDE5    160    /* STRIPE_K * 32 */

/*
 * Name: masked_poly_uniform_eta (PINI, d = 2), eta = 2 or 4
 *
 * Produces a 2-share arithmetic sharing (mod q) of one s1/s2 polynomial,
 * ExpandS(rho', nonce): draw 4-bit nibbles from SHAKE-256(rho'||nonce) and
 * map each accepted nibble n to eta - reduce(n) per FIPS 204 CoeffFromHalfByte:
 *   eta=2: reject n == 15, coefficient = 2 - (n mod 5)
 *   eta=4: reject n >= 9,  coefficient = 4 - n
 *
 *   1: start masked SHAKE-256 over the shared seed and nonce
 *   2: draw nibbles; reveal the public reject bit and pack the accepted ones
 *      (two shares each) into G0/G1 until 256 collected
 *   3: bitslice G0 and G1
 *   4: eta=2 only: m = n mod 5 = n - 5*(n>=5) - 5*(n>=10); eta=4 uses n as-is
 *   5: B2A: reduce(n) -> arithmetic shares (mod q)
 *   6: coefficient = eta - reduce(n)   (eta folded into one share)
 *
 * This is FIPS 204 CoeffFromHalfByte, NOT [ABCH+23] Alg. 6 SecSampleModp:
 * Alg. 6 also samples [-eta, eta] but encodes the XOF differently (3-bit,
 * accept 5/8 vs FIPS's 15/16), deriving a different key from the same seed;
 * we must match the FIPS key bit-for-bit.
 *
 * Primitives: SecAnd / SecAdd / SecB2AModp [BC22]; (n>=5)/(n>=10) use the
 * [ABCH+23] SecLeq carry bit.
 *
 * @param[out]  a0: dptr_out, 2 * 1024 B arithmetic shares (mod q); also holds
 *                  bitsliced m transiently before the b2a consumes it.
 * @param[in]   a1: dptr_seed, 2 * CRHBYTES masked rho' (share-major).
 * @param[in]   a2: nonce (uint16_t).
 * @param[in]   a3: dptr_scratch, >= 3104 B (also the b2a seca2b scratch).
 * @param[in]   a4: dptr_b2a_buf, 1536 B (secb2amodq_eta Boolean buffer).
 * @param[in]  w31: all-zero.
 *
 * clobbered registers: x2, x5 to x31, w0 to w27
 * clobbered flag groups: FG0
 */
.globl masked_poly_uniform_eta
masked_poly_uniform_eta:
    addi sp, sp, -32
    sw   a0, 0(sp)                 /* out ptr (also bitsliced m, then output) */
    sw   a3, 4(sp)                 /* scratch base (= b2a seca2b scratch) */
    sw   a4, 8(sp)                 /* b2a Boolean buffer */
    sw   s0, 16(sp)                /* callee-save: caller parks pointers here */
    sw   s1, 20(sp)
    sw   s2, 24(sp)
    sw   s11, 28(sp)

    /* ---- Init masked SHAKE-256, absorb rho' shares + nonce. ---- */
    addi  a4, x0, CRHBYTES
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
    /* wM = per-nibble bit-0 mask (bits 0,4,8,...,252).  Built from the byte
     * pattern 0x11 (= bits 0,4) with byte-aligned shifts only, since the
     * shifted-operand form encodes the shift as uimm5<<3 (multiples of 8). */
    #define wM w30
    bn.addi wM, bn0, 0x11
    bn.or   wM, wM, wM << 8
    bn.or   wM, wM, wM << 16
    bn.or   wM, wM, wM << 32
    bn.or   wM, wM, wM << 64
    bn.or   wM, wM, wM << 128

    lw   a3, 4(sp)
    addi s0, a3, OFF_G0           /* G0 write cursor */
    addi s1, a3, OFF_G1           /* G1 write cursor */
    addi s2, a3, 1024             /* G0 end (256 nibbles done) */

_mpue_squeeze:
    /* s0_w/s1_w = next 64 masked nibbles (share 0 / share 1). */
    bn.wsrr w0, kmac_digest
    bn.wsrr w1, kmac_digest1

#if ETA == 2
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
#elif ETA == 4
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
#endif

    /* Reveal only the per-nibble reject bits (mask off the garbage). */
    bn.and  w7, w7, wM
    bn.and  w3, w3, wM
    bn.xor  w7, w7, w3           /* public reject mask, bit 4i set => reject */

    /* Stash share words + reject mask for the scalar gather. */
    li   s11, OFF_SQ0
    add  t2, a3, s11
    bn.sid x0, 0(t2)             /* x0 indexes w0 */
    li   s11, OFF_SQ1
    add  t2, a3, s11
    li   t3, 1
    bn.sid t3, 0(t2)             /* w1 */
    li   s11, OFF_REJ
    add  t2, a3, s11
    li   t3, 7
    bn.sid t3, 0(t2)             /* w7 */

    /* Gather: 8 words x 8 nibbles, compacting accepted nibbles. */
    li   s11, OFF_SQ0
    add  t0, a3, s11
    li   s11, OFF_SQ1
    add  t2, a3, s11
    li   s11, OFF_REJ
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
#if ETA == 2
    /* ---- mod-5 in the Boolean domain. ---- */
    lw   a3, 4(sp)

    /* Bitslice share 0 -> BS, copy low 5 stripes to N5 share 0; then reuse
     * BS for share 1.  (Single bitslice buffer overlaid by lifetime.) */
    li   s11, OFF_BS
    add  a0, a3, s11
    addi a1, a3, OFF_G0
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, OFF_BS
    add  t0, a3, s11
    li   s11, OFF_N5
    add  t1, a3, s11
    li   t2, 0
    loopi STRIPE_K, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)

    /* Whitening */
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
    li   s11, OFF_BS
    add  a0, a3, s11
    addi a1, a3, OFF_G1
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, OFF_BS
    add  t0, a3, s11
    li   s11, OFF_N5
    add  t1, a3, s11
    addi t1, t1, STRIDE5
    loopi STRIPE_K, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)

    /* c1 = [n>=5] = !SecLeq_4(n): SecAdd_5(n, 2^5-4-1=27), bit 4 = [n<=4]. */
    li   s11, OFF_N5
    add  a0, a3, s11
    li   a2, STRIPE_K
    li   a3, STRIDE5
    li   a4, 2
    lw   a5, 4(sp)
    li   s11, OFF_Z
    add  a5, a5, s11
    bn.xor w17, w17, w17
    bn.addi w17, w17, 27
    jal  x1, secadd_bc22_immd_d2

    /* Build T = c1 gated into the 27 bit-pattern {0,1,3,4}, c1 = !Z[4]. */
    lw   a3, 4(sp)
    jal  x1, _mpue_build_subtrahend

    /* m1 = SecAdd_5(n, T) = n - 5*c1. */
    lw   a3, 4(sp)
    li   s11, OFF_N5
    add  a0, a3, s11
    li   s11, OFF_T
    add  a1, a3, s11
    li   a2, STRIPE_K
    li   a3, STRIDE5
    li   a4, 2
    lw   a5, 4(sp)
    li   s11, OFF_M1
    add  a5, a5, s11
    jal  x1, secadd_bc22

    /* c2 = [n>=10] = !SecLeq_9(n): SecAdd_5(n, 2^5-9-1=22), bit 4 = [n<=9]. */
    lw   a3, 4(sp)
    li   s11, OFF_N5
    add  a0, a3, s11
    li   a2, STRIPE_K
    li   a3, STRIDE5
    li   a4, 2
    lw   a5, 4(sp)
    li   s11, OFF_Z
    add  a5, a5, s11
    bn.xor w17, w17, w17
    bn.addi w17, w17, 22
    jal  x1, secadd_bc22_immd_d2

    lw   a3, 4(sp)
    jal  x1, _mpue_build_subtrahend

    /* m = SecAdd_5(m1, T) = n - 5*c1 - 5*c2 = n mod 5, written to the OUTPUT
     * buffer (share0 at out+0, share1 at out+STRIDE5). */
    lw   a3, 4(sp)
    li   s11, OFF_M1
    add  a0, a3, s11
    li   s11, OFF_T
    add  a1, a3, s11
    li   a2, STRIPE_K
    li   a3, STRIDE5
    li   a4, 2
    lw   a5, 0(sp)               /* out */
    jal  x1, secadd_bc22

    /* ---- B2A(m, k=3): out holds m; a3 (dead) is the seca2b scratch. ---- */
    lw   a0, 0(sp)
    addi a1, a0, 0               /* m share0 in out */
    addi a2, a0, STRIDE5         /* m share1 in out */
    li   a3, 3
    lw   a4, 4(sp)               /* seca2b scratch (= a3) */
    lw   a5, 8(sp)               /* Boolean buffer */
    jal  x1, secb2amodq_eta
#elif ETA == 4
    /* ---- eta=4: no mod 5; coeff = 4 - n.  Bitslice n, B2A(k=4). ---- */
    lw   a3, 4(sp)

    /* Bitslice share 0 -> BS; copy low 4 stripes to out+0 (b2a share 0). */
    li   s11, OFF_BS
    add  a0, a3, s11
    addi a1, a3, OFF_G0
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, OFF_BS
    add  t0, a3, s11
    lw   t1, 0(sp)
    li   t2, 0
    loopi 4, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)

    /* Whitening */
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
    li   s11, OFF_BS
    add  a0, a3, s11
    addi a1, a3, OFF_G1
    li   a2, 32
    jal  x1, bitslice

    lw   a3, 4(sp)
    li   s11, OFF_BS
    add  t0, a3, s11
    lw   t1, 0(sp)
    addi t1, t1, 128
    li   t2, 0
    loopi 4, 2
        bn.lid t2, 0(t0++)
        bn.sid t2, 0(t1++)

    /* B2A(n, k=4): out+0 / out+128 hold n; out receives arith shares. */
    lw   a0, 0(sp)
    addi a1, a0, 0
    addi a2, a0, 128
    li   a3, 4
    lw   a4, 4(sp)               /* seca2b scratch */
    lw   a5, 8(sp)               /* Boolean buffer */
    jal  x1, secb2amodq_eta
#endif

    /* coeff = eta - reduce(n): share 0 = eta - m0, share 1 = -m1  (mod q). */
    la     t0, eta
    li     t1, 4
    bn.lid t1, 0(t0)             /* w4 = eta in each lane */

    lw   a0, 0(sp)
    li   t0, 0
    addi t1, a0, 0
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w4, w0
        bn.sid t0, 0(t1++)

    /* Whitening */
    bn.xor w0, w0, w0
    lw   a0, 0(sp)
    addi t1, a0, 1024
    loopi 32, 3
        bn.lid t0, 0(t1)
        bn.subvm.8s w0, w31, w0
        bn.sid t0, 0(t1++)

    lw   s0, 16(sp)
    lw   s1, 20(sp)
    lw   s2, 24(sp)
    lw   s11, 28(sp)
    addi sp, sp, 32
    ret

#if ETA == 2
/*
 * Helper: build T (OFF_T) from the comparison bit at stripe 4 of OFF_Z.
 * c = !Z[4] (flip share 0); gate c into the bit pattern of 27 (= -5 mod 2^5),
 * i.e. stripes {0,1,3,4} = c, stripe 2 = 0.  a3 = scratch base.
 */
_mpue_build_subtrahend:
    /* Load c shares: w0 = !Z[4]_s0, w1 = Z[4]_s1. */
    li   s11, OFF_Z
    add  t0, a3, s11
    addi t0, t0, 128             /* stripe 4 (4 * 32), share 0 */
    li   t2, 0
    bn.lid t2, 0(t0)
    bn.not w0, w0                /* c_s0 = NOT Z[4]_s0 */
    li   s11, OFF_Z
    add  t0, a3, s11
    addi t0, t0, STRIDE5
    addi t0, t0, 128             /* stripe 4, share 1 */
    li   t2, 1
    bn.lid t2, 0(t0)

    /* Write share 0 stripes {0,1,3,4}=c, {2}=0. */
    li   s11, OFF_T
    add  t1, a3, s11
    li   t2, 0
    li   t3, 31                  /* w31 = 0 */
    bn.sid t2, 0(t1)             /* stripe 0 = c */
    bn.sid t2, 32(t1)            /* stripe 1 = c */
    bn.sid t3, 64(t1)            /* stripe 2 = 0 */
    bn.sid t2, 96(t1)            /* stripe 3 = c */
    bn.sid t2, 128(t1)           /* stripe 4 = c */

    /* Write share 1 stripes {0,1,3,4}=c, {2}=0. */
    li   s11, OFF_T
    add  t1, a3, s11
    addi t1, t1, STRIDE5
    li   t2, 1                   /* w1 = c_s1 */
    bn.sid t2, 0(t1)
    bn.sid t2, 32(t1)
    bn.sid t3, 64(t1)
    bn.sid t2, 96(t1)
    bn.sid t2, 128(t1)
    ret
#endif
