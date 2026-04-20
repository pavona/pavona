/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define RNDBYTES 32
#define N 256
#define Q 8380417
#define D 13
#define ROOT_OF_UNITY 1753

#if DILITHIUM_MODE == 2
#define K 4
#define L 4
#define ETA 2
#define TAU 39
#define BETA 78
#define GAMMA1 131072
#define GAMMA2 95232
#define OMEGA 80
#define CTILDEBYTES 32

#define POLYVECK_BYTES 4096
#define POLYVECL_BYTES 4096

#define CRYPTO_PUBLICKEYBYTES 1312
#define CRYPTO_SECRETKEYBYTES 2560
#define CRYPTO_BYTES 2420

#elif DILITHIUM_MODE == 3
#define K 6
#define L 5
#define ETA 4
#define TAU 49
#define BETA 196
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 55
#define CTILDEBYTES 48

#define POLYVECK_BYTES 6144
#define POLYVECL_BYTES 5120

#define CRYPTO_PUBLICKEYBYTES 1952
#define CRYPTO_SECRETKEYBYTES 4032
#define CRYPTO_BYTES 3309

#elif DILITHIUM_MODE == 5
#define K 8
#define L 7
#define ETA 2
#define TAU 60
#define BETA 120
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 75
#define CTILDEBYTES 64

#define POLYVECK_BYTES 8192
#define POLYVECL_BYTES 7168

#define CRYPTO_PUBLICKEYBYTES 2592
#define CRYPTO_SECRETKEYBYTES 4896
#define CRYPTO_BYTES 4627

#endif

#define POLYT1_PACKEDBYTES  320
#define POLYT0_PACKEDBYTES  416
#define POLYVECH_PACKEDBYTES (OMEGA + K)

/* w0_polyvec_shares is sized at the L5 width (8 polys/share) for every param set,
 * so the scratch layout is K-independent. */
#define W0_POLYS        8
#define W0_SHARE_STRIDE 8192

#if GAMMA1 == (1 << 17)
#define POLYZ_PACKEDBYTES   576
#elif GAMMA1 == (1 << 19)
#define POLYZ_PACKEDBYTES   640
#endif

#if GAMMA2 == (Q-1)/88
#define POLYW1_PACKEDBYTES  192
#elif GAMMA2 == (Q-1)/32
#define POLYW1_PACKEDBYTES  128
#endif

/* secboundcheck bounds C_Z = (1 << 24) - 2*(GAMMA1-BETA-1) - 1 and
 * C_R = (1 << 24) - 2*(GAMMA2-BETA-1) - 1, split into 8-bit slices for
 * the per-call bn.addi/bn.shv.8S build of w17 (acc_as does not evaluate
 * arithmetic in bn.addi immediates). */
#if DILITHIUM_MODE == 2
#define C_Z_HI  0xFC
#define C_Z_MID 0x00
#define C_Z_LO  0x9D
#define C_R_HI  0xFD
#define C_R_MID 0x18
#define C_R_LO  0x9D
#elif DILITHIUM_MODE == 3
#define C_Z_HI  0xF0
#define C_Z_MID 0x01
#define C_Z_LO  0x89
#define C_R_HI  0xF8
#define C_R_MID 0x03
#define C_R_LO  0x89
#elif DILITHIUM_MODE == 5
#define C_Z_HI  0xF0
#define C_Z_MID 0x00
#define C_Z_LO  0xF1
#define C_R_HI  0xF8
#define C_R_MID 0x02
#define C_R_LO  0xF1
#endif

#if ETA == 2
#define POLYETA_PACKEDBYTES  96
#define ETA_KBITS              3
#elif ETA == 4
#define POLYETA_PACKEDBYTES 128
#define ETA_KBITS              4
#endif

/* Register aliases */
.equ x2, sp
.equ x3, fp

.equ x5, t0
/* TODO(acc_as): switch back to `.equ x6, t1` once the assembler's
 * naive textual substitution stops mangling identifiers that end in
 * `t1` (e.g., `kmac_digest1` -> `kmac_digesx6`). */
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

.equ w31, bn0

/* Index of the Keccak command special register. */
#define KECCAK_CFG_REG 0x7d9
/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/* Matrix-mult accumulator. In the masked build it holds NSHARES contiguous
 * polyvecs (share-major); after the unmask boundary, share 0's slot holds
 * the plaintext result and the rest of the pipeline reads it as before. */
#define W0_POLYVEC w0_polyvec_shares


/**
 * Dilithium Sign_internal (external-mu mode; FIPS 204 Algorithm 7).
 *
 * Returns: 0 on success
 *
 * The caller pre-hashes the message+context to mu and places it in
 * dmem[mu].  ML-DSA-spec mu = SHAKE256(tr || 0x00 || byte(ctxlen) ||
 * ctx || msg, 64).
 *
 * All input DMEM buffers must be 32-byte aligned and initialized up to the
 * next 32B boundary so wide-reads succeed.
 *
 * @param[in]  x10: *sig (destination pointer)
 * @param[in]  dmem[mu]: pre-hashed message (64B)
 * @param[in]  dmem[sk]: secret key, 32B aligned
 * @param[in]  dmem[rnd]: signature randomization value (32B)
 * @param[out] x10: 0 (success)
 * @param[out] x11: siglen
 * @param[out] dmem[*sig]: signature
 *
 */
