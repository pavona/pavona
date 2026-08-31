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
#define N 256
#define Q 8380417
#define D 13

/* Worst-case (ML-DSA-87) polyvec size. */
#define POLYVECK_BYTES 8192

/* Offsets into the mldsa_params struct (in mldsa_consts.s). */
#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_L_OFFSET 4
#define MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET 24

/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/**
 * Dilithium Key Pair generation
 *
 * Returns: 0 on success
 *
 * @param[in]  dmem[zeta]: 32 random bytes
 * @param[in]  dmem[mldsa_params]: active mode parameters
 * @param[out] dmem[pk]: public key
 * @param[out] dmem[sk]: secret key
 *
 * clobbered registers: a0-a6, t0-t5, s1, w0-w30
 */
.globl crypto_sign_keypair
.type crypto_sign_keypair, @function
crypto_sign_keypair:
#ifdef HARDENED
  /* Masked gadgets use sp for stack frames. */
  la    x2, keygen_mask_stack_end
  /* Runtime parameters. */
  la    x27, mldsa_params
  /* Masked seed expansion: absorb d=2 zeta shares into masked SHAKE-256. */
  li    x11, SEEDBYTES
  addi  x11, x11, 2 /* SEEDBYTES+2 */
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  li    x14, 1
  slli  x14, x14, 20 /* masking-enable bit */
  add   x5, x5, x14
  csrrw x0, kmac_cfg, x5

  /* Refresh and absorb the Boolean shares of the seed. */
  la      x6, zeta_shares
  bn.wsrr w2, urnd
  bn.xor  w0, w0, w0            /* Whitening */
  bn.lid  x0, 0(x6)
  bn.xor  w0, w0, w2
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0            /* Whitening */
  bn.lid  x0, 32(x6)
  bn.xor  w0, w0, w2
  bn.wsrw kmac_msg1, w0

  /* K, L are public: share 1 = 0. */
  la      x6, poly_wdr2gpr
  li      x5, 1
  csrrw   x0, kmac_partial_write, x5
  lw      x7, MLDSA_PARAM_K_OFFSET(x27)
  sw      x7, 0(x6)
  bn.lid  x0, 0(x6)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.wsrw kmac_msg1, w0
  csrrw   x0, kmac_partial_write, x5
  lw      x7, MLDSA_PARAM_L_OFFSET(x27)
  sw      x7, 0(x6)
  bn.lid  x0, 0(x6)
  bn.wsrw kmac_msg, w0
  bn.xor  w0, w0, w0
  bn.wsrw kmac_msg1, w0

  /* Sec-unmask of rho (public): refresh shares with URND, then XOR-collapse. */
  la      x5, sk
  bn.wsrr w0, kmac_digest
  bn.wsrr w1, kmac_digest1
  bn.wsrr w2, urnd
  bn.xor  w0, w0, w2
  bn.xor  w1, w1, w2
  bn.xor  w0, w0, w1
  bn.sid  x0, 0(x5)
  /* rho': masked output to rho_prime_shares (share-major). */
  la      x6, rho_prime_shares
  li      x7, 1
  bn.wsrr w0, kmac_digest
  bn.wsrr w1, kmac_digest1
  bn.sid  x0, 0(x6)
  bn.sid  x7, 64(x6)
  bn.wsrr w0, kmac_digest
  bn.wsrr w1, kmac_digest1
  bn.sid  x0, 32(x6)
  bn.sid  x7, 96(x6)
  /* K: masked output to K_shares (K is unused by keygen). */
  la      x6, K_shares
  bn.wsrr w0, kmac_digest
  bn.wsrr w1, kmac_digest1
  bn.sid  x0, 0(x6)
  bn.sid  x7, 32(x6)

  /* Finish the SHAKE-256 operation. */

  bn.wsrr   w16, mod /* w16 = R | Q */

  bn.shv.8s w22, w16 << 1 /* w22 = 2*R | 2*Q */
  bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */

  /* Load destination pointer for matrix-vector multiplication. */
  la  x18, t_polyvec

  /* Load source pointers for matrix-vector multiplication. */
  la   x21, eta_out
  addi x26, x21, 1024
  addi x8, x18, 1024
  la  x9, keygen_tmp

  /* Zero the destination buffer (2*K share polynomials). */
  li x5, 31
  addi x6, x18, 0
  lw   x7, MLDSA_PARAM_K_OFFSET(x27)
  loop x7, 3
    loopi 32, 1
      bn.sid x5, 0(x6++)
    endloop
    nop
  endloop
  loop x7, 3
    loopi 32, 1
      bn.sid x5, 0(x6++)
    endloop
    nop
  endloop

  /* Load offset for resetting vector pointer (2 * K * 1024). */
  lw   x19, MLDSA_PARAM_K_OFFSET(x27)
  slli x19, x19, 11

  /* Initialize the nonce for matrix expansion. This value should be
       byte(i) || byte(j)
     for entry A[i][j]. */
  bn.xor w23, w23, w23

  /* Load pointer to rho. */
  la  x24, sk

  /* Initialize the nonce for sampling s1. */
  li   x22, 0

  /* Secret-key write cursor (masked packs only t0, here at sk+128). */
  la   x23, sk
  addi x23, x23, 128

  /* Precompute the SHAKE128 configuration for poly_uniform. */
  addi  x20, x0, 34
  slli  x20, x20, 5
  addi  x20, x20, SHAKE128_CFG

  /* Compute A * s1, computing elements of A on the fly.

     We compute column-wise so that we generate elements of s1 only once; in
     pseudocode, this computation does:

       for j in 0..l-1:
         s1j = ntt(s1[j])
         for i in 0..k-1:
           t[i] += A[i][j] * s1j
  */
  /* bne-based (not loopi) so masked_poly_uniform_eta's loop/secadd chain
     gets the full hardware loop stack. */
  lw   x25, MLDSA_PARAM_L_OFFSET(x27)
