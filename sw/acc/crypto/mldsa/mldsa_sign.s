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

/* Worst-case (ML-DSA-87) polyvec sizes for static buffers. */
#define POLYVECK_BYTES 8192
#define POLYVECL_BYTES 7168

/* Offsets into the mldsa_params struct (in mldsa_consts.s). */
#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_L_OFFSET 4
#define MLDSA_PARAM_TAU_OFFSET 8
#define MLDSA_PARAM_OMEGA_OFFSET 12
#define MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET 16
#define MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET 20
#define MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET 24
#define MLDSA_PARAM_GAMMA2_OFFSET 28
#define MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET 32
#define MLDSA_PARAM_SK_S2_OFFSET_OFFSET 36
#define MLDSA_PARAM_SK_T0_OFFSET_OFFSET 40
#define MLDSA_PARAM_CRYPTO_BYTES_OFFSET 44

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

/**
 * Dilithium Sign
 *
 * Returns: 0 on success
 *
 * All input DMEM buffers must be 32-byte aligned and initialized up to the
 * next 32B boundary so wide-reads succeed.
 *
 * @param[in]  x10: *sig (destination pointer)
 * @param[in]  dmem[mu]: externally computed mu (64B)
 * @param[in]  dmem[sk]: secret key, 32B aligned
 * @param[in]  dmem[rnd]: signature randomization value (32B)
 * @param[out] x10: 0 (success)
 * @param[out] x11: siglen
 * @param[out] dmem[*sig]: signature
 */
.globl crypto_sign_signature_internal
.type crypto_sign_signature_internal, @function
crypto_sign_signature_internal:
#ifdef HARDENED
#define NSHARES 2
#define W0_POLYS 8
#define W0_SHARE_STRIDE 8192
#define W0_POLYVEC w0_polyvec_shares

  /* Masked gadgets use x2 for stack frames; init it once on entry. */
  la x2, mask_stack_end
  /* External-mu mode (FIPS 204 Algorithm 7, ML-DSA.Sign_internal):
   * caller pre-hashes the message and provides mu in dmem[mu].  The
   * msg/ctx buffers and the initial SHAKE-256 over tr||ctxlen||ctx||msg
   * are gone -- saves ~2.4 KiB DMEM and one Keccak invocation. */

  /* rho' = SHAKE256(K || rnd || mu) (64 B).  K is masked as two Boolean
   * shares; rnd and mu are unmasked, so their second share is zero. */

  /* Initialize a SHAKE256 operation. */
  addi  x11, x0, SEEDBYTES
  addi  x11, x11, RNDBYTES
  addi  x11, x11, CRHBYTES
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  /* Set masked-digest bit (bit 20) of kmac_cfg so K stays shared
   * across the SHAKE256 and rho' is produced as 2 shares. */
  addi  x6, x0, 1
  slli  x6, x6, 20
  add   x5, x5, x6
  csrrw x0, KECCAK_CFG_REG, x5

  /* Refresh and absorb the Boolean shares of K. */
  la      x5, K_shares
  bn.wsrr w2, urnd
  bn.xor  w0, w0, w0            /* Whitening */
  bn.lid  x0, 0(x5)
  bn.xor  w0, w0, w2
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0            /* Whitening */
  bn.lid  x0, 32(x5)
  bn.xor  w0, w0, w2
  bn.wsrw kmac_msg1, w0

  /* Send rnd as (rnd, 0): public input trivially shared on share 0. */
  la     x5, rnd
  bn.lid x0, 0(x5)
  bn.wsrw kmac_msg, w0
  bn.xor w0, w0, w0             /* share 1 = 0 */
  bn.wsrw kmac_msg1, w0

  /* Send mu (64B = 2 chunks) as (mu, 0). */
  la     x5, mu
  bn.lid x0, 0(x5)
  bn.wsrw kmac_msg, w0
  bn.xor w0, w0, w0             /* share 1 = 0 */
  bn.wsrw kmac_msg1, w0
  la     x5, mu
  bn.lid x0, 32(x5)
  bn.wsrw kmac_msg, w0
  bn.xor w0, w0, w0             /* share 1 = 0 */
  bn.wsrw kmac_msg1, w0

  /* Read 64B masked digest into sign_gamma1_buf[0..127] in the
   * share-major chunked layout that masked_poly_uniform_gamma_1
   * expects: share 0 chunks at [0,32], share 1 chunks at [64,96]. */
  la      x10, sign_gamma1_buf
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x10)
  bn.xor  w0, w0, w0             /* Whitening */
  bn.wsrr w0, kmac_digest1
  bn.sid  x0, 64(x10)
  bn.xor  w0, w0, w0             /* Whitening */
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 32(x10)
  bn.xor  w0, w0, w0             /* Whitening */
  bn.wsrr w0, kmac_digest1
  bn.sid  x0, 96(x10)

  /* Finish the SHAKE-256 operation. */

  /* Prepare modulus */
  #define mod_x2 w22
  bn.wsrr   w16, 0x0 /* w16 = MOD = R | Q */
  bn.shv.8s mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

  li x27, 0 /* nonce */

  jal  x1, sign_attempt
  ret

/**
 * sign_attempt
 *
 * Rejection-retry body.  Computes w, w0/w1 + c~, c,
 * z (z-loop), h (hint loop), z pack; restarts in place on rejection.
 * Inputs are taken from caller-set state (sign_gamma1_buf, sk, etc.); on
 * success returns x10 = 0, x11 = CRYPTO_BYTES.
 */
.globl sign_attempt
.type sign_attempt, @function
sign_attempt:
  /* sign_w params: w_out, rho, rho_prime, y_staging, A_staging,
   * seca2b_scratch, gamma1_buf.  A_staging + gamma1_buf live in
   * dead sig during P1; c_poly (= NTT(c) post-P1) is now in overlay slack. */
  la   x10, W0_POLYVEC
  la   x11, sk                        /* rho is sk[0..32) */
  la   x12, sign_gamma1_buf
  la   x13, sign_y
  la   x14, sig                       /* A_staging at sig+1536 (after gamma1 buf) */
  addi x14, x14, 1536
  la   x15, sig                       /* seca2b scratch at sig+2560 */
  addi x15, x15, 1024
  addi x15, x15, 1536
  la   x16, sig                       /* gamma1 bitslice buf at sig+0 */
  jal  x1, sign_w

  /* sign_w0_w1_ctilde params: w_polyvec, mu, w1_repvec, sig,
   * w1_tmp_scratch, seca2b_scratch (sig+2560, same as in sign_w). */
  la   x10, W0_POLYVEC
  la   x11, mu
  la   x12, sign_w1_repvec
  la   x13, sig
  la   x14, sign_tmp
  la   x15, sig
  addi x15, x15, 1024
  addi x15, x15, 1536
  jal  x1, sign_w0_w1_ctilde

  la   x10, c_poly                    /* ntt_c output */
  la   x11, sign_tmp                /* aligned c~ stash */
  jal  x1, sign_c

  la   x11, c_poly
  la   x12, sign_gamma1_buf
  la   x14, sign_c_poly_shares
  la   x15, sign_tmp
  la   x16, sign_y
  la   x17, sign_hint_b2a
  jal  x1, sign_z_check
  bne  x10, x0, sign_attempt

  la   x10, sk
  addi x10, x10, 128
  la   x12, c_poly
  la   x13, W0_POLYVEC
  la   x14, sign_w1_repvec
  jal  x1, sign_h_check
  bne  x10, x0, sign_attempt

  /* Every r-tilde check passed: unmask r-tilde and emit the hints. */
  la   x10, sk
  addi x10, x10, 128
  la   x12, c_poly
  la   x13, W0_POLYVEC
  la   x14, sign_w1_repvec
  jal  x1, sign_h
  bne  x10, x0, sign_attempt

  /* All checks passed: replay the z loop to unmask and pack z. */
  la   x11, c_poly
  la   x12, sign_gamma1_buf
  la   x13, sig
  la   x5, mldsa_params
  lw   x5, MLDSA_PARAM_K_OFFSET(x5)
  slli x5, x5, 3                     /* CTILDEBYTES = K * 8 */
  add  x13, x13, x5
  la   x14, sign_c_poly_shares
  la   x15, sign_tmp
  la   x16, sign_y
  la   x17, sign_hint_b2a
  jal  x1, sign_z_pack

  li   x10, 0
  la   x5, mldsa_params
  lw   x11, MLDSA_PARAM_CRYPTO_BYTES_OFFSET(x5)
  ret