.global crypto_sign_signature_internal
crypto_sign_signature_internal:
    /* Masked gadgets use sp for stack frames; init it once on entry. */
    la sp, mask_stack_end
    /* External-mu mode (FIPS 204 Algorithm 7, ML-DSA.Sign_internal):
     * caller pre-hashes the message and provides mu in dmem[mu].  The
     * msg/ctx buffers and the initial SHAKE-256 over tr||ctxlen||ctx||msg
     * are gone -- saves ~2.4 KiB DMEM and one Keccak invocation. */

    /* Initialize a SHAKE256 operation. */
    addi  a1, x0, SEEDBYTES
    addi  a1, a1, RNDBYTES
    addi  a1, a1, CRHBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    /* Set masked-digest bit (bit 20) of kmac_cfg so K stays shared
     * across the SHAKE256 and rho' is produced as 2 shares. */
    addi  t1, x0, 1
    slli  t1, t1, 20
    add   t0, t0, t1
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send K shares: K_shares[0..31] -> share 0, K_shares[32..63] -> share 1. */
    la     t0, K_shares
    bn.lid x0, 0(t0)
    bn.wsrw kmac_msg, w0
    bn.xor w0, w0, w0              /* Whitening */
    bn.lid x0, 32(t0)
    bn.wsrw kmac_msg1, w0

    /* Send rnd as (rnd, 0): public input trivially shared on share 0. */
    la     t0, rnd
    bn.lid x0, 0(t0)
    bn.wsrw kmac_msg, w0
    bn.xor w0, w0, w0
    bn.wsrw kmac_msg1, w0

    /* Send mu (64B = 2 chunks) as (mu, 0). */
    la     t0, mu
    bn.lid x0, 0(t0)
    bn.wsrw kmac_msg, w0
    bn.xor w0, w0, w0
    bn.wsrw kmac_msg1, w0
    la     t0, mu
    bn.lid x0, 32(t0)
    bn.wsrw kmac_msg, w0
    bn.xor w0, w0, w0
    bn.wsrw kmac_msg1, w0

    /* Read 64B masked digest into sign_gamma1_buf[0..127] in the
     * share-major chunked layout that masked_poly_uniform_gamma_1
     * expects: share 0 chunks at [0,32], share 1 chunks at [64,96]. */
    la      a0, sign_gamma1_buf
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 0(a0)
    bn.xor  w0, w0, w0             /* Whitening */
    bn.wsrr w0, kmac_digest1
    bn.sid  x0, 64(a0)
    bn.xor  w0, w0, w0             /* Whitening */
    bn.wsrr w0, kmac_digest
    bn.sid  x0, 32(a0)
    bn.xor  w0, w0, w0             /* Whitening */
    bn.wsrr w0, kmac_digest1
    bn.sid  x0, 96(a0)

    /* Finish the SHAKE-256 operation. */

    /* Prepare modulus */
    #define mod_x2 w22
    bn.wsrr   w16, 0x0 /* w16 = MOD = R | Q */
    bn.shv.8S mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

    li s11, 0 /* nonce */

    jal  x1, sign_attempt
    ret

/* sign_attempt: rejection-retry body.  Computes w, w0/w1 + c~, c,
 * z (z-loop), h (hint loop); restarts in place on rejection.  Inputs
 * are taken from caller-set state (sign_gamma1_buf, sk, etc.); on
 * success returns a0 = 0, a1 = CRYPTO_BYTES. */
.global sign_attempt
sign_attempt:
    /* sign_w params: w_out, rho, rho_prime, y_staging, A_staging,
     * seca2b_scratch, gamma1_buf.  A_staging + gamma1_buf live in
     * dead sig during P1; c_poly (= NTT(c) post-P1) is now in overlay slack. */
    la   a0, W0_POLYVEC
    la   a1, sk                        /* rho is sk[0..32) */
    la   a2, sign_gamma1_buf
    la   a3, sign_y
    la   a4, sig                       /* A_staging at sig+1536 (after gamma1 buf) */
    addi a4, a4, 1536
#if CTILDEBYTES == 48
    addi a4, a4, 16                    /* L3 sig is 16 B off 32-align */
#endif
    la   a5, sig                       /* seca2b scratch at sig+2560 */
    addi a5, a5, 1024
    addi a5, a5, 1536
#if CTILDEBYTES == 48
    addi a5, a5, 16
#endif
    la   a6, sig                       /* gamma1 bitslice buf at sig+0 */
#if CTILDEBYTES == 48
    addi a6, a6, 16                    /* L3 sig is 16 B off 32-align */
#endif
    jal  x1, sign_w

    /* sign_w0_w1_ctilde params: w_polyvec, mu, w1_repvec, sig,
     * w1_tmp_scratch, seca2b_scratch (sig+2560, same as in sign_w). */
    la   a0, W0_POLYVEC
    la   a1, mu
    la   a2, sign_w1_repvec
    la   a3, sig
    la   a4, sign_tmp
    la   a5, sig
    addi a5, a5, 1024
    addi a5, a5, 1536
#if CTILDEBYTES == 48
    addi a5, a5, 16
#endif
    jal  x1, sign_w0_w1_ctilde

    la   a0, c_poly                    /* ntt_c output */
    la   a1, sign_tmp                /* aligned c~ stash */
    jal  x1, sign_c

    /* sign_z params: ntt_c, rho_prime(gamma1), sig_z_start,
     * z_staging, tmp_poly, cs1_share1, seca2b_scratch.  s1 is now derived
     * from rho_prime_shares in-loop, so a0 (was s1_packed) is unused. */
    la   a1, c_poly
    la   a2, sign_gamma1_buf
    la   a3, sig
    addi a3, a3, CTILDEBYTES
    la   a4, sign_c_poly_shares
    la   a5, sign_tmp
    la   a6, sign_y
    la   a7, sign_hint_b2a
    jal  x1, sign_z
    bne  a0, x0, sign_attempt

    /* sign_h params: sk_t0, ntt_c, packed_b, w1_repvec, sig_h.  s2 is now
     * derived from rho_prime_shares in-loop, so a1 (was s2_packed) is unused. */
    la   a0, sk
    addi a0, a0, 128
    la   a2, c_poly
    la   a3, W0_POLYVEC
    la   a4, sign_w1_repvec
    la   a5, sig
    addi a5, a5, CTILDEBYTES
    .rept L
        addi a5, a5, POLYZ_PACKEDBYTES
    .endr
    jal  x1, sign_h
    bne  a0, x0, sign_attempt
    li   a0, 0
    li   a1, CRYPTO_BYTES
    ret

