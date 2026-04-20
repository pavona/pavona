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

#define W0_POLYVEC w0_polyvec


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
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send K component of sk (sk[32:64]) to the Keccak core. */
    li   a1, SEEDBYTES /* set message length to SEEDBYTES */
    la   a0, sk
    addi a0, a0, 32
    jal x1, keccak_send_message

    /* Send rnd to the Keccak core. */
    li  a1, RNDBYTES /* set message length to RNDBYTES */
    la  a0, rnd
    jal x1, keccak_send_message

    /* Send mu to the Keccak core. */
    li  a1, CRHBYTES /* set message length to CRHBYTES */
    la  a0, mu
    jal x1, keccak_send_message

    /* Setup WDR */
    li t1, 8

    la      a0, rhoprime
    bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
    bn.sid  t1, 0(a0++) /* Store into rhoprime buffer */
    bn.wsrr w8, 0xA     /* KECCAK_DIGEST */
    bn.sid  t1, 0(a0++) /* Store into rhoprime buffer */

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
 * are taken from caller-set state (masked_gamma1_buf, sk, etc.); on
 * success returns a0 = 0, a1 = CRYPTO_BYTES. */
.global sign_attempt
sign_attempt:
    /* Matrix-vector multiplication */

    /* Get destination pointer. */
    la s1, W0_POLYVEC

    /* Zero each share's polyvec; t1 walks the contiguous buffer. */
    li t0, 31
    addi t1, s1, 0
    LOOPI K, 3
        LOOPI 32, 1
          bn.sid t0, 0(t1++)
        nop

    /* Load the constant for resetting the w pointer. */
    li s6, POLYVECK_BYTES

    /* Initialize the nonce for matrix expansion. This value should be
         byte(i) || byte(j)
       for entry A[i][j]. */
    bn.xor w23, w23, w23

    /* Load a constant pointer to the zero wide register. */
    li s5, 31

    /* Load a pointer to the vectorized gamma1. */
    la   s7, gamma1_vec_const

    /* Load other pointers. */
    la   s8, y_poly
    la   s10, tmp_poly
    la   s0, sk /* rho is the first 32B of sk */
    la   s2, rhoprime

    /* Precompute the SHAKE128 configuration for poly_uniform. */
    addi  s4, x0, 34
    slli  s4, s4, 5
    addi  s4, s4, SHAKE128_CFG

    /* Compute A * y, computing the values for A and y on the fly.

       We compute column-wise so that we genearate elements of y only once; in
       pseudocode, this computation does:

         for j in 0..l-1:
           yj = ntt(y[j])
           for i in 0..k-1:
             w[i] += A[i][j] * yj
    */
    loopi L, 41
        /* Zero the buffer for y[j]. */
        addi  t0, s8, 0
        loopi 32, 1
          bn.sid s5, 0(t0++)
        /* Compute y[j]. */
        addi a0, s8, 0
        addi a1, s2, 0
        addi a2, s11, 0 /* y sampling nonce */
        addi a3, s7, 0
        jal  x1, poly_uniform_gamma_1
        addi s11, a2, 1 /* a2 should be preserved after execution */
        /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
        csrrw x0, kmac_cfg, s4
        addi  a0, s0, 0
        bn.lid    x0, 0(a0)
        bn.wsrw   kmac_msg, w0
        addi      t0, x0, 2
        csrrw     x0, kmac_partial_write, t0
        bn.wsrw   kmac_msg, w23
        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
        /* Compute ntt(y[j]). */
        addi a0, s8, 0
        addi a2, s8, 0
        jal x1, ntt
        loopi K, 15
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
            addi a0, s8, 0
            addi a1, s10, 0
            addi a2, s1, 0 /* *w[i] */
            /* Add A[i][j] * y[j] to w[i]. */
            jal  x1, poly_pointwise_acc
            /* Increment the w pointer. */
            addi s1, s1, 1024
        /* Reset w pointer. */
        sub  s1, s1, s6
        /* Increment the column index in the nonce by one. */
        bn.addi w23, w23, 1
        /* Reset the row index in the nonce to zero. */
        bn.rshi w23, w23, bn0 >> 8
        bn.rshi w23, bn0, w23 >> 248
        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
    /* Inverse NTT on w. */
    la  a0, W0_POLYVEC
    LOOPI K, 2
        jal x1, intt
        addi a0, a0, 1024

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */


    /* Random oracle */
    /* Initialize a SHAKE256 operation. */
    addi  a1, x0, CRHBYTES
    LOOPI K, 1
        addi a1, a1, POLYW1_PACKEDBYTES
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw x0, KECCAK_CFG_REG, t0

    /* Send mu to the Keccak core. */
    li  a1, CRHBYTES /* set mu length to CRHBYTES */
    la  a0, mu
    jal x1, keccak_send_message

    /* Save some pointers for loop. */
    la  s0, W0_POLYVEC
    la  s1, w1_repvec
    la  s4, tmp_poly

    /* Get the pointer to the signature (used as tmp buffer for packed w1). */
    la  s2, sig
    addi s3, s2, 0 /* Save *sig. */