_matmul_col_loop:
    bn.wsrw   mod, w16 /* MOD = R | Q for the gadget */
    /* The gadget clobbers w0-w27; stash the matrix nonce. */
    li     x5, 23
    la     x6, matmul_nonce
    bn.sid x5, 0(x6)
    /* Masked ExpandS: s1[j] as arithmetic shares in eta_out. */
    addi x10, x21, 0
    la   x11, rho_prime_shares
    addi x12, x22, 0
    /* eta scratch reuses the unwritten sk t0 region (sk+128) and pk;
       both are K=8-sized, so this is mode-independent. */
    la   x13, sk
    addi x13, x13, 128
    la   x14, pk
    /* Expanded sk: export s1[j] bitsliced shares to s1s2_shares + j*2*P
       (2*POLYETA_PACKEDBYTES = 256 for ETA=4 (K=6), else 192). */
    la   x16, s1s2_shares
    lw   x5, MLDSA_PARAM_K_OFFSET(x27)
    li   x6, 6
    beq  x5, x6, _kg1_k6
    li   x15, 2                   /* eta = 2 (ML-DSA-44/87) */
    slli x5, x22, 7
    slli x6, x22, 6
    add  x5, x5, x6
    beq  x0, x0, _kg1_done
_kg1_k6:
    li   x15, 4                   /* eta = 4 (ML-DSA-65, k == 6) */
    slli x5, x22, 8
