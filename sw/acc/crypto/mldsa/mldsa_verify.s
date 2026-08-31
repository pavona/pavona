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
#define MLDSA_PARAM_CRYPTO_BYTES_OFFSET 44

/**
 * Hardened boolean values.
 *
 * Should match the values in `hardened_asm.h`.
 */
.equ HARDENED_BOOL_TRUE, 0x739
.equ HARDENED_BOOL_FALSE, 0x1d4

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
 * Dilithium Verify
 *
 * Returns: 0 on success
 *
 * All input DMEM buffers must be 32-byte aligned and initialized up to the
 * next 32B boundary so wide-reads succeed.
 *
 * @param[in]  x10: *sig, pointer to signature in DMEM
 * @param[in]  dmem[mu]: externally computed mu (64B)
 * @param[in]  dmem[mldsa_params]: active mode parameters
 * @param[in]  dmem[pk]: public key
 * @param[out] dmem[result]: HARDENED_BOOL_TRUE if valid, HARDENED_BOOL_FALSE otherwise
 */
.globl crypto_sign_verify_internal
.type crypto_sign_verify_internal, @function
crypto_sign_verify_internal:
  la   x27, mldsa_params

  /* Save signature pointer. */
  la  x5, dptr_sig
  sw  x10, 0(x5)

  /* Unpack sig */

  /* Unpack ctilde. CTILDEBYTES depends on K (= K*8 bytes). */
  la  x5, dptr_sig
  lw  x5, 0(x5)
  la  x6, ctilde
  lw  x7, MLDSA_PARAM_K_OFFSET(x27)
  li  x28, 4
  beq x7, x28, _ctilde_unpack_44
  li  x28, 6
  beq x7, x28, _ctilde_unpack_65
  /* ML-DSA-87 (K=8, CTILDEBYTES=64): two 32B copies. */
  bn.lid x0, 0(x5++)
  bn.sid x0, 0(x6++)
  bn.lid x0, 0(x5++)
  bn.sid x0, 0(x6++)
  jal x0, _ctilde_unpack_done
_ctilde_unpack_44:
  /* ML-DSA-44 (K=4, CTILDEBYTES=32): one 32B copy. */
  bn.lid x0, 0(x5++)
  bn.sid x0, 0(x6++)
  jal x0, _ctilde_unpack_done
_ctilde_unpack_65:
  /* ML-DSA-65 (K=6, CTILDEBYTES=48): the signature is not 32-byte aligned,
     so copy using GPRs. Zero-pad the remaining 16B to avoid bignum load
     errors at the later compare. */
  loopi 12, 4
    lw x28, 0(x5)
    sw x28, 0(x6)
    addi x5, x5, 4
    addi x6, x6, 4
  endloop
  loopi 4, 2
    sw x0, 0(x6)
    addi x6, x6, 4
  endloop