/**
 * sign_w
 *
 * Matrix-vector multiplication w = A * y.  Column-wise loop over
 * j in [0, L): sample y[j] both shares via gamma1, NTT each share in place,
 * then for each i in [0, K): generate A[i][j] from rho and accumulate
 * A[i][j] * NTT(y[j])[d] into w[i][d].  Inverse-NTT w at the end.
 *
 * @param[out] x10: dptr_w, NSHARES * K * 1024 B accumulator (W0_POLYVEC).
 * @param[in]  x11: dptr_rho, 32 B (sk[0..32)).
 * @param[in]  x12: dptr_rho_prime, 128 B rho' seed (sign_gamma1_buf).
 * @param[in]  x13: dptr_y_staging, 2 KiB (y[j] both shares).
 * @param[in]  x14: dptr_A_staging, 1 KiB.
 * @param[in]  x15: dptr_seca2b_scratch, 1.5 KiB (forwarded to gamma1's b2a).
 * @param[in]  x16: dptr_gamma1_buf, 1.5 KiB bitslice-u staging.
 *
 * In/out: advances the nonce counter in x27 by L (each gamma1 call uses
 * it).  Restores MOD = R|Q.
 */
.globl sign_w
.type sign_w, @function
sign_w:
  /* Park pointer args in s-regs so internal jals can clobber a-regs. */
  addi x9, x10, 0           /* w_out */
  addi x8, x11, 0           /* rho */
  addi x25, x12, 0           /* rho_prime */
  addi x19, x13, 0           /* y_staging */
  addi x26, x14, 0          /* A_staging */
  addi x18, x15, 0           /* seca2b_scratch (was: rhoprime slot) */
  addi x23, x16, 0           /* gamma1_buf (was: gamma1_vec_const slot) */

  /* Zero each share's polyvec; t1 walks the contiguous buffer. */
  li x5, 31
  addi x6, x9, 0
  .rept NSHARES
  loopi W0_POLYS, 3
    loopi 32, 1
      bn.sid x5, 0(x6++)
    endloop
    nop
  endloop
  .endr

  /* Per-column constants. */
  li x22, W0_SHARE_STRIDE           /* stride between w shares */
  bn.xor w23, w23, w23             /* matrix nonce = byte(i) || byte(j) */

  /* SHAKE128 cfg for poly_uniform (rho||i||j). */
  addi x20, x0, 34
  slli x20, x20, 5
  addi x20, x20, SHAKE128_CFG

  la   x5, mldsa_params
  lw   x5, MLDSA_PARAM_L_OFFSET(x5)
  loop x5, 94
    addi x10, x19, 0
    addi x11, x25, 0
    addi x12, x27, 0
    addi x13, x18, 0
    addi x14, x23, 0
    /* gamma_1 dispatches on x15 (2 => POLYZ_BITS = 18 for ML-DSA-44, else 20);
     * gamma2 == 95232 selects ML-DSA-44. */
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_GAMMA2_OFFSET(x5)
    li   x6, 95232
    li   x15, 2
    beq  x5, x6, _sign_w_gamma1_a_5
    li   x15, 3
_sign_w_gamma1_a_5:
    jal  x1, masked_poly_uniform_gamma_1
    addi x27, x27, 1

    /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
    csrrw x0, kmac_cfg, x20
    addi  x10, x8, 0
    bn.lid    x0, 0(x10)
    bn.wsrw   kmac_msg, w0
    addi      x5, x0, 2
    csrrw     x0, kmac_partial_write, x5
    bn.wsrw   kmac_msg, w23
    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* Stage forward twiddles once per column; both shares reuse them. */
    jal  x1, gen_twiddles_fwd
    /* NTT each share of y[j] in place. */
    addi x24, x19, 0
    li   x30, NSHARES
    loop x30, 34
      la   x11, scratch
      addi x10, x24, 0
      addi x12, x24, 0
      jal  x1, ntt
      addi x24, x24, 1024
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
    endloop
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_K_OFFSET(x5)
    loop x5, 23
      /* Compute A[i][j]. */
      addi x11, x26, 0
      jal  x1, poly_uniform
      /* Increment the row index by 1. */
      bn.addi w23, w23, 256
      /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
      csrrw x0, kmac_cfg, x20
      addi  x10, x8, 0
      bn.lid    x0, 0(x10)
      bn.wsrw   kmac_msg, w0
      addi      x5, x0, 2
      csrrw     x0, kmac_partial_write, x5
      bn.wsrw   kmac_msg, w23
      /* For each share d:  w_d[i] += A[i][j] * y_d[j]. */
      addi x24, x19, 0
      addi x21, x9, 0
      li   x30, NSHARES
      loop x30, 8
        addi x10, x24, 0
        addi x11, x26, 0
        addi x12, x21, 0
        jal  x1, poly_pointwise_acc
        addi x24, x24, 1024
        add  x21, x21, x22
        /* Whitening */
        bn.xor w0, w0, w0
        bn.xor w1, w1, w1
      endloop
      addi x9, x9, 1024
    endloop
    /* Reset w pointer for next column. */
    la   x9, W0_POLYVEC
    /* Increment the column index in the nonce by one. */
    bn.addi w23, w23, 1
    /* Reset the row index in the nonce to zero. */
    bn.rshi w23, w23, w31 >> 8
    bn.rshi w23, w31, w23 >> 248
    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */
  endloop

  bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
  /* Stage inverse twiddles once; all NSHARES*K transforms reuse them. */
  jal x1, _inv_transform
  /* Inverse NTT each share's K polys; shares are W0_SHARE_STRIDE apart. */
  la  x9, W0_POLYVEC
  loopi NSHARES, 39
    addi x10, x9, 0
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_K_OFFSET(x5)
    loop x5, 4
      la  x11, scratch
      jal x1, intt
      addi x10, x10, 1024
    endloop
    li  x5, W0_SHARE_STRIDE
    add x9, x9, x5
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
  endloop

  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */
  ret

/**
 * sign_w0_w1_ctilde
 *
 * Decompose w and derive c~, over K polys.
 *
 *     (w1[i], b'[i]) = Decompose(w[i])      (b' overlays w in place)
 *     c~ = SHAKE256(mu || polyw1_pack(w1))
 *
 * w1's nonzero positions are recorded in w1_repvec.  c~ is written to
 * sig[0..CTILDEBYTES) and, 32-byte aligned, to `sign_tmp` for sign_c.
 *
 * @param[inout]   x10: dptr_w_polyvec.  Read as w (NSHARES*K*1024 B); the
 *                      K decompose iters overlay it in place with packed b'
 *                      (K*608 B per share at stride W0_SHARE_STRIDE).
 * @param[in]      x11: dptr_mu, 64 B (caller's mu).
 * @param[out]     x12: dptr_w1_repvec, K*32 B nonzero-summary of each w1[i].
 * @param[out]     x13: dptr_sig_ctilde, CTILDEBYTES at sig[0..).  Also
 *                      serves as decompose's scratch base (+16 for L3
 *                      alignment).
 * @param[scratch] x14: dptr_w1_tmp, 1 KiB temporary for decompose's w1
 *                      output and Keccak interim.
 * @param[scratch] x15: dptr_seca2b_scratch, 1.5 KiB (decompose internal).
 */
.globl sign_w0_w1_ctilde
.type sign_w0_w1_ctilde, @function
sign_w0_w1_ctilde:
  /* Park pointer args.  x23 holds mu just long enough for the
   * keccak_send_message; the K-loop later overwrites it with NSHARES. */
  addi x8, x10, 0            /* w polyvec walker */
  addi x23, x11, 0            /* mu (consumed below) */
  addi x9, x12, 0            /* sign_w1_repvec walker */
  addi x19, x13, 0            /* sig (for c~ writes) */
  addi x18, x13, 0            /* decompose scratch base (sig, 32B aligned) */
  addi x20, x14, 0            /* w1 tmp scratch */
  addi x21, x15, 0            /* seca2b scratch */

  /* Initialize a SHAKE256 operation. */
  addi  x11, x0, CRHBYTES
  la    x5, mldsa_params
  lw    x7, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x5)
  lw    x5, MLDSA_PARAM_K_OFFSET(x5)
  loop  x5, 1
    add x11, x11, x7
  endloop
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send mu (parked in x23). */
  li   x11, CRHBYTES
  addi x10, x23, 0
  jal  x1, keccak_send_message
  li   x22, W0_SHARE_STRIDE  /* stride between w_in / packed b' shares */

  /* Masked path: per poly, secdecompose produces an unmasked w1 (in
   * sign_tmp) and updates share 0 of w0 in place.  The K outer loop is
   * bne-based (not loopi) so it does not consume an ACC hardware loop-
   * stack slot -- secdecompose's call chain already uses every available
   * level. */
  li   x23, NSHARES
  la   x5, mldsa_params
  lw   x24, MLDSA_PARAM_K_OFFSET(x5)
  /* Packed b' poly i: share 0 at i*608, share 1 at W0_SHARE_STRIDE +
   * i*608.  Per-poly stride 608 < input stride 1024, so dumps stay
   * in the consumed slot of their own share. */
  addi x25, x8, 0