_kg1_done:
    add  x16, x16, x5
    jal  x1, masked_poly_uniform_eta_export
    addi x22, x22, 1
    li     x5, 23
    la     x6, matmul_nonce
    bn.lid x5, 0(x6)
    bn.wsrr w16, mod /* gadget left MOD = R | Q */
    /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
    csrrw x0, kmac_cfg, x20
    addi  x10, x24, 0
    bn.lid    x0, 0(x10)
    bn.wsrw   kmac_msg, w0
    addi      x5, x0, 2
    csrrw     x0, kmac_partial_write, x5
    bn.wsrw   kmac_msg, w23
    bn.shv.8s w22, w16 << 1 /* w22 = 2*R | 2*Q */
    bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */
    /* Stage forward twiddles once (eta gadget clobbered scratch); both
     * shares of s1[j] reuse them. */
    jal  x1, gen_twiddles_fwd
    /* ntt both shares of s1[j] in place. */
    addi x10, x21, 0
    addi x12, x21, 0
    la   x11, scratch
    jal  x1, ntt
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
    addi x10, x26, 0
    addi x12, x26, 0
    la   x11, scratch
    jal  x1, ntt
    lw   x5, MLDSA_PARAM_K_OFFSET(x27)
    loop x5, 24
      /* Compute A[i][j]. */
      addi x11, x9, 0
      jal  x1, poly_uniform
      /* Increment the row in the matrix nonce (upper byte). */
      bn.addi w23, w23, 256
      /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
      csrrw x0, kmac_cfg, x20
      addi  x10, x24, 0
      bn.lid    x0, 0(x10)
      bn.wsrw   kmac_msg, w0
      addi      x5, x0, 2
      csrrw     x0, kmac_partial_write, x5
      bn.wsrw   kmac_msg, w23
      /* t share 0 += A[i][j] * ntt(s1[j])_share0. */
      addi x10, x21, 0
      addi x11, x9, 0
      addi x12, x18, 0
      jal  x1, poly_pointwise_acc
      /* Whitening */
      bn.xor w0, w0, w0
      bn.xor w1, w1, w1
      /* t share 1 += A[i][j] * ntt(s1[j])_share1. */
      addi x10, x26, 0
      addi x11, x9, 0
      addi x12, x8, 0
      jal  x1, poly_pointwise_acc
      addi x18, x18, 1024
      addi x18, x18, 1024
      addi x8, x8, 1024
      addi x8, x8, 1024
    endloop
    /* Reset output vector pointers. */
    sub  x18, x18, x19
    sub  x8, x8, x19
    /* Increment the column index in the nonce by one. */
    bn.addi w23, w23, 1
    /* Reset the row index in the nonce to zero. */
    bn.rshi w23, w23, w31 >> 8
    bn.rshi w23, w31, w23 >> 248
    bne x22, x25, _matmul_col_loop

  /* After poly_pointwise, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /* Stage inverse twiddles once; both INTT clusters reuse them. */
  jal x1, _inv_transform
  /* Inverse NTT on t=A*s1 */
  la  x10, t_polyvec

  lw   x5, MLDSA_PARAM_K_OFFSET(x27)
  loop x5, 32
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
    la   x11, scratch
    jal  x1, intt
    addi x10, x10, 1024
  endloop
  lw   x5, MLDSA_PARAM_K_OFFSET(x27)
  loop x5, 32
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
    la   x11, scratch
    jal  x1, intt
    addi x10, x10, 1024
  endloop
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /* Load pointers for loop. */
  la   x18, t_polyvec
  addi x8, x18, 1024
  la   x9, keygen_tmp

  /* Initialize the nonce for sampling s2. */
  lw x22, MLDSA_PARAM_L_OFFSET(x27)

  /* This loop samples s2 and adds it to A*s1 (currently in the t buffer). */
  lw   x25, MLDSA_PARAM_L_OFFSET(x27)
  lw   x5, MLDSA_PARAM_K_OFFSET(x27)
  add  x25, x25, x5