_ctilde_unpack_done:

  /* z is not 32-byte aligned for ML-DSA-65: GPR-copy it into w1_polyvec and
     unpack from there. z_bytes = CRYPTO_BYTES - CTILDEBYTES - OMEGA - K. */
  lw   x6, MLDSA_PARAM_CRYPTO_BYTES_OFFSET(x27)
  lw   x7, MLDSA_PARAM_K_OFFSET(x27)
  slli x28, x7, 3   /* CTILDEBYTES = K*8 */
  sub  x6, x6, x28
  lw   x28, MLDSA_PARAM_OMEGA_OFFSET(x27)
  sub  x6, x6, x28
  sub  x6, x6, x7  /* z_bytes (multiple of 4) */
  srli x6, x6, 2
  addi x25, x5, 0   /* walk the sig z-region; ends at the hint */
  la   x10, w1_polyvec
  loop x6, 4
    lw   x7, 0(x25)
    sw   x7, 0(x10)
    addi x25, x25, 4
    addi x10, x10, 4
  endloop

  /* x25 now points at the hint region. Unpack z from the aligned copy. */
  la   x11, w1_polyvec
  la   x10, z_polyvec
  lw   x14, MLDSA_PARAM_K_OFFSET(x27)
  lw   x5, MLDSA_PARAM_L_OFFSET(x27)
  loop x5, 2
    jal x1, polyz_unpack
    nop
  endloop

  /* reduce32(z) for central representation */
  la x10, z_polyvec
  la x11, w1_polyvec
  lw   x5, MLDSA_PARAM_L_OFFSET(x27)
  loop x5, 2
    jal x1, poly_reduce32
    nop
  endloop

  /* chknorm */
  lw   x11, MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET(x27)   /* GAMMA1 - BETA */
  la   x10, w1_polyvec
  li   x18, 0

  lw   x5, MLDSA_PARAM_L_OFFSET(x27)
  loop x5, 2
    jal x1, poly_chknorm
    or  x18, x18, x12
  endloop
  bne x18, x0, _fail_crypto_sign_verify_internal /* Raise error */

  /* External mu: dmem[mu] is supplied by the caller. */

  la  x10, c_poly
  la  x11, ctilde
  lw   x5, MLDSA_PARAM_K_OFFSET(x27)
  slli x12, x5, 3   /* CTILDEBYTES = K * 8 */
  lw   x13, MLDSA_PARAM_TAU_OFFSET(x27)
  jal x1, poly_challenge

  /* Prepare modulus */
  #define mod_x2 w22
  bn.wsrr   w16, 0x0 /* w16 = R | Q */
  bn.shv.8s mod_x2, w16 << 1 /* mod_x2 = 2*R | 2*Q */

  bn.wsrw 0x0, mod_x2 /* MOD = 2*R | 2*Q */
#ifdef HARDENED
  /* Stage the forward twiddle table once.  Nothing in verify clobbers
   * scratch, so it stays resident for NTT(z), NTT(c) and every per-row
   * ntt(t1). */
  jal  x1, gen_twiddles_fwd
#endif
  /* NTT(z) */
  la   x10, z_polyvec
  addi x12, x10, 0 /* inplace */

  lw x5, MLDSA_PARAM_L_OFFSET(x27)
#ifdef HARDENED
  loop x5, 4
    la   x11, scratch
#else
  loop x5, 2
#endif
    jal  x1, ntt
    addi x11, x11, -1024
  endloop

  /* Initialize the nonce for matrix expansion. This value should be
       byte(i) || byte(j)
     for entry A[i][j]. */
  bn.xor w23, w23, w23

  /* Precompute the SHAKE128 configuration for poly_uniform. */
  addi  x20, x0, 34
  slli  x20, x20, 5
  addi  x20, x20, SHAKE128_CFG

  /* Start the SHAKE computation for A[0][0] ahead of NTT for performance. */
  csrrw     x0, kmac_cfg, x20
  la        x10, pk
  bn.lid    x0, 0(x10)
  bn.wsrw   kmac_msg, w0
  addi      x5, x0, 2
  csrrw     x0, kmac_partial_write, x5
  bn.wsrw   kmac_msg, w23

  /* After NTT(z), w16 is still R | Q and MOD is still 2*R | 2*Q */
  /* NTT(c) */
  la   x10, c_poly
  addi x12, x10, 0 /* inplace */
#ifdef HARDENED
  la   x11, scratch