_decompose_loop:
  addi   x10, x20, 0
  addi   x11, x8, 0
  addi   x14, x22, 0
  /* secdecompose dispatches on x12 (2 = L2, else L35); set it + the matching
   * scratch off gamma2 (L2 = 95232). */
  la     x5, mldsa_params
  lw     x5, MLDSA_PARAM_GAMMA2_OFFSET(x5)
  li     x6, 95232
  bne    x5, x6, _decompose_l35
  la     x13, sign_w0_l2_seccompress_scratch
  la     x15, sign_w0_l2_b
  la     x16, sign_w0_l2_t_packed
  li     x12, 2
  jal x0, _decompose_call
_decompose_l35:
  addi   x13, x18, 0
  addi   x15, x25, 0
  add    x16, x25, x22
  addi   x17, x21, 0
  li     x12, 3
_decompose_call:
  jal    x1, secdecompose
  /* Pack w1, send to Keccak, record nonzero bits.  Runtime polyw1_pack
   * dispatches on x14 = K (selects the (Q-1)/88 vs (Q-1)/32 packing);
   * secdecompose clobbered x14, so reload it. */
  addi   x10, x18, 0
  addi   x11, x20, 0
  la     x5, mldsa_params
  lw     x14, MLDSA_PARAM_K_OFFSET(x5)
  jal    x1, polyw1_pack
  addi   x10, x18, 0
  la     x5, mldsa_params
  lw     x11, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x5)
  jal    x1, keccak_send_message
  addi   x10, x20, 0
  jal    x1, poly_nonzero_encode
  bn.sid x0, 0(x9++)
  addi   x8, x8, 1024
  addi   x25, x25, 608
  addi   x24, x24, -1
  bne    x24, x0, _decompose_loop

  /* Setup WDR */
  li x6, 8

  /* Read first 32 bytes of digest. */
  bn.wsrr w8, kmac_digest

  /* Get always-aligned temporary buffer. */
  la   x5, sign_tmp
  /* c~ layout depends on CTILDEBYTES (= K*8): 32 (K=4), 48 (K=6), 64 (K=8). */
  la   x28, mldsa_params
  lw   x28, MLDSA_PARAM_K_OFFSET(x28)
  li   x29, 4
  beq  x28, x29, _sign_pack_ctilde_44
  li   x29, 6
  beq  x28, x29, _sign_pack_ctilde_65
  /* ML-DSA-87 (K=8, CTILDEBYTES=64). */
  bn.sid  x6, 0(x5)
  bn.sid  x6, 0(x19)
  bn.wsrr w8, kmac_digest
  bn.sid  x6, 32(x5)
  bn.sid  x6, 32(x19)
  jal x0, _sign_pack_ctilde_done
_sign_pack_ctilde_44:
  /* ML-DSA-44 (K=4, CTILDEBYTES=32). */
  bn.sid  x6, 0(x5)
  bn.sid  x6, 0(x19)
  jal x0, _sign_pack_ctilde_done
_sign_pack_ctilde_65:
  /* ML-DSA-65 (K=6, CTILDEBYTES=48); signature unaligned, copy via GPRs. */
  bn.sid  x6, 0(x5)
  loopi 8, 4
    lw x7, 0(x5)
    sw x7, 0(x19)
    addi x5, x5, 4
    addi x19, x19, 4
  endloop
  bn.wsrr w8, kmac_digest
  bn.sid  x6, 0(x5)
  loopi 4, 4
    lw x7, 0(x5)
    sw x7, 0(x19)
    addi x5, x5, 4
    addi x19, x19, 4
  endloop
_sign_pack_ctilde_done:

  /* Finish the SHAKE-256 operation. */
  ret

/**
 * sign_c
 *
 * Sample challenge c from c~ (poly_challenge); NTT(c) in place.
 *
 * @param[out] x10: dptr_ntt_c, 1024 B buffer for NTT(c).
 * @param[in]  x11: dptr_ctilde, 32-byte aligned source of c~.
 *
 * Restores MOD = R|Q.
 */
.globl sign_c
.type sign_c, @function
sign_c:
  addi x8, x10, 0            /* park ntt_c_out across poly_challenge */
  /* Runtime poly_challenge takes x12 = CTILDEBYTES (= K*8), x13 = TAU; x10/x11
   * (output, c~) are already set by the caller. */
  la   x5, mldsa_params
  lw   x6, MLDSA_PARAM_K_OFFSET(x5)
  slli x12, x6, 3
  lw   x13, MLDSA_PARAM_TAU_OFFSET(x5)
  jal  x1, poly_challenge

  bn.wsrw 0x0, mod_x2
  jal  x1, gen_twiddles_fwd
  addi x10, x8, 0
  addi x12, x10, 0
  la   x11, scratch
  jal  x1, ntt
  bn.wsrw 0x0, w16
  ret

/**
 * sign_z_check / sign_z_pack
 *
 * Compute z = y + c * s1.  Loops over L polys: unpack/b2a
 * s1, NTT chain c*s1, sample y (gamma1), z = y + c*s1.  sign_z_check
 * bound-checks z and leaves it masked; sign_z_pack packs it to
 * sig[CTILDE..CTILDE+L*POLYZ_PACKEDBYTES).
 *
 * @param[in]      x11: dptr_ntt_c, 1 KiB.
 * @param[in]      x12: dptr_rho_prime, 128 B.
 * @param[in]      x13: dptr_sig_z_start (sig + CTILDEBYTES), sign_z_pack only.
 * @param[scratch] x14: dptr_z_staging, 3.3 KiB (sign_c_poly_shares-sized).
 * @param[scratch] x15: dptr_tmp_poly, 1 KiB (polyeta_unpack tgt + collapsed z).
 * @param[scratch] x16: dptr_cs1_share1, 1 KiB (also secb2amodq_eta/secboundcheck
 *                      bitslice buf).
 * @param[scratch] x17: dptr_seca2b_scratch, 3.3 KiB (forwarded to inner gadgets;
 *                      L5 also takes its +1536 as gamma1 staging).
 *
 * In/out: reads x27 (= nonce counter advanced by sign_w); uses
 * x27 - L as the per-iter gamma1 nonce base.
 * Returns x10 = 0 on success, x10 = 1 on rejection.
 */
/**
 * _masked_eta_from_shares
 *
 * Load one s1/s2 poly from the expanded sk: refresh the stored Boolean
 * bitsliced t-shares (t = eta - s) in place, B2A to arithmetic, coeff = eta - t.
 * Runtime ETA_KBITS = eta/2 + 2; POLYETA_PACKEDBYTES = ETA_KBITS * 32.
 *
 * @param[in]  x10: out (2 * 1024 B).
 * @param[in]  x11: src bitsliced shares (share 0 @ +0, share 1 @ +POLYETA).
 * @param[in]  x12: seca2b scratch.
 * @param[in]  x13: b2a Boolean buffer.
 */
_masked_eta_from_shares:
  addi x2, x2, -32
  sw   x1, 0(x2)
  sw   x10, 4(x2)
  sw   x11, 8(x2)
  sw   x12, 12(x2)
  sw   x13, 16(x2)

  la   x28, eta
  lw   x28, 0(x28)
  srli x28, x28, 1
  addi x28, x28, 2               /* x28 = ETA_KBITS (3 or 4) */
  slli x29, x28, 5              /* x29 = POLYETA_PACKEDBYTES (96 or 128) */

  /* Refresh shares. */
  addi x5, x11, 0
  add  x6, x11, x29
  li   x7, 0
  loop x28, 9
    bn.wsrr w2, urnd
    bn.xor  w0, w0, w0            /* Whitening */
    bn.lid  x7, 0(x5)
    bn.xor  w0, w0, w2
    bn.sid  x7, 0(x5++)
    bn.xor  w0, w0, w0            /* Whitening */
    bn.lid  x7, 0(x6)
    bn.xor  w0, w0, w2
    bn.sid  x7, 0(x6++)
  endloop

  /* B2A(t, ETA_KBITS): out receives arith shares of t. */
  lw   x10, 4(x2)
  lw   x11, 8(x2)
  add  x12, x11, x29
  addi x13, x28, 0
  lw   x14, 12(x2)
  lw   x15, 16(x2)
  jal  x1, secb2amodq_eta

  /* coeff = eta - t: share 0 = eta - t0, share 1 = -t1 (mod q). */
  la     x5, eta
  li     x6, 4
  bn.lid x6, 0(x5)
  lw   x10, 4(x2)
  li   x5, 0
  addi x6, x10, 0
  loopi 32, 3
    bn.lid x5, 0(x6)
    bn.subvm.8s w0, w4, w0
    bn.sid x5, 0(x6++)
  endloop
  bn.xor w0, w0, w0
  lw   x10, 4(x2)
  addi x6, x10, 1024
  loopi 32, 3
    bn.lid x5, 0(x6)
    bn.subvm.8s w0, w31, w0
    bn.sid x5, 0(x6++)
  endloop

  lw   x1, 0(x2)
  addi x2, x2, 32
  ret