/* sign_w: matrix-vector multiplication w = A * y.  Column-wise loop over
 * j in [0, L): sample y[j] both shares via gamma1, NTT each share in place,
 * then for each i in [0, K): generate A[i][j] from rho and accumulate
 * A[i][j] * NTT(y[j])[d] into w[i][d].  Inverse-NTT w at the end.
 *
 * @param[out] a0: dptr_w, NSHARES * K * 1024 B accumulator (W0_POLYVEC).
 * @param[in]  a1: dptr_rho, 32 B (sk[0..32)).
 * @param[in]  a2: dptr_rho_prime, 128 B rho' seed (sign_gamma1_buf).
 * @param[in]  a3: dptr_y_staging, 2 KiB (y[j] both shares).
 * @param[in]  a4: dptr_A_staging, 1 KiB.
 * @param[in]  a5: dptr_seca2b_scratch, 1.5 KiB (forwarded to gamma1's b2a).
 * @param[in]  a6: dptr_gamma1_buf, 1.5 KiB bitslice-u staging.
 *
 * In/out: advances nonce counter in s11 by L (each gamma1 call uses it).
 * Clobbers a/t regs, s0-s10, w16/w22/w23.  Restores MOD = R|Q.
 */
.global sign_w
sign_w:
    /* Park pointer args in s-regs so internal jals can clobber a-regs. */
    addi s1, a0, 0           /* w_out */
    addi s0, a1, 0           /* rho */
    addi s9, a2, 0           /* rho_prime */
    addi s3, a3, 0           /* y_staging */
    addi s10, a4, 0          /* A_staging */
    addi s2, a5, 0           /* seca2b_scratch (was: rhoprime slot) */
    addi s7, a6, 0           /* gamma1_buf (was: gamma1_vec_const slot) */

    /* Zero each share's polyvec; t1 walks the contiguous buffer. */
    li t0, 31
    addi t1, s1, 0
    .rept NSHARES
    LOOPI W0_POLYS, 3
        LOOPI 32, 1
          bn.sid t0, 0(t1++)
        nop
    .endr

    /* Per-column constants. */
    li s6, W0_SHARE_STRIDE           /* stride between w shares */
    bn.xor w23, w23, w23             /* matrix nonce = byte(i) || byte(j) */
    li s5, 31                        /* w31 ref (unused but historical) */

    /* SHAKE128 cfg for poly_uniform (rho||i||j). */
    addi s4, x0, 34
    slli s4, s4, 5
    addi s4, s4, SHAKE128_CFG

    loopi L, 81
        addi a0, s3, 0
        addi a1, s9, 0
        addi a2, s11, 0
        addi a3, s2, 0
        addi a4, s7, 0
        jal  x1, masked_poly_uniform_gamma_1
        addi s11, s11, 1

        /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
        csrrw x0, kmac_cfg, s4
        addi  a0, s0, 0
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        addi      t0, x0, 2
        csrrw     x0, kmac_partial_write, t0
        bn.wsrw   kmac_msg, w23
        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
        /* NTT each share of y[j] in place. */
        addi s8, s3, 0
        li   t5, NSHARES
        loop t5, 32
            addi a0, s8, 0
            addi a2, s8, 0
            jal  x1, ntt
            addi s8, s8, 1024
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
            bn.xor w17, w17, w17
            bn.xor w18, w18, w18
            bn.xor w19, w19, w19
            bn.xor w20, w20, w20
            bn.xor w21, w21, w21
            bn.xor w24, w24, w24
            bn.xor w25, w25, w25
            bn.xor w26, w26, w26
            bn.xor w27, w27, w27
            bn.xor w28, w28, w28
            bn.xor w29, w29, w29
            bn.xor w30, w30, w30
        loopi K, 23
            /* Compute A[i][j]. */
            addi a1, s10, 0
            jal  x1, poly_uniform
            /* Increment the row index by 1. */
            bn.addi w23, w23, 256
            /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
            csrrw x0, kmac_cfg, s4
            addi  a0, s0, 0
            bn.lid    x0, 0(a0)
            bn.wsrw   kmac_msg, w0
            addi      t0, x0, 2
            csrrw     x0, kmac_partial_write, t0
            bn.wsrw   kmac_msg, w23
            /* For each share d:  w_d[i] += A[i][j] * y_d[j]. */
            addi s8, s3, 0
            addi s5, s1, 0
            li   t5, NSHARES
            loop t5, 8
                addi a0, s8, 0
                addi a1, s10, 0
                addi a2, s5, 0
                jal  x1, poly_pointwise_acc
                addi s8, s8, 1024
                add  s5, s5, s6
                /* Whitening */
                bn.xor w0, w0, w0
                bn.xor w1, w1, w1
            addi s1, s1, 1024
        /* Reset w pointer for next column. */
        la   s1, W0_POLYVEC
        /* Increment the column index in the nonce by one. */
        bn.addi w23, w23, 1
        /* Reset the row index in the nonce to zero. */
        bn.rshi w23, w23, bn0 >> 8
        bn.rshi w23, bn0, w23 >> 248
        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* Inverse NTT each share's K polys; shares are W0_SHARE_STRIDE apart. */
    la  s1, W0_POLYVEC
    .rept NSHARES
    addi a0, s1, 0
    LOOPI K, 2
        jal x1, intt
        addi a0, a0, 1024
    li  t0, W0_SHARE_STRIDE
    add s1, s1, t0
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
    bn.xor w17, w17, w17
    bn.xor w18, w18, w18
    bn.xor w19, w19, w19
    bn.xor w20, w20, w20
    bn.xor w21, w21, w21
    bn.xor w24, w24, w24
    bn.xor w25, w25, w25
    bn.xor w26, w26, w26
    bn.xor w27, w27, w27
    bn.xor w28, w28, w28
    bn.xor w29, w29, w29
    bn.xor w30, w30, w30
    .endr

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */
    ret