_s2_sample_loop:
    /* Masked ExpandS: s2[i] as arithmetic shares in eta_out. */
    addi x10, x21, 0
    la   x11, rho_prime_shares
    addi x12, x22, 0
    /* eta scratch reuses the unwritten sk t0 region (sk+128) and pk;
       both are K=8-sized, so this is mode-independent. */
    la   x13, sk
    addi x13, x13, 128
    la   x14, pk
    /* Expanded sk: export s2[i] bitsliced shares to s1s2_shares + (L+i)*2*P. */
    la   x16, s1s2_shares
    lw   x5, MLDSA_PARAM_K_OFFSET(x27)
    li   x6, 6
    beq  x5, x6, _kg2_k6
    li   x15, 2                   /* eta = 2 (ML-DSA-44/87) */
    slli x5, x22, 7
    slli x6, x22, 6
    add  x5, x5, x6
    beq  x0, x0, _kg2_done
_kg2_k6:
    li   x15, 4                   /* eta = 4 (ML-DSA-65, k == 6) */
    slli x5, x22, 8
_kg2_done:
    add  x16, x16, x5
    jal  x1, masked_poly_uniform_eta_export
    addi x22, x22, 1
    /* t share 0 += s2[i]_share0. */
    addi x10, x21, 0
    addi x11, x18, 0
    addi x12, x18, 0
    jal  x1, poly_add
    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    /* t share 1 += s2[i]_share1. */
    addi x10, x26, 0
    addi x11, x8, 0
    addi x12, x8, 0
    jal  x1, poly_add
    /* Whitening */
    bn.xor w0, w0, w0
    bn.xor w1, w1, w1
    addi x18, x18, 1024
    addi x18, x18, 1024
    addi x8, x8, 1024
    addi x8, x8, 1024
    bne x22, x25, _s2_sample_loop

  /* Unmask t into t_polyvec[0:K*1024]. */
  la   x8, t_polyvec
  addi x9, x8, 0
  lw   x25, MLDSA_PARAM_K_OFFSET(x27)
_t_unmask_loop:
    addi x10, x9, 0
    addi x11, x8, 0
    jal  x1, secunmask_modq
    addi x8, x8, 1024
    addi x8, x8, 1024
    addi x9, x9, 1024
    addi x25, x25, -1
    bne  x25, x0, _t_unmask_loop
  la  x8, keygen_tmp

  /* Reset t pointer for power2round loop. */
  la  x9, t_polyvec

  lw   x5, MLDSA_PARAM_K_OFFSET(x27)
  loop x5, 9
    /* Split t polynomial into t0 (tmp buffer) and t1 (t buffer). */
    addi x10, x9, 0
    addi x11, x8, 0
    addi x12, x9, 0
    jal  x1, poly_power2round
    /* Pack the t0 polynomial into secret key. */
    addi x10, x23, 0
    addi x11, x8, 0
    jal  x1, polyt0_pack
    addi x23, x10, 0
    /* Increment polyvec pointer *t. */
    addi x9, x9, 1024
  endloop

  /* Pack pk. */
  la x10, pk

  /* Copy rho from secret key. */
  la     x6, sk
  bn.lid x0, 0(x6)
  bn.sid x0, 0(x10++)

  /* Load pointer to t1 */
  la  x11, t_polyvec

  /* Pack t1 */
  lw   x5, MLDSA_PARAM_K_OFFSET(x27)
  loop x5, 2
    jal x1, polyt1_pack
    nop
  endloop

  /* Hash pk */

  /* Initialize a SHAKE256 operation. */
  lw    x11, MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET(x27)
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, kmac_cfg, x5

  /* Send the message to the Keccak core. */
  la     x10, pk
  jal  x1, keccak_send_message

  /* Read the digest (tr) into the secret key.
     dmem[sk+64] <= SHAKE256(pk, 64) */
  la      x5, sk
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 64(x5)
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 96(x5)

  /* Finish the SHAKE-256 operation. */

  ret