/* Pass selector for the split check/unmask loops below. */
.equ CHECK,  0x3c9
.equ UNMASK, 0x65e

/**
 * sign_z_check / sign_z_pack
 *
 * Per-poly z computation over L polys.
 *
 *     z[j] = c*s1[j] + y[j]        (y[j] sampled via gamma1)
 *
 * sign_z_check bound-checks z and leaves it masked; sign_z_pack unmasks it
 * and polyz_packs it into the signature.
 *
 * @param[in]  x11: dptr_ntt_c, 1 KiB.
 * @param[in]  x12: dptr_rho_prime, rho' seed for gamma1.
 * @param[in]  x13: dptr_sig_z, z write pointer (sign_z_pack only).
 * @param[in]  x14: dptr_z_staging, z[j] both shares.
 * @param[in]  x15: dptr_tmp_poly.
 * @param[in]  x16: dptr_cs1_share1, c*s1 share 1 plus bitslice buffer.
 * @param[in]  x17: dptr_seca2b_scratch; gamma1 staging sits at +1536.
 * @param[in]  x27: gamma1 nonce counter, read only (the loop runs from
 *                  x27 - L up to x27).
 *
 * s1 is loaded from `s1s2_shares` in-loop.
 *
 * Returns x10 = 0 on success, x10 = 1 on rejection.
 */
.globl sign_z_pack
.type sign_z_pack, @function
sign_z_pack:
  addi x21, x0, UNMASK
  addi x25, x13, 0            /* sig_z write ptr (advances per polyz_pack) */
  beq  x0, x0, _sign_z_park

.globl sign_z_check
.type sign_z_check, @function
sign_z_check:
  addi x21, x0, CHECK
_sign_z_park:
  /* Park pointer args. */
  li   x8, 0                /* ExpandS nonce: s1[j] uses nonce j */
  addi x23, x11, 0            /* NTT(c) */
  addi x20, x12, 0            /* rho_prime (gamma1 seed) */
  addi x22, x14, 0            /* z staging */
  addi x18, x15, 0            /* sign_tmp */
  addi x19, x16, 0            /* c*s1 share 1 + bitslice buf */
  addi x26, x17, 0           /* seca2b scratch (eta/gamma1/boundcheck) */

  /* Per-iter gamma1 nonce starts at x27 - L (sign_w advanced x27 by L);
   * the loop runs until x24 climbs back to x27 (L iterations). */
  la   x5, mldsa_params
  lw   x5, MLDSA_PARAM_L_OFFSET(x5)
  sub  x24, x27, x5

  /* This loop computes z = (cp * s1) = y one element at a time, and does
     rejection sampling on each element before packing it into the signature. */
_sign_z_loop:
    /* Load s1[j] from the expanded sk (poly index j = nonce s0);
     * offset = j * 2*POLYETA (256 for K=6, else 192). */
    addi x10, x22, 0
    la   x11, s1s2_shares
    la   x7, mldsa_params
    lw   x5, MLDSA_PARAM_K_OFFSET(x7)
    li   x6, 6
    beq  x5, x6, _sz_k6
    slli x5, x8, 7
    slli x6, x8, 6
    add  x5, x5, x6
    beq  x0, x0, _sz_done
_sz_k6:
    slli x5, x8, 8
_sz_done:
    add  x11, x11, x5
    la   x12, sign_hint_b2a
    la   x13, sign_y
    jal  x1, _masked_eta_from_shares
    addi x8, x8, 1

    /* gadget's b2a clobbered w16/w22; rebuild from MOD (still R|Q). */
    bn.wsrr   w16, 0x0

    bn.shv.8s mod_x2, w16 << 1

    /* c*s1 share 0 at x18 (sign_tmp), share 1 at x19; delta in x28
     * (survives ntt/intt/poly_pointwise; x5 to x7 don't). */
    bn.wsrw 0x0, mod_x2
    addi x9, x22, 0
    addi x31, x18, 0
    sub  x28, x19, x18
    li   x5, NSHARES
    loop x5, 45
      addi x10, x9, 0
      addi x12, x31, 0
      jal  x1, gen_twiddles_fwd
      la   x11, scratch
      jal  x1, ntt
      addi x10, x31, 0
      addi x11, x23, 0
      addi x12, x31, 0
      jal  x1, poly_pointwise
      jal  x1, _inv_transform
      addi x10, x31, 0
      la   x11, scratch
      jal  x1, intt
      addi x9, x9, 1024
      add  x31, x31, x28
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
    endloop
    bn.wsrw 0x0, w16

    /* Sample y -> z_staging (overwrites bitsliced s1, now consumed). */
    addi x10, x22, 0
    addi x11, x20, 0
    addi x12, x24, 0
    addi x13, x26, 0           /* seca2b scratch */
    /* hint_b2a region is L5-sized (8192 B) for both params; gamma1
     * staging fits at scratch+1536. */
    addi x14, x26, 1536
    /* gamma_1 dispatches on x15 (2 => POLYZ_BITS = 18 for ML-DSA-44, else 20);
     * gamma2 == 95232 selects ML-DSA-44. */
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_GAMMA2_OFFSET(x5)
    li   x6, 95232
    li   x15, 2
    beq  x5, x6, _sign_z_gamma1_a_5
    li   x15, 3
_sign_z_gamma1_a_5:
    jal  x1, masked_poly_uniform_gamma_1
    addi x24, x24, 1

    /* z = y + c*s1 per share; same x18 / x19 split as NTT. */
    addi x9, x22, 0
    addi x31, x18, 0
    sub  x28, x19, x18
    li   x5, NSHARES
    loop x5, 8
      addi x10, x9, 0
      addi x11, x31, 0
      addi x12, x9, 0
      jal  x1, poly_add
      addi x9, x9, 1024
      add  x31, x31, x28
      /* Whitening */
      bn.xor w0, w0, w0
      bn.xor w1, w1, w1
    endloop

    /* Reduce z to unsigned canonical [0, q). */
    addi x5, x22, 0
    li   x6, 0
    li   x7, NSHARES
    loop x7, 5
      loopi 32, 3
        bn.lid x6, 0(x5)
        bn.addvm.8s w0, w0, w31
        bn.sid x6, 0(x5++)
      endloop
      bn.xor w0, w0, w0          /* Whitening */
    endloop

    addi x5, x0, UNMASK
    beq  x21, x5, _sign_z_pack_poly

    /* secboundcheck on shared z, then AND-reduce the per-lane mask
     * to a 1-bit verdict; retry on fail. */
    /* Load C_Z into w17 lane 0 (gadget broadcasts lane 0 internally). */
    li     x5, 17
    la     x6, c_z_const
    bn.lid x5, 0(x6)
    addi x10, x22, 0
    la   x12, lambda0_z_vec
    addi x13, x26, 0           /* seca2b scratch */
    addi x14, x19, 0            /* boundcheck bitslice buf */
    jal  x1, secboundcheck

    bn.not w0, w0
    bn.cmp w0, w31
    csrrs x12, FG0, x0
    andi x12, x12, 8
    xori x12, x12, 8
    /* Reject if ||z|| >= gamma1 - beta on any lane. */
    bne  x12, x0, _sign_z_reject
    beq  x0, x0, _sign_z_next

_sign_z_pack_poly:
    addi x10, x18, 0
    addi x11, x22, 0
    jal  x1, secunmask_modq

    /* Reduce collapsed z to mod^{+-} for polyz_pack. */
    addi x10, x18, 0
    addi x11, x18, 0
    jal  x1, poly_reduce32

    /* Pack z[i] in place (aligned x18), then GPR-copy to the sig z-region
     * (unaligned for K=6). Runtime polyz_pack takes x14 = K. */
    addi x10, x18, 0
    addi x11, x18, 0
    la   x5, mldsa_params
    lw   x14, MLDSA_PARAM_K_OFFSET(x5)
    jal x1, polyz_pack
    sub  x5, x10, x18
    srli x5, x5, 2
    addi x11, x18, 0
    loop x5, 4
      lw   x6, 0(x11)
      sw   x6, 0(x25)
      addi x11, x11, 4
      addi x25, x25, 4
    endloop