/* sign_w0_w1_ctilde: per-poly decompose w[i] -> (w1[i], packed b'[i]);
 * polyw1_pack(w1[i]); SHAKE absorb; record w1 nonzero positions.
 * Finalize SHAKE -> c~ at sig[0..CTILDEBYTES).
 *
 * @param[inout] a0: dptr_w_polyvec.  Read as w (NSHARES*K*1024 B); the
 *                   K decompose iters overlay it in place with packed b'
 *                   (K*608 B per share at stride W0_SHARE_STRIDE).
 * @param[in]    a1: dptr_mu, 64 B (caller's mu).
 * @param[out]   a2: dptr_w1_repvec, K*32 B nonzero-summary of each w1[i].
 * @param[out]   a3: dptr_sig_ctilde, CTILDEBYTES at sig[0..).  Also
 *                   serves as decompose's scratch base (+16 for L3
 *                   alignment).
 * @param[scratch] a4: dptr_w1_tmp, 1 KiB temporary for decompose's w1
 *                   output and Keccak interim.
 * @param[scratch] a5: dptr_seca2b_scratch, 1.5 KiB (decompose internal).
 *
 * Clobbers: a/t regs, s0-s9.
 */
.global sign_w0_w1_ctilde
sign_w0_w1_ctilde:
    /* Park pointer args.  s7 holds mu just long enough for the
     * keccak_send_message; the K-loop later overwrites it with NSHARES. */
    addi s0, a0, 0            /* w polyvec walker */
    addi s7, a1, 0            /* mu (consumed below) */
    addi s1, a2, 0            /* sign_w1_repvec walker */
    addi s3, a3, 0            /* sig (for c~ writes) */
    addi s2, a3, 0            /* decompose scratch base (aligned below) */
#if CTILDEBYTES == 48
    addi s2, s2, 16           /* L3 sig is 16 B off 32-align */
#endif
    addi s4, a4, 0            /* w1 tmp scratch */
    addi s5, a5, 0            /* seca2b scratch */

    /* Initialize a SHAKE256 operation. */
    addi  a1, x0, CRHBYTES
    LOOPI K, 1
        addi a1, a1, POLYW1_PACKEDBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send mu (parked in s7). */
    li   a1, CRHBYTES
    addi a0, s7, 0
    jal  x1, keccak_send_message
    li   s6, W0_SHARE_STRIDE  /* stride between w_in / packed b' shares */

    /* Masked path: per poly, secdecompose produces an unmasked w1 (in
     * sign_tmp) and updates share 0 of w0 in place.  The K outer loop is
     * bne-based (not loopi) so it does not consume an ACC hardware loop-
     * stack slot -- secdecompose's call chain already uses every available
     * level. */
    li   s7, NSHARES
    li   s8, K
    /* Packed b' poly i: share 0 at i*608, share 1 at W0_SHARE_STRIDE +
     * i*608.  Per-poly stride 608 < input stride 1024, so dumps stay
     * in the consumed slot of their own share. */
    addi s9, s0, 0
_decompose_loop:
    addi   a0, s4, 0
    addi   a1, s0, 0
    addi   a4, s6, 0
#if DILITHIUM_MODE == 2
    /* L2: secdecompose scratch in w0_polyvec slots dead during decompose. */
    la     a3, sign_w0_l2_seccompress_scratch
    la     a5, sign_w0_l2_b
    la     a6, sign_w0_l2_t_packed
#else
    /* scratch_base = aligned sig (= s2); sig is empty during matrix-mult +
     * decompose (c~ writes happen after this K-loop's Keccak finalize).
     * a5/a6 = packed b' shares; a7 = seca2b scratch. */
    addi   a3, s2, 0
    addi   a5, s9, 0
    add    a6, s9, s6
    addi   a7, s5, 0
#endif
    jal    x1, secdecompose
    /* Pack w1, send to Keccak, record nonzero bits. */
    addi   a0, s2, 0
    addi   a1, s4, 0
    jal    x1, polyw1_pack
    addi   a0, s2, 0
    addi   a1, x0, POLYW1_PACKEDBYTES
    jal    x1, keccak_send_message
    addi   a0, s4, 0
    jal    x1, poly_nonzero_encode
    bn.sid x0, 0(s1++)
    addi   s0, s0, 1024
    addi   s9, s9, 608
    addi   s8, s8, -1
    bne    s8, x0, _decompose_loop

    /* Setup WDR */
    li t1, 8

    /* Read first 32 bytes of digest. */
    bn.wsrr w8, 0xA

    /* Get always-aligned temporary buffer. */
    la   t0, sign_tmp
#if CTILDEBYTES == 32
    /* Store first 32 bytes into temp buffer and signature. */
    bn.sid  t1, 0(t0)
    bn.sid  t1, 0(s3)