#if CTILDEBYTES == 48
    /* Use an offset of 16 to get an aligned buffer (alignment hack for CTILDE). */
    addi s2, s2, 16
#endif

    /* This loop:
         - decomposes each polynomial w[i] into w0[i] and w1[i]
         - packs w1[i] and sends it to the Keccak core
         - records the nonzero high bits of w1[i] for later use

       Afterwards, the w1[i] value can be discarded, so we do not need to keep
       two w-sized polyvecs in scope at once. */
    loopi K, 14
        /* Decompose w and store w0 in-place, w1 in tmp. */
        addi   a0, s0, 0
        addi   a1, s4, 0
        addi   a2, s0, 0
        jal    x1, poly_decompose
        /* Pack w1. */
        addi   a0, s2, 0
        addi   a1, s4, 0
        jal    x1, polyw1_pack
        /* Send packed w1 to the Keccak core. */
        addi   a0, s2, 0
        addi   a1, x0, POLYW1_PACKEDBYTES
        jal    x1, keccak_send_message
        /* Calculate the coefficients of w1 that are nonzero mod q, and store them. */
        addi   a0, s4, 0
        jal    x1, poly_nonzero_encode
        bn.sid x0, 0(s1++)
        /* Increment w pointer. */
        addi s0, s0, 1024

    /* Setup WDR */
    li t1, 8

    /* Read first 32 bytes of digest. */
    bn.wsrr w8, 0xA

    /* Get always-aligned temporary buffer. */
    la   t0, tmp_poly
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

    /* Challenge */
    /* CTILDE was temporarily stored in tmp_poly. Re-use here because it is aligned,
       for CTILDEBYTES = 48 as well */
    la   a0, c_poly
    la   a1, tmp_poly
    jal  x1, poly_challenge

    bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

    /* NTT(cp) */
    la   a0, c_poly /* Input */
    addi a2, a0, 0  /* Output inplace */
    jal  x1, ntt

    bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

    /* Load pointer to packed s1 */
    la   s0, sk
    addi s0, s0, 128

    /* Reset the nonce for y and set up a constant for poly_uniform_gamma1. */
    addi s8, s11, -L

    /* Save some pointers. */
    la   s2, tmp_poly
    la   s3, rhoprime
    la   s7, c_poly
    la   s9, sig
    addi s9, s9, CTILDEBYTES /* c is already packed */
    la   s10, gamma1_vec_const

    /* This loop computes z = (cp * s1) = y one element at a time, and does
       rejection sampling on each element before packing it into the signature. */
    .rept L
        /* Unpack the next polynomial from s1. */
        addi a0, s2, 0
        addi a1, s0, 0
        jal x1, polyeta_unpack
        /* Update the packed s1 pointer. */
        addi s0, a1, 0

        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

        /* Compute ntt(s1). */
        addi a0, s2, 0
        addi a2, s2, 0
        jal x1, ntt
        /* z = cp * s1 */
        addi a0, s2, 0
        addi a1, s7, 0
        addi a2, s2, 0
        jal  x1, poly_pointwise
        /* After poly_pointwise, w16 is still R | Q and MOD is still 2*R | 2*Q */

        /* Inverse NTT on z */
        addi a0, s2, 0
        jal x1, intt

        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* Sample the next value of y and add it to z. */
        addi a0, s2, 0
        addi a1, s3, 0
        addi a2, s8, 0
        addi a3, s10, 0
        jal  x1, poly_uniform_gamma_1

        /* Update the nonce for y. */
        addi s8, a2, 1

        /* reduce32(z) to move to mod^{+-} for bound check */
        addi a0, s2, 0
        addi a1, s2, 0
        jal x1, poly_reduce32

        /* chknorm */
        addi a0, s2, 0
        li   t0, GAMMA1
        li   t1, BETA
        sub  a1, t0, t1
        jal x1, poly_chknorm

        bne a2, x0, sign_attempt

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

    addi a0, s9, 0

    /* Load pointer to packed S2. */
    la   s0, sk