_sign_z_next:
    /* L iterations: loop until the gamma1 nonce x24 reaches x27. */
    bne  x24, x27, _sign_z_loop

  li   x10, 0
  ret
_sign_z_reject:
  li   x10, 1
  ret

/**
 * sign_h_check / sign_h
 *
 * Per-poly hint computation over K polys.
 *
 *     r~[i] = w0[i] - c*s2[i]      (w0[i] unpacked from the packed b')
 *
 * sign_h_check bound-checks r~ and leaves it masked; sign_h unmasks it,
 * combines with c*t0, and runs poly_make_hint / encode_h into the sig tail.
 *
 * @param[in]  x10: dptr_sk_t0, K * POLYT0_PACKEDBYTES (packed t0).
 * @param[in]  x12: dptr_ntt_c, 1 KiB.
 * @param[in]  x13: dptr_packed_b (post-decompose b' share 0 base; share 1 at +W0_SHARE_STRIDE).
 * @param[in]  x14: dptr_w1_repvec, K * 32 B (nonzero summary written by sign_w0_w1_ctilde).
 *
 * s2 is loaded from `s1s2_shares` in-loop.
 *
 * Scratch: sign_c_poly_shares, sign_hint_b2a, sign_y, sign_tmp.
 *
 * Returns x10 = 0 on success, x10 = 1 on rejection.
 */
.globl sign_h_check
.type sign_h_check, @function
sign_h_check:
  addi x22, x0, CHECK
  beq  x0, x0, _sign_h_park

.globl sign_h
.type sign_h, @function
sign_h:
  addi x22, x0, UNMASK
_sign_h_park:
  /* Park pointer args; preserve x27 (nonce counter) for sign_z's retry. */
  addi x8, x10, 0            /* sk t0 walker */
  la   x18, mldsa_params     /* ExpandS nonce: s2[i] uses nonce L+i */
  lw   x18, MLDSA_PARAM_L_OFFSET(x18)
  addi x23, x12, 0            /* NTT(c) */
  addi x19, x13, 0            /* packed b' walker */
  addi x21, x14, 0            /* sign_w1_repvec walker */

  /* Zero the hint region (sig + CRYPTO_BYTES - (OMEGA + K), length
     OMEGA + K), rounded up to a word. */
  la    x5, mldsa_params
  lw    x6, MLDSA_PARAM_OMEGA_OFFSET(x5)
  lw    x7, MLDSA_PARAM_K_OFFSET(x5)
  add   x6, x6, x7
  lw    x25, MLDSA_PARAM_CRYPTO_BYTES_OFFSET(x5)
  sub   x25, x25, x6          /* sig hint write ptr */
  la    x5, sig
  add   x25, x25, x5
  addi  x10, x25, 0
  addi  x6, x6, 3
  srli  x6, x6, 2
  loop  x6, 2
    sw   x0, 0(x10)
    addi x10, x10, 4
  endloop

  la   x26, sign_tmp

  /* Initialize the coefficient sum for the hint for post-check. */
  li  x20, 0

  /* Hint loop counter. */
  la  x24, mldsa_params
  lw  x24, MLDSA_PARAM_K_OFFSET(x24)

_mldsa_sign_hint_loop:

    /* Load s2[i] from the expanded sk (poly index L+i = nonce s2);
     * offset = (L+i) * 2*POLYETA (256 for K=6, else 192). */
    la   x10, sign_c_poly_shares
    la   x11, s1s2_shares
    la   x7, mldsa_params
    lw   x5, MLDSA_PARAM_K_OFFSET(x7)
    li   x6, 6
    beq  x5, x6, _sh_k6
    slli x5, x18, 7
    slli x6, x18, 6
    add  x5, x5, x6
    beq  x0, x0, _sh_done
_sh_k6:
    slli x5, x18, 8
_sh_done:
    add  x11, x11, x5
    la   x12, sign_hint_b2a
    la   x13, sign_hint_b2a
    addi x13, x13, 1536
    jal  x1, _masked_eta_from_shares
    addi x18, x18, 1

    /* b2a chain clobbered w16/w22; rebuild from MOD (still R|Q). */
    bn.wsrr   w16, 0x0

    bn.shv.8s mod_x2, w16 << 1

    /* Per-share NTT chain in place on sign_c_poly_shares -> c*s2. */
    la   x9, sign_c_poly_shares
    li   x5, NSHARES
    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    loop x5, 45
      addi x10, x9, 0
      addi x12, x9, 0
      jal  x1, gen_twiddles_fwd
      la   x11, scratch
      jal  x1, ntt
      addi x10, x9, 0
      addi x11, x23, 0
      addi x12, x9, 0
      jal  x1, poly_pointwise
      jal  x1, _inv_transform
      addi x10, x9, 0
      la   x11, scratch
      jal  x1, intt
      addi x9, x9, 1024
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
    endloop
    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Reduce c*s2 shares to unsigned canonical [0, q). */
    la   x5, sign_c_poly_shares
    li   x6, 0
    li   x7, NSHARES
    loop x7, 5
      loopi 32, 3
        bn.lid x6, 0(x5)
        bn.addvm.8s w0, w0, w31
        bn.sid x6, 0(x5++)
      endloop
      bn.xor w0, w0, w0          /* Whitening */
    endloop

    /* r-tilde reconstruction differs by gamma2 (matching secdecompose's
     * two regimes).  L2 (gamma2=95232): r-tilde_s = w0_s - c*s2_s
     * sharewise.  L3/5: r-tilde = (gamma2 - U) - c*s2 via b2a. */
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_GAMMA2_OFFSET(x5)
    li   x6, 95232
    bne  x5, x6, _sign_h_rtilde_l35
    /* L2: r-tilde_s = w0_s - c*s2_s (mod q) sharewise.  Arithmetic w0[i]
     * lives in W0_POLYVEC (x19, shares W0_SHARE_STRIDE apart); c*s2 and the
     * r-tilde dst are in sign_c_poly_shares (shares 1024 apart). */
    la   x29, sign_c_poly_shares
    addi x30, x19, 0
    li   x7, 0
    li   x28, 2
    loopi 32, 4
      bn.lid x7, 0(x30++)
      bn.lid x28, 0(x29)
      bn.subvm.8s w0, w0, w2
      bn.sid x7, 0(x29++)
    endloop
    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w2, w2, w2
    li   x31, W0_SHARE_STRIDE
    add  x30, x19, x31
    loopi 32, 4
      bn.lid x7, 0(x30++)
      bn.lid x28, 0(x29)
      bn.subvm.8s w0, w0, w2
      bn.sid x7, 0(x29++)
    endloop
    jal x0, _sign_h_rtilde_done
_sign_h_rtilde_l35:
    /* r-tilde = (gamma2 - U) - c*s2; b2a in/out at sign_hint_b2a. */
    li   x7, 0
    li   x28, 31
    la   x5, sign_hint_b2a
    addi x6, x19, 0
    loopi 19, 2
      bn.lid x7, 0(x6++)
      bn.sid x7, 0(x5++)
    endloop
    loopi 5, 1
      bn.sid x28, 0(x5++)
    endloop
    bn.xor w0, w0, w0              /* Whitening */
    li   x6, W0_SHARE_STRIDE
    add  x6, x19, x6
    loopi 19, 2
      bn.lid x7, 0(x6++)
      bn.sid x7, 0(x5++)
    endloop
    loopi 5, 1
      bn.sid x28, 0(x5++)
    endloop

    /* gamma2-U b2a: scratch at sign_y (dead). */
    la   x11, sign_hint_b2a
    addi x10, x11, 1536
    la   x13, sign_y
    jal  x1, secb2amodq

    la   x10, sign_tmp
    la   x11, sign_hint_b2a
    addi x11, x11, 1536
    jal  x1, unbitslice

    la     x5, gamma2_vec_const
    li     x6, 1
    bn.lid x6, 0(x5)
    la     x29, sign_c_poly_shares
    la     x30, sign_tmp
    li     x7, 0
    li     x28, 2
    loopi 32, 5
      bn.lid x7, 0(x29)
      bn.lid x28, 0(x30++)
      bn.addvm.8s w0, w0, w2
      bn.subvm.8s w0, w1, w0
      bn.sid x7, 0(x29++)
    endloop

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
    la   x10, sign_tmp
    la   x11, sign_hint_b2a
    addi x11, x11, 1536
    addi x11, x11, 768
    jal  x1, unbitslice

    la     x29, sign_c_poly_shares
    addi   x29, x29, 1024
    la     x30, sign_tmp
    li     x7, 0
    li     x28, 2
    loopi 32, 5
      bn.lid x7, 0(x29)
      bn.lid x28, 0(x30++)
      bn.addvm.8s w0, w0, w2
      bn.subvm.8s w0, w31, w0
      bn.sid x7, 0(x29++)
    endloop