#elif CTILDEBYTES == 48
    /* Store first 32 bytes into temp buffer and (unaligned) signature. */
    bn.sid  t1, 0(t0)
    LOOPI 8, 4
        lw t2, 0(t0)
        sw t2, 0(s3)
        addi t0, t0, 4
        addi s3, s3, 4

    /* Read 32 more bytes and store 16 of them. */
    bn.wsrr w8, 0xA
    bn.sid  t1, 0(t0)
    LOOPI 4, 4
        lw t2, 0(t0)
        sw t2, 0(s3)
        addi t0, t0, 4
        addi s3, s3, 4
#elif CTILDEBYTES == 64
    /* Store first 32 bytes into temp buffer and signature. */
    bn.sid  t1, 0(t0)
    bn.sid  t1, 0(s3)
    /* Store 32 more bytes (both places). */
    bn.wsrr w8, 0xA
    bn.sid  t1, 32(t0)
    bn.sid  t1, 32(s3)
#endif

    /* Finish the SHAKE-256 operation. */
    ret

/* sign_c: sample challenge c from c~ (poly_challenge); NTT(c) in place.
 *
 * @param[out] a0: dptr_ntt_c, 1024 B buffer for NTT(c).
 * @param[in]  a1: dptr_ctilde, 32-byte aligned source of c~.
 *
 * Clobbers: t-regs, a-regs, s0.  Restores MOD = R|Q.
 */
.global sign_c
sign_c:
    addi s0, a0, 0            /* park ntt_c_out across poly_challenge */
    jal  x1, poly_challenge

    bn.wsrw 0x0, mod_x2
    addi a0, s0, 0
    addi a2, a0, 0
    jal  x1, ntt
    bn.wsrw 0x0, w16
    ret

/* sign_z: z = y + c * s1.  Loops over L polys: unpack/b2a s1, NTT chain
 * c*s1, sample y (gamma1), z = y + c*s1, bound-check; on success, pack
 * z to sig[CTILDE..CTILDE+L*POLYZ_PACKEDBYTES) and zero the hint tail.
 *
 * @param[in]   a1: dptr_ntt_c, 1 KiB.
 * @param[in]   a2: dptr_rho_prime, 128 B.
 * @param[in]   a3: dptr_sig_z_start (sig + CTILDEBYTES).
 * @param[scratch] a4: dptr_z_staging, 3.3 KiB (sign_c_poly_shares-sized).
 * @param[scratch] a5: dptr_tmp_poly, 1 KiB (polyeta_unpack tgt + collapsed z).
 * @param[scratch] a6: dptr_cs1_share1, 1 KiB (also secb2amodq_eta/secboundcheck
 *                    bitslice buf).
 * @param[scratch] a7: dptr_seca2b_scratch, 3.3 KiB (forwarded to inner gadgets;
 *                    L5 also takes its +1536 as gamma1 staging).
 *
 * In/out: reads s11 (= nonce counter advanced by sign_w); uses
 * s11 - L as the per-iter gamma1 nonce base.
 * Returns a0 = 0 on success, a0 = 1 on rejection.
 */