#endif
  jal  x1, ntt

  /* After NTT(c), w16 is still R | Q and MOD is still 2*R | 2*Q */

  /* Load source pointers for matrix-vector multiplication. */
  la  x8, z_polyvec
  la  x9, tmp_poly

  /* Load destination pointer for matrix-vector multiplication. */
  la  x18, w1_polyvec

  lw   x5, MLDSA_PARAM_L_OFFSET(x27)
  slli x19, x5, 10

  /* Load pointer to rho (first 32B of public key). */
  la x21, pk

  /* Compute A * z, computing elements of A on the fly. */
  lw x14, MLDSA_PARAM_K_OFFSET(x27)
  loop x14, 43
    /* Compute A[i][0]. */
    addi x11, x9, 0
    jal  x1, poly_uniform
    /* Increment the matrix nonce. */
    bn.addi w23, w23, 1
    /* Start the SHAKE128 operation for poly_uniform for A[i][1]. */
    csrrw     x0, kmac_cfg, x20
    bn.lid    x0, 0(x21)
    bn.wsrw   kmac_msg, w0
    addi      x5, x0, 2
    csrrw     x0, kmac_partial_write, x5
    bn.wsrw   kmac_msg, w23
    /* Compute A[i][0] * z[0] and set the output at index i. */
    addi x10, x8, 0
    addi x11, x9, 0
    addi x12, x18, 0
    jal  x1, poly_pointwise
    addi x8, x8, 1024
    lw x5, MLDSA_PARAM_L_OFFSET(x27)
    addi x5, x5, -1
    loop x5, 14
      /* Compute A[i][j]. */
      addi x11, x9, 0
      jal  x1, poly_uniform
      /* Increment the matrix nonce. */
      bn.addi w23, w23, 1
      /* Start the SHAKE128 operation for poly_uniform for A[i][j+1]. */
      csrrw     x0, kmac_cfg, x20
      bn.lid    x0, 0(x21)
      bn.wsrw   kmac_msg, w0
      addi      x5, x0, 2
      csrrw     x0, kmac_partial_write, x5
      bn.wsrw   kmac_msg, w23
      /* Compute A[i][j] * z[j] and add it to the output at index i. */
      addi x10, x8, 0
      addi x11, x9, 0
      addi x12, x18, 0
      jal  x1, poly_pointwise_acc
      addi x8, x8, 1024
    endloop
    /* Reset input vector pointer */
    sub  x8, x8, x19
    addi x18, x18, 1024
    /* Adjust the matrix nonce to reset the column and increment the row. */
    bn.addi w23, w23, 256
    lw x5, MLDSA_PARAM_L_OFFSET(x27)
    loop x5, 1
      bn.subi w23, w23, 1
    endloop
    /* Start the SHAKE128 operation for poly_uniform for A[i+1][j]. */
    csrrw     x0, kmac_cfg, x20
    bn.lid    x0, 0(x21)
    bn.wsrw   kmac_msg, w0
    addi      x5, x0, 2
    csrrw     x0, kmac_partial_write, x5
    bn.wsrw   kmac_msg, w23
  endloop

  /* Call random oracle and verify challenge */
  /* Initialize a SHAKE256 operation. */
  li x11, CRHBYTES
  lw x5, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x27)
  lw x14, MLDSA_PARAM_K_OFFSET(x27)
  loop x14, 1
    add x11, x11, x5
  endloop
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send mu to the Keccak core. */
  la  x10, mu
  li  x11, CRHBYTES /* set mu length to CRHBYTES */
  jal x1, keccak_send_message

  /* Load the pointer to the packed t1 within the public key. */
  la   x22, pk
  addi x22, x22, 32

  /* Initialize the counters for poly_decode_h. */
  li   x23, 0
  li   x24, 0

  /* Initialize failure buffer (0 on success, -1 on failure) */
  li   x26, 0

  /* This loop computes w1 polynomials and sends them to the Keccak core
     incrementally. This way, we avoid ever storing the entire w1 on the
     stack. */
  la  x9, w1_polyvec
  la  x19, tmp_poly
  la  x20, c_poly
#ifdef HARDENED
  /* z_polyvec is dead after the A*z matmul: copy the resident forward table
   * there, then turn scratch into the inverse table.  The per-row loop runs
   * ntt(t1) from z_polyvec and intt from scratch with no regeneration. */
  la     x5, scratch
  la     x6, z_polyvec
  li     x7, 0
  loopi 32, 2
    bn.lid x7, 0(x5++)
    bn.sid x7, 0(x6++)
  endloop
  jal    x1, _inv_transform
#endif
  lw  x14, MLDSA_PARAM_K_OFFSET(x27)
#ifdef HARDENED
  loop x14, 49
#else
  loop x14, 45
#endif
    /* Unpack the next polynomial from t1 and store it in temp buffer. */
    addi x10, x19, 0
    addi x11, x22, 0
    jal  x1, polyt1_unpack
    addi x22, x11, 0
    /* Shift-left of t1 polynomial. */
    addi x6, x19, 0
    loopi 32, 3
      bn.lid    x0, 0(x6)
      bn.shv.8s w0, w0 << D
      bn.sid    x0, 0(x6++)
    endloop
    /* Compute ntt(t1) in place. */
    addi x10, x19, 0
    addi x12, x19, 0