_sign_h_rtilde_done:

    /* b2a chain clobbered w16/w22; rebuild from MOD (still R|Q). */
    bn.wsrr   w16, 0x0
    bn.shv.8s mod_x2, w16 << 1

    addi x5, x0, UNMASK
    beq  x22, x5, _sign_h_hint_poly

    /* secboundcheck on shared r-tilde, AND-reduce verdict into x24. */
    /* Load C_R into w17 lane 0 (gadget broadcasts lane 0 internally). */
    li     x5, 17
    la     x6, c_r_const
    bn.lid x5, 0(x6)
    la   x10, sign_c_poly_shares
    la   x12, lambda0_r_vec
    la   x13, sign_hint_b2a
    la   x14, sign_y
    jal  x1, secboundcheck

    bn.not w0, w0
    bn.cmp w0, w31
    csrrs x12, FG0, x0
    andi x12, x12, 8
    xori x12, x12, 8
    /* Reject if ||rtilde|| >= gamma2 - beta on any lane. */
    bne  x12, x0, _sign_h_reject
    beq  x0, x0, _sign_h_next

_sign_h_hint_poly:
    la   x10, sign_hint_b2a
    la   x11, sign_c_poly_shares
    jal  x1, secunmask_modq

    /* Restore w16 = MOD (secunmask_modq's contract leaves low32 = q). */
    bn.wsrr w16, 0x0

    /* Unpack the next polynomial from t0. */
    addi x10, x26, 0
    addi x11, x8, 0
    jal  x1, polyt0_unpack

    /* Update the packed t0 pointer. */
    addi x8, x11, 0

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

    /* Compute ntt(t0[i]) in-place. */
    jal x1, gen_twiddles_fwd
    addi x10, x26, 0
    addi x12, x10, 0
    la  x11, scratch
    jal x1, ntt

    /* tmp = cp * t0 */
    addi x10, x26, 0
    addi x11, x23, 0
    addi x12, x26, 0
    jal  x1, poly_pointwise

    /* Inverse NTT on tmp (reuse fwd table still in scratch). */
    jal x1, _inv_transform
    addi x10, x26, 0
    la  x11, scratch
    jal x1, intt

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* w0[i] += tmp */
    la   x10, sign_hint_b2a
    addi x11, x26, 0
    addi x12, x10, 0
    jal  x1, poly_add

    /* h = reduce32(tmp) to move to mod^{+-} for bound check */
    addi x10, x26, 0
    addi x11, x26, 0
    jal  x1, poly_reduce32

    /* chknorm(h, gamma2) */
    la   x11, mldsa_params
    lw   x11, MLDSA_PARAM_GAMMA2_OFFSET(x11)
    addi x10, x26, 0
    jal  x1, poly_chknorm

    /* Reject if ||c*t0|| >= gamma2 on any lane. */
    bne x12, x0, _sign_h_reject

    /* h[i] = make_hint(w0[i], w1[i]); runtime poly_make_hint takes
     * x12 = GAMMA2. */
    addi   x10, x26, 0
    la     x11, sign_hint_b2a
    la     x12, mldsa_params
    lw     x12, MLDSA_PARAM_GAMMA2_OFFSET(x12)
    bn.lid x0, 0(x21++)
    jal    x1, poly_make_hint

    /* Update the coefficient sum accumulator (saving previous value). */
    add  x12, x20, 0
    add  x20, x20, x10

    /* If the accumulator (# nonzero coeffs in h) is > omega, reject. */
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_OMEGA_OFFSET(x5)
    sub  x5, x5, x20
    srli x5, x5, 31

    /* Reject if hint weight > omega. */
    bne x5, x0, _sign_h_reject

    /* Encode h[i] into the signature; runtime poly_encode_h takes
     * x13 = i (= K - x24) and x14 = OMEGA. */
    addi x10, x25, 0
    addi x11, x26, 0
    la   x13, mldsa_params
    lw   x13, MLDSA_PARAM_K_OFFSET(x13)
    sub  x13, x13, x24
    la   x14, mldsa_params
    lw   x14, MLDSA_PARAM_OMEGA_OFFSET(x14)
    jal  x1, poly_encode_h

_sign_h_next:
    /* Advance to next poly: L2 carries arithmetic w0 (1024 stride), L3/5
     * the packed b' (608 stride). */
    la   x5, mldsa_params
    lw   x5, MLDSA_PARAM_GAMMA2_OFFSET(x5)
    li   x6, 95232
    bne  x5, x6, _sign_h_stride_l35
    addi x19, x19, 1024
    jal x0, _sign_h_stride_done
_sign_h_stride_l35:
    addi x19, x19, 608
_sign_h_stride_done:
    /* Decrement remaining-iter count and loop while > 0. */
    addi x24, x24, -1
    bne  x24, x0, _mldsa_sign_hint_loop

  li   x10, 0
  ret
_sign_h_reject:
  li   x10, 1
  ret
#else
  /* Store pointer parameters. */
  la  x5, dptr_sig
  sw  x10, 0(x5)

  /* External mu: dmem[mu] is supplied by the caller. */

  /* Initialize a SHAKE256 operation. */
  addi  x11, x0, SEEDBYTES
  addi  x11, x11, RNDBYTES
  addi  x11, x11, CRHBYTES
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send K component of sk (sk[32:64]) to the Keccak core. */
  li   x11, SEEDBYTES /* set message length to SEEDBYTES */
  la   x10, sk
  addi x10, x10, 32
  jal x1, keccak_send_message

  /* Send rnd to the Keccak core. */
  li  x11, RNDBYTES /* set message length to RNDBYTES */
  la  x10, rnd
  jal x1, keccak_send_message

  /* Send mu to the Keccak core. */
  li  x11, CRHBYTES /* set message length to CRHBYTES */
  la  x10, mu
  jal x1, keccak_send_message

  /* Setup WDR */
  li x6, 8

  la      x10, rhoprime
  bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
  bn.sid  x6, 0(x10++) /* Store into rhoprime buffer */
  bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
  bn.sid  x6, 0(x10++) /* Store into rhoprime buffer */

  /* Finish the SHAKE-256 operation. */

  /* Prepare modulus */
  #define mod_x2 w22
  bn.wsrr   w16, 0x0 /* w16 = MOD = R | Q */
  bn.shv.8s mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

  li x27, 0 /* nonce */