.global sign_z
sign_z:
    /* Park pointer args. */
    li   s0, 0               /* ExpandS nonce: s1[j] uses nonce j */
    addi s7, a1, 0            /* NTT(c) */
    addi s4, a2, 0            /* rho_prime (gamma1 seed) */
    addi s9, a3, 0            /* sig_z write ptr (advances per polyz_pack) */
    addi s6, a4, 0            /* z staging */
    addi s2, a5, 0            /* sign_tmp */
    addi s3, a6, 0            /* c*s1 share 1 + bitslice buf */
    addi s10, a7, 0           /* seca2b scratch (eta/gamma1/boundcheck) */

    li   s5, NSHARES
    /* Per-iter gamma1 nonce starts at s11 - L (sign_w advanced s11 by L). */
    addi s8, s11, -L

    /* This loop computes z = (cp * s1) = y one element at a time, and does
       rejection sampling on each element before packing it into the signature. */
    .rept L
        /* Derive s1[j] = ExpandS(rho', nonce=j) to canonical arith shares.
         * seca2b scratch = hint_b2a, b2a buf = sign_y; m rides in the
         * output until the gadget's b2a consumes it. */
        addi a0, s6, 0
        la   a1, rho_prime_shares
        addi a2, s0, 0
        la   a3, sign_hint_b2a
        la   a4, sign_y
        jal  x1, masked_poly_uniform_eta
        addi s0, s0, 1

        /* gadget's b2a clobbered w16/w22; rebuild from MOD (still R|Q). */
        bn.wsrr   w16, 0x0

        bn.shv.8S mod_x2, w16 << 1

        /* c*s1 share 0 at s2 (sign_tmp), share 1 at s3; delta in t3
         * (survives ntt/intt/poly_pointwise; t0-t2 don't). */
        bn.wsrw 0x0, mod_x2
        addi s1, s6, 0
        addi t6, s2, 0
        sub  t3, s3, s2
        loop s5, 39
            addi x10, s1, 0
            addi x12, t6, 0
            jal  x1, ntt
            addi x10, t6, 0
            addi x11, s7, 0
            addi x12, t6, 0
            jal  x1, poly_pointwise
            addi x10, t6, 0
            jal  x1, intt
            addi s1, s1, 1024
            add  t6, t6, t3
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
            bn.xor w17, w17, w17
            bn.xor w18, w18, w18
            bn.xor w19, w19, w19
            bn.xor w20, w20, w20
            bn.xor w21, w21, w21
            bn.xor w24, w24, w24
            bn.xor w25, w25, w25
            bn.xor w26, w26, w26
            bn.xor w27, w27, w27
            bn.xor w28, w28, w28
            bn.xor w29, w29, w29
            bn.xor w30, w30, w30
        bn.wsrw 0x0, w16

        /* Sample y -> z_staging (overwrites bitsliced s1, now consumed). */
        addi a0, s6, 0
        addi a1, s4, 0
        addi a2, s8, 0
        addi a3, s10, 0           /* seca2b scratch */
        /* hint_b2a region is L5-sized (8192 B) for both params; gamma1
         * staging fits at scratch+1536. */
        addi a4, s10, 1536
        jal  x1, masked_poly_uniform_gamma_1
        addi s8, s8, 1

        /* z = y + c*s1 per share; same s2 / s3 split as NTT. */
        addi s1, s6, 0
        addi t6, s2, 0
        sub  t3, s3, s2
        loop s5, 8
            addi a0, s1, 0
            addi a1, t6, 0
            addi a2, s1, 0
            jal  x1, poly_add
            addi s1, s1, 1024
            add  t6, t6, t3
            /* Whitening */
            bn.xor w0, w0, w0
            bn.xor w1, w1, w1

        /* Reduce z to unsigned canonical [0, q). */
        addi t0, s6, 0
        li   t1, 0
        loop s5, 5
            loopi 32, 3
                bn.lid t1, 0(t0)
                bn.addvm.8S w0, w0, w31
                bn.sid t1, 0(t0++)
            bn.xor w0, w0, w0          /* Whitening */


        /* secboundcheck on shared z, then AND-reduce the per-lane mask
         * to a 1-bit verdict; retry on fail.  Collapse z to sign_tmp
         * only after the bound check passes. */
        /* Build C_Z in w17 lane 0. */
        bn.xor    w17, w17, w17
        bn.addi   w17, w17, C_Z_HI
        bn.shv.8S w17, w17 << 8
        bn.addi   w17, w17, C_Z_MID
        bn.shv.8S w17, w17 << 8
        bn.addi   w17, w17, C_Z_LO
        addi a0, s6, 0
        la   a2, lambda0_z_vec
        addi a3, s10, 0           /* seca2b scratch */
        addi a4, s3, 0            /* boundcheck bitslice buf */
        jal  x1, secboundcheck

        bn.not w0, w0
        bn.cmp w0, w31
        csrrs a2, FG0, x0
        andi a2, a2, 8
        xori a2, a2, 8
        /* Reject if ||z|| >= gamma1 - beta on any lane. */
        bne  a2, x0, _sign_z_reject

        addi a0, s2, 0
        addi a1, s6, 0
        jal  x1, secunmask_modq

        /* TODO(masking,perf): polyz_pack expects mod^{+-} z, so we send
         * collapsed z through poly_reduce32 here.  Investigate whether
         * the share-wise reduce-to-canonical above can be reshaped so
         * the collapsed result is already mod^{+-}, dropping this call. */
        addi a0, s2, 0
        addi a1, s2, 0
        jal  x1, poly_reduce32

        /* Speculatively pack z[i] into the signature. */
        addi a0, s9, 0
        addi a1, s2, 0
        jal x1, polyz_pack
        /* Update the pointer to the end of the packed part. */
        addi s9, a0, 0
    .endr

    /* get *sig + CTILDEBYTES + L*POLYZ_PACKEDBYTES */
    addi a0, s9, 0

    /* Set hint bytes at end of signature (length omega + k) to 0. Round to
       next word boundary. */
    li    t1, OMEGA
    addi  t1, t1, K
    addi  t1, t1, 3
    srli  t1, t1, 2
    LOOP  t1, 2
      sw   x0, 0(a0)
      addi a0, a0, 4

    li   a0, 0
    ret
_sign_z_reject:
    li   a0, 1
    ret

/* sign_h: per-poly hint computation.  Loops over K polys: unpack/b2a s2,
 * c*s2, build r-tilde from packed_b'[i], subtract c*s2, bound-check,
 * compute c*t0, combine, poly_make_hint, encode_h to sig tail.
 *
 * @param[in]  a0: dptr_sk_t0, K * POLYT0_PACKEDBYTES (packed t0).
 * @param[in]  a2: dptr_ntt_c, 1 KiB.
 * @param[in]  a3: dptr_packed_b (post-decompose b' share 0 base; share 1 at +W0_SHARE_STRIDE).
 * @param[in]  a4: dptr_w1_repvec, K * 32 B (nonzero summary written by sign_w0_w1_ctilde).
 * @param[out] a5: dptr_sig_h_start, write target for hint bytes (sig + CTILDE + L*POLYZ_PACKEDBYTES).
 *
 * Scratch (currently hardcoded via la): sign_c_poly_shares, sign_hint_b2a,
 * sign_y, sign_tmp.
 *
 * Returns a0 = 0 on success, a0 = 1 on rejection.
 */
.global sign_h
sign_h:
    /* Park pointer args; preserve s11 (nonce counter) for sign_z's retry. */
    addi s0, a0, 0            /* sk t0 walker */
    li   s2, L               /* ExpandS nonce: s2[i] uses nonce L+i */
    addi s7, a2, 0            /* NTT(c) */
    addi s3, a3, 0            /* packed b' walker */
    addi s5, a4, 0            /* sign_w1_repvec walker */
    addi s9, a5, 0            /* sig hint write ptr */

    la   s10, sign_tmp

    /* Initialize the coefficient sum for the hint for post-check. */
    li  s4, 0

    /* Initialize the counter for the index in the hint vector. */
    li  s6, 0

    /* Hint loop counter. */
    li  s8, K

    /* Normalize w0 to the [0, q) range (in-place).  The masked path
     * doesn't carry arithmetic w0; its r-tilde computation produces
     * canonical [0, q) directly via bn.subvm.8S. */