#if DILITHIUM_MODE == 2
    addi s2, s0, 512
#elif DILITHIUM_MODE == 3
    addi s2, s0, 768
#elif DILITHIUM_MODE == 5
    addi s2, s0, 800
#endif

    /* Load pointer to packed T0. */
#if DILITHIUM_MODE == 2
    addi s0, s0, 896
#elif DILITHIUM_MODE == 3
    addi s0, s0, 1536
#elif DILITHIUM_MODE == 5
    addi s0, s0, 1568
#endif

    /* s3 walks packed share 0 (608 B/poly), share 1 at s3 +
     * POLYVECK_BYTES.  hint_b2a_scratch re-`la`'d per use to keep s11
     * free for the y-sampling nonce on rejection. */
    la  s3, W0_POLYVEC
    la  s5, w1_repvec
    la  s7, c_poly
    la  s10, tmp_poly

    /* Initialize the coefficient sum for the hint for post-check. */
    li  s4, 0

    /* Initialize the counter for the index in the hint vector. */
    li  s6, 0

    /* Hint loop counter. */
    li  s8, K

    /* Normalize w0 to the [0, q) range (in-place). */
    addi   a0, s3, 0
    li     t1, 1
    la     t0, modulus
    bn.lid t1, 0(t0)
    LOOPI K, 6
        LOOPI 32, 4
            bn.lid      x0, 0(a0)
            bn.addv.8S  w0, w0, w1
            bn.addvm.8S w0, bn0, w0
            bn.sid      x0, 0(a0++)
        NOP

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
_mldsa_sign_hint_loop:

        /* Unpack the next polynomial from s2. */
        addi a0, s10, 0
        addi a1, s2, 0
        jal  x1, polyeta_unpack
        addi a0, a0, -1024

        /* Update the packed s2 pointer. */
        addi s2, a1, 0

        bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */

        /* Compute ntt(s2[i]) in-place. */
        addi a2, a0, 0
        jal x1, ntt

        /* tmp = cp * s2 */
        addi a0, s10, 0
        addi a1, s7, 0
        addi a2, s10, 0
        jal  x1, poly_pointwise

        /* Inverse NTT on tmp */
        addi a0, s10, 0
        jal x1, intt

        bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

        /* w0[i] -= tmp */
        addi a0, s3, 0
        addi a1, s10, 0
        addi a2, s3, 0
        jal  x1, poly_sub

        /* tmp = reduce32(w0[i]) to move to mod^{+-} for bound check */
        addi a0, s3, 0
        addi a1, s10, 0
        jal  x1, poly_reduce32

        /* chknorm(tmp, gamma2 - beta) */
        addi a0, s10, 0
        li   t0, GAMMA2 /* This li expands to 2 instructions */
        addi t1, x0, BETA
        sub  a1, t0, t1
        jal  x1, poly_chknorm

        /* Reject if ||rtilde|| >= gamma2 - beta on any lane. */
        bne a2, x0, sign_attempt

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
        addi a0, s3, 0
        addi a1, s10, 0
        addi a2, s3, 0
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
        bne a2, x0, sign_attempt

        /* h[i] = make_hint(w0[i], w1[i]) */
        addi   a0, s10, 0
        addi   a1, s3, 0
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
        bne t0, x0, sign_attempt

        /* Encode h[i] into the signature. */
        addi a0, s9, 0
        addi a1, s10, 0
        addi a3, s6, 0
        jal  x1, poly_encode_h

        /* Increment i. */
        addi s6, s6, 1
        /* Advance to next poly. */
        addi s3, s3, 1024
        /* Decrement remaining-iter count and loop while > 0. */
        addi s8, s8, -1
        bne  s8, x0, _mldsa_sign_hint_loop

    /* Return success and signature length */
    li a0, 0
    li a1, CRYPTO_BYTES
  ret

.bss

/* mu (64B) is supplied by the caller's data section in external-mu mode. */

/* rho' intermediate value (64B). */
.balign 32
rhoprime:
.zero 64

.balign 32
tmp_poly:
.zero 1024
.balign 32
.globl c_poly
c_poly:
y_poly:
.zero 1024

/* w1 representative vector (K*32B). */
.balign 32
w1_repvec:
#if DILITHIUM_MODE == 2
.zero 128
#elif DILITHIUM_MODE == 3
.zero 192
#elif DILITHIUM_MODE == 5
.zero 256
#endif

.balign 32
w0_polyvec:
.zero POLYVECK_BYTES