_rej_crypto_sign_signature_internal:
  /* Matrix-vector multiplication */

  /* Get destination pointer. */
  la x9, w0_polyvec

  /* Initialize destination to 0. */
  li x5, 31
  addi x6, x9, 0
  la x7, mldsa_params
  lw x28, MLDSA_PARAM_K_OFFSET(x7)
  loop x28, 3
    loopi 32, 1
      bn.sid x5, 0(x6++)
    endloop
    nop
  endloop

  /* Load the constant for resetting the w pointer (K * 1024). */
  slli x22, x28, 10

  /* Initialize the nonce for matrix expansion. This value should be
       byte(i) || byte(j)
     for entry A[i][j]. */
  bn.xor w23, w23, w23

  /* Load a constant pointer to the zero wide register. */
  li x21, 31

  /* Load other pointers. */
  la   x24, y_poly
  la   x26, tmp_poly
  la   x8, sk /* rho is the first 32B of sk */
  la   x18, rhoprime

  /* Precompute the SHAKE128 configuration for poly_uniform. */
  addi  x20, x0, 34
  slli  x20, x20, 5
  addi  x20, x20, SHAKE128_CFG

  /* Compute A * y, computing the values for A and y on the fly.

     We compute column-wise so that we genearate elements of y only once; in
     pseudocode, this computation does:

       for j in 0..l-1:
         yj = ntt(y[j])
         for i in 0..k-1:
           w[i] += A[i][j] * yj
  */
  la x7, mldsa_params
  lw x28, MLDSA_PARAM_L_OFFSET(x7)
  loop x28, 46
    /* Zero the buffer for y[j]. */
    addi  x5, x24, 0
    loopi 32, 1
      bn.sid x21, 0(x5++)
    endloop
    /* Compute y[j]. */
    addi x10, x24, 0
    addi x11, x18, 0
    addi x12, x27, 0 /* y sampling nonce */
    la x7, mldsa_params
    lw x14, MLDSA_PARAM_K_OFFSET(x7)
    jal  x1, poly_uniform_gamma_1
    addi x27, x12, 1 /* x12 should be preserved after execution */
    /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
    csrrw x0, kmac_cfg, x20
    addi  x10, x8, 0
    bn.lid    x0, 0(x10)
    bn.wsrw   kmac_msg, w0
    addi      x5, x0, 2
    csrrw     x0, kmac_partial_write, x5
    bn.wsrw   kmac_msg, w23
    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* Compute ntt(y[j]). */
    addi x10, x24, 0
    addi x12, x24, 0
    jal x1, ntt
    la x7, mldsa_params
    lw x28, MLDSA_PARAM_K_OFFSET(x7)
    loop x28, 15
      /* Compute A[i][j]. */
      addi x11, x26, 0
      jal  x1, poly_uniform
      /* Increment the row index by 1. */
      bn.addi w23, w23, 256
      /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
      csrrw x0, kmac_cfg, x20
      addi  x10, x8, 0
      bn.lid    x0, 0(x10)
      bn.wsrw   kmac_msg, w0
      addi      x5, x0, 2
      csrrw     x0, kmac_partial_write, x5
      bn.wsrw   kmac_msg, w23
      addi x10, x24, 0
      addi x11, x26, 0
      addi x12, x9, 0 /* *w[i] */
      /* Add A[i][j] * y[j] to w[i]. */
      jal  x1, poly_pointwise_acc
      /* Increment the w pointer. */
      addi x9, x9, 1024
    endloop
    /* Reset w pointer. */
    sub  x9, x9, x22
    /* Increment the column index in the nonce by one. */
    bn.addi w23, w23, 1
    /* Reset the row index in the nonce to zero. */
    bn.rshi w23, w23, w31 >> 8
    bn.rshi w23, w31, w23 >> 248
    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */
  endloop

  bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
  /* Inverse NTT on w */
  la  x10, w0_polyvec

  la x7, mldsa_params
  lw x28, MLDSA_PARAM_K_OFFSET(x7)
  loop x28, 2
    jal x1, intt
    /* Go to next input polynomial */
    addi x10, x10, 1024
  endloop

  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /* Random oracle */
  /* Initialize a SHAKE256 operation. */
  addi  x11, x0, CRHBYTES
  la x7, mldsa_params
  lw x29, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x7)
  loop x28, 1
    add x11, x11, x29
  endloop
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send mu to the Keccak core. */
  li  x11, CRHBYTES /* set mu length to CRHBYTES */
  la  x10, mu
  jal x1, keccak_send_message

  /* Save some pointers for loop. */
  la  x8, w0_polyvec
  la  x9, w1_repvec
  la  x20, tmp_poly

  /* Save the signature pointer (ctilde destination). */
  la  x19, dptr_sig
  lw  x19, 0(x19)
  /* Pack w1 into c_poly: 32-byte aligned and free until poly_challenge. */
  la  x18, c_poly
  la   x5, mldsa_params
  lw   x28, MLDSA_PARAM_K_OFFSET(x5)

  /* This loop:
       - decomposes each polynomial w[i] into w0[i] and w1[i]
       - packs w1[i] and sends it to the Keccak core
       - records the nonzero high bits of w1[i] for later use

     Afterwards, the w1[i] value can be discarded, so we do not need to keep
     two w-sized polyvecs in scope at once. */
  loop x28, 19
    /* Decompose w and store w0 in-place, w1 in tmp. */
    addi   x10, x8, 0
    addi   x11, x20, 0
    addi   x12, x8, 0
    la x7, mldsa_params
    lw x14, MLDSA_PARAM_K_OFFSET(x7)
    jal    x1, poly_decompose
    /* Pack w1. */
    addi   x10, x18, 0
    addi   x11, x20, 0
    jal    x1, polyw1_pack
    /* Send packed w1 to the Keccak core. */
    addi   x10, x18, 0
    la x7, mldsa_params
    lw x11, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x7)
    jal    x1, keccak_send_message
    /* Calculate the coefficients of w1 that are nonzero mod q, and store them. */
    addi   x10, x20, 0
    jal    x1, poly_nonzero_encode
    bn.sid x0, 0(x9++)
    /* Increment w pointer. */
    addi x8, x8, 1024
  endloop

  /* Setup WDR */
  li x6, 8

  /* Read first 32 bytes of digest. */
  bn.wsrr w8, 0xA

  /* Get always-aligned temporary buffer. */
  la   x5, tmp_poly

  /* Pack ctilde into temp buffer and signature; layout depends on K. */
  la   x28, mldsa_params
  lw   x28, MLDSA_PARAM_K_OFFSET(x28)
  li   x29, 4
  beq  x28, x29, _sign_pack_ctilde_44
  li   x29, 6
  beq  x28, x29, _sign_pack_ctilde_65
  /* ML-DSA-87 (K=8, CTILDEBYTES=64). */
  bn.sid  x6, 0(x5)
  bn.sid  x6, 0(x19)
  bn.wsrr w8, 0xA
  bn.sid  x6, 32(x5)
  bn.sid  x6, 32(x19)
  jal x0, _sign_pack_ctilde_done
_sign_pack_ctilde_44:
  /* ML-DSA-44 (K=4, CTILDEBYTES=32). */
  bn.sid  x6, 0(x5)
  bn.sid  x6, 0(x19)
  jal x0, _sign_pack_ctilde_done
_sign_pack_ctilde_65:
  /* ML-DSA-65 (K=6, CTILDEBYTES=48). The signature is not aligned, so
     copy via GPRs. */
  bn.sid  x6, 0(x5)
  loopi 8, 4
    lw x7, 0(x5)
    sw x7, 0(x19)
    addi x5, x5, 4
    addi x19, x19, 4
  endloop
  bn.wsrr w8, 0xA
  bn.sid  x6, 0(x5)
  loopi 4, 4
    lw x7, 0(x5)
    sw x7, 0(x19)
    addi x5, x5, 4
    addi x19, x19, 4
  endloop
_sign_pack_ctilde_done:

  /* Finish the SHAKE-256 operation. */

  /* Challenge */
  /* CTILDE was temporarily stored in tmp_poly. Re-use here because it is aligned,
     for CTILDEBYTES = 48 as well */
  la   x10, c_poly
  la   x11, tmp_poly
  la   x5, mldsa_params
  lw   x6, MLDSA_PARAM_K_OFFSET(x5)
  slli x12, x6, 3  /* CTILDEBYTES = K * 8 */
  lw   x13, MLDSA_PARAM_TAU_OFFSET(x5)
  jal  x1, poly_challenge

  bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

  /* NTT(cp) */
  la   x10, c_poly /* Input */
  addi x12, x10, 0  /* Output inplace */
  jal  x1, ntt

  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /* Load pointer to packed s1 */
  la   x8, sk
  addi x8, x8, 128

  /* Reset the nonce for y and set up a constant for poly_uniform_gamma1. */
  la   x5, mldsa_params
  lw   x6, MLDSA_PARAM_L_OFFSET(x5)
  sub  x24, x27, x6

  /* Save some pointers. */
  la   x18, tmp_poly
  la   x19, rhoprime
  la   x23, c_poly
  la   x25, dptr_sig
  lw   x25, 0(x25)
  lw   x6, MLDSA_PARAM_K_OFFSET(x5)
  slli x6, x6, 3      /* CTILDEBYTES = K * 8 */
  add  x25, x25, x6     /* c is already packed */

  /* This loop computes z = (cp * s1) = y one element at a time, and does
     rejection sampling on each element before packing it into the signature.
     Uses a regular branch-back loop so we can bail out early on rejection. */
  li x20, 0