#else
  la   x27, mldsa_params
  lw   x26, MLDSA_PARAM_K_OFFSET(x27)

  /* Initialize a SHAKE256 operation. */
  li    x11, SEEDBYTES
  addi  x11, x11, 2 /* SEEDBYTES+2 */
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, kmac_cfg, x5

  /* Send zeta to KMAC block. */
  la x10, zeta
  li x11, 32
  jal  x1, keccak_send_message

  /* Send K, L to KMAC block. */
  la      x6, poly_wdr2gpr
  li      x5, 1
  csrrw   x0, kmac_partial_write, x5
  sw      x26, 0(x6)
  bn.lid  x0, 0(x6)
  bn.wsrw kmac_msg, w0
  csrrw   x0, kmac_partial_write, x5
  lw      x7, MLDSA_PARAM_L_OFFSET(x27)
  sw      x7, 0(x6)
  bn.lid  x0, 0(x6)
  bn.wsrw kmac_msg, w0

  /* Squeeze into output buffers. Store rho and the key in sk. */
  la      x5, sk
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5++)
  la      x6, rhoprime
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x6++)
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x6)
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 0(x5)

  /* Finish the SHAKE-256 operation. */

  bn.wsrr   w16, mod /* w16 = R | Q */
  bn.shv.8s w22, w16 << 1 /* w22 = 2*R | 2*Q */
  bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */

  /* Load source pointers for matrix-vector multiplication. */
  la  x8, s1_poly
  la  x9, tmp_poly

  /* Load destination pointer for matrix-vector multiplication. */
  la  x18, t_polyvec

  /* Zero the destination buffer. */
  li x5, 31
  addi x6, x18, 0
  loop x26, 3
    loopi 32, 1
      bn.sid x5, 0(x6++)
    nop

  /* Load offset for resetting vector pointer (K * 1024). */
  slli x19, x26, 10

  /* Initialize the nonce for matrix expansion. This value should be
       byte(i) || byte(j)
     for entry A[i][j]. */
  bn.xor w23, w23, w23

  /* Load pointers to rho and rho'. */
  la  x24, sk
  la  x21, rhoprime

  /* Initialize the nonce for sampling s1. */
  li   x22, 0

  /* Load the destination for packed s1 within the secret key. */
  la   x23, sk
  addi x23, x23, 128

  /* Precompute the SHAKE128 configuration for poly_uniform. */
  addi  x20, x0, 34
  slli  x20, x20, 5
  addi  x20, x20, SHAKE128_CFG

  /* Compute A * s1, computing elements of A on the fly.

     We compute column-wise so that we generate elements of s1 only once; in
     pseudocode, this computation does:

       for j in 0..l-1:
         s1j = ntt(s1[j])
         for i in 0..k-1:
           t[i] += A[i][j] * s1j
  */
  lw x5, MLDSA_PARAM_L_OFFSET(x27)
  loop x5, 43
    bn.wsrw   mod, w16 /* MOD = R | Q */
    /* Sample the next polynomial from s1. */
    addi x10, x21, 0
    addi x11, x8, 0
    addi x12, x22, 0
    addi x14, x26, 0
    jal  x1, poly_uniform_eta
    addi x22, x22, 1
    /* Start the SHAKE128 operation for poly_uniform for A[0][j]. */
    csrrw x0, kmac_cfg, x20
    addi  x10, x24, 0
    bn.lid    x0, 0(x10)
    bn.wsrw   kmac_msg, w0
    addi      x5, x0, 2
    csrrw     x0, kmac_partial_write, x5
    bn.wsrw   kmac_msg, w23
    /* Pack the s1 polynomial into the secret key. */
    addi x10, x23, 0
    addi x11, x8, 0
    addi x14, x26, 0
    jal x1, polyeta_pack
    addi x23, x10, 0
    bn.wsrw   mod, w22 /* MOD = 2*R | 2*Q */
    /* Compute ntt(s1[j]). */
    addi x10, x8, 0
    addi x12, x8, 0
    jal  x1, ntt
    loop x26, 15
      /* Compute A[i][j]. */
      addi x11, x9, 0
      jal  x1, poly_uniform
      /* Increment the row in the matrix nonce (upper byte). */
      bn.addi w23, w23, 256
      /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
      csrrw x0, kmac_cfg, x20
      addi  x10, x24, 0
      bn.lid    x0, 0(x10)
      bn.wsrw   kmac_msg, w0
      addi      x5, x0, 2
      csrrw     x0, kmac_partial_write, x5
      bn.wsrw   kmac_msg, w23
      /* Compute A[i][j] * s1[j] and add it to the output at index i. */
      addi x10, x8, 0
      addi x11, x9, 0
      addi x12, x18, 0
      jal  x1, poly_pointwise_acc
      /* Increment the output vector pointer *t. */
      addi x18, x18, 1024
    /* Reset output vector pointer. */
    sub  x18, x18, x19
    /* Increment the column index in the nonce by one. */
    bn.addi w23, w23, 1
    /* Reset the row index in the nonce to zero. */
    bn.rshi w23, w23, w31 >> 8
    bn.rshi w23, w31, w23 >> 248

  /* After poly_pointwise, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /* Inverse NTT on t=A*s1 */
  la  x10, t_polyvec

  loop x26, 2
    jal  x1, intt
    addi x10, x10, 1024 /* Go to next input polynomial */
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

  /* Load pointers for loop. */
  la  x8, tmp_poly
  la  x9, t_polyvec
  la  x19, rhoprime

  /* Initialize the nonce for sampling s2. */
  lw x22, MLDSA_PARAM_L_OFFSET(x27)

  /* This loop samples s2 and adds it to A*s1 (currently in the t buffer). */
  loop x26, 16
    /* Sample the next polynomial from s2 and store in temp buffer. */
    addi x10, x19, 0
    addi x11, x8, 0
    addi x12, x22, 0
    addi x14, x26, 0
    jal  x1, poly_uniform_eta
    addi x22, x22, 1
    /* Pack the s2 polynomial into the secret key. */
    addi x10, x23, 0
    addi x11, x8, 0
    addi x14, x26, 0
    jal  x1, polyeta_pack
    addi x23, x10, 0
    /* t[i] += s2 */
    addi x10, x8, 0
    addi x11, x9, 0
    addi x12, x9, 0
    jal  x1, poly_add
    /* Increment polyvec pointer *t. */
    addi x9, x9, 1024

  /* Reset t pointer for power2round loop. */
  la  x9, t_polyvec

  loop x26, 9
    /* Split t polynomial into t0 (tmp buffer) and t1 (t buffer). */
    addi x10, x9, 0
    addi x11, x8, 0
    addi x12, x9, 0
    jal  x1, poly_power2round
    /* Pack the t0 polynomial into secret key. */
    addi x10, x23, 0
    addi x11, x8, 0
    jal  x1, polyt0_pack
    addi x23, x10, 0
    /* Increment polyvec pointer *t. */
    addi x9, x9, 1024

  /* Pack pk. */
  la x10, pk

  /* Copy rho from secret key. */
  la     x6, sk
  bn.lid x0, 0(x6)
  bn.sid x0, 0(x10++)

  /* Load pointer to t1 */
  la  x11, t_polyvec

  /* Pack t1 */
  loop x26, 2
    jal x1, polyt1_pack
    nop

  /* Hash pk */

  /* Initialize a SHAKE256 operation. */
  lw    x11, MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET(x27)
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, kmac_cfg, x5

  /* Send the message to the Keccak core. */
  la     x10, pk
  jal  x1, keccak_send_message

  /* Read the digest (tr) into the secret key.
     dmem[sk+64] <= SHAKE256(pk, 64) */
  la      x5, sk
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 64(x5)
  bn.wsrr w0, kmac_digest
  bn.sid  x0, 96(x5)

  /* Finish the SHAKE-256 operation. */

  ret
#endif