_mldsa_sign_hint_loop:

        /* Derive s2[i] = ExpandS(rho', nonce=L+i) to canonical arith shares.
         * seca2b scratch = hint_b2a, b2a buf = hint_b2a+1536; m rides in the
         * output until the gadget's b2a consumes it. */
        la   a0, sign_c_poly_shares
        la   a1, rho_prime_shares
        addi a2, s2, 0
        la   a3, sign_hint_b2a
        la   a4, sign_hint_b2a
        addi a4, a4, 1536
        jal  x1, masked_poly_uniform_eta
        addi s2, s2, 1

        /* b2a chain clobbered w16/w22; rebuild from MOD (still R|Q). */
        bn.wsrr   w16, 0x0

        bn.shv.8S mod_x2, w16 << 1

        /* Per-share NTT chain in place on sign_c_poly_shares -> c*s2. */
        la   s1, sign_c_poly_shares
        li   t0, NSHARES
        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
        loop t0, 39
            addi x10, s1, 0
            addi x12, s1, 0
            jal  x1, ntt
            addi x10, s1, 0
            addi x11, s7, 0
            addi x12, s1, 0
            jal  x1, poly_pointwise
            addi x10, s1, 0
            jal  x1, intt
            addi s1, s1, 1024
            nop
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
            bn.xor w17, w17, w17
            bn.xor w18, w18, w18
            bn.xor w19, w19, w19
            bn.xor w20, w20, w20
            bn.xor w21, w21, w21
            bn.xor w24, w24, w24
            bn.xor w25, w25, w25
            bn.xor w26, w26, w26
            bn.xor w27, w27, w27
            bn.xor w28, w28, w28
            bn.xor w29, w29, w29
            bn.xor w30, w30, w30
        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* Reduce c*s2 shares to unsigned canonical [0, q). */
        la   t0, sign_c_poly_shares
        li   t1, 0
        li   t2, NSHARES
        loop t2, 5
            loopi 32, 3
                bn.lid t1, 0(t0)
                bn.addvm.8S w0, w0, w31
                bn.sid t1, 0(t0++)
            bn.xor w0, w0, w0          /* Whitening */

#if DILITHIUM_MODE == 2
        /* L2: r-tilde_s = w0_s - c*s2_s (mod q) sharewise.  Arithmetic w0[i]
         * lives in W0_POLYVEC (s3, shares W0_SHARE_STRIDE apart); c*s2 and the
         * r-tilde dst are in sign_c_poly_shares (shares 1024 apart). */
        la   t4, sign_c_poly_shares
        addi t5, s3, 0
        li   t2, 0
        li   t3, 2
        loopi 32, 4
            bn.lid t2, 0(t5++)
            bn.lid t3, 0(t4)
            bn.subvm.8S w0, w0, w2
            bn.sid t2, 0(t4++)
        /* Whitening */
        bn.xor w0, w0, w0
        bn.xor w2, w2, w2
        li   t6, W0_SHARE_STRIDE
        add  t5, s3, t6
        loopi 32, 4
            bn.lid t2, 0(t5++)
            bn.lid t3, 0(t4)
            bn.subvm.8S w0, w0, w2
            bn.sid t2, 0(t4++)
#else
        /* r-tilde = (gamma2 - U) - c*s2; b2a in/out at sign_hint_b2a. */
        li   t2, 0
        li   t3, 31
        la   t0, sign_hint_b2a
        addi t1, s3, 0
        loopi 19, 2
            bn.lid t2, 0(t1++)
            bn.sid t2, 0(t0++)
        loopi 5, 1
            bn.sid t3, 0(t0++)
        bn.xor w0, w0, w0              /* Whitening */
        li   t1, W0_SHARE_STRIDE
        add  t1, s3, t1
        loopi 19, 2
            bn.lid t2, 0(t1++)
            bn.sid t2, 0(t0++)
        loopi 5, 1
            bn.sid t3, 0(t0++)

        /* gamma2-U b2a: scratch at sign_y (dead). */
        la   a1, sign_hint_b2a
        addi a0, a1, 1536
        la   a3, sign_y
        jal  x1, secb2amodq_bc22

        la   a0, sign_tmp
        la   a1, sign_hint_b2a
        addi a1, a1, 1536
        jal  x1, unbitslice

        la     t0, gamma2_vec_const
        li     t1, 1
        bn.lid t1, 0(t0)
        la     t4, sign_c_poly_shares
        la     t5, sign_tmp
        li     t2, 0
        li     t3, 2
        loopi 32, 5
            bn.lid t2, 0(t4)
            bn.lid t3, 0(t5++)
            bn.addvm.8S w0, w0, w2
            bn.subvm.8S w0, w1, w0
            bn.sid t2, 0(t4++)

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
        la   a0, sign_tmp
        la   a1, sign_hint_b2a
        addi a1, a1, 1536
        addi a1, a1, 768
        jal  x1, unbitslice

        la     t4, sign_c_poly_shares
        addi   t4, t4, 1024
        la     t5, sign_tmp
        li     t2, 0
        li     t3, 2
        loopi 32, 5
            bn.lid t2, 0(t4)
            bn.lid t3, 0(t5++)
            bn.addvm.8S w0, w0, w2
            bn.subvm.8S w0, w31, w0
            bn.sid t2, 0(t4++)