_rejsmpl_loop:
    /* Unpack the next polynomial from s1. */
    addi x10, x18, 0
    addi x11, x8, 0
    la x7, mldsa_params
    lw x14, MLDSA_PARAM_K_OFFSET(x7)
    jal x1, polyeta_unpack
    /* Update the packed s1 pointer. */
    addi x8, x11, 0

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

    /* Compute ntt(s1). */
    addi x10, x18, 0
    addi x12, x18, 0
    jal x1, ntt
    /* z = cp * s1 */
    addi x10, x18, 0
    addi x11, x23, 0
    addi x12, x18, 0
    jal  x1, poly_pointwise
    /* After poly_pointwise, w16 is still R | Q and MOD is still 2*R | 2*Q */

    /* Inverse NTT on z */
    addi x10, x18, 0
    jal x1, intt

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Sample the next value of y and add it to z. */
    addi x10, x18, 0
    addi x11, x19, 0
    addi x12, x24, 0
    la x7, mldsa_params
    lw x14, MLDSA_PARAM_K_OFFSET(x7)
    jal  x1, poly_uniform_gamma_1

    /* Update the nonce for y. */
    addi x24, x12, 1

    /* reduce32(z) to move to mod^{+-} for bound check */
    addi x10, x18, 0
    addi x11, x18, 0
    jal x1, poly_reduce32

    /* chknorm */
    addi x10, x18, 0
    la   x7, mldsa_params
    lw   x11, MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET(x7)
    jal x1, poly_chknorm

    bne x12, x0, _rej_crypto_sign_signature_internal

    /* Pack z[i] in place, then GPR-copy into the unaligned sig slot. */
    addi x10, x18, 0
    addi x11, x18, 0
    la x7, mldsa_params
    lw x14, MLDSA_PARAM_K_OFFSET(x7)
    jal x1, polyz_pack
    sub  x5, x10, x18   /* POLYZ_PACKEDBYTES */
    srli x5, x5, 2
    addi x11, x18, 0
    loop x5, 4
      lw   x6, 0(x11)
      sw   x6, 0(x25)
      addi x11, x11, 4
      addi x25, x25, 4
    endloop
  addi x20, x20, 1
  la x5, mldsa_params
  lw x6, MLDSA_PARAM_L_OFFSET(x5)
  bne x20, x6, _rejsmpl_loop

  /* get *sig + CTILDEBYTES + L*POLYZ_PACKEDBYTES */
  addi x10, x25, 0

  /* Set hint bytes at end of signature (length omega + k) to 0. Round to
     next word boundary. */
  lw    x6, MLDSA_PARAM_OMEGA_OFFSET(x5)
  lw    x7, MLDSA_PARAM_K_OFFSET(x5)
  add   x6, x6, x7
  addi  x6, x6, 3
  srli  x6, x6, 2
  loop  x6, 2
    sw   x0, 0(x10)
    addi x10, x10, 4
  endloop

  addi x10, x25, 0

  /* Load pointers to packed S2 and T0 within sk. */
  la   x8, sk
  lw   x6, MLDSA_PARAM_SK_S2_OFFSET_OFFSET(x5)
  add  x18, x8, x6
  lw   x6, MLDSA_PARAM_SK_T0_OFFSET_OFFSET(x5)
  add  x8, x8, x6

  /* Initialize some pointers for the loop. */
  la  x19, w0_polyvec
  la  x21, w1_repvec
  la  x23, c_poly
  la  x26, tmp_poly

  /* Initialize the coefficient sum for the hint for post-check. */
  li  x20, 0

  /* Initialize the counter for the index in the hint vector. */
  li  x22, 0

  /* Initialize the register that says whether the checks failed. */
  li  x24, 0

  /* Normalize w0 to the [0, q) range (in-place). */
  addi   x10, x19, 0
  li     x6, 1
  la     x5, modulus
  bn.lid x6, 0(x5)
  la x5, mldsa_params
  lw x6, MLDSA_PARAM_K_OFFSET(x5)
  loop x6, 6
    loopi 32, 4
      bn.lid      x0, 0(x10)
      bn.addv.8s  w0, w0, w1
      bn.addvm.8s w0, w31, w0
      bn.sid      x0, 0(x10++)
    endloop
    NOP
  endloop

  /* This loop computes the hint one element at a time, and performs
     rejection sampling. For each index i=0..k-1, it does:

       tmp = cp * s2[i]
       w0[i] -= tmp
       tmp = reduce32(w0[i])
       if not poly_chknorm(tmp, gamma - beta):
         reject
       tmp = cp * t0[i]
       h = reduce32(tmp)
       if not poly_chknorm(h, gamma):
         reject
       w0[i] += h
       if not poly_chknorm(w0[i], gamma - beta):
         reject
       make_hint(h, w0[i], w1[i]) # gets written directly into signature
   */
  la x5, mldsa_params
  lw x6, MLDSA_PARAM_K_OFFSET(x5)
  loop x6, 85
    /* If there was a failure, skip to the end of the
       loop body (because of architectural loop rules, we have to complete
       all iterations). */
    bne  x24, x0, _mldsa_sign_hint_loop_end

    /* Unpack the next polynomial from s2. */
    addi x10, x26, 0
    addi x11, x18, 0
    la x5, mldsa_params
    lw x14, MLDSA_PARAM_K_OFFSET(x5)
    jal  x1, polyeta_unpack
    addi x10, x10, -1024

    /* Update the packed s2 pointer. */
    addi x18, x11, 0

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

    /* Compute ntt(s2[i]) in-place. */
    addi x12, x10, 0
    jal x1, ntt

    /* tmp = cp * s2 */
    addi x10, x26, 0
    addi x11, x23, 0
    addi x12, x26, 0
    jal  x1, poly_pointwise

    /* Inverse NTT on tmp */
    addi x10, x26, 0
    jal x1, intt

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* w0[i] -= tmp */
    addi x10, x19, 0
    addi x11, x26, 0
    addi x12, x19, 0
    jal  x1, poly_sub

    /* tmp = reduce32(w0[i]) to move to mod^{+-} for bound check */
    addi x10, x19, 0
    addi x11, x26, 0
    jal  x1, poly_reduce32

    /* chknorm(tmp, gamma2 - beta) */
    addi x10, x26, 0
    la   x5, mldsa_params
    lw   x11, MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET(x5)
    jal  x1, poly_chknorm

    /* Update the continuation register. */
    or  x24, x24, x12

    /* Unpack the next polynomial from t0. */
    addi x10, x26, 0
    addi x11, x8, 0
    jal  x1, polyt0_unpack

    /* Update the packed t0 pointer. */
    addi x8, x11, 0

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

    /* Compute ntt(t0[i]) in-place. */
    addi x10, x26, 0
    addi x12, x10, 0
    jal x1, ntt

    /* tmp = cp * t0 */
    addi x10, x26, 0
    addi x11, x23, 0
    addi x12, x26, 0
    jal  x1, poly_pointwise

    /* Inverse NTT on tmp */
    addi x10, x26, 0
    jal x1, intt

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* w0[i] += tmp */
    addi x10, x19, 0
    addi x11, x26, 0
    addi x12, x19, 0
    jal  x1, poly_add

    /* h = reduce32(tmp) to move to mod^{+-} for bound check */
    addi x10, x26, 0
    addi x11, x26, 0
    jal  x1, poly_reduce32

    /* chknorm(h, gamma2) */
    la   x5, mldsa_params
    lw   x11, MLDSA_PARAM_GAMMA2_OFFSET(x5)
    addi x10, x26, 0
    jal  x1, poly_chknorm

    /* Update the continuation register. */
    or  x24, x24, x12

    /* h[i] = make_hint(w0[i], w1[i]) */
    addi   x10, x26, 0
    addi   x11, x19, 0
    la     x5, mldsa_params
    lw     x12, MLDSA_PARAM_GAMMA2_OFFSET(x5)
    bn.lid x0, 0(x21++)
    jal    x1, poly_make_hint

    /* Update the coefficient sum accumulator (saving previous value). */
    add  x12, x20, 0
    add  x20, x20, x10

    /* If the accumulator (# nonzero coeffs in h) is > omega, reject. */
    la   x5, mldsa_params
    lw   x6, MLDSA_PARAM_OMEGA_OFFSET(x5)
    sub  x5, x6, x20
    srli x5, x5, 31

    /* Update the continuation register. */
    or  x24, x24, x5

    /* Skip encode in case of rejection. */
    bne  x24, x0, _mldsa_sign_hint_loop_end
    /* Encode h[i] into the signature. */
    addi x10, x25, 0
    addi x11, x26, 0
    addi x13, x22, 0
    la   x5, mldsa_params
    lw   x14, MLDSA_PARAM_OMEGA_OFFSET(x5)
    jal  x1, poly_encode_h

    /* Increment i. */
    addi x22, x22, 1
    _mldsa_sign_hint_loop_end:
    /* Update pointer into w0. */
    addi x19, x19, 1024
  endloop

  /* Reject the signature if any conditions failed in the hint loop. */
  bne  x24, x0, _rej_crypto_sign_signature_internal

  /* Return success and signature length */
  li x10, 0
  la x5, mldsa_params
  lw x11, MLDSA_PARAM_CRYPTO_BYTES_OFFSET(x5)
  ret
#endif