#ifdef HARDENED
    la   x11, z_polyvec
#endif
    jal  x1, ntt
    /* Compute cp * t1, storing the result in t1. */
    addi x10, x20, 0
    addi x11, x19, 0
    addi x12, x19, 0
    jal  x1, poly_pointwise
    /* Compute the next polynomial of w_approx = Az - t1. */
    addi x10, x9, 0
    addi x11, x19, 0
    addi x12, x9, 0
    jal x1, poly_sub
    /* Inverse NTT on w_approx (stored in w1 buffer). */
    addi x10, x9, 0
#ifdef HARDENED
    la   x11, scratch
#endif
    jal  x1, intt
    /* Decode the next polynomial from the hint and update the error register. */
    addi x10, x19, 0
    addi x11, x25, 0
    addi x12, x23, 0
    addi x13, x24, 0
    lw   x15, MLDSA_PARAM_K_OFFSET(x27)
    lw   x29, MLDSA_PARAM_OMEGA_OFFSET(x27)
    jal x1, poly_decode_h
    addi x25, x11, 0
    addi x23, x12, 0
    addi x24, x13, 0
    or   x26, x26, x14
    /* Use the hint to compute the next w1 polynomial. */
    addi x10, x9, 0
    addi x11, x9, 0
    addi x12, x19, 0
    lw   x14, MLDSA_PARAM_K_OFFSET(x27)
    jal  x1, poly_use_hint
    /* Pack the w1 polynomial (in-place). */
    addi x10, x9, 0
    addi x11, x9, 0
    jal  x1, polyw1_pack
    /* Send the packed w1 polynomial to the Keccak core. */
    addi x10, x9, 0
    lw   x11, MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET(x27)
    jal  x1, keccak_send_message
    addi x9, x9, 1024 /* increment *w1 */
  endloop

  bn.wsrr w8, 0xA /* KECCAK_DIGEST */

  /* Restore MOD = R | Q to avoid clobbering, unused from here on. */
  bn.wsrw mod, w16

  /* Check the failure register from the loop. */
  bne x26, x0, _fail_crypto_sign_verify_internal

  /* Setup WDR for c2 */
  li x6, 8

  /* Setup WDR for c */
  li x7, 9

  la     x5, ctilde
  bn.lid x7, 0(x5++)

  /* Check if c == c2 */
  bn.cmp w8, w9

  /* Get the FG0.Z flag into a register.
  x2 <= (CSRs[FG0] >> 3) & 1 = FG0.Z */
  csrrs x6, 0x7c0, x0
  srli  x6, x6, 3
  andi  x6, x6, 1

  beq x6, x0, _fail_crypto_sign_verify_internal

  /* If CTILDEBYTES == 32 (K=4), one 32B compare suffices. */
  lw   x6, MLDSA_PARAM_K_OFFSET(x27)
  li   x28, 4
  beq  x6, x28, _success_crypto_sign_verify_internal

  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  /* Remove upper 16B from digest in the case of CTILDEBYTES == 48 (K=6). */
  li   x28, 6
  bne  x6, x28, _skip_mask_ctilde
  bn.rshi w8, w8, w31 >> 128
  bn.rshi w8, w31, w8 >> 128
_skip_mask_ctilde:
  bn.lid x7, 0(x5++)

  /* Check if c == c2 */
  bn.cmp w8, w9

  /* Get the FG0.Z flag into a register.
  x2 <= (CSRs[FG0] >> 3) & 1 = FG0.Z */
  csrrs x5, 0x7c0, x0
  srli  x5, x5, 3
  andi  x5, x5, 1

  beq x5, x0, _fail_crypto_sign_verify_internal
  jal x0, _success_crypto_sign_verify_internal

  /* ------------------------ */

  /* Free space on the stack */
  addi x2, x3, 0
_success_crypto_sign_verify_internal:
  addi x10, x0, HARDENED_BOOL_TRUE
  la x11, result
  sw x10, 0(x11)
  ret

_fail_crypto_sign_verify_internal:
  addi x10, x0, HARDENED_BOOL_FALSE
  la x11, result
  sw x10, 0(x11)
  /*unimp*/
  ret