#endif

        /* b2a chain clobbered w16/w22; rebuild from MOD (still R|Q). */
        bn.wsrr   w16, 0x0
        bn.shv.8S mod_x2, w16 << 1

        /* secboundcheck on shared r-tilde, AND-reduce verdict into s8. */
        /* Build C_R in w17 lane 0. */
        bn.xor    w17, w17, w17
        bn.addi   w17, w17, C_R_HI
        bn.shv.8S w17, w17 << 8
        bn.addi   w17, w17, C_R_MID
        bn.shv.8S w17, w17 << 8
        bn.addi   w17, w17, C_R_LO
        la   a0, sign_c_poly_shares
        la   a2, lambda0_r_vec
        la   a3, sign_hint_b2a
        la   a4, sign_y
        jal  x1, secboundcheck

        bn.not w0, w0
        bn.cmp w0, w31
        csrrs a2, FG0, x0
        andi a2, a2, 8
        xori a2, a2, 8
        /* Reject if ||rtilde|| >= gamma2 - beta on any lane. */
        bne  a2, x0, _sign_h_reject

        la   a0, sign_hint_b2a
        la   a1, sign_c_poly_shares
        jal  x1, secunmask_modq

        /* Restore w16 = MOD (secunmask_modq's contract leaves low32 = q). */
        bn.wsrr w16, 0x0

        /* Unpack the next polynomial from t0. */
        addi a0, s10, 0
        addi a1, s0, 0
        jal  x1, polyt0_unpack

        /* Update the packed t0 pointer. */
        addi s0, a1, 0

        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

        /* Compute ntt(t0[i]) in-place. */
        addi a0, s10, 0
        addi a2, a0, 0
        jal x1, ntt

        /* tmp = cp * t0 */
        addi a0, s10, 0
        addi a1, s7, 0
        addi a2, s10, 0
        jal  x1, poly_pointwise

        /* Inverse NTT on tmp */
        addi a0, s10, 0
        jal x1, intt

        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* w0[i] += tmp */
        la   a0, sign_hint_b2a
        addi a1, s10, 0
        addi a2, a0, 0
        jal  x1, poly_add

        /* h = reduce32(tmp) to move to mod^{+-} for bound check */
        addi a0, s10, 0
        addi a1, s10, 0
        jal  x1, poly_reduce32

        /* chknorm(h, gamma2) */
        li   a1, GAMMA2 /* This li expands to 2 instructions */
        addi a0, s10, 0
        jal  x1, poly_chknorm

        /* Reject if ||c*t0|| >= gamma2 on any lane. */
        bne a2, x0, _sign_h_reject

        /* h[i] = make_hint(w0[i], w1[i]) */
        addi   a0, s10, 0
        la     a1, sign_hint_b2a
        bn.lid x0, 0(s5++)
        jal    x1, poly_make_hint

        /* Update the coefficient sum accumulator (saving previous value). */
        add  a2, s4, 0
        add  s4, s4, a0

        /* If the accumulator (# nonzero coeffs in h) is > omega, reject. */
        addi t0, x0, OMEGA
        sub  t0, t0, s4
        srli t0, t0, 31

        /* Reject if hint weight > omega. */
        bne t0, x0, _sign_h_reject

        /* Encode h[i] into the signature. */
        addi a0, s9, 0
        addi a1, s10, 0
        addi a3, s6, 0
        jal  x1, poly_encode_h

        /* Increment i. */
        addi s6, s6, 1
        /* Advance to next poly. */
#if DILITHIUM_MODE == 2
        addi s3, s3, 1024              /* W0_POLYVEC stride (arithmetic w0) */
#else
        addi s3, s3, 608               /* packed-b' stride */
#endif
        /* Decrement remaining-iter count and loop while > 0. */
        addi s8, s8, -1
        bne  s8, x0, _mldsa_sign_hint_loop

    li   a0, 0
    ret
_sign_h_reject:
    li   a0, 1
    ret

.bss

/* mu (64B) is supplied by the caller's data section in external-mu mode. */

/* Sign working buffers, laid out back to back in .bss.  sign_y and sign_tmp are
 * independent 1 KiB scratch polys, except in sign_w where together they form a
 * 2 KiB y_staging (y[j] both shares).  w0_polyvec_shares is the matrix-mult
 * accumulator; once sign_w0 consumes it, packed_b' overwrites it in place and the
 * hint_b2a/c_poly_shares/c_poly scratch reuses its remaining bytes.  Per-phase
 * role (W write, R read, . idle):
 *
 *   region             off,size     w      w0       c     z        h
 *   sign_y             0,   1024     y[0]   .        .     cs1_1    bitsl+twid
 *   sign_tmp           1024,1024     y[1]   w1tmp/c~ c~ R  cs1_0/z  c*t0,h
 *   sign_w1_repvec     2048, 256     .      W        .     .        R
 *   w0_polyvec_shares  2304,16384    accW   packd-b' .     scratch  packd-b' R
 *   sign_gamma1_buf    18688,128     rho'R  .        .     rho'R    . */
.balign 32
sign_y:
    .zero 1024
sign_tmp:
    .zero 1024
sign_w1_repvec:
    .zero 256
w0_polyvec_shares:
    .zero 16384
sign_gamma1_buf:
    .zero 128

.balign 32
mask_stack:
    .zero 256
mask_stack_end:

/* Scratch overlaying w0_polyvec_shares once its rows are consumed: hint_b2a
 * past packed_b' share 0 (W0_POLYS*608 B), then c_poly_shares and c_poly past
 * share 1. */
.set sign_hint_b2a,      w0_polyvec_shares + W0_POLYS * 608
.set sign_c_poly_shares, w0_polyvec_shares + W0_SHARE_STRIDE + W0_POLYS * 608
.set c_poly,             w0_polyvec_shares + W0_SHARE_STRIDE + W0_POLYS * 608 + NSHARES * 1024

/* L2 only: secdecompose scratch overlaying w0_polyvec's dead rows (only K of
 * each share's 8 rows are live during decompose). */
.set sign_w0_l2_seccompress_scratch, w0_polyvec_shares + K*1024
.set sign_w0_l2_b,                   w0_polyvec_shares + W0_SHARE_STRIDE + K*1024
.set sign_w0_l2_t_packed,            sign_w0_l2_b + 2048
